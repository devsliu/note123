import 'package:drift/drift.dart';

/// Local edit type.
/// none(0) = synced, no pending upload changes
/// edit(1) = has local edits (metadata and/or file content, check fileEditAt > 0)
/// delete(2) = local deletion
///
/// Detection:
///   Has edits           → editType > none
///   Need to upload work file → fileEditAt > 0
///   Conflict            → editType > none && version != remoteVersion
///   Local deletion     → editType == delete
class LocalEditType {
  static const int none = 0;
  static const int edit = 1;
  static const int delete = 2;
}

@TableIndex(name: 'records_path_idx', columns: {#path})
@TableIndex(name: 'records_version_idx', columns: {#remoteVersion})
@DataClassName('LocalRecord')
class LocalRecords extends Table {
  // ========== Identity ==========
  TextColumn get uuid => text()();

  // ========== Pull tracking ==========
  IntColumn get batchNo => integer().withDefault(const Constant(0))();

  // ========== Server authoritative (downloaded from server) ==========
  /// Conflict detection + sort, participates in SQL WHERE/ORDER BY
  IntColumn get remoteVersion => integer().withDefault(const Constant(0))();

  /// Empty-record detection (server never had a file)
  TextColumn get remoteMd5 => text().withDefault(const Constant(''))();

  /// Download detection + file conflict, participates in SQL logic
  IntColumn get remoteFileVersion => integer().withDefault(const Constant(0))();

  /// Full server snapshot as JSON (all RemoteRecord fields).
  /// The 3 columns above are redundant indexed copies kept only for SQL WHERE/ORDER BY.
  /// Decoded lazily into RemoteRecord via RecordEntry.remote.
  TextColumn get remoteJson => text().withDefault(const Constant(''))();

  // ========== Base file tracking ==========
  /// The server-side fileVersion of the locally downloaded base file.
  /// Written only after downloadBaseFile succeeds, never cleared.
  /// Whether to re-download: remoteFileVersion > baseFileVersion (or file does not exist).
  IntColumn get baseFileVersion => integer().withDefault(const Constant(0))();

  // ========== Local working state ==========
  /// Local edit type: 0=synced, 1=edited, 2=deleted
  IntColumn get editType => integer().withDefault(const Constant(0))();

  /// Local globally-modified version number. Conflict detection: editType>0 && version != remoteVersion
  IntColumn get version => integer().withDefault(const Constant(0))();

  /// Local file edit based on the remote fileVersion. File conflict detection: localFileEdited==1 && fileVersion != remoteFileVersion
  IntColumn get fileVersion => integer().withDefault(const Constant(0))();

  /// Local edit timestamp (optimistic concurrency + server editAt). 0=no edit
  IntColumn get editAt => integer().withDefault(const Constant(0))();

  /// Local file edit timestamp. 0=no file edit
  IntColumn get fileEditAt => integer().withDefault(const Constant(0))();

  /// Field values after local edits. Overwritten with remote_* after successful sync (restored to server values)
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get md5 => text().withDefault(const Constant(''))();
  IntColumn get locked => integer().withDefault(const Constant(0))();
  TextColumn get reminder => text().withDefault(const Constant(''))();

  /// Local path: COLLATE BINARY ensures LIKE index works, CHECK constraint guarantees format
  TextColumn get path =>
      text().withDefault(const Constant('/')).customConstraint("NOT NULL COLLATE BINARY CHECK (path LIKE '%/')")();

  @override
  Set<Column> get primaryKey => {uuid};
}

// Path dashboard view
@DriftView(name: 'PathRecordCounts')
abstract class PathRecordCounts extends View {
  LocalRecords get records;
  Expression<int> get recordCount => records.uuid.count();

  @override
  Query as() => select([records.path, recordCount]).from(records)..groupBy([records.path]);
}

/// Recycle bin entry: metadata snapshot of a locally deleted record.
/// The content file is kept in the recycler/ folder named by uuid.
/// Restore re-creates the record as a pure local edit (remote_* zeroed, uuid unchanged),
/// which is pushed to the server as a new record on next sync.
@DataClassName('RecycleRecord')
class RecycleRecords extends Table {
  TextColumn get uuid => text()();

  // Snapshot of the deleted record's local_* fields
  TextColumn get path => text().withDefault(const Constant(''))();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get reminder => text().withDefault(const Constant(''))();
  IntColumn get locked => integer().withDefault(const Constant(0))();

  /// Deletion timestamp (ms)
  IntColumn get deleteAt => integer()();

  @override
  Set<Column> get primaryKey => {uuid};
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
