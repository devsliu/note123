import 'package:flutter/widgets.dart';
import 'package:note123/filesync/record_tree.dart';
import 'package:note123/filesync/record_utils.dart';
import 'package:note123/filesync/repository.dart';

/// Tracks which folder and record are currently open in the UI.
///
/// This is navigation/selection state rather than part of the record tree
/// structure, so it lives separately from [RecordTree]. The tree resolves the
/// stored path/uuid to actual nodes/content when needed.
///
/// On first access via [get], this state binds to `Repository.get().recordTree`
/// and listens to its refresh events. When a folder is deleted and it was the
/// currently opened folder, the opened folder is moved to its parent.
class RecordOpenedState {
  static final RecordOpenedState _instance = RecordOpenedState._();
  RecordOpenedState._();

  static RecordOpenedState get() {
    if (_instance._tree == null) {
      _instance.bind(Repository.get().recordTree);
    }
    return _instance;
  }

  //path
  final ValueNotifier<String> openedFolderNotifier = ValueNotifier<String>("/");
  //uuid
  final ValueNotifier<String> openedFileNotifier = ValueNotifier<String>("");

  /// Stack of opened record uuids; the last element is the currently active one.
  final List<String> openedUuids = [];

  RecordTree? _tree;

  /// Attach to [tree] and start listening for folder delete events so the
  /// opened folder can be adjusted automatically.
  void bind(RecordTree tree) {
    _tree = tree;
    tree.refreshNotifier.addListener(_onTreeEvents);
  }

  void _onTreeEvents() {
    final tree = _tree;
    if (tree == null) return;
    for (final event in tree.refreshNotifier.value) {
      switch (event.type) {
        case RecordEvent.typeDeleteFolder:
          final deletedPath = event.value1!;
          final current = openedFolderNotifier.value;
          // The opened folder is gone if it was the deleted folder itself or a
          // descendant (deleteFolder clears all subfolders silently). Navigate
          // to the deleted folder's parent in either case.
          if (current == deletedPath || current.startsWith(deletedPath)) {
            setOpenedFolder(dirname(deletedPath));
          }
          break;
        case RecordEvent.typeRenameFolder:
          final oldPath = event.value1!;
          final newPath = event.value2!;
          final current = openedFolderNotifier.value;
          // Remap the opened folder if it was the renamed folder or a descendant.
          if (current == oldPath || current.startsWith(oldPath)) {
            setOpenedFolder(newPath + current.substring(oldPath.length));
          }
          break;
        case RecordEvent.typeCreateFolder:
          // Creating a folder does not change the currently opened folder.
          break;
      }
    }
  }

  /// Open [uuid]: move it to the top of the stack (or add it) and make it the
  /// currently active record.
  void openFile(String uuid) {
    openedUuids.remove(uuid);
    openedUuids.add(uuid);
    _syncOpenedFile();
  }

  /// Close [uuid]: remove it from the stack. The previous record (if any)
  /// becomes active again.
  void closeFile(String uuid) {
    openedUuids.remove(uuid);
    _syncOpenedFile();
  }

  void _syncOpenedFile() {
    openedFileNotifier.value = openedUuids.isNotEmpty ? openedUuids.last : "";
  }

  void setOpenedFolder(String path) {
    openedFolderNotifier.value = path;
  }

  TreeNode? get openedFileNode {
    return _tree?.findFileNode(openedFileNotifier.value);
  }

  TreeNode get openedFolderNode {
    return _tree?.findFolder(openedFolderNotifier.value) ?? _tree!;
  }

  TreeContentFolder get openedFolder {
    return openedFolderNode.content as TreeContentFolder;
  }

  TreeContentFile? get openedFile => openedFileNode?.content as TreeContentFile?;
}
