import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:note123/filesync/remote_record.dart';
import 'package:note123/filesync/user.dart';
import 'package:note123/utils/app_logger.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:http/io_client.dart';

import 'sync_exception.dart';

class HttpApi {
  static int ResultSuccess = 200; //, "Operation succeeded"}
  static int ResultErrorRecordConflict = 531; //, "Record conflict"}
  static int ResultErrorDatabase = 532; //, "Database error"}
  static int ResultErrorRecordNotFound = 533; //, "Record not found"}
  static int ResultErrorParams = 534; //, "Parameter error"}
  static int ResultErrorFileSave = 535; //, "File save error"}
  static int ResultErrorFileNotFound = 536; //, "File not found"}
  static int ResultErrorNeedFullSync = 537; //, "Need full sync"} // client version < purgedVersion, must do a full pull
  static int ResultErrorUserPasswordError = 561; //, "User or password error"}

  // Client-side internal error codes (6xx range, avoid HTTP standard codes and server 531-561)
  static const int ClientErrorNetwork = 600;
  static const int ClientErrorTimeout = 601;
  static const int ClientErrorNoBaseUrl = 602;
  static const int ClientErrorDownloadFailed = 603;

  static String _baseUrl = "";
  static String get baseUrl => _baseUrl;

  /// Inject baseUrl, called by Repository.init / LoginDialog.
  static void setBaseUrl(String url) {
    _baseUrl = url;
  }

  // =========================================================================
  // 🎯 Global HttpClient — unified timeout, auto-attached to all http_api requests
  // =========================================================================
  // Duration constants
  static const Duration _connectTimeout = Duration(seconds: 15);
  static const Duration _receiveTimeout = Duration(seconds: 30);
  static const Duration _sendTimeout = Duration(seconds: 30);

  /// Singleton client, all API requests go through here
  static final Client _client = _createClient();

  static Client _createClient() {
    final ioClient = HttpClient()
      ..connectionTimeout = _connectTimeout
      ..idleTimeout = const Duration(seconds: 10)
      ..maxConnectionsPerHost = 8;
    return IOClient(ioClient);
  }

  // =========================================================================
  // 🎯 Request wrapper — exponential backoff retry
  // =========================================================================

  static Future<ApiResult<T>> _apiWrapper<T>(
    String name,
    Future<ApiResult<T>> Function(Client client, String baseUrl) func,
  ) async {
    try {
      final baseUrl = HttpApi.baseUrl;
      if (baseUrl.isEmpty) {
        return ApiResult(ClientErrorNoBaseUrl, "Sync server URL not configured", null);
      }
      AppLogger.i("ApiService.$name start");

      // Auto-retry on network exceptions (disconnect/timeout), exponential backoff 1s/2s/4s, max 3 retries.
      // Only retry network-layer exceptions, HTTP business error codes (like 531) do not retry
      const maxRetries = 3; // Total attempts = maxRetries + 1 (first + 3 retries)
      const retryDelays = [Duration(seconds: 1), Duration(seconds: 2), Duration(seconds: 4)];
      // Auto-relogin retry flag after 401, only allowed once (prevent infinite loop)
      bool triedRelogin = false;

      late ApiResult<T> result;
      for (;;) {
        for (int attempt = 0; attempt <= maxRetries; attempt++) {
          try {
            result = await func(_client, baseUrl);
            break;
          } on SocketException catch (e) {
            if (attempt >= maxRetries) rethrow;
            AppLogger.w("ApiService.$name network error, retry ${attempt + 1}: $e");
            await Future.delayed(retryDelays[attempt]);
          } on TimeoutException catch (e) {
            if (attempt >= maxRetries) rethrow;
            AppLogger.w("ApiService.$name request timeout, retry ${attempt + 1}: $e");
            await Future.delayed(retryDelays[attempt]);
          }
        }

        AppLogger.i("ApiService.$name success, code: ${result.code}, message: ${result.message}");

        if (result.code == 401 && !triedRelogin) {
          triedRelogin = true;
          final reason = result.authReason;
          final isExpired = reason == 'expired';
          if (isExpired) {
            // Token more than half its lifetime remaining: auto relogin with cached password to renew
            AppLogger.w("ApiService.$name received 401(expired), attempting auto relogin...");
            final ok = await User.instance.autoRelogin();
            if (ok) {
              AppLogger.i("ApiService.$name relogin succeeded, retrying original request");
              continue; // Re-run for loop
            }
            // autoRelogin failed (password not in SP / password changed) → handle same as notfound
            AppLogger.w("ApiService.$name relogin failed, switching to manual login flow");
          } else {
            // notfound / null: truly expired / kicked / server restarted / parameter error
            AppLogger.w("ApiService.$name received 401(${reason ?? 'no-reason'}), manual login required");
          }
          await User.instance.clearToken();
          return ApiResult(401, "Auth failed, please login again", null);
        }

        return result;
      }
    } catch (e) {
      AppLogger.e("ApiService.$name error: $e");
      if (e is SocketException) {
        return ApiResult(ClientErrorNetwork, "Network error, check your connection", null);
      } else if (e is TimeoutException) {
        return ApiResult(ClientErrorTimeout, "Request timeout, please retry", null);
      }
      return ApiResult(SyncException.unknown, e.toString(), null);
    }
  }

  // =========================================================================
  // 🎯 All API Endpoints
  // =========================================================================

  static Future<ApiResult<LoginResult>> login(String name, String password) async {
    return _apiWrapper("login $name", (client, baseUrl) async {
      final resp = await client
          .post(
            Uri.parse('$baseUrl/user/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'name': name, 'password': password}),
          )
          .timeout(_receiveTimeout);
      if (resp.statusCode == 200) {
        var res = jsonDecode(resp.body);
        return ApiResult.success(LoginResult(res['userId'], res['token']));
      }
      return ApiResult.fromResponse(resp);
    });
  }

  static Future<ApiResult<FetchEntitesResult>> fetchRecords(
    int version, // Start version number, exclusive
    int limit,
  ) async {
    return _apiWrapper("fetchRecords $version", (client, baseUrl) async {
      var req = http.Request('GET', Uri.parse('$baseUrl/record/list?version=$version&limit=$limit'));
      setTokenToRequest(req);
      final resp = await Response.fromStream(await req.send().timeout(_receiveTimeout));
      if (resp.statusCode == 200) {
        var res = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        final List<RemoteRecord> data =
            (res['records'] as List?)?.map((e) => RemoteRecord.fromJson(e)).toList().cast<RemoteRecord>() ?? [];
        // Server abnormal responses may be missing fields, must have fallback, otherwise assigning to int directly throws TypeError
        final int purgedVersion = (res['purgedVersion'] as int?) ?? 0;
        return ApiResult.success(FetchEntitesResult(data, purgedVersion));
      }
      return ApiResult.fromResponse(resp);
    });
  }

  static Future<ApiResult<DownloadFileMeta>> downloadFile(String uuid, String toFile) async {
    return _apiWrapper("downloadFile $uuid $toFile", (client, baseUrl) async {
      var req = http.Request('GET', Uri.parse('$baseUrl/record/download?uuid=$uuid'));
      await setTokenToRequest(req);
      var response = await req.send().timeout(_receiveTimeout);
      if (response.statusCode == 200) {
        // Extract server-side record's fileVersion and md5 from response header,
        // used to verify file integrity and version correctness after download completes
        final headerFileVersion = int.tryParse(response.headers['x-record-fileversion'] ?? '') ?? 0;
        final headerMd5 = response.headers['x-record-md5'] ?? '';
        // Write to temp file first then rename: network interruption/response truncation won't leave corrupted file at the final path
        final tmpFile = File('$toFile.downloading');
        final file = File(toFile);
        final bakFile = File('$toFile.bak');
        IOSink? sink;
        try {
          await tmpFile.create(recursive: true);
          sink = tmpFile.openWrite();
          await response.stream.pipe(sink).timeout(Duration(seconds: 120));
          await sink.close();
          sink = null;
          // On Windows, rename does not overwrite existing files, first back up old file to .bak,
          // to avoid target file loss caused by delete-then-rename failure
          if (await file.exists()) {
            try {
              await file.rename(bakFile.path);
            } catch (e) {
              AppLogger.e("[downloadFile] failed to back up old file: $e");
            }
          }
          try {
            await tmpFile.rename(file.path); // Same directory rename, no cross-disk involved
          } catch (e) {
            AppLogger.e("[downloadFile] rename failed: $e");
            rethrow;
          }
          // Clean up backup file
          await bakFile.delete().catchError((_) => bakFile);
        } catch (e) {
          // close's own exception must not mask the original download error
          await sink?.close().catchError((_) {});
          if (await tmpFile.exists()) {
            await tmpFile.delete();
          }
          // When rename fails, target file has been moved to .bak, must restore it, otherwise user has no file to read temporarily
          if (!await file.exists() && await bakFile.exists()) {
            try {
              await bakFile.rename(file.path);
            } catch (restoreErr) {
              AppLogger.e("[downloadFile] failed to restore backup file: $restoreErr");
            }
          }
          rethrow;
        }
        return ApiResult.success(DownloadFileMeta(headerFileVersion, headerMd5));
      } else {
        return ApiResult.fromResponse(await Response.fromStream(response));
      }
    });
  }

  static Future<void> setTokenToRequest(http.BaseRequest req) async {
    req.headers['x-user-id'] = '${User.instance.id}';
    req.headers['x-token'] = User.instance.token ?? "";
  }

  static Future<ApiResult<RemoteRecord>> upsertRecord(
    String uuid,
    String path,
    String name,
    int createAt,
    int editAt,
    int fileEditAt,
    int locked,
    String reminder,
    String filePath,
    int version,
  ) async {
    return _apiWrapper("updateRecord $uuid $path$name $filePath", (client, baseUrl) async {
      var req = http.MultipartRequest('POST', Uri.parse('$baseUrl/record/update?uuid=$uuid'));
      await setTokenToRequest(req);
      req.fields['path'] = path;
      req.fields['name'] = name;
      req.fields['createAt'] = createAt.toString();
      req.fields['editAt'] = editAt.toString();
      req.fields['fileEditAt'] = fileEditAt.toString();
      req.fields['locked'] = locked.toString();
      req.fields['reminder'] = reminder;
      req.fields['version'] = version.toString();
      if (filePath.isNotEmpty) {
        // If filePath is not empty, it means file needs to be uploaded
        req.files.add(await http.MultipartFile.fromPath('file', filePath, filename: uuid));
      }
      req.headers.remove('content-length');
      final resp = await Response.fromStream(await req.send().timeout(_sendTimeout + Duration(seconds: 30)));
      if (resp.statusCode == 200) {
        RemoteRecord record = RemoteRecord.fromJson(jsonDecode(utf8.decode(resp.bodyBytes)));
        return ApiResult.success(record);
      }
      // Conflict (531): server returns current record JSON, client marks conflict accordingly
      if (resp.statusCode == ResultErrorRecordConflict) {
        try {
          RemoteRecord record = RemoteRecord.fromJson(jsonDecode(utf8.decode(resp.bodyBytes)));
          return ApiResult(ResultErrorRecordConflict, "Note conflict", record);
        } catch (_) {
          // fallthrough
        }
      }
      return ApiResult.fromResponse(resp);
    });
  }

  static Future<ApiResult<RemoteRecord>> deleteRecord(String uuid) async {
    return _apiWrapper("deleteRecordById $uuid", (client, baseUrl) async {
      var req = http.Request('POST', Uri.parse('$baseUrl/record/delete?uuid=${Uri.encodeComponent(uuid)}'));
      await setTokenToRequest(req);
      final resp = await Response.fromStream(await req.send().timeout(_receiveTimeout));
      if (resp.statusCode == 200) {
        RemoteRecord record = RemoteRecord.fromJson(jsonDecode(utf8.decode(resp.bodyBytes)));
        return ApiResult.success(record);
      }
      return ApiResult.fromResponse(resp);
    });
  }

  static Future<ApiResult<List<APIStat>>> fetchAPIStats() async {
    return _apiWrapper("fetchAPIStats", (client, baseUrl) async {
      var req = http.Request('GET', Uri.parse('$baseUrl/api_stat/list'));
      setTokenToRequest(req);
      final resp = await Response.fromStream(await req.send().timeout(_receiveTimeout));
      if (resp.statusCode == 200) {
        final List data = jsonDecode(utf8.decode(resp.bodyBytes));
        return ApiResult.success(data.map((e) => APIStat.fromJson(e)).toList());
      }
      return ApiResult.fromResponse(resp);
    });
  }

  /// GET /upgrade/check —— 公开接口, 不需要登录 token
  /// 只传 platform, 服务端永远返回最新版本; 客户端自行对比判断是否有更新
  static Future<ApiResult<VersionInfo>> checkUpgrade(String platform) async {
    return _apiWrapper("checkUpgrade $platform", (client, baseUrl) async {
      final resp = await client
          .get(Uri.parse('$baseUrl/upgrade/check?platform=$platform'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final json = jsonDecode(utf8.decode(resp.bodyBytes));
        return ApiResult.success(VersionInfo.fromJson(json));
      }
      return ApiResult.fromResponse(resp);
    });
  }
}

class LoginResult {
  final int userId;
  final String token;

  LoginResult(this.userId, this.token);
}

class FetchEntitesResult {
  final List<RemoteRecord> records;
  final int purgedVersion; // The maximum purged value (inclusive). In other words, it is the lower bound of your safe history data.
  // As long as your data version number yourVersion < purgedVersion, that data has been physically deleted from the server.
  // You need to perform a full data pull; otherwise, data deleted on the server in the range (yourVersion, purgedVersion] will
  // never be known to you.

  FetchEntitesResult(this.records, this.purgedVersion);
}

/// Record metadata carried in download file response, used to verify file integrity and version
class DownloadFileMeta {
  final int fileVersion;
  final String md5;
  DownloadFileMeta(this.fileVersion, this.md5);
}

/// Upgrade check response from /upgrade/check?platform=xxx
class VersionInfo {
  final String platform;
  final String versionName;
  final String changelog;
  final String md5;
  final String downloadUrl;

  VersionInfo({
    required this.platform,
    required this.versionName,
    required this.changelog,
    required this.md5,
    required this.downloadUrl,
  });

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    return VersionInfo(
      platform: json['platform'] ?? '',
      versionName: json['versionName'] ?? '',
      changelog: json['changelog'] ?? '',
      md5: json['md5'] ?? '',
      downloadUrl: json['downloadUrl'] ?? '',
    );
  }
}

class ApiResult<T> {
  final int code;
  final String message;
  final T? data;
  final String?
  authReason; // Only present when code=401: "expired" = auto-relogin possible, null = manual login required

  ApiResult(this.code, this.message, this.data, {this.authReason});

  bool isSuccess() {
    return code == 200;
  }

  static ApiResult<T> success<T>(T data) {
    return ApiResult(200, "OK", data);
  }

  static ApiResult<T> fromResponse<T>(Response resp) {
    return ApiResult(resp.statusCode, resp.body, null, authReason: resp.headers['x-auth-reason']);
  }
}

class APIStat {
  final String apiName;
  final int count;
  final int lastCallTime;

  APIStat(this.apiName, this.count, this.lastCallTime);

  factory APIStat.fromJson(Map<String, dynamic> json) {
    return APIStat(json['apiName'], json['count'], json['lastCallTime']);
  }
}
