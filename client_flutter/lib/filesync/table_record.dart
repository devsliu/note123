import 'package:drift/drift.dart';

/// Local edit type.
/// none(0) = synced, no pending upload changes
/// edit(1) = has local edits (metadata and/or file content, check localFileEditAt > remoteFileEditAt)
/// delete(2) = local deletion
///
/// Detection:
///   Has edits           → localEditType > none
///   Need to upload work file → localFileEditAt > remoteFileEditAt
///   Conflict            → localEditType > none && localVersion != remoteVersion
///   Local deletion     → localEditType == delete
class LocalEditType {
  static const int none = 0;
  static const int edit = 1;
  static const int delete = 2;
}

@TableIndex(name: 'records_path_idx', columns: {#localPath})
@TableIndex(name: 'records_version_idx', columns: {#remoteVersion})
@DataClassName('LocalRecord')
class LocalRecords extends Table {
  // ========== Identity ==========
  TextColumn get uuid => text()();

  // ========== Pull tracking ==========
  IntColumn get batchNo => integer().withDefault(const Constant(0))();

  // ========== Server authoritative (downloaded from server) ==========
  IntColumn get remoteVersion => integer().withDefault(const Constant(0))();
  IntColumn get remoteCreateAt => integer().withDefault(const Constant(0))();
  IntColumn get remoteEditAt => integer().withDefault(const Constant(0))();
  IntColumn get remoteFileEditAt => integer().withDefault(const Constant(0))();
  IntColumn get remoteDeleteAt => integer().withDefault(const Constant(0))();
  IntColumn get remoteLocked => integer().withDefault(const Constant(0))();
  TextColumn get remoteMd5 => text().withDefault(const Constant(''))();
  TextColumn get remoteName => text().withDefault(const Constant(''))();
  TextColumn get remotePath => text().withDefault(const Constant(''))();
  TextColumn get remoteReminder => text().withDefault(const Constant(''))();

  /// Server-side file version number (incremented independently per record, only +1 when file content changes, defaults to 0)
  IntColumn get remoteFileVersion => integer().withDefault(const Constant(0))();

  // ========== Base file tracking ==========
  /// The server-side fileVersion of the locally downloaded base file.
  /// Written only after downloadBaseFile succeeds, never cleared.
  /// Whether to re-download: remoteFileVersion > baseFileVersion (or file does not exist).
  IntColumn get baseFileVersion => integer().withDefault(const Constant(0))();

  // ========== Local working state ==========
  /// Local edit type: 0=synced, 1=edited, 2=deleted
  IntColumn get localEditType => integer().withDefault(const Constant(0))();

  /// Local globally-modified version number. Conflict detection: localEditType>0 && localVersion != remoteVersion
  IntColumn get localVersion => integer().withDefault(const Constant(0))();

  /// Local file edit based on the remote fileVersion. File conflict detection: localFileEdited==1 && localFileVersion != remoteFileVersion
  IntColumn get localFileVersion => integer().withDefault(const Constant(0))();

  /// Local edit timestamp (optimistic concurrency + server editAt). 0=no edit
  IntColumn get localEditAt => integer().withDefault(const Constant(0))();

  /// Local file edit timestamp. 0=no file edit
  IntColumn get localFileEditAt => integer().withDefault(const Constant(0))();

  /// Field values after local edits. Overwritten with remote_* after successful sync (restored to server values)
  TextColumn get localName => text().withDefault(const Constant(''))();
  TextColumn get localMd5 => text().withDefault(const Constant(''))();
  IntColumn get localLocked => integer().withDefault(const Constant(0))();
  TextColumn get localReminder => text().withDefault(const Constant(''))();

  /// Local path: COLLATE BINARY ensures LIKE index works, CHECK constraint guarantees format
  TextColumn get localPath =>
      text().withLength(min: 1, max: 1024).customConstraint("NOT NULL COLLATE BINARY CHECK (local_path LIKE '%/')")();

  @override
  Set<Column> get primaryKey => {uuid};
}

// Path dashboard view
@DriftView(name: 'PathRecordCounts')
abstract class PathRecordCounts extends View {
  LocalRecords get records;
  Expression<int> get recordCount => records.uuid.count();

  @override
  Query as() => select([records.localPath, recordCount]).from(records)..groupBy([records.localPath]);
}

@DataClassName('Operate')
class Operates extends Table {
  static const typeLocal = "local";
  static const typeDownload = "download";
  static const typeUpload = "upload";
  static const typeError = "error";

  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()();
  TextColumn get value => text()();
  IntColumn get time => integer()();
}

@DataClassName('KVConfig')
class KVConfigs extends Table {
  // Last synced maximum version number (inclusive)
  static const String lastSyncedVersion = 'last_synced_version';

  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
