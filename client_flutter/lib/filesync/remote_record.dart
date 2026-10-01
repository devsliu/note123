import 'package:note123/filesync/database.dart';

import 'table_record.dart';

class RemoteRecord {
  final String uuid;
  String path;
  String name;
  final int version;
  final int createAt;
  final int editAt;
  final int fileEditAt;
  final int fileVersion;
  final int deleteAt;
  final String md5;
  final int locked;

  RemoteRecord({
    required this.uuid,
    required this.path,
    required this.name,
    required this.version,
    required this.createAt,
    required this.editAt,
    required this.fileEditAt,
    required this.fileVersion,
    required this.locked,
    required this.deleteAt,
    required this.md5,
  });

  /// RemoteRecord → LocalRecord: copy all remote_*, local_* = remote_* (synced baseline).
  /// Optional [source]: existing LocalRecord, use copyWith to preserve baseFileVersion from source,
  /// overwrite all others from current RemoteRecord.
  /// When source is not provided, baseFileVersion defaults to 0 (new record).
  LocalRecord toLocalRecord(int batchNo, {LocalRecord? source}) {
    String formattedPath = path;
    if (!formattedPath.endsWith('/')) formattedPath += '/';
    if (!formattedPath.startsWith('/')) formattedPath = '/$formattedPath';

    return LocalRecord(
      uuid: uuid,
      batchNo: batchNo,
      // Server authoritative
      remoteVersion: version,
      remoteCreateAt: createAt,
      remoteEditAt: editAt,
      remoteFileEditAt: fileEditAt,
      remoteDeleteAt: deleteAt,
      remoteLocked: locked,
      remoteMd5: md5,
      remoteName: name,
      remotePath: formattedPath,
      remoteFileVersion: fileVersion,
      // baseFileVersion: pass through existing value, default 0 for new records
      baseFileVersion: source?.baseFileVersion ?? 0,
      // Local = remote (synced)
      localEditType: LocalEditType.none,
      localVersion: version,
      localFileVersion: fileVersion,
      localEditAt: editAt,
      localFileEditAt: fileEditAt,
      localName: name,
      localMd5: md5,
      localPath: formattedPath,
      localLocked: locked,
    );
  }

  factory RemoteRecord.fromJson(Map<String, dynamic> json) => RemoteRecord(
    uuid: json['uuid'] as String? ?? '',
    path: json['path'] as String? ?? '',
    name: json['name'] as String? ?? '',
    version: (json['version'] as num?)?.toInt() ?? 0,
    createAt: (json['createAt'] as num?)?.toInt() ?? 0,
    editAt: (json['editAt'] as num?)?.toInt() ?? 0,
    fileEditAt: (json['fileEditAt'] as num?)?.toInt() ?? 0,
    fileVersion: (json['fileVersion'] as num?)?.toInt() ?? 1,
    locked: (json['locked'] as num?)?.toInt() ?? 0,
    deleteAt: (json['deleteAt'] as num?)?.toInt() ?? 0,
    md5: json['md5'] as String? ?? '',
  );

  Map<String, Object?> toJson() => {
    'uuid': uuid,
    'path': path,
    'name': name,
    'version': version,
    'createAt': createAt,
    'editAt': editAt,
    'fileEditAt': fileEditAt,
    'fileVersion': fileVersion,
    'deleteAt': deleteAt,
    'md5': md5,
    'locked': locked,
  };

  @override
  bool operator ==(Object other) => other is RemoteRecord && uuid == other.uuid;

  @override
  int get hashCode => Object.hash(uuid, "RemoteRecord");
}
