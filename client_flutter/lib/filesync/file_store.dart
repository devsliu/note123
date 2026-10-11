import 'dart:async';
import 'dart:io';

import 'package:note123/filesync/database.dart';
import 'package:note123/filesync/http_api.dart';
import 'package:note123/filesync/table_record.dart';
import 'package:note123/utils/app_logger.dart';
import 'package:note123/utils/utils.dart';
import 'package:path/path.dart';

class _DownloadFile {
  final String uuid;
  final Future<void> future;
  _DownloadFile(this.uuid, this.future);
}

class FileStore {
  final String rootDir;
  late final String baseFilesDir;
  late final String workFilesDir;
  final Map<String, _DownloadFile> _downloadFiles = {};
  AppDatabase? db;

  FileStore(this.rootDir) {
    baseFilesDir = join(rootDir, "base_files");
    workFilesDir = join(rootDir, "work_files");
    var files = Directory(baseFilesDir);
    if (!files.existsSync()) {
      files.createSync(recursive: true);
    }
    files = Directory(workFilesDir);
    if (!files.existsSync()) {
      files.createSync(recursive: true);
    }
  }

  bool isWorkFileExist(String uuid) {
    return File(getWorkFile(uuid)).existsSync();
  }

  bool isBaseFileExist(String uuid) {
    return File(getBaseFile(uuid)).existsSync();
  }

  String getWorkFile(String uuid) {
    return join(workFilesDir, uuid);
  }

  void deleteWorkFile(String uuid) {
    final file = File(getWorkFile(uuid));
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  String getBaseFile(String uuid) {
    return join(baseFilesDir, uuid);
  }

  void deleteBaseFile(String uuid) {
    final file = File(getBaseFile(uuid));
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  void moveBaseFileToWorkIfWorkFileNotExist(String uuid) {
    var workFile = File(getWorkFile(uuid));
    if (!workFile.existsSync()) {
      var baseFile = File(getBaseFile(uuid));
      if (baseFile.existsSync()) {
        try {
          baseFile.renameSync(workFile.absolute.path);
        } on FileSystemException {
          // When base/work are on different filesystems (e.g. mounted drives/removable storage),
          // rename will fail; fall back to copy+delete to ensure content is not lost
          baseFile.copySync(workFile.absolute.path);
          baseFile.deleteSync();
        }
      }
    }
  }

  /// Promote work file to base file after successful upload (prefer rename on same disk,
  /// fall back to copy+delete across disks).
  /// On Windows, rename does not overwrite existing files, so use "backup old base → replace → cleanup backup"
  /// pattern to avoid base file loss caused by delete-then-rename failure
  void moveWorkFileToBase(String uuid) {
    final workFile = File(getWorkFile(uuid));
    if (!workFile.existsSync()) return;
    final basePath = getBaseFile(uuid);
    final baseFile = File(basePath);
    final bakPath = '$basePath.bak';
    final bakFile = File(bakPath);
    // 1. Back up old base to .bak (Windows rename does not overwrite, must move it first)
    if (baseFile.existsSync()) {
      try {
        baseFile.renameSync(bakPath);
      } catch (e) {
        AppLogger.e("[moveWorkFileToBase] uuid=$uuid failed to back up old base: $e");
      }
    }
    // 2. work → base
    try {
      workFile.renameSync(basePath);
    } on FileSystemException {
      workFile.copySync(basePath);
      try {
        workFile.deleteSync();
      } catch (e) {
        // copy succeeded but delete work failed: work file remains, will be re-uploaded next sync,
        // but base file is correctly written, does not affect user reading
        AppLogger.e("[moveWorkFileToBase] uuid=$uuid copy succeeded but deleting work failed: $e");
      }
    }
    // 3. Clean up backup
    if (bakFile.existsSync()) {
      try {
        bakFile.deleteSync();
      } catch (e) {
        AppLogger.e("[moveWorkFileToBase] uuid=$uuid failed to clean up backup: $e");
      }
    }
  }

  /// Download base file. Determine whether download is needed by comparing server-side remoteFileVersion
  /// with local baseFileVersion (remoteFileVersion > baseFileVersion or file does not exist).
  /// Save baseFileVersion after successful download, never clear it.
  Future<bool> downloadBaseFile(String uuid) async {
    File file = File(getBaseFile(uuid));

    // Register placeholder completer first (synchronous, no await, guarantees atomicity).
    // Subsequent concurrent calls will wait on previous.future, eliminating races where two calls download simultaneously.
    final completer = Completer<void>();
    final previous = _downloadFiles[uuid];
    _downloadFiles[uuid] = _DownloadFile(uuid, completer.future);

    Object? error;
    try {
      if (previous != null) {
        await previous.future;
      }

      final localRecord = await db?.getRecord(uuid);

      if (file.existsSync() && localRecord != null && localRecord.remoteFileVersion <= localRecord.baseFileVersion) {
        return true;
      }

      final result = await HttpApi.downloadFile(uuid, getBaseFile(uuid));

      if (!result.isSuccess() || result.data == null) {
        AppLogger.e("[downloadBaseFile] uuid=$uuid download failed ${result.message}");
        // Server returned "file not found", meaning this record has no file; reset local flag
        // to avoid retrying download on next loadContent
        if (result.code == HttpApi.ResultErrorFileNotFound) {
          await db?.updateRecord(uuid, localFileEditAt: 0);
        }
        return false;
      }

      final meta = result.data!;
      // During download, the record in DB may have been updated by sync flow; re-read latest expected state
      final latestRecord = await db?.getRecord(uuid);
      final latestFileVersion = latestRecord?.remoteFileVersion ?? 0;
      // Verify fileVersion: downloaded file version must >= latest expected to prevent stale files
      if (meta.fileVersion < latestFileVersion) {
        AppLogger.e(
          "[downloadBaseFile] uuid=$uuid fileVersion mismatch, expected>=$latestFileVersion actual=${meta.fileVersion}",
        );
        return false;
      }
      // Verify integrity: md5 in header must match actual file, to prevent truncation/corruption
      if (meta.md5.isNotEmpty && file.existsSync()) {
        final actualMd5 = await Utils.generateFileMd5(file: file);
        if (actualMd5 != meta.md5) {
          AppLogger.e("[downloadBaseFile] uuid=$uuid md5 mismatch, expected=${meta.md5} actual=$actualMd5");
          return false;
        }
      }

      // Download succeeded, update DB: write server fileVersion to baseFileVersion, never clear.
      // Also update remoteMd5 to current file md5.
      // DB update failure does not affect download result: file is already written to disk,
      // just means it will be re-downloaded next time, no data loss.
      try {
        await db?.updateRecord(uuid, baseFileVersion: meta.fileVersion, remoteMd5: meta.md5);
      } catch (e) {
        AppLogger.e("[downloadBaseFile] uuid=$uuid failed to update baseFileVersion: $e");
      }

      try {
        await db?.createOperate(Operates.typeDownload, "download base file $uuid");
      } catch (e) {
        AppLogger.e("[downloadBaseFile] uuid=$uuid failed to record operate log: $e");
      }
      return true;
    } catch (e) {
      error = e;
      rethrow;
    } finally {
      // Notify all waiters uniformly: success/failure both after DB update (or failed return),
      // ensuring waiters read the latest baseFileVersion and do not re-download
      if (!completer.isCompleted) {
        if (error != null) {
          completer.completeError(error);
        } else {
          completer.complete();
        }
      }
      _downloadFiles.remove(uuid);
    }
  }

  /// Batch download base files. Internally deduplicates by uuid; failures only log, do not throw.
  /// All downloads are guaranteed to not race on the same uuid by downloadBaseFile's own _downloadFiles deduplication.
  Future<void> downloadBaseFiles(Iterable<String> uuids) async {
    final Set<String> unique = uuids.toSet();
    if (unique.isEmpty) return;
    await Future.wait(
      unique.map(
        (uuid) => downloadBaseFile(uuid).catchError((e) {
          AppLogger.e("downloadBaseFiles failed uuid=$uuid: $e");
          return false;
        }),
      ),
    ).catchError((e) {
      AppLogger.e("downloadBaseFiles batch failed: $e");
      return <bool>[];
    });
  }

  /// Create/overwrite work file. Write to temp file first then rename (back up old file to .bak first),
  /// to avoid "delete then write" leaving missing or corrupted target file on write failure/process interruption
  Future<void> createWorkFile(String uuid, String content) async {
    final file = File(getWorkFile(uuid));
    final tmpFile = File('${file.path}.creating');
    final bakFile = File('${file.path}.bak');
    await tmpFile.writeAsString(content);
    if (await file.exists()) {
      try {
        await file.rename(bakFile.path);
      } catch (e) {
        // Old file cannot be moved (locked/permission), fall back to direct delete
        AppLogger.e("[createWorkFile] uuid=$uuid failed to back up old file, trying direct delete: $e");
        await file.delete();
      }
    }
    try {
      await tmpFile.rename(file.path);
    } catch (e) {
      // If rename fails and target is missing, restore backup so user always has the previous version readable
      if (!await file.exists() && await bakFile.exists()) {
        try {
          await bakFile.rename(file.path);
        } catch (restoreErr) {
          AppLogger.e("[createWorkFile] uuid=$uuid failed to restore backup: $restoreErr");
        }
      }
      rethrow;
    }
    if (await bakFile.exists()) {
      try {
        await bakFile.delete();
      } catch (_) {
        // Backup residue does not affect main flow, ignore
      }
    }
  }
}
