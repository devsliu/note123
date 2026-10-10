import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:note123/utils/app_logger.dart';
import 'package:note123/filesync/remote_record.dart';

import 'table_record.dart';
import 'table_config.dart';
import 'table_operate.dart';

part 'database.g.dart';

@DriftDatabase(tables: [LocalRecords, KVConfigs, Operates], views: [PathRecordCounts])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => await m.createAll(),
    onUpgrade: (m, from, to) async {
      AppLogger.w("DB migration from $from to $to — adding all missing tables/columns");
      // Drift default strategy: createMissing does not delete existing data
      await m.createAll();
    },
  );

  // ========== Queries ==========

  Future<List<LocalRecord>> getAllLocalRecords() async => await select(localRecords).get();

  /// Latest 15 non-deleted entries (ordered by remoteVersion descending)
  Future<List<LocalRecord>> getRecentRecords() async =>
      await (select(localRecords)
            ..where((t) => t.localEditType.equals(LocalEditType.delete).not())
            ..orderBy([(t) => OrderingTerm(expression: t.remoteVersion, mode: OrderingMode.desc)])
            ..limit(15))
          .get();

  Future<List<Operate>> getAllOperates() async =>
      await (select(operates)..orderBy([(t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc)])).get();

  Future<int> createOperate(String type, String value) async {
    final op = OperatesCompanion.insert(type: type, value: value, time: DateTime.now().millisecondsSinceEpoch);
    int id = await into(operates).insert(op);
    if (id % 10000 == 0) {
      await (delete(operates)..where((t) => t.id.isSmallerThanValue(id - 10000))).go();
    }
    return id;
  }

  /// PUSH: retrieve all locally edited entries (edit=1, non-delete)
  Future<List<LocalRecord>> getEditRecords() async =>
      await (select(localRecords)..where((t) => t.localEditType.equals(LocalEditType.edit))).get();

  Future<LocalRecord?> getRecord(String uuid) async =>
      await (select(localRecords)..where((t) => t.uuid.equals(uuid))).getSingleOrNull();

  /// PUSH: retrieve all locally deleted entries
  Future<List<LocalRecord>> getDeleteRecords() async =>
      await (select(localRecords)..where((t) => t.localEditType.equals(LocalEditType.delete))).get();

  /// All conflicted entries: local has edit (non-delete) && localVersion != remoteVersion
  /// Local deletion is not considered a conflict (deletion is an independent push flow)
  Future<List<LocalRecord>> getSyncConflictRecords() async =>
      await (select(localRecords)
            ..where((t) => t.localEditType.equals(LocalEditType.edit))
            ..where((t) => t.localVersion.equalsExp(t.remoteVersion).not()))
          .get();

  // ========== KV ==========

  Future<int> getConfigInt(String key, int def) async {
    var str = await getConfigStr(key, null);
    return str != null && str.isNotEmpty ? int.parse(str) : def;
  }

  Future<String?> getConfigStr(String key, String? def) async {
    var config = await (select(kVConfigs)..where((t) => t.key.equals(key))).getSingleOrNull();
    return config != null ? config.value : def;
  }

  Future<int> setIntValue(String key, int value) async => await setStringValue(key, value.toString());

  Future<int> setStringValue(String key, String value) async =>
      await into(kVConfigs).insertOnConflictUpdate(KVConfig(key: key, value: value));

  // ========== Writes ==========

  Future<int> deleteRecord(String uuid) async => await (delete(localRecords)..where((t) => t.uuid.equals(uuid))).go();

  Future<int> replaceRecord(LocalRecord localRecord) async =>
      await into(localRecords).insertOnConflictUpdate(localRecord);

  /// Create a new local record (remote_* all zeroes, uses DB default values).
  Future<int> insertRecord({
    required String uuid,
    required String name,
    required String path,
    required int localFileEditAt,
    required int time,
  }) async {
    return await into(localRecords).insert(
      LocalRecordsCompanion.insert(
        uuid: uuid,
        localEditType: const Value(LocalEditType.edit),
        localEditAt: Value(time),
        localFileEditAt: Value(localFileEditAt),
        localName: Value(name),
        localPath: path,
      ),
    );
  }

  /// Unified LocalRecord update. All fields optional, null means do not update.
  ///
  /// local_* / remote_* split fields are directly named.
  /// Called after successful sync: overwrites remote_* to local_*, localVersion=remoteVersion, localEditType=none.
  Future<int> updateRecord(
    String uuid, {
    int? batchNo,
    // remote_*
    int? remoteVersion,
    int? remoteCreateAt,
    int? remoteEditAt,
    int? remoteFileEditAt,
    int? remoteDeleteAt,
    int? remoteLocked,
    String? remoteMd5,
    String? remoteName,
    String? remotePath,
    String? remoteReminder,
    // remote file version
    int? remoteFileVersion,
    // base file tracking
    int? baseFileVersion,
    // local_*
    int? localEditType,
    int? localVersion,
    int? localFileVersion,
    int? localEditAt,
    int? localFileEditAt,
    String? localName,
    String? localMd5,
    String? localPath,
    int? localLocked,
    String? localReminder,
  }) async {
    return await (update(localRecords)..where((t) => t.uuid.equals(uuid))).write(
      LocalRecordsCompanion(
        batchNo: batchNo != null ? Value(batchNo) : Value.absent(),
        remoteVersion: remoteVersion != null ? Value(remoteVersion) : Value.absent(),
        remoteCreateAt: remoteCreateAt != null ? Value(remoteCreateAt) : Value.absent(),
        remoteEditAt: remoteEditAt != null ? Value(remoteEditAt) : Value.absent(),
        remoteFileEditAt: remoteFileEditAt != null ? Value(remoteFileEditAt) : Value.absent(),
        remoteDeleteAt: remoteDeleteAt != null ? Value(remoteDeleteAt) : Value.absent(),
        remoteLocked: remoteLocked != null ? Value(remoteLocked) : Value.absent(),
        remoteMd5: remoteMd5 != null ? Value(remoteMd5) : Value.absent(),
        remoteName: remoteName != null ? Value(remoteName) : Value.absent(),
        remotePath: remotePath != null ? Value(remotePath) : Value.absent(),
        remoteReminder: remoteReminder != null ? Value(remoteReminder) : Value.absent(),
        remoteFileVersion: remoteFileVersion != null ? Value(remoteFileVersion) : Value.absent(),
        baseFileVersion: baseFileVersion != null ? Value(baseFileVersion) : Value.absent(),
        localEditType: localEditType != null ? Value(localEditType) : Value.absent(),
        localVersion: localVersion != null ? Value(localVersion) : Value.absent(),
        localFileVersion: localFileVersion != null ? Value(localFileVersion) : Value.absent(),
        localEditAt: localEditAt != null ? Value(localEditAt) : Value.absent(),
        localFileEditAt: localFileEditAt != null ? Value(localFileEditAt) : Value.absent(),
        localName: localName != null ? Value(localName) : Value.absent(),
        localMd5: localMd5 != null ? Value(localMd5) : Value.absent(),
        localPath: localPath != null ? Value(localPath) : Value.absent(),
        localLocked: localLocked != null ? Value(localLocked) : Value.absent(),
        localReminder: localReminder != null ? Value(localReminder) : Value.absent(),
      ),
    );
  }

  /// Update DB remote_* fields from server-side RemoteRecord (do not touch local_*).
  /// Optional batchNo: mark this pull cycle, used for full cleanup.
  /// Optional localVersion: needed to align baseline version during concurrent push edits.
  Future<int> updateRecordRemote(String uuid, RemoteRecord remote, {int? batchNo, int? localVersion}) async {
    String formattedPath = remote.path;
    if (!formattedPath.endsWith('/')) formattedPath += '/';
    return await updateRecord(
      uuid,
      batchNo: batchNo,
      remoteVersion: remote.version,
      remoteCreateAt: remote.createAt,
      remoteEditAt: remote.editAt,
      remoteFileEditAt: remote.fileEditAt,
      remoteDeleteAt: remote.deleteAt,
      remoteLocked: remote.locked,
      remoteMd5: remote.md5,
      remoteName: remote.name,
      remotePath: formattedPath,
      remoteReminder: remote.reminder,
      remoteFileVersion: remote.fileVersion,
      localVersion: localVersion,
    );
  }

  /// Clear remote_* fields (server deleted, local has edits = needs to be re-created).
  /// Also resets localVersion/localFileVersion to zero so push treats it as a new record via upsertRecord.
  /// Optional batchNo: mark this pull cycle, used for full cleanup.
  Future<int> clearRecordRemote(String uuid, {int? batchNo}) async {
    return await updateRecord(
      uuid,
      batchNo: batchNo,
      remoteVersion: 0,
      remoteCreateAt: 0,
      remoteEditAt: 0,
      remoteFileEditAt: 0,
      remoteDeleteAt: 0,
      remoteLocked: 0,
      remoteMd5: '',
      remoteName: '',
      remotePath: '',
      remoteReminder: '',
      remoteFileVersion: 0,
      localVersion: 0,
      localFileVersion: 0,
      baseFileVersion: 0,
    );
  }

  /// One-click alignment after successful sync: local_* all = remote_*, localEditType=none.
  /// localEditAt/localFileEditAt are also set to remote values (not cleared),
  /// so the UI layer can directly read local fields as correct values, no need to fall back to remote.
  /// Optional batchNo: mark this pull cycle, used for full cleanup.
  Future<int> markSynced(String uuid, {int? batchNo}) async {
    final e = await getRecord(uuid);
    if (e == null) return 0;
    // Only update local_* fields, aligning them to remote_*; remote_* / baseFileVersion remain unchanged.
    return await updateRecord(
      uuid,
      batchNo: batchNo,
      localEditType: LocalEditType.none,
      localVersion: e.remoteVersion,
      localFileVersion: e.remoteFileVersion,
      localEditAt: e.remoteEditAt,
      localFileEditAt: e.remoteFileEditAt,
      localName: e.remoteName,
      localMd5: e.remoteMd5,
      localPath: e.remotePath,
      localLocked: e.remoteLocked,
      localReminder: e.remoteReminder,
    );
  }
}

// ========== Physical connector ==========

AppDatabase createRecordsDatabase(File file) {
  AppLogger.i("createRecordsDatabase: $file");
  final executor = NativeDatabase.createInBackground(
    file,
    setup: (rawDb) {
      rawDb.execute('PRAGMA journal_mode=WAL;');
      rawDb.execute('PRAGMA synchronous=NORMAL;');
      rawDb.execute('PRAGMA busy_timeout = 5000;');
    },
  );
  return AppDatabase(executor);
}
