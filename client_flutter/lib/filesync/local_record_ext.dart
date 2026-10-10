// LocalRecord convenience extensions.
// Only keep status-derived getters. Field values are read directly:
//   Local-edit related: localName/localPath/localEditAt/localFileEditAt/localVersion/localEditType
//   Remote authoritative: remoteVersion/remoteMd5/remoteCreateAt/remoteEditAt/remoteFileEditAt/remoteLocked/remoteName/remotePath

import 'table_record.dart';
import 'database.dart';

extension LocalRecordExt on LocalRecord {
  // ========= Status queries (derived, not direct field reads) =========

  /// Local file/metadata edit status (edit only, not delete)
  bool get isLocalEdit => localEditType == LocalEditType.edit;

  /// Local deletion status
  bool get isLocallyDeleted => localEditType == LocalEditType.delete;

  /// Conflict detection: local has edit (non-delete) && local baseline version != server version
  /// Local deletion is not considered a conflict (deletion is an independent push flow)
  bool get syncConflict => localEditType == LocalEditType.edit && localVersion != remoteVersion;

  /// Whether synced (no pending upload changes)
  bool get isSynced => localEditType == LocalEditType.none;
}
