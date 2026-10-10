// Sync engine: complete sync state machine (lock + state + pull + push), Repository only does thin forwarding.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:drift/drift.dart';
import 'package:note123/filesync/database.dart';
import 'package:note123/filesync/record_tree.dart';
import 'package:note123/filesync/file_store.dart';
import 'package:note123/filesync/http_api.dart';
import 'package:note123/filesync/local_record_ext.dart';
import 'package:note123/filesync/remote_record.dart';
import 'package:note123/filesync/table_record.dart';
import 'package:note123/filesync/table_config.dart';
import 'package:note123/filesync/table_operate.dart';
import 'package:note123/utils/app_logger.dart';
import 'package:note123/filesync/sync_exception.dart';
import 'package:note123/filesync/user.dart';

class SyncState {
  static const int idle = 0;
  static const int syncing = 1;
  static const int success = 2;
  static const int error = 3;
  final int state;
  final String message;
  final int errorCode; // Only present when state=error, from SyncException.code

  SyncState({required this.state, this.message = "", this.errorCode = SyncException.unknown});
  bool get isError => state == error;
  bool get isConflict => state == error && errorCode == HttpApi.ResultErrorRecordConflict;
  bool get isAuthError => state == error && (errorCode == 401 || errorCode == HttpApi.ResultErrorUserPasswordError);
}

class SyncEngine {
  static const int fetchLimit = 200;

  final AppDatabase db;
  final FileStore fileStore;
  final RecordTree recordTree;
  final ValueNotifier<SyncState> syncStateNotifier;

  int _syncCount = 0; // 0=idle, 1=syncing, 2=syncing+queued
  Completer<void>? _syncTask;
  DateTime? _lastSuccessfulPullTime;
  final Duration _syncInterval = Duration(minutes: 10);

  DateTime? get lastSuccessfulPullTime => _lastSuccessfulPullTime;

  SyncEngine({required this.db, required this.fileStore, required this.recordTree, required this.syncStateNotifier});

  Future<void> waitForSync() async {
    if (_syncTask != null) await _syncTask!.future;
  }

  bool shouldSyncFromBackground() {
    if (_lastSuccessfulPullTime == null) return true;
    return DateTime.now().difference(_lastSuccessfulPullTime!) >= _syncInterval;
  }

  // =========================================================================
  // 🎯 SYNC — full state machine with lock + state + pull + push
  // =========================================================================

  Future<void> sync(bool forcePull) async {
    if (User.instance.id <= 0 || User.instance.token == null || User.instance.token!.isEmpty) {
      AppLogger.i("[SyncEngine] sync skipped — user not logged in");
      return;
    }

    if (forcePull) _lastSuccessfulPullTime = null;

    // Count +1 (capped at 2). Reentrant callers wait for chain to end, owner starts the chain.
    if (_syncCount < 2) _syncCount++;

    if (_syncTask != null) {
      AppLogger.i("[SyncEngine] sync queued (count=$_syncCount) — waiting for current chain");
      await _syncTask!.future;
      return;
    }

    final done = Completer<void>();
    _syncTask = done;
    do {
      try {
        await _runSync();
      } catch (e) {
        AppLogger.e(e.toString());
        if (e is SyncException) {
          syncStateNotifier.value = SyncState(state: SyncState.error, message: e.message, errorCode: e.code);
        } else {
          syncStateNotifier.value = SyncState(
            state: SyncState.error,
            message: e.toString(),
            errorCode: SyncException.unknown,
          );
        }
      } finally {
        _syncCount--;
      }
    } while (_syncCount > 0);
    _syncTask = null;
    done.complete(); // Wake all reentrant waiters
  }

  Future<void> _runSync() async {
    syncStateNotifier.value = SyncState(state: SyncState.syncing);

    DateTime now = DateTime.now();
    if (_lastSuccessfulPullTime == null || now.difference(_lastSuccessfulPullTime!) >= _syncInterval) {
      await pullRecords();
      _lastSuccessfulPullTime = now;
    }

    await pushRecords();

    // Check conflicts again after push
    var conflictList = await db.getSyncConflictRecords();
    if (conflictList.isNotEmpty) {
      syncStateNotifier.value = SyncState(
        state: SyncState.error,
        message: "Note conflict",
        errorCode: HttpApi.ResultErrorRecordConflict,
      );
      return;
    }

    syncStateNotifier.value = SyncState(state: SyncState.success);
  }

  // =========================================================================
  // 🎯 PULL — pull remote data, write to remote_*, detect conflicts
  // =========================================================================

  static Future<void> saveRemoteRecords(
    List<RemoteRecord> remoteRecords,
    int batchNo,
    AppDatabase db,
    FileStore fileStore,
    RecordTree recordTree,
  ) async {
    if (remoteRecords.isEmpty) return;
    final List<String> deleteUuids = [];
    final List<LocalRecord> upsertRecords = [];
    // Local file operations (fast, no network): delete/move files
    final List<void Function()> fileActions = [];
    // Base file downloads (slow, need HTTP): dedup with Set, only download once per uuid
    final Set<String> downloadUUids = {};

    await db.transaction(() async {
      final remoteUuids = remoteRecords.map((e) => e.uuid).toList();
      final localList = await (db.select(db.localRecords)..where((t) => t.uuid.isIn(remoteUuids))).get();
      final localMap = {for (var e in localList) e.uuid: e};

      for (var remote in remoteRecords) {
        var local = localMap.remove(remote.uuid);

        // === Local does not exist ===
        if (local == null) {
          if (remote.deleteAt > 0) {
            // Remote already deleted, no need to handle
            continue;
          }
          // Remote not deleted, save directly
          var newRecord = remote.toLocalRecord(batchNo);
          await db.replaceRecord(newRecord);
          await db.createOperate(
            Operates.typeDownload,
            "create record ${newRecord.uuid} ${newRecord.localPath}${newRecord.localName} version:${newRecord.remoteVersion}",
          );
          upsertRecords.add(newRecord);
          downloadUUids.add(remote.uuid);
        }
        // === Remote already deleted ===
        else if (remote.deleteAt > 0) {
          if (local.localEditType == LocalEditType.delete || local.localEditType == LocalEditType.none) {
            // Local deleted or local not modified: delete directly
            await (db.delete(db.localRecords)..where((t) => t.uuid.equals(remote.uuid))).go();
            deleteUuids.add(remote.uuid);
            fileActions.add(() {
              fileStore.deleteBaseFile(remote.uuid);
              fileStore.deleteWorkFile(remote.uuid);
            });
          } else {
            // Local modified, remote deleted, will push later
            // Remote already deleted, this one needs to be pushed to server later
            // Clear remote_* so push treats it as a new record via upsertRecord
            await db.clearRecordRemote(remote.uuid, batchNo: batchNo);
            final refreshed = await db.getRecord(remote.uuid);
            if (refreshed != null) upsertRecords.add(refreshed);
            // If local has no work file, try to copy downloaded source file to work file directory
            fileActions.add(() => fileStore.moveBaseFileToWorkIfWorkFileNotExist(remote.uuid));
          }
        }
        // === Remote not deleted ===
        else if (local.localEditType == LocalEditType.delete || local.localEditType == LocalEditType.none) {
          // ---- Local deleted or local not modified ----
          if (remote.version > local.remoteVersion) {
            // Remote version updated, undo local delete / align local state (handled by one replaceLocalRecord)
            var newRecord = remote.toLocalRecord(batchNo, baseFileVersion: local.baseFileVersion);
            await db.replaceRecord(newRecord);
            upsertRecords.add(newRecord);
            await db.createOperate(
              Operates.typeDownload,
              "edit record ${remote.uuid} ${remote.path}${remote.name} version:${remote.version}",
            );
            fileActions.add(() => fileStore.deleteWorkFile(remote.uuid));
            // Server file updated, download latest base (judge by fileVersion)
            if (local.baseFileVersion < remote.fileVersion) {
              downloadUUids.add(remote.uuid);
            }
          } else {
            // Remote version unchanged, will push directly (local delete/no-edit state stays unchanged)
          }
        }
        // Remote modified, local modified → conflict
        else if (remote.version > local.remoteVersion) {
          final localVersion = local.localVersion;
          // Remote version advanced → conflict
          await db.updateRecordRemote(remote.uuid, remote, batchNo: batchNo);
          // Base file modified, download latest base for diff comparison (judge by fileVersion)
          if (local.baseFileVersion < remote.fileVersion) {
            downloadUUids.add(remote.uuid);
          }
          final conflicted = await db.getRecord(remote.uuid);
          if (conflicted != null) upsertRecords.add(conflicted);
          await db.createOperate(
            Operates.typeDownload,
            "conflict record ${remote.uuid} ${remote.path}${remote.name} remoteV:${remote.version} localV:$localVersion",
          );
        }
        // Remote version unchanged, why did it get downloaded???
        else {
          AppLogger.w(
            "version equals ${remote.version} ${local.remoteVersion} ${remote.uuid} ${remote.path}${remote.name}",
          );
        }
      }
    }); // transaction ends, release DB lock

    recordTree.batchUpdateRecords(deleteUuids, upsertRecords);
    // UI already updated, run file actions in background without blocking sync return.
    // When user opens a record, loadContent will wait for downloadBaseFile internally (dedup by uuid).
    // Download failures must log, otherwise file loss goes unnoticed until user opens the record.

    // 1. Local file operations (fast, no network, synchronous execution)
    for (final action in fileActions) {
      try {
        action();
      } catch (e) {
        AppLogger.e("saveRemoteRecords local file action failed: $e");
      }
    }

    // 2. Base file downloads (slow, need HTTP, fire-and-forget)
    // When user opens a record, loadContent will wait for downloadBaseFile internally (dedup by uuid).
    unawaited(fileStore.downloadBaseFiles(downloadUUids));
  }

  Future<void> pullRecords() async {
    var batchNo = DateTime.now().millisecondsSinceEpoch;
    var lastVersion = await db.getConfigInt(KVConfigs.lastSyncedVersion, 0);
    bool isInFullPull = lastVersion <= 0;
    int purgedVersion = 0;

    while (true) {
      var fetchRecords = await HttpApi.fetchRecords(lastVersion, fetchLimit);
      if (!fetchRecords.isSuccess()) {
        throw SyncException(fetchRecords.message, null, fetchRecords.code);
      }

      final remotePurgedVersion = fetchRecords.data!.purgedVersion;
      if (lastVersion < remotePurgedVersion && (!isInFullPull || remotePurgedVersion > purgedVersion)) {
        isInFullPull = true;
        lastVersion = 0;
        purgedVersion = remotePurgedVersion;
        await db.createOperate(Operates.typeDownload, "full pull begin, purge version:$purgedVersion");
        continue;
      }

      final remoteRecords = fetchRecords.data!.records;
      if (remoteRecords.isNotEmpty) {
        await saveRemoteRecords(remoteRecords, batchNo, db, fileStore, recordTree);
        lastVersion = remoteRecords.map((t) => t.version).reduce(math.max);
      }
      if (remoteRecords.length < fetchLimit) {
        await db.setIntValue(KVConfigs.lastSyncedVersion, lastVersion);
        break;
      }
    }

    if (isInFullPull) {
      var list =
          await (db.select(db.localRecords)..where(
                (t) =>
                    (t.batchNo.equals(batchNo).not()) &
                    (t.remoteVersion.isSmallerOrEqualValue(purgedVersion)) &
                    (t.localEditType.equals(LocalEditType.none)),
              ))
              .get();
      var uuids = list.map((e) => e.uuid).toList();
      for (var uuid in uuids) {
        fileStore.deleteBaseFile(uuid);
        fileStore.deleteWorkFile(uuid);
      }
      recordTree.batchUpdateRecords(uuids, []);
      int count = await (db.delete(db.localRecords)..where((t) => t.uuid.isIn(uuids))).go();
      await db.createOperate(
        Operates.typeDownload,
        "full pull and delete $count records, purge version:$purgedVersion",
      );
    }
  }

  // =========================================================================
  // 🎯 PUSH — upload local edits to server
  // =========================================================================

  Future<void> pushRecords() async {
    // Push deletions first
    for (var localRecord in await db.getDeleteRecords()) {
      final result = await HttpApi.deleteRecord(localRecord.uuid);
      if (result.isSuccess() || result.code == HttpApi.ResultErrorRecordNotFound) {
        // Only delete DB + files on successful request, prevent data loss from network failure
        recordTree.deleteRecord(localRecord.uuid);
        await db.deleteRecord(localRecord.uuid);
        fileStore.deleteBaseFile(localRecord.uuid);
        fileStore.deleteWorkFile(localRecord.uuid);
        await db.createOperate(
          Operates.typeUpload,
          "delete record ${localRecord.uuid} ${localRecord.localPath}${localRecord.localName} version:${localRecord.remoteVersion}",
        );
      } else if (result.code == HttpApi.ResultErrorRecordConflict) {
        // Server rejected deletion (record modified by someone else), restore to latest remote state
        final remote = result.data!;
        final newRecord = remote.toLocalRecord(0, baseFileVersion: localRecord.baseFileVersion);
        int rows = await db.replaceRecord(newRecord);
        if (localRecord.baseFileVersion < remote.fileVersion) {
          await fileStore.downloadBaseFile(localRecord.uuid);
        }
        if (rows > 0) recordTree.insertRecord(newRecord);
      } else {
        throw SyncException(result.message, null, result.code);
      }
    }

    // Push edits second
    for (var localRecord in await db.getEditRecords()) {
      if (localRecord.syncConflict) continue;

      final file = File(fileStore.getWorkFile(localRecord.uuid));
      final fileExist = file.existsSync();

      final uploadPath = localRecord.localPath.isNotEmpty ? localRecord.localPath : localRecord.remotePath;
      final uploadName = localRecord.localName.isNotEmpty ? localRecord.localName : localRecord.remoteName;
      final baseVersion = localRecord.localVersion;
      final uploadFileEditAt = fileExist && localRecord.localFileEditAt > 0
          ? localRecord.localFileEditAt
          : localRecord.remoteFileEditAt;

      final result = await HttpApi.upsertRecord(
        localRecord.uuid,
        uploadPath,
        uploadName,
        localRecord.remoteCreateAt,
        localRecord.localEditAt > 0 ? localRecord.localEditAt : localRecord.remoteEditAt,
        uploadFileEditAt,
        localRecord.localLocked,
        fileExist ? file.absolute.path : '',
        baseVersion,
      );

      if (result.isSuccess()) {
        final newRemote = result.data!;
        // 若上传了文件, base 文件内容已更新为最新, baseFileVersion 必须跟随远端 fileVersion,
        // 否则后续 pull 会因 baseFileVersion 陈旧而重复下载或漏下载
        final newRecord = newRemote.toLocalRecord(
          0,
          baseFileVersion: fileExist ? newRemote.fileVersion : localRecord.baseFileVersion,
        );

        int rows =
            await (db.update(db.localRecords)..where(
                  (t) =>
                      t.uuid.equals(localRecord.uuid) &
                      t.localEditAt.equals(localRecord.localEditAt) &
                      t.localEditType.equals(localRecord.localEditType),
                ))
                .write(newRecord);

        if (rows == 0) {
          // Concurrent edit: only update remote_*, keep local edits
          await db.updateRecordRemote(localRecord.uuid, newRemote, localVersion: newRemote.version);
          final merged = await db.getRecord(localRecord.uuid);
          if (merged != null) recordTree.insertRecord(merged);
        } else {
          await db.createOperate(
            Operates.typeUpload,
            "edit record ${newRecord.uuid} ${newRecord.localPath}${newRecord.localName} version:${newRecord.remoteVersion}",
          );
          if (fileExist) fileStore.moveWorkFileToBase(localRecord.uuid);
          recordTree.insertRecord(newRecord);
        }
      } else if (result.code == HttpApi.ResultErrorRecordConflict) {
        final remote = result.data!;
        await db.updateRecordRemote(localRecord.uuid, remote);
        if (localRecord.baseFileVersion < remote.fileVersion) {
          await fileStore.downloadBaseFile(localRecord.uuid);
        }
        final refreshed = await db.getRecord(localRecord.uuid);
        if (refreshed != null) recordTree.insertRecord(refreshed);
      } else {
        throw SyncException(result.message, null, result.code);
      }
    }
  }
}
