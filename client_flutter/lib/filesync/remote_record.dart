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
  final String reminder;

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
    this.reminder = '',
  });

  /// RemoteRecord → LocalRecord: copy all remote_*, local_* = remote_* (synced baseline).
  /// [baseFileVersion]: which file version the local base file corresponds to, default 0 (new record).
  LocalRecord toLocalRecord(int batchNo, {int baseFileVersion = 0}) {
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
      remoteReminder: reminder,
      remoteFileVersion: fileVersion,
      baseFileVersion: baseFileVersion,
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
      localReminder: reminder,
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
    fileVersion: (json['fileVersion'] as num?)?.toInt() ?? 0,
    locked: (json['locked'] as num?)?.toInt() ?? 0,
    deleteAt: (json['deleteAt'] as num?)?.toInt() ?? 0,
    md5: json['md5'] as String? ?? '',
    reminder: json['reminder'] as String? ?? '',
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
    'reminder': reminder,
  };

  @override
  bool operator ==(Object other) => other is RemoteRecord && uuid == other.uuid;

  @override
  int get hashCode => Object.hash(uuid, "RemoteRecord");
}
