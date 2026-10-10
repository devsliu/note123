import 'package:flutter/widgets.dart';
import 'package:note123/filesync/database.dart';
import 'package:note123/filesync/local_record_ext.dart';
import 'package:note123/filesync/record_utils.dart';
import 'package:note123/filesync/table_record.dart';
import 'package:note123/utils/app_logger.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

class RecordEvent {
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
  LocalRecord _record;
  int _editAt;

  TreeContentFile(this._record) : _editAt = _record.localEditAt, super(_record.localPath, _record.localName);

  String get uuid => _record.uuid;
  String get md5 => _record.remoteMd5;
  int get version => _record.remoteVersion;
  int get createAt => _record.remoteCreateAt;
  int get editAt => _editAt;
  int get fileEditAt => _record.localFileEditAt;
  bool get syncConflict => _record.syncConflict;
  int get locked => _record.localLocked;
  // All LocalRecord fields are final; setLocalRecord replaces the whole thing during sync,
  // external callers can compare before/after to determine if file/title changed
  LocalRecord get record => _record;

  @override
  String get dir => _path;
  @override
  String get key => _record.uuid;

  void setLocalRecord(LocalRecord record) {
    _record = record;
    _path = record.localPath;
    _name = record.localName;
    _editAt = record.localEditAt;
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
  final Map<String /* uuid */, LocalRecord> _conflictMap = {};

  // Since TreeContentFile objects once created always exist and are only modified, never re-created until delete,
  // only insert and delete operations need to modify _recentlyFiles array; rename/name changes and edits only need sorting
  final RecordList _sortedFiles = RecordList();

  final ValueNotifier<List<RecordEvent>> refreshNotifier = ValueNotifier<List<RecordEvent>>([]);

  RecordTree() : super(TreeContentFolder("/", ""));

  void build(List<LocalRecord> allRecords) {
    // 1. Create root node
    children.clear();
    _foldersMap.clear();
    _filesMap.clear();
    _conflictMap.clear();
    _foldersMap["/"] = this;

    _sortedFiles.files.clear();

    List<RecordEvent> eventList = [];
    for (final n in allRecords) {
      final (node, isNew) = _insertRecord(n, eventList);
      if (node != null && isNew) {
        _sortedFiles.add(node.content as TreeContentFile);
      }
    }
    _sortedFiles.sort();
    _notifyEvents(eventList);
  }

  int get recordsCount => _filesMap.length;
  List<TreeContentFile> get sortedFiles => _sortedFiles.files;

  void setSortListType(int type) {
    _sortedFiles.setSortType(type);
    _sortedFiles.sort();
  }

  TreeContentFile? findFile(String uuid) {
    return _filesMap[uuid]?.content as TreeContentFile?;
  }

  TreeNode? findFileNode(String uuid) {
    return _filesMap[uuid];
  }

  /// Helper: ensure a folder exists by path; if not, recursively create and attach to tree
  TreeNode _ensureFolderExists(String folderPath, List<RecordEvent> eventList) {
    // If already created, return directly
    if (_foldersMap.containsKey(folderPath)) {
      return _foldersMap[folderPath]!;
    }

    // If not, we need to break it down level by level upward and ensure parents exist
    // e.g. break "/work/flutter/ui/" into: "/", "/work/", "/work/flutter/", "/work/flutter/ui/"
    final segments = folderPath.split('/').where((s) => s.isNotEmpty).toList();

    String currentPath = '/';
    TreeNode current = this;

    for (final segment in segments) {
      currentPath += '$segment/';

      // If this level's folder hasn't been created yet
      if (!_foldersMap.containsKey(currentPath)) {
        final newFolder = TreeContentFolder(currentPath, segment);
        final treeNode = TreeNode(newFolder);
        _foldersMap[currentPath] = treeNode;

        // Attach it to the parent folder's children list
        current.insertChild(treeNode);
        current = treeNode;

        eventList.add(RecordEvent(RecordEvent.typeCreateFolder, value1: newFolder._path));
      }

      // Move pointer down
      current = _foldersMap[currentPath]!;
    }

    return current;
  }

  List<LocalRecord> get conflictRecords => _conflictMap.values.toList();

  LocalRecord? findConflictRecord(String uuid) => _conflictMap[uuid];

  void _deleteRecord(String recordUuid, List<RecordEvent> eventList) {
    _conflictMap.remove(recordUuid);
    // 1. Get its parent folder path
    final TreeNode? file = _filesMap.remove(recordUuid);
    if (file == null) return;
    eventList.add(RecordEvent(RecordEvent.typeDeleteRecord, value1: file.content.path, value2: recordUuid));

    final String folder = file.content.dir;
    final TreeNode? parent = _foldersMap[folder];
    if (parent == null) return;
    // 2. O(1) locate and physically delete the record
    parent.removeChild(recordUuid);
    // 3. 🧠 Smart cleanup: if this folder has neither records nor subfolders anymore, it's an empty shell; remove it too
    _checkAndPurgeEmptyFolder(folder, eventList);
  }

  // Recursively clean up empty folders
  void _checkAndPurgeEmptyFolder(String folder, List<RecordEvent> eventList) {
    String current = folder;
    while (current != '/' && current != '') {
      final TreeNode? node = _foldersMap[current];
      if (node == null) return;
      if (node.children.isNotEmpty) return;

      _foldersMap.remove(current);
      eventList.add(RecordEvent(RecordEvent.typeDeleteFolder, value1: current));
      String parentDir = dirname(current);
      _foldersMap[parentDir]?.removeChild(current);

      current = parentDir;
    }
  }

  (TreeNode?, bool) _insertRecord(LocalRecord newRecord, List<RecordEvent> eventList) {
    if (newRecord.localEditType == LocalEditType.delete) {
      _deleteRecord(newRecord.uuid, eventList);
      return (null, false);
    }

    bool isNew = false;
    TreeNode? node = _filesMap[newRecord.uuid];
    final newFolderPath = ensurePathFormat(newRecord.localPath);
    final TreeContentFile? oldFile = node?.content as TreeContentFile?;
    _conflictMap.remove(newRecord.uuid);
    if (newRecord.syncConflict) {
      _conflictMap[newRecord.uuid] = newRecord;
    }

    if (oldFile != null && oldFile.path == newFolderPath) {
      // 🟢 Case A: in-place modification (title, modification time, etc. changed, directory unchanged)
      oldFile.setLocalRecord(newRecord);
    } else if (oldFile != null) {
      // 🟢 Case B: cross-directory move
      final String oldFolder = oldFile.dir;
      final TreeNode? oldParent = _foldersMap[oldFolder];

      // 1. Detach from old home
      oldParent?.removeChild(newRecord.uuid);

      // 2. Ensure new home folder exists
      final newParent = _ensureFolderExists(newFolderPath, eventList);

      // 3. Update internal record, create new TreeNode to trigger Flutter TreeView structural change detection
      oldFile.setLocalRecord(newRecord);
      newParent.insertChild(node = TreeNode(oldFile));
      _filesMap[oldFile.uuid] = node;

      // 4. Clean up if old home is empty
      _checkAndPurgeEmptyFolder(oldFolder, eventList);
    } else {
      // 🟢 Case C: absolute new record registration
      final newParent = _ensureFolderExists(newFolderPath, eventList);
      final file = TreeContentFile(newRecord);
      file.setLocalRecord(newRecord);
      node = TreeNode(file);
      newParent.insertChild(node);
      _filesMap[newRecord.uuid] = node;
      isNew = true;
    }

    eventList.add(RecordEvent(RecordEvent.typeUpsertRecord, value1: newRecord.localPath, value2: newRecord.uuid));
    return (node, isNew);
  }

  void _clearFolder(TreeNode node) {
    for (final f in node.children) {
      if (f.content is TreeContentFolder) {
        _clearFolder(f as TreeNode);
        _foldersMap.remove(f.content.key);
      } else {
        _filesMap.remove(f.content.key);
        _conflictMap.remove(f.content.key);
      }
    }
    node.children.clear();
  }

  void _notifyEvents(List<RecordEvent> eventList) {
    if (eventList.isEmpty) return;
    for (final event in eventList) {
      AppLogger.i("_notifyEvent ${event.type}");
    }
    // Directly use event list as value, listeners can filter by uuid accordingly
    refreshNotifier.value = List.unmodifiable(eventList);
  }

  void insertRecord(LocalRecord newRecord) {
    List<RecordEvent> eventList = [];
    final (node, isNew) = _insertRecord(newRecord, eventList);
    if (node != null && isNew) {
      _sortedFiles.add(node.content as TreeContentFile);
    }
    _sortedFiles.sort();
    _notifyEvents(eventList);
  }

  void deleteRecord(String recordUuid) {
    List<RecordEvent> eventList = [];
    _deleteRecord(recordUuid, eventList);
    _sortedFiles.delete(recordUuid);
    _notifyEvents(eventList);
  }

  void batchUpdateRecords(List<String> deleteUUids, List<LocalRecord> records) {
    List<RecordEvent> eventList = [];
    for (final uuid in deleteUUids) {
      _deleteRecord(uuid, eventList);
    }
    _sortedFiles.deleteSome(deleteUUids);
    for (final record in records) {
      final (node, isNew) = _insertRecord(record, eventList);
      if (node != null && isNew) {
        _sortedFiles.add(node.content as TreeContentFile);
      }
    }
    _sortedFiles.sort();
    _notifyEvents(eventList);
  }

  void deleteFolder(String folderPath) {
    folderPath = ensurePathFormat(folderPath);
    final folder = _foldersMap[folderPath];
    if (folder == null) return;
    List<RecordEvent> eventList = [];
    _clearFolder(folder);
    _checkAndPurgeEmptyFolder(folderPath, eventList);
    _sortedFiles.deleteByPath(folderPath);
    _notifyEvents(eventList);
  }

  /// 👑 Main entry point for folder rename (perfectly adapts to virtual file structure)
  void renameFolder(String oldFolderPath, String newFolderPath, int time) {
    // 1. Force-format and clean input paths
    final oldPath = ensurePathFormat(oldFolderPath);
    final newPath = ensurePathFormat(newFolderPath);

    // Defense: if paths are exactly same, or attempting to rename root directory, reject directly
    if (oldPath == newPath || oldPath == '/') return;

    List<RecordEvent> eventList = [];

    // 2. Find the target source folder object to be renamed
    final sourceFolder = findFolder(oldPath);
    if (sourceFolder == null) return; // Old folder not found, safe exit
    final sourceParent = findFolder(dirname(sourceFolder.content.path));
    if (sourceParent == null) return; // Old folder's parent not found, also safe exit
    sourceParent.removeChild(sourceFolder.content.key);

    // _ensureFolderExists already guarantees newPath node exists (creates if missing),
    // therefore target must not be null; uniformly use merge logic: transfer source's descendants to target
    _ensureFolderExists(newPath, eventList);
    final targetFolder = findFolder(newPath)!;
    _mergeVirtualFolders(sourceFolder, targetFolder, time);

    _checkAndPurgeEmptyFolder(sourceParent.content.path, eventList);

    // Folder modification does not involve content object add/delete, only update sortedFiles
    _sortedFiles.sort();

    // 4. Notify of state change
    eventList.add(RecordEvent(RecordEvent.typeRenameFolder, value1: oldPath, value2: newPath));
    _notifyEvents(eventList);
  }

  /// 🧬 Merge same-named purely virtual structures
  /// Transfer all descendant nodes in [source] to [target] in original condition, completely discard [source] container
  void _mergeVirtualFolders(TreeNode source, TreeNode target, int time) {
    // 1. First completely unbind old source folder from its original parent and global Map (unbind old container)
    TreeNode? sourceParent = _foldersMap[source.content.dir];
    sourceParent?.removeChild(source.content.path);
    _foldersMap.remove(source.content.key);

    // 2. Virtual file move: directly batch inject into new folder's files container
    for (final child in source.children) {
      if (child.content is TreeContentFile) {
        final file = child.content as TreeContentFile;
        _filesMap.remove(file.key);
        // Use setLocalRecord to also update _record.localPath / _record.localEditAt,
        // avoid only changing _path causing record.path to return stale value during window
        file.setLocalRecord(file.record.copyWith(localPath: target.content.path, localEditAt: time));
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
        // After path correction, must attach under target, otherwise this subfolder only exists in _foldersMap,
        // missing this entire layer when UI tree traverses target.children
        target.insertChild(folderNode);
      }
    }
    source.children.clear();
  }

  /// 🧠 Full-scope cascade path correction algorithm (absolute reference anchor version)
  /// Responsible for replacing the virtual path of [currentFolder] and all its descendants (files and folders)
  /// from [oldPrefix] with [newPrefix] as a whole shift
  void _updateDescendantsPath(TreeNode currentFolder, String oldPrefix, String newPrefix, int time) {
    // 1. First remove self from global old map cache
    final oldFolderPath = currentFolder.content.path;
    _foldersMap.remove(oldFolderPath);

    // 2. Precisely compute current folder's absolute virtual path in new environment
    // e.g.: oldPrefix is "/work/", newPrefix is "/job/"
    // Current node is "/work/flutter/" → cut prefix to get "flutter/" → prepend new prefix to get "/job/flutter/"
    final relativePath = oldFolderPath.substring(oldPrefix.length);
    final updatedFolderPath = newPrefix + relativePath;

    // 3. Correct content's path/name in place and re-index.
    // Cannot replace with new TreeNode: parent's children still hold the old node,
    // which would cause _foldersMap to be inconsistent with real tree structure references
    final content = currentFolder.content;
    content._path = updatedFolderPath;
    content._name = basename(updatedFolderPath); // Ensure virtual name updates synchronously with path
    _foldersMap[updatedFolderPath] = currentFolder;

    // 4. 📝 Batch correct virtual path of files directly under current folder
    for (final node in currentFolder.children) {
      if (node.content is TreeContentFile) {
        final file = node.content as TreeContentFile;
        final fileRelativePath = file.path.substring(oldPrefix.length);
        // Use setLocalRecord to update _record synchronously, avoid dirty reads during record.path window
        file.setLocalRecord(file.record.copyWith(localPath: newPrefix + fileRelativePath, localEditAt: time));
      } else {
        // 5. 🌊 Recurse downward: correct all subfolders
        // Core closure: when passing downward, oldPrefix and newPrefix as absolute references remain unchanged!
        _updateDescendantsPath(node as TreeNode, oldPrefix, newPrefix, time);
      }
    }
  }

  TreeNode? findFolder(String path) {
    return _foldersMap[ensurePathFormat(path)];
  }

  void createFolder(String path) {
    _ensureFolderExists(path, []);
    _notifyEvents([RecordEvent(RecordEvent.typeCreateFolder, value1: path)]);
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
