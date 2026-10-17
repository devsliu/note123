import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:note123/filesync/database.dart';
import 'package:note123/filesync/file_store.dart';
import 'package:note123/filesync/record_tree.dart';
import 'package:note123/filesync/reminder_tree.dart';
import 'package:note123/filesync/tag_tree.dart';
import 'package:note123/filesync/table_record.dart';
import 'package:note123/filesync/record_ext.dart';
import 'package:note123/filesync/search_index.dart';
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

  /// Directory name for the local-only database used before any login.
  static const _guestDirName = 'guest';

  /// Path of the records SQLite file inside [dir].
  static String _dbFilePath(String dir) => join(dir, 'records0.db');
  static String _searchFilePath(String dir) => join(dir, 'search0.db');
  static Repository? _instance;

  int _userId = 0;
  AppDatabase? _db;
  FileStore? _fileStore;
  SearchIndex? _searchIndex;
  TextExtractor? _searchExtractor;
  String _baseUrl = '';
  SyncEngine? _syncEngine;
  StreamSubscription<int>? _recyclerCountSub;
  StreamSubscription<ContentFileEvent>? _searchIndexSub;

  AppDatabase? get db => _db;
  FileStore? get fileStore => _fileStore;
  SearchIndex? get searchIndex => _searchIndex;

  DateTime? get lastSuccessfulPullTime => _syncEngine?.lastSuccessfulPullTime;

  final RecordTree recordTree = RecordTree();
  final ReminderTree reminderTree = ReminderTree();
  final TagTree tagTree = TagTree();
  final ValueNotifier<SyncState> syncStateNotifier = ValueNotifier(SyncState(state: SyncState.idle));

  /// Recycle bin entry count, for the list page entry badge.
  final ValueNotifier<int> recyclerCountNotifier = ValueNotifier(0);

  Repository._() {
    reminderTree.bind(recordTree);
    tagTree.bind(recordTree);
  }
  static Repository get() => _instance!;

  static Future<void> init(String appRootDir, {TextExtractor? searchExtractor}) async {
    if (_instance != null) return;
    final sp = await SharedPreferences.getInstance();
    final baseUrl = sp.getString(_kApiUrl) ?? '';
    HttpApi.setBaseUrl(baseUrl);
    await User.instance.init();
    _instance = Repository._();
    _instance!._baseUrl = baseUrl;
    _instance!._searchExtractor = searchExtractor;
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
    if (_userId == userId && _db != null) return;
    // Wait for ongoing sync to finish, prevent background sync from writing to closed DB and crashing
    await _syncEngine?.waitForSync();
    await _recyclerCountSub?.cancel();
    _recyclerCountSub = null;
    await _searchIndexSub?.cancel();
    _searchIndexSub = null;
    await _searchIndex?.close();
    _searchIndex = null;
    await _db?.close();
    _fileStore = null;
    _db = null;
    _syncEngine = null;
    // Guest mode (never logged in / forgot user): local-only db, no sync engine.
    final dirName = userId != 0 ? userId.toString() : _guestDirName;
    _fileStore = FileStore(join(appRootDir, dirName));
    _db = createRecordsDatabase(File(_dbFilePath(_fileStore!.rootDir)));
    _fileStore!.db = _db!;
    _searchIndex = SearchIndex(File(_searchFilePath(_fileStore!.rootDir)), _fileStore!, _searchExtractor);
    await _searchIndex!.open();
    _searchIndexSub = _fileStore!.onContentChanged.listen((event) async {
      try {
        await _searchIndex?.refresh(event.uuid);
      } catch (e) {
        AppLogger.e("[Repository] search index sync failed uuid=${event.uuid}: $e");
      }
    });
    // Badge count is pushed only when the recycle table actually changes
    _recyclerCountSub = _db!.watchRecycleCount().listen((c) => recyclerCountNotifier.value = c);
    if (userId != 0) {
      _syncEngine = SyncEngine(
        db: _db!,
        fileStore: _fileStore!,
        recordTree: recordTree,
        syncStateNotifier: syncStateNotifier,
      );
    }
    // Account login merges guest data before the tree reads the records
    await recordTree.rebuild(() async {
      if (userId != 0) await _mergeGuestData(appRootDir);
      final records = await _db!.getAllRecords();
      return records;
    }());

    await clearExpiredRecycler();
    if (userId != 0) syncRecords(true);
    _userId = userId;
  }

  /// Merge guest-mode data (created before any login) into the freshly opened
  /// account database, then remove the guest directory. Guest rows carry no
  /// remote_* state, so the next sync pushes them as brand-new records.
  Future<void> _mergeGuestData(String appRootDir) async {
    final guestDir = Directory(join(appRootDir, _guestDirName));
    if (!guestDir.existsSync()) return;
    if (!File(_dbFilePath(guestDir.path)).existsSync()) return;
    final guestDb = createRecordsDatabase(File(_dbFilePath(guestDir.path)));
    try {
      final records = await guestDb.select(guestDb.localRecords).get();
      final recycles = await guestDb.select(guestDb.recycleRecords).get();
      await _db!.batch((b) {
        b.insertAllOnConflictUpdate(_db!.localRecords, records);
        b.insertAllOnConflictUpdate(_db!.recycleRecords, recycles);
      });
    } finally {
      await guestDb.close();
    }
    // Move attachment files (uuid-named, collisions mean same content → drop source)
    const subDirs = ['base_files', 'work_files', 'recycler'];
    for (final sub in subDirs) {
      final src = Directory(join(guestDir.path, sub));
      if (!src.existsSync()) continue;
      final dst = join(_fileStore!.rootDir, sub);
      await for (final f in src.list()) {
        if (f is! File) continue;
        final fileName = f.path.split(Platform.pathSeparator).last;
        final target = File(join(dst, fileName));
        if (target.existsSync()) {
          await f.delete();
        } else {
          await f.rename(target.path);
        }
      }
    }
    try {
      await guestDir.delete(recursive: true);
    } catch (e) {
      AppLogger.e("Failed to delete guest dir: $e");
    }
  }

  bool shouldSyncFromBackground() => _syncEngine?.shouldSyncFromBackground() ?? false;

  Future<void> syncRecordsFromBackground() async {
    if (shouldSyncFromBackground()) await syncRecords(false);
  }

  Future<void> waitForSync() async => await _syncEngine?.waitForSync();

  // =========================================================================
  // 🎯 CREATE / EDIT / DELETE — local write operations
  // =========================================================================

  Future<RecordEntry?> createRecord(
    String path,
    String name,
    bool sync,
    int fileEditAt, {
    String? reminder,
    String? tags,
  }) async {
    if (_db == null || _fileStore == null) return null;
    int time = DateTime.now().millisecondsSinceEpoch;
    final uuid = Uuid().v4();
    await _db!.insertRecord(
      uuid: uuid,
      name: name,
      path: path,
      fileEditAt: fileEditAt,
      editAt: time,
      createAt: time,
      reminder: reminder,
      tags: tags,
    );
    final record = (await _db!.getRecord(uuid))!;
    recordTree.insertRecord(record);
    await _db!.createOperate(Operates.typeLocal, "create record $uuid ${record.local.path}${record.local.name}");
    _fileStore!.deleteWorkFile(uuid);
    if (sync) await syncRecords(false);
    return record;
  }

  /// Edit existing record. fileEdit=true means work file content also changed.
  /// md5: md5 of the work file content (post-encryption if locked).
  /// path/name/locked/md5: optional; when null the field is left unchanged.
  /// reminder: optional JSON string of reminder tasks; pass null to leave it unchanged.
  /// tags: optional comma-separated tag string; pass null to leave it unchanged.
  Future<RecordEntry?> editRecord(
    String uuid,
    bool fileEdit,
    int time, {
    String? path,
    String? name,
    int? locked,
    String? md5,
    String? reminder,
    String? tags,
  }) async {
    if (_db == null) return null;
    AppDatabase db = _db!;

    final existing = await db.getRecord(uuid);
    if (existing == null) return null;

    await db.updateRecord(
      uuid,
      path: path,
      name: name,
      md5: md5,
      editType: LocalEditType.edit,
      editAt: time,
      fileEditAt: fileEdit ? time : null,
      locked: locked,
      reminder: reminder,
      tags: tags,
    );

    await db.createOperate(
      Operates.typeLocal,
      "edit record ${existing.uuid} ${existing.local.path}${existing.local.name} version:${existing.local.version}, fileEdit:$fileEdit",
    );
    final record = await recordTree.withRefreshLock(() async {
      final r = await db.getRecord(uuid);
      if (r != null) {
        recordTree.insertRecord(r);
      }
      return r;
    });
    if (record != null) {
      unawaited(
        syncRecords(false).catchError((e) {
          AppLogger.e("[Repository] editLocalRecord sync failed: $e");
        }),
      );
    }
    return record;
  }

  /// Soft delete: mark editType=delete and capture into recycle bin immediately
  /// (works offline too). Push conflict will undo the capture and restore the record.
  Future<void> deleteRecord(String uuid) async {
    if (_db == null) return;
    AppDatabase db = _db!;
    RecordEntry? record = await db.getRecord(uuid);
    int time = DateTime.now().millisecondsSinceEpoch;
    int count = await db.updateRecord(uuid, editType: LocalEditType.delete, editAt: time);
    if (count > 0) {
      // Records with no content at all (no work file and remoteMd5 empty)
      // skip the recycle bin capture.
      final hasContent = (_fileStore?.isWorkFileExist(uuid) ?? false) || (record?.local.remoteMd5.isNotEmpty ?? false);
      if (hasContent) {
        await _captureToRecycler(record?.local, time);
      }
      recordTree.deleteRecord(uuid);
      await db.createOperate(
        Operates.typeLocal,
        "delete record ${record?.local.uuid} ${record?.local.path}${record?.local.name} version:${record?.local.remoteVersion}",
      );
      await syncRecords(false);
    }
  }

  /// Capture a (deleted) record into the recycle bin: metadata snapshot + move content file
  /// into the recycler folder (work file preferred, base file as fallback).
  /// Failure only logs and must not block the delete flow.
  Future<void> _captureToRecycler(LocalRecord? record, int deleteAt) async {
    if (record == null || _db == null) return;
    try {
      await _db!.insertRecycleRecord(
        uuid: record.uuid,
        path: record.path,
        name: record.name,
        reminder: record.reminder,
        tags: record.tags,
        locked: record.locked,
        deleteAt: deleteAt,
      );
      _fileStore?.moveFileToRecycler(record.uuid);
    } catch (e) {
      AppLogger.e("[Repository] capture to recycler failed uuid=${record.uuid}: $e");
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
    final localPathCol = db.localRecords.path.name;
    final editAtCol = db.localRecords.editAt.name;
    final typeCol = db.localRecords.editType.name;

    await db.customUpdate(
      'UPDATE $tableName '
      'SET $localPathCol = ? || SUBSTR($localPathCol, ?), '
      '    $editAtCol = ?, '
      '    $typeCol = ${LocalEditType.edit} '
      'WHERE $localPathCol LIKE ? AND $typeCol != ${LocalEditType.delete}',
      variables: [
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
    final localPathCol = db.localRecords.path.name;
    final typeCol = db.localRecords.editType.name;
    final editAtCol = db.localRecords.editAt.name;

    // Records to capture (not yet delete-marked; already-marked ones were captured when deleted)
    final toCapture = await db.getUndeletedRecordsByPathPrefix(path);

    int count = await db.customUpdate(
      'UPDATE $table '
      'SET $typeCol = ${LocalEditType.delete}, $editAtCol = ? '
      'WHERE $localPathCol LIKE ?',
      variables: [Variable.withInt(time), Variable.withString(likePattern)],
      updates: {db.localRecords},
    );
    for (final record in toCapture) {
      await _captureToRecycler(record.local, time);
    }
    await db.createOperate(Operates.typeLocal, "delete folder $path, records count:$count");
    recordTree.deleteFolder(path);
    await syncRecords(false);
  }

  // =========================================================================
  // 🎯 CONFLICT — detection and resolution
  // =========================================================================

  Future<List<RecordEntry>> getConflictRecords() async {
    if (_db == null) return [];
    return _db!.getConflictRecords();
  }

  /// Resolve conflict.
  /// keepLocal=true:  keep local edits, align baseline, next push overwrites remote
  /// keepLocal=false: discard local edits, overwrite with remote version
  Future<void> resolveConflict(String uuid, bool keepLocal) async {
    if (_db == null || _fileStore == null) return;
    final db = _db!;
    final fileStore = _fileStore!;
    final record = await db.getRecord(uuid);
    if (record == null || !record.local.syncConflict) return;

    if (keepLocal) {
      // Only align baseline version, keep all local edits
      await db.updateRecord(uuid, version: record.local.remoteVersion);
      final refreshed = await db.getRecord(uuid);
      if (refreshed != null) recordTree.insertRecord(refreshed);
    } else {
      // Discard local edits, fully overwrite with remote (same behavior as normal push success markSynced)
      await db.markSynced(uuid);
      fileStore.deleteWorkFile(uuid);
      final refreshed = await db.getRecord(uuid);
      if (refreshed != null) recordTree.insertRecord(refreshed);
    }

    final remaining = await db.getConflictRecords();
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

  // =========================================================================
  // 🎯 RECYCLE BIN — list / restore / purge / clear
  // =========================================================================

  /// All recycle bin entries, newest deletion first.
  Future<List<RecycleRecord>> getRecycleRecords() async => await _db?.getRecycleRecords() ?? [];

  /// Restore a recycle bin entry: move the content file back into the work folder and bring the
  /// record back as a local edit (uuid unchanged), pushed to the server on next sync.
  Future<bool> restoreRecycleRecord(String uuid) async {
    if (_db == null || _fileStore == null) return false;
    final db = _db!;
    final entry = await db.getRecycleRecord(uuid);
    if (entry == null) return false;

    final existing = await db.getRecord(uuid);
    if (existing != null && existing.local.editType != LocalEditType.delete) {
      // Same uuid still live locally and not pending deletion (e.g. re-created on another device),
      // refuse to avoid duplicate primary key
      return false;
    }

    int time = DateTime.now().millisecondsSinceEpoch;
    _fileStore!.moveRecyclerFileToWork(uuid);
    if (existing != null) {
      // Delete not yet pushed to server (e.g. deleted offline): just un-delete the pending record
      await db.updateRecord(
        uuid,
        editType: LocalEditType.edit,
        editAt: time,
        fileEditAt: _fileStore!.isWorkFileExist(uuid) ? time : null,
      );
    } else {
      // Delete already pushed: re-create the local record (remote_* zeroed, DB default values),
      // push treats it as a new record via upsertRecord on next sync
      await db.restoreRecord(
        uuid: entry.uuid,
        name: entry.name,
        path: entry.path,
        locked: entry.locked,
        reminder: entry.reminder,
        tags: entry.tags,
        fileEditAt: _fileStore!.isWorkFileExist(uuid) ? time : 0,
        editAt: time,
        createAt: time,
      );
    }
    await db.deleteRecycleRecord(uuid);
    await recordTree.withRefreshLock(() async {
      final record = await db.getRecord(uuid);
      if (record != null) {
        recordTree.insertRecord(record);
      }
    });
    await db.createOperate(Operates.typeLocal, "restore record $uuid ${entry.path}${entry.name} from recycler");
    unawaited(syncRecords(false));
    return true;
  }

  /// Permanently delete a recycle bin entry (metadata row + recycler content file).
  Future<void> purgeRecycleRecord(String uuid) async {
    if (_db == null) return;
    await _db!.deleteRecycleRecord(uuid);
    _fileStore?.deleteRecyclerFile(uuid);
    await _db!.createOperate(Operates.typeLocal, "purge recycler record $uuid");
  }

  /// Empty the recycle bin: delete all metadata rows and recycler content files.
  Future<void> clearRecycleRecords() async {
    if (_db == null) return;
    final rows = await _db!.getRecycleRecords();
    await _db!.clearRecycleRecords();
    for (final row in rows) {
      _fileStore?.deleteRecyclerFile(row.uuid);
    }
    await _db!.createOperate(Operates.typeLocal, "clear recycler records, count:${rows.length}");
  }

  /// Startup-only sweep: physically remove recycle-bin entries older than 30 days.
  /// Runs once per user open (guest or logged-in) so the bin never grows unbounded.
  static const recyclerExpireDays = 30;
  Future<void> clearExpiredRecycler() async {
    if (_db == null) return;
    final threshold = DateTime.now().millisecondsSinceEpoch - recyclerExpireDays * 24 * 60 * 60 * 1000;
    final expired = await _db!.purgeRecycleRecordsBefore(threshold);
    for (final row in expired) {
      _fileStore?.deleteRecyclerFile(row.uuid);
    }
    if (expired.isNotEmpty) {
      AppLogger.i("[Repository] auto-purged ${expired.length} expired recycler entries (>30d)");
    }
  }
}
