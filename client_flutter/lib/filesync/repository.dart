import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:note123/filesync/database.dart';
import 'package:note123/filesync/table_operate.dart';
import 'package:note123/filesync/file_store.dart';
import 'package:note123/filesync/record_tree.dart';
import 'package:note123/filesync/reminder_tree.dart';
import 'package:note123/filesync/table_record.dart';
import 'package:note123/filesync/local_record_ext.dart';
import 'package:note123/filesync/sync_engine.dart' show SyncEngine, SyncState;
import 'package:note123/filesync/user.dart';
import 'package:note123/filesync/http_api.dart';
import 'package:note123/utils/app_logger.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class Repository {
  static const int fetchLimit = 200;
  static const _kApiUrl = 'api_url';
  static Repository? _instance;

  int _userId = 0;
  AppDatabase? _db;
  FileStore? _fileStore;
  String _baseUrl = '';
  SyncEngine? _syncEngine;

  AppDatabase? get db => _db;
  FileStore? get fileStore => _fileStore;

  DateTime? get lastSuccessfulPullTime => _syncEngine?.lastSuccessfulPullTime;

  final RecordTree recordTree = RecordTree();
  final ValueNotifier<SyncState> syncStateNotifier = ValueNotifier(SyncState(state: SyncState.idle));

  /// Shortcut to the reminder tree held by [recordTree].
  ReminderTree get reminderTree => recordTree.reminderTree;

  Repository._();
  static Repository get() => _instance!;

  static Future<void> init(String appRootDir) async {
    if (_instance != null) return;
    final sp = await SharedPreferences.getInstance();
    final baseUrl = sp.getString(_kApiUrl) ?? '';
    HttpApi.setBaseUrl(baseUrl);
    await User.instance.init();
    _instance = Repository._();
    _instance!._baseUrl = baseUrl;
    await _instance!._onUserChanged(appRootDir, User.instance.id);
    User.instance.isLogin.addListener(() {
      _instance?._onUserChanged(appRootDir, User.instance.id);
    });
  }

  Future<void> setApiUrl(String url) async {
    _baseUrl = url;
    HttpApi.setBaseUrl(url);
    final sp = await SharedPreferences.getInstance();
    if (url.isEmpty) {
      await sp.remove(_kApiUrl);
    } else {
      await sp.setString(_kApiUrl, url);
    }
  }

  String get apiUrl => _baseUrl;

  Future<void> _onUserChanged(String appRootDir, int userId) async {
    // Same user triggered repeatedly (token refresh, etc.), skip duplicate initialization
    if (_userId == userId) return;
    // Wait for ongoing sync to finish, prevent background sync from writing to closed DB and crashing
    await _syncEngine?.waitForSync();
    await _db?.close();
    _fileStore = null;
    _db = null;
    _syncEngine = null;
    recordTree.build([]);
    if (userId != 0) {
      _fileStore = FileStore(join(appRootDir, userId.toString()));
      _db = createRecordsDatabase(File(join(_fileStore!.rootDir, "records_v2.db")));
      _fileStore!.db = _db!;
      _syncEngine = SyncEngine(
        db: _db!,
        fileStore: _fileStore!,
        recordTree: recordTree,
        syncStateNotifier: syncStateNotifier,
      );
      recordTree.build(await _db!.getAllLocalRecords());
    }
    _userId = userId;
  }

  bool shouldSyncFromBackground() => _syncEngine?.shouldSyncFromBackground() ?? false;

  Future<void> syncRecordsFromBackground() async {
    if (shouldSyncFromBackground()) await syncRecords(false);
  }

  Future<void> waitForSync() async => await _syncEngine?.waitForSync();

  // =========================================================================
  // 🎯 CREATE / EDIT / DELETE — local write operations
  // =========================================================================

  Future<LocalRecord?> createRecord(String path, String name, bool sync, int localFileEditAt) async {
    if (_db == null || _fileStore == null) return null;
    int time = DateTime.now().millisecondsSinceEpoch;
    final uuid = Uuid().v4();
    await _db!.insertRecord(uuid: uuid, name: name, path: path, localFileEditAt: localFileEditAt, time: time);
    final record = (await _db!.getRecord(uuid))!;
    recordTree.insertRecord(record);
    await _db!.createOperate(Operates.typeLocal, "create record $uuid ${record.localPath}${record.localName}");
    _fileStore!.deleteWorkFile(uuid);
    if (sync) await syncRecords(false);
    return record;
  }

  /// Edit existing record. fileEdit=true means work file content also changed.
  /// md5: md5 of the work file content (post-encryption if locked).
  /// path/name/locked/md5: optional; when null the field is left unchanged.
  /// reminder: optional JSON string of reminder tasks; pass null to leave it unchanged.
  Future<LocalRecord?> editRecord(
    String uuid,
    bool fileEdit,
    int time, {
    String? path,
    String? name,
    int? locked,
    String? md5,
    String? reminder,
  }) async {
    if (_db == null) return null;
    AppDatabase db = _db!;

    final existing = await db.getRecord(uuid);
    if (existing == null) return null;

    await db.updateRecord(
      uuid,
      localPath: path,
      localName: name,
      localMd5: md5,
      localEditType: LocalEditType.edit,
      localEditAt: time,
      localFileEditAt: fileEdit ? time : null,
      localLocked: locked,
      localReminder: reminder,
    );

    final record = await db.getRecord(uuid);
    if (record != null) {
      await db.createOperate(
        Operates.typeLocal,
        "edit record ${record.uuid} ${record.localPath}${record.localName} version:${record.remoteVersion}, fileEdit:$fileEdit",
      );
      recordTree.insertRecord(record);
      unawaited(
        syncRecords(false).catchError((e) {
          AppLogger.e("[Repository] editLocalRecord sync failed: $e");
        }),
      );
    }
    return record;
  }

  /// Soft delete: mark localEditType=delete
  Future<void> deleteRecord(String uuid) async {
    if (_db == null) return;
    AppDatabase db = _db!;
    LocalRecord? record = await db.getRecord(uuid);
    int time = DateTime.now().millisecondsSinceEpoch;
    int count = await db.updateRecord(uuid, localEditType: LocalEditType.delete, localEditAt: time);
    if (count > 0) {
      recordTree.deleteRecord(uuid);
      await db.createOperate(
        Operates.typeLocal,
        "delete record ${record?.uuid} ${record?.localPath}${record?.localName} version:${record?.remoteVersion}",
      );
      await syncRecords(false);
    }
  }

  /// Physically purge local records that have never been successfully synced (remoteVersion==0) and their work files.
  Future<void> purgeUnsyncedRecord(String uuid) async {
    if (_db == null) return;
    final rows = await (_db!.delete(
      _db!.localRecords,
    )..where((t) => t.uuid.equals(uuid) & t.remoteVersion.equals(0))).go();
    if (rows == 0) return;
    _fileStore?.deleteWorkFile(uuid);
    recordTree.deleteRecord(uuid);
    await _db!.createOperate(Operates.typeLocal, "purge unsynced record $uuid (local creation rolled back)");
  }

  // =========================================================================
  // 🎯 RENAME FOLDER — path prefix replacement (SQL SUBSTR)
  // =========================================================================

  Future<void> renameFolder(String oldPath, String newPath) async {
    if (_db == null) return;
    AppDatabase db = _db!;
    final likePattern = '$oldPath%';
    final time = DateTime.now().millisecondsSinceEpoch;
    await db.createOperate(Operates.typeLocal, "rename folder $oldPath to $newPath");

    final tableName = db.localRecords.actualTableName;
    final localPathCol = db.localRecords.localPath.name;
    final remotePathCol = db.localRecords.remotePath.name;
    final editAtCol = db.localRecords.localEditAt.name;
    final typeCol = db.localRecords.localEditType.name;

    await db.customUpdate(
      'UPDATE $tableName '
      'SET $localPathCol = ? || SUBSTR($localPathCol, ?), '
      '    $remotePathCol = ? || SUBSTR($remotePathCol, ?), '
      '    $editAtCol = ?, '
      '    $typeCol = ${LocalEditType.edit} '
      'WHERE $localPathCol LIKE ? AND $typeCol != ${LocalEditType.delete}',
      variables: [
        Variable.withString(newPath),
        Variable.withInt(oldPath.runes.length + 1),
        Variable.withString(newPath),
        Variable.withInt(oldPath.runes.length + 1),
        Variable.withInt(time),
        Variable.withString(likePattern),
      ],
      updates: {db.localRecords},
    );

    recordTree.renameFolder(oldPath, newPath, time);
    await syncRecords(false);
  }

  Future<void> deleteFolder(String path) async {
    if (_db == null) return;
    AppDatabase db = _db!;
    if (path.isEmpty || path == '/' || !path.endsWith('/') || !path.startsWith('/')) {
      return;
    }

    final likePattern = '$path%';
    final time = DateTime.now().millisecondsSinceEpoch;
    final table = db.localRecords.actualTableName;
    final localPathCol = db.localRecords.localPath.name;
    final typeCol = db.localRecords.localEditType.name;
    final editAtCol = db.localRecords.localEditAt.name;

    int count = await db.customUpdate(
      'UPDATE $table '
      'SET $typeCol = ${LocalEditType.delete}, $editAtCol = ? '
      'WHERE $localPathCol LIKE ?',
      variables: [Variable.withInt(time), Variable.withString(likePattern)],
      updates: {db.localRecords},
    );
    await db.createOperate(Operates.typeLocal, "delete folder $path, records count:$count");
    recordTree.deleteFolder(path);
    await syncRecords(false);
  }

  // =========================================================================
  // 🎯 CONFLICT — detection and resolution
  // =========================================================================

  Future<List<LocalRecord>> getConflictRecords() async {
    if (_db == null) return [];
    return _db!.getSyncConflictRecords();
  }

  /// Resolve conflict.
  /// keepLocal=true:  keep local edits, align baseline, next push overwrites remote
  /// keepLocal=false: discard local edits, overwrite with remote version
  Future<void> resolveConflict(String uuid, bool keepLocal) async {
    if (_db == null || _fileStore == null) return;
    final db = _db!;
    final fileStore = _fileStore!;
    final record = await db.getRecord(uuid);
    if (record == null || !record.syncConflict) return;

    if (keepLocal) {
      // Only align baseline version, keep all local edits
      await db.updateRecord(uuid, localVersion: record.remoteVersion);
      final refreshed = await db.getRecord(uuid);
      if (refreshed != null) recordTree.insertRecord(refreshed);
    } else {
      // Discard local edits, fully overwrite with remote (same behavior as normal push success markSynced)
      await db.markSynced(uuid);
      fileStore.deleteWorkFile(uuid);
      final refreshed = await db.getRecord(uuid);
      if (refreshed != null) recordTree.insertRecord(refreshed);
    }

    final remaining = await db.getSyncConflictRecords();
    if (remaining.isEmpty) {
      syncStateNotifier.value = SyncState(state: SyncState.success);
    }
    await syncRecords(false);
  }

  // =========================================================================
  // 🎯 SYNC — delegate to SyncEngine
  // =========================================================================

  Future<void> syncRecords(bool forcePull) async {
    if (_syncEngine == null) return;
    await _syncEngine!.sync(forcePull);
  }
}
