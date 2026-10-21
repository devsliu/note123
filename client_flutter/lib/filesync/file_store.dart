import 'dart:async';
import 'dart:io';

import 'package:notee/filesync/database.dart';
import 'package:notee/filesync/http_api.dart';
import 'package:notee/utils/app_logger.dart';
import 'package:path/path.dart';



class _DownloadFile {
  final String uuid;
  final Future<void> future;
  _DownloadFile(this.uuid, this.future);
}

/// Simple semaphore to limit concurrent operations (await acquire() before use, release() when done).
class _Semaphore {
  final List<Completer<void>> _waiters = [];
  int _available;

  _Semaphore(int limit) : _available = limit;

  Future<void> acquire() {
    if (_available > 0) {
      _available--;
      return Future.value();
    }
    final c = Completer<void>();
    _waiters.add(c);
    return c.future;
  }

  void release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete();
    } else {
      _available++;
    }
  }
}

enum ContentFileEventType { create, delete, move, download }

class ContentFileEvent {
  final String uuid;
  final ContentFileEventType type;
  ContentFileEvent(this.uuid, this.type);
}

class FileStore {
  final String rootDir;
  late final String baseFilesDir;
  late final String workFilesDir;
  late final String recyclerFilesDir;
  final Map<String, _DownloadFile> _downloadFiles = {};
  AppDatabase? db;
  bool _closed = false;

  final _controller = StreamController<ContentFileEvent>.broadcast();
  Stream<ContentFileEvent> get onContentChanged => _controller.stream;

  Future<void> close() async {
    _closed = true;
    // Do NOT await in-flight downloads. HttpApi.downloadFile has no Dart-side
    // cancellation; they'll complete naturally but downloadBaseFile's _closed
    // guards and the db?. nullable access protect against using closed DB.
    _downloadFiles.clear();
  }

  FileStore(this.rootDir) {
    baseFilesDir = join(rootDir, "base_files");
    workFilesDir = join(rootDir, "work_files");
    recyclerFilesDir = join(rootDir, "recycler");
    var files = Directory(baseFilesDir);
    if (!files.existsSync()) {
      files.createSync(recursive: true);
    }
    files = Directory(workFilesDir);
    if (!files.existsSync()) {
      files.createSync(recursive: true);
    }
    files = Directory(recyclerFilesDir);
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
      _fireChanged(uuid, ContentFileEventType.delete);
    }
  }

  String getBaseFile(String uuid) {
    return join(baseFilesDir, uuid);
  }

  void deleteBaseFile(String uuid) {
    final file = File(getBaseFile(uuid));
    if (file.existsSync()) {
      file.deleteSync();
      _fireChanged(uuid, ContentFileEventType.delete);
    }
  }

  String getRecyclerFile(String uuid) {
    return join(recyclerFilesDir, uuid);
  }

  bool isRecyclerFileExist(String uuid) {
    return File(getRecyclerFile(uuid)).existsSync();
  }

  void deleteRecyclerFile(String uuid) {
    final file = File(getRecyclerFile(uuid));
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
        _fireChanged(uuid, ContentFileEventType.move);
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
        AppLogger.e('FileStore', "[moveWorkFileToBase] uuid=$uuid failed to back up old base: $e");
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
        AppLogger.e('FileStore', "[moveWorkFileToBase] uuid=$uuid copy succeeded but deleting work failed: $e");
      }
    }
    // 3. Clean up backup
    if (bakFile.existsSync()) {
      try {
        bakFile.deleteSync();
      } catch (e) {
        AppLogger.e('FileStore', "[moveWorkFileToBase] uuid=$uuid failed to clean up backup: $e");
      }
    }
    _fireChanged(uuid, ContentFileEventType.move);
  }

  /// Move the record's content file into the recycler folder (work file preferred, base file as
  /// fallback). The base file is not kept: it is the stale synced baseline, and restore re-creates
  /// the record as a pure local edit (next sync pushes it as new, base is re-derived from work).
  void moveFileToRecycler(String uuid) {
    final workFile = File(getWorkFile(uuid));
    final baseFile = File(getBaseFile(uuid));
    if (workFile.existsSync()) {
      _moveFile(workFile, File(getRecyclerFile(uuid)));
      // Base is the stale synced baseline; delete it so it cannot be mistaken for live content.
      if (baseFile.existsSync()) {
        try {
          baseFile.deleteSync();
        } catch (e) {
          AppLogger.e('FileStore', "[moveFileToRecycler] uuid=$uuid failed to delete stale base file: $e");
        }
      }
      _fireChanged(uuid, ContentFileEventType.move);
    } else if (baseFile.existsSync()) {
      _moveFile(baseFile, File(getRecyclerFile(uuid)));
      _fireChanged(uuid, ContentFileEventType.move);
    }
  }

  /// Move the recycler content file back into the work folder.
  void moveRecyclerFileToWork(String uuid) {
    final src = File(getRecyclerFile(uuid));
    if (!src.existsSync()) return;
    _moveFile(src, File(getWorkFile(uuid)));
    _fireChanged(uuid, ContentFileEventType.move);
  }

  /// Move a work content file back into the recycler folder (rollback compensation).
  void moveWorkFileToRecycler(String uuid) {
    final src = File(getWorkFile(uuid));
    if (!src.existsSync()) return;
    _moveFile(src, File(getRecyclerFile(uuid)));
    _fireChanged(uuid, ContentFileEventType.move);
  }

  void _moveFile(File src, File dst) {
    try {
      // Windows rename does not overwrite existing files, remove target first
      if (dst.existsSync()) {
        dst.deleteSync();
      }
      src.renameSync(dst.absolute.path);
    } on FileSystemException {
      // When source/target are on different filesystems (e.g. mounted drives/removable storage),
      // rename will fail; fall back to copy+delete to ensure content is not lost
      src.copySync(dst.absolute.path);
      src.deleteSync();
    }
  }

  /// Download base file. Determine whether download is needed by comparing server-side remoteFileVersion
  /// with local baseFileVersion (remoteFileVersion > baseFileVersion or file does not exist).
  /// Save baseFileVersion after successful download, never clear it.
  Future<bool> downloadBaseFile(String uuid) async {
    File file = File(getBaseFile(uuid));

    if (_closed) {
      AppLogger.i('FileStore', "download uuid=$uuid skipped — fileStore closed");
      return false;
    }

    // Register placeholder completer first (synchronous, no await, guarantees atomicity).
    // Subsequent concurrent calls will wait on previous.future, eliminating races where two calls download simultaneously.
    final completer = Completer<void>();
    final entry = _DownloadFile(uuid, completer.future);
    final previous = _downloadFiles[uuid];
    _downloadFiles[uuid] = entry;

    try {
      if (previous != null) {
        await previous.future;
      }

      if (_closed) {
        AppLogger.i('FileStore', "download uuid=$uuid aborted — fileStore closed");
        return false;
      }

      final record = await db?.getRecord(uuid);

      if (file.existsSync() && record != null && record.local.remoteFileVersion <= record.local.baseFileVersion) {
        return true;
      }

      if (_closed) return false;
      final result = await HttpApi.downloadFile(uuid, getBaseFile(uuid));

      if (!result.isSuccess() || result.data == null) {
        AppLogger.e('FileStore', "download uuid=$uuid download failed ${result.message}");
        // Server returned "file not found", meaning this record has no file; reset local flag
        // to avoid retrying download on next loadContent
        if (result.code == HttpApi.kResultErrorFileNotFound) {
          await db?.updateRecord(uuid, fileEditAt: 0);
        }
        return false;
      }

      final meta = result.data!;
      // During download, the record in DB may have been updated by sync flow; re-read latest expected state
      final latestRecord = await db?.getRecord(uuid);
      final latestFileVersion = latestRecord?.local.remoteFileVersion ?? 0;
      // Verify fileVersion: downloaded file version must >= latest expected to prevent stale files
      if (meta.fileVersion < latestFileVersion) {
        AppLogger.e('FileStore', 
          "download uuid=$uuid fileVersion mismatch, expected>=$latestFileVersion actual=${meta.fileVersion}",
        );
        return false;
      }

      // 切换用户/关闭资源后, fileStore._closed 已置位, 跳过 DB 更新和事件派发:
      // 避免对正在关闭的 db 写入 (拖慢 db.close), 也避免触发已关闭的 searchIndex.refresh 报错
      if (_closed) {
        AppLogger.i('FileStore', "download uuid=$uuid skipped post-download — fileStore closed");
        return false;
      }

      // Download succeeded, update DB: write server fileVersion to baseFileVersion, never clear.
      // Also update remoteMd5 to current file md5.
      // DB update failure does not affect download result: file is already written to disk,
      // just means it will be re-downloaded next time, no data loss.
      try {
        await db?.updateRecord(uuid, baseFileVersion: meta.fileVersion, remoteMd5: meta.md5);
      } catch (e) {
        AppLogger.e('FileStore', "download uuid=$uuid failed to update baseFileVersion: $e");
      }

      try {
        AppLogger.i('FileStore', "download base file $uuid");
      } catch (e) {
        AppLogger.e('FileStore', "download uuid=$uuid failed to record operate log: $e");
      }
      if (!isWorkFileExist(uuid)) {
        _fireChanged(uuid, ContentFileEventType.download);
      }
      return true;
    } catch (e) {
      rethrow;
    } finally {
      if (!completer.isCompleted) {
        completer.complete();
      }
      // Only remove our own entry; a newer concurrent call may have overwritten
      // it, and removing theirs would break the dedup chain.
      if (identical(_downloadFiles[uuid], entry)) {
        _downloadFiles.remove(uuid);
      }
    }
  }

  /// Batch download base files with concurrency limit. Internally deduplicates by uuid;
  /// failures only log, do not throw. All downloads are guaranteed to not race on the
  /// same uuid by downloadBaseFile's own _downloadFiles deduplication.
  static const int _downloadConcurrency = 4;

  Future<void> downloadBaseFiles(Iterable<String> uuids) async {
    final Set<String> unique = uuids.toSet();
    if (unique.isEmpty || _closed) return;

    final queue = List<String>.from(unique);
    final sem = _Semaphore(_downloadConcurrency);
    final List<Future<void>> tasks = [];

    for (final uuid in queue) {
      if (_closed) break;
      final task = sem.acquire().then((_) async {
        try {
          if (!_closed) await downloadBaseFile(uuid);
        } catch (e) {
          if (!_closed) {
            AppLogger.e('FileStore', "downloadBaseFiles failed uuid=$uuid: $e");
          }
        } finally {
          sem.release();
        }
      });
      tasks.add(task);
    }

    await Future.wait(tasks).catchError((e) {
      if (!_closed) {
        AppLogger.e('FileStore', "downloadBaseFiles batch failed: $e");
      }
      return <void>[];
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
        AppLogger.e('FileStore', "[createWorkFile] uuid=$uuid failed to back up old file, trying direct delete: $e");
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
          AppLogger.e('FileStore', "[createWorkFile] uuid=$uuid failed to restore backup: $restoreErr");
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
    _fireChanged(uuid, ContentFileEventType.create);
  }

  void _fireChanged(String uuid, ContentFileEventType type) {
    _controller.add(ContentFileEvent(uuid, type));
  }
}
