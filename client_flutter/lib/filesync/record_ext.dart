// Path utilities for the record tree's "slash-prefixed and slash-suffixed"
// folder path convention. These are pure functions with no dependency on
// RecordTree state.

import 'dart:convert';

import 'database.dart';
import 'remote_record.dart';
import 'table_record.dart';

export 'path_utils.dart';

/// Wrapper that groups LocalRecord (DB row) with a lazily-constructed RemoteRecord.
/// Use [local] for DB column access, [remote] for server-authoritative values.
/// [remoteJson] stores the full server snapshot (all 11 RemoteRecord fields).
/// The 3 columns remoteVersion/remoteMd5/remoteFileVersion are redundant indexed copies
/// kept only for SQL WHERE/ORDER BY; [remote] is decoded straight from [remoteJson].
class RecordEntry {
  final LocalRecord local;
  late final RemoteRecord remote = _decodeRemote();
  RecordEntry(this.local);

  String get uuid => local.uuid;

  RemoteRecord _decodeRemote() {
    if (local.remoteJson.isEmpty) {
      return RemoteRecord(
        uuid: local.uuid,
        path: '',
        name: '',
        version: 0,
        createAt: 0,
        editAt: 0,
        fileEditAt: 0,
        fileVersion: 0,
        deleteAt: 0,
        md5: '',
        locked: 0,
        tags: '',
      );
    }
    return RemoteRecord.fromJson(jsonDecode(local.remoteJson) as Map<String, dynamic>);
  }
}

// LocalRecord convenience extensions.
// Only keep status-derived getters. Field values are read directly:
//   Local-edit related: name/path/editAt/fileEditAt/version/editType
//   Remote authoritative: remoteVersion/remoteMd5/remoteFileVersion (columns),
//                          createAt/editAt/fileEditAt/locked/name/path/reminder (via RecordEntry.remote from remoteJson)

extension LocalRecordExt on LocalRecord {
  // ========= Status queries (derived, not direct field reads) =========

  /// Local file/metadata edit status (edit only, not delete)
  bool get isLocalEdit => editType == LocalEditType.edit;

  /// Local deletion status
  bool get isLocallyDeleted => editType == LocalEditType.delete;

  /// Conflict detection: local has edit (non-delete) && local baseline version != server version
  /// Local deletion is not considered a conflict (deletion is an independent push flow)
  bool get syncConflict => editType == LocalEditType.edit && version != remoteVersion;

  /// Whether synced (no pending upload changes)
  bool get isSynced => editType == LocalEditType.none;
}
