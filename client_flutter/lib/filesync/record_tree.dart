import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:note123/filesync/record_ext.dart';
import 'package:note123/filesync/table_record.dart';
import 'package:note123/utils/app_logger.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

class RecordEvent {
  static const int typeRebuild = 0; // full rebuild from DB, value2 为 null
  static const int typeDeleteFolder = 1; // value1 = path
  static const int typeRenameFolder = 2; // value1 = oldPath, value2 = newPath
  static const int typeCreateFolder = 3; // value1 = path;
  static const int typeDeleteRecord = 4; // value1 = path, value2 = uuid
  static const int typeUpsertRecord = 5; // value1 = path, value2 = uuid

  final int type;
  String? value1;
  String? value2;
  RecordEvent(this.type, {this.value1, this.value2});
}

abstract class TreeContent {
  String _path; // Must end with /
  String _name;
  TreeContent(this._path, this._name);

  String get path => _path;
  String get name => _name;
  String get dir; // The folder's parent is the parent directory; the file's dir is the path
  String get key;
}

// Once a TreeContentFile object is created, regardless of how the file corresponding to the uuid is modified,
// the object will always exist and never be re-created unless the file is deleted
class TreeContentFile extends TreeContent {
  RecordEntry _entry;
  int _editAt;

  TreeContentFile(RecordEntry entry)
    : _entry = entry,
      _editAt = entry.local.editAt,
      super(entry.local.path, entry.local.name);

  String get uuid => _entry.local.uuid;
  String get md5 => _entry.local.remoteMd5;
  int get version => _entry.local.remoteVersion;
  int get createAt => _entry.remote.createAt;
  int get editAt => _editAt;
  int get fileEditAt => _entry.local.fileEditAt;
  bool get syncConflict => _entry.local.syncConflict;
  int get locked => _entry.local.locked;
  // All LocalRecord fields are final; setLocalRecord replaces the whole thing during sync,
  // external callers can compare before/after to determine if file/title changed
  RecordEntry get record => _entry;

  @override
  String get dir => _path;
  @override
  String get key => _entry.local.uuid;

  void setLocalRecord(RecordEntry entry) {
    _entry = entry;
    _path = entry.local.path;
    _name = entry.local.name;
    _editAt = entry.local.editAt;
  }
}

class TreeContentFolder extends TreeContent {
  TreeContentFolder(super._path, super.name);

  @override
  String get dir => dirname(_path);
  @override
  String get key => _path;
}

class TreeNode extends TreeViewNode<TreeContent> {
  TreeNode(super.content, {super.children});

  void removeChild(String key) {
    children.removeWhere((f) => f.content.key == key);
  }

  int indexOfChild(String key) {
    for (var i = 0; i < children.length; i++) {
      if (children[i].content.key == key) {
        return i;
      }
    }
    return -1;
  }

  bool hasChild(String key) => children.any((f) => f.content.key == key);

  void insertChild(TreeNode node) {
    // Determine whether node is folder or file; files are always placed after folders,
    // folders sorted lexicographically among themselves, files sorted lexicographically among themselves
    final bool isFolder = node.content is TreeContentFolder;
    final String name = node.content.name;
    final list = children;

    int i = 0;
    if (isFolder) {
      // 1. If the new node is a folder, it must be inserted in the folder section (front of the List)
      for (; i < list.length; i++) {
        final existing = list[i].content;
        if (existing is! TreeContentFolder) break; // Reached file area, insert immediately here
        if (name.compareTo(existing.name) < 0) break; // Found lexicographic position
      }
    } else {
      // 2. If the new node is a file, it must be inserted after all folders
      // First skip all preceding folders
      for (; i < list.length; i++) {
        if (list[i].content is! TreeContentFolder) break;
      }
      // Find insertion point in the file area by lexicographic order
      for (; i < list.length; i++) {
        final existing = list[i].content;
        if (name.compareTo(existing.name) < 0) break;
      }
    }

    list.insert(i, node);
  }
}

class RecordTree extends TreeNode {
  final Map<String /* path */, TreeNode> _foldersMap = {};
  final Map<String /* uuid */, TreeNode> _filesMap = {};
  final Map<String /* uuid */, RecordEntry> _conflictMap = {};

  // Since TreeContentFile objects once created always exist and are only modified, never re-created until delete,
  // only insert and delete operations need to modify _recentlyFiles array; rename/name changes and edits only need sorting
  final RecordList _sortedFiles = RecordList();

  /// Detailed record change events (upsert/delete/rename folder/create folder/delete folder),
  /// emitted individually as they happen so listeners can react incrementally.
  final StreamController<RecordEvent> _eventController = StreamController.broadcast();
  Stream<RecordEvent> get onEvent => _eventController.stream;

  final ValueNotifier<int> countNotifier = ValueNotifier<int>(0);

  /// 串行化"读 DB → 刷树"临界区: 防止并发事务提交后, 持有旧快照的一方后执行 insert 覆盖新快照
  Future<void> _refreshChain = Future<void>.value();
  Future<T> withRefreshLock<T>(Future<T> Function() action) {
    final next = _refreshChain.then((_) => action());
    _refreshChain = next.then((_) {}, onError: (_) {});
    return next;
  }

  RecordTree() : super(TreeContentFolder("/", ""));

  void build(List<RecordEntry> allRecords) {
    children.clear();
    _foldersMap.clear();
    _filesMap.clear();
    _conflictMap.clear();
    _foldersMap["/"] = this;
    _sortedFiles.files.clear();

    for (final n in allRecords) {
      final (node, isNew) = _insertRecord(n, emit: false);
      if (node != null && isNew) {
        _sortedFiles.add(node.content as TreeContentFile);
      }
    }
    _sortedFiles.sort();
    _emit(RecordEvent(RecordEvent.typeRebuild));
  }

  List<TreeContentFile> get sortedFiles => _sortedFiles.files;

  void setSortListType(int type) {
    _sortedFiles.setSortType(type);
    _sortedFiles.sort();
  }

  RecordEntry? findRecord(String uuid) {
    return (_filesMap[uuid]?.content as TreeContentFile?)?._entry;
  }

  TreeNode? findFileNode(String uuid) {
    return _filesMap[uuid];
  }

  /// Emit a single event on the public stream (with logging), and update
  /// countNotifier so listeners see the current file count right away.
  void _emit(RecordEvent event) {
    AppLogger.i("_notifyEvent ${event.type}");
    _eventController.add(event);
    countNotifier.value = _filesMap.length;
  }

  /// Helper: ensure a folder exists by path; if not, recursively create and attach to tree
  TreeNode _ensureFolderExists(String folderPath, {bool emit = true}) {
    if (_foldersMap.containsKey(folderPath)) {
      return _foldersMap[folderPath]!;
    }

    final segments = folderPath.split('/').where((s) => s.isNotEmpty).toList();

    String currentPath = '/';
    TreeNode current = this;

    for (final segment in segments) {
      currentPath += '$segment/';

      if (!_foldersMap.containsKey(currentPath)) {
        final newFolder = TreeContentFolder(currentPath, segment);
        final treeNode = TreeNode(newFolder);
        _foldersMap[currentPath] = treeNode;

        current.insertChild(treeNode);
        current = treeNode;

        if (emit) _emit(RecordEvent(RecordEvent.typeCreateFolder, value1: newFolder._path));
      }

      current = _foldersMap[currentPath]!;
    }

    return current;
  }

  List<RecordEntry> get conflictRecords => _conflictMap.values.toList();

  RecordEntry? findConflictRecord(String uuid) => _conflictMap[uuid];

  void _deleteRecord(String recordUuid, {bool emit = true}) {
    _conflictMap.remove(recordUuid);
    final TreeNode? file = _filesMap.remove(recordUuid);
    if (file == null) return;
    if (emit) _emit(RecordEvent(RecordEvent.typeDeleteRecord, value1: file.content.path, value2: recordUuid));

    final String folder = file.content.dir;
    final TreeNode? parent = _foldersMap[folder];
    if (parent == null) return;
    parent.removeChild(recordUuid);
    _checkAndPurgeEmptyFolder(folder);
  }

  void _checkAndPurgeEmptyFolder(String folder) {
    String current = folder;
    while (current != '/' && current != '') {
      final TreeNode? node = _foldersMap[current];
      if (node == null) return;
      if (node.children.isNotEmpty) return;

      _foldersMap.remove(current);
      _emit(RecordEvent(RecordEvent.typeDeleteFolder, value1: current));
      String parentDir = dirname(current);
      _foldersMap[parentDir]?.removeChild(current);

      current = parentDir;
    }
  }

  (TreeNode?, bool) _insertRecord(RecordEntry newRecord, {bool emit = true}) {
    if (newRecord.local.editType == LocalEditType.delete) {
      _deleteRecord(newRecord.local.uuid, emit: emit);
      return (null, false);
    }

    bool isNew = false;
    TreeNode? node = _filesMap[newRecord.local.uuid];
    final newFolderPath = normalizePath(newRecord.local.path);
    final TreeContentFile? oldFile = node?.content as TreeContentFile?;
    _conflictMap.remove(newRecord.local.uuid);
    if (newRecord.local.syncConflict) {
      _conflictMap[newRecord.local.uuid] = newRecord;
    }

    if (oldFile != null && oldFile.path == newFolderPath) {
      oldFile.setLocalRecord(newRecord);
    } else if (oldFile != null) {
      final String oldFolder = oldFile.dir;
      final TreeNode? oldParent = _foldersMap[oldFolder];

      oldParent?.removeChild(newRecord.local.uuid);

      final newParent = _ensureFolderExists(newFolderPath, emit: emit);

      oldFile.setLocalRecord(newRecord);
      newParent.insertChild(node = TreeNode(oldFile));
      _filesMap[oldFile.uuid] = node;

      _checkAndPurgeEmptyFolder(oldFolder);
    } else {
      final newParent = _ensureFolderExists(newFolderPath, emit: emit);
      final file = TreeContentFile(newRecord);
      file.setLocalRecord(newRecord);
      node = TreeNode(file);
      newParent.insertChild(node);
      _filesMap[newRecord.local.uuid] = node;
      isNew = true;
    }

    if (emit) {
      _emit(RecordEvent(RecordEvent.typeUpsertRecord, value1: newRecord.local.path, value2: newRecord.local.uuid));
    }
    return (node, isNew);
  }

  void _clearFolder(TreeNode node) {
    for (final f in node.children) {
      if (f.content is TreeContentFolder) {
        _clearFolder(f as TreeNode);
        _foldersMap.remove(f.content.key);
      } else {
        final file = f.content as TreeContentFile;
        _filesMap.remove(f.content.key);
        _conflictMap.remove(f.content.key);
        _emit(RecordEvent(RecordEvent.typeDeleteRecord, value1: file.path, value2: file.uuid));
      }
    }
    node.children.clear();
  }

  void insertRecord(RecordEntry newRecord) {
    final (node, isNew) = _insertRecord(newRecord);
    if (node != null && isNew) {
      _sortedFiles.add(node.content as TreeContentFile);
    }
    _sortedFiles.sort();
  }

  void deleteRecord(String recordUuid) {
    _deleteRecord(recordUuid);
    _sortedFiles.delete(recordUuid);
  }

  void batchUpdateRecords(List<String> deleteUUids, List<RecordEntry> records) {
    for (final uuid in deleteUUids) {
      _deleteRecord(uuid);
    }
    _sortedFiles.deleteSome(deleteUUids);
    for (final record in records) {
      final (node, isNew) = _insertRecord(record);
      if (node != null && isNew) {
        _sortedFiles.add(node.content as TreeContentFile);
      }
    }
    _sortedFiles.sort();
  }

  void deleteFolder(String folderPath) {
    folderPath = normalizePath(folderPath);
    final folder = _foldersMap[folderPath];
    if (folder == null) return;
    _clearFolder(folder);
    _checkAndPurgeEmptyFolder(folderPath);
    _sortedFiles.deleteByPath(folderPath);
  }

  void renameFolder(String oldFolderPath, String newFolderPath, int time) {
    final oldPath = normalizePath(oldFolderPath);
    final newPath = normalizePath(newFolderPath);

    if (oldPath == newPath || oldPath == '/') return;

    final sourceFolder = findFolder(oldPath);
    if (sourceFolder == null) return;
    final sourceParent = findFolder(dirname(sourceFolder.content.path));
    if (sourceParent == null) return;

    // Collect affected file uuids BEFORE merge (merge moves/recreates nodes).
    final affectedUuids = <String>[];
    _collectFileUuids(sourceFolder, affectedUuids);

    sourceParent.removeChild(sourceFolder.content.key);

    _ensureFolderExists(newPath);
    final targetFolder = findFolder(newPath)!;
    _mergeVirtualFolders(sourceFolder, targetFolder, time);

    _checkAndPurgeEmptyFolder(sourceParent.content.path);

    _sortedFiles.sort();

    // Emit upsert for each moved file so listeners (TagTree, ReminderTree,
    // bars) refresh their cached RecordEntry references.
    for (final uuid in affectedUuids) {
      _emit(RecordEvent(RecordEvent.typeUpsertRecord, value1: newPath, value2: uuid));
    }
    _emit(RecordEvent(RecordEvent.typeRenameFolder, value1: oldPath, value2: newPath));
  }

  /// Collect uuids of all TreeContentFile descendants under [node].
  void _collectFileUuids(TreeNode node, List<String> out) {
    for (final child in node.children) {
      if (child.content is TreeContentFile) {
        out.add((child.content as TreeContentFile).uuid);
      } else {
        _collectFileUuids(child as TreeNode, out);
      }
    }
  }

  void _mergeVirtualFolders(TreeNode source, TreeNode target, int time) {
    TreeNode? sourceParent = _foldersMap[source.content.dir];
    sourceParent?.removeChild(source.content.path);
    _foldersMap.remove(source.content.key);

    for (final child in source.children) {
      if (child.content is TreeContentFile) {
        final file = child.content as TreeContentFile;
        _filesMap.remove(file.key);
        file.setLocalRecord(RecordEntry(file.record.local.copyWith(path: target.content.path, editAt: time)));
        TreeNode fileNode = TreeNode(file);
        target.insertChild(fileNode);
        _filesMap[fileNode.content.key] = fileNode;
      } else {
        _foldersMap.remove(child.content.key);
        TreeNode folderNode = TreeNode(
          TreeContentFolder(child.content.path, child.content.name),
          children: child.children,
        );
        _updateDescendantsPath(folderNode, source.content.path, target.content.path, time);
        target.insertChild(folderNode);
      }
    }
    source.children.clear();
  }

  void _updateDescendantsPath(TreeNode currentFolder, String oldPrefix, String newPrefix, int time) {
    final oldFolderPath = currentFolder.content.path;
    _foldersMap.remove(oldFolderPath);

    final relativePath = oldFolderPath.substring(oldPrefix.length);
    final updatedFolderPath = newPrefix + relativePath;

    final content = currentFolder.content;
    content._path = updatedFolderPath;
    content._name = basename(updatedFolderPath);
    _foldersMap[updatedFolderPath] = currentFolder;

    for (final node in currentFolder.children) {
      if (node.content is TreeContentFile) {
        final file = node.content as TreeContentFile;
        final fileRelativePath = file.path.substring(oldPrefix.length);
        file.setLocalRecord(RecordEntry(file.record.local.copyWith(path: newPrefix + fileRelativePath, editAt: time)));
      } else {
        _updateDescendantsPath(node as TreeNode, oldPrefix, newPrefix, time);
      }
    }
  }

  TreeNode? findFolder(String path) {
    return _foldersMap[normalizePath(path)];
  }

  void createFolder(String path) {
    _ensureFolderExists(path);
    _emit(RecordEvent(RecordEvent.typeCreateFolder, value1: path));
  }
}

class RecordList {
  final List<TreeContentFile> files = [];
  static final int sSortTypeName = 1;
  static final int sSortTypeByTime = 2;
  int sortType = 0;
  void sort() {
    if (sortType == sSortTypeName) {
      files.sort((a, b) => a.name.compareTo(b.name));
    } else if (sortType == sSortTypeByTime) {
      files.sort((a, b) => b.editAt.compareTo(a.editAt));
    }
  }

  void setSortType(int type) {
    sortType = type;
  }

  void delete(String uuid) {
    files.removeWhere((e) => e.uuid == uuid);
  }

  void deleteByPath(String path) {
    files.removeWhere((e) => e.path.startsWith(path));
  }

  void deleteSome(List<String> uuids) {
    files.removeWhere((e) => uuids.contains(e.uuid));
  }

  void add(TreeContentFile file) {
    files.add(file);
  }
}
