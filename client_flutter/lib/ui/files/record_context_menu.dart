import 'dart:io';

import 'package:note123/filesync/file_store.dart';
import 'package:note123/filesync/record_tree.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/ui/common/input_dialog.dart';
import 'package:note123/ui/files/record_list_bottom_bar.dart';
import 'package:note123/ui/files/record_move_dialog.dart';
import 'package:note123/config/language_manager.dart';
import 'package:note123/utils/utils.dart';
import 'package:note123/config/app_config.dart';
import 'package:flutter/material.dart';

Future<void> showRecordContextMenu(
  BuildContext context,
  TreeContent file,
  Offset position,
  ValueCallback<TreeContentFile>? onClickFile,
) async {
  final isFile = file is TreeContentFile;
  final isFolder = file is TreeContentFolder;
  final actions = <PopupMenuEntry<String>>[];

  if (isFile) {
    actions.add(PopupMenuItem<String>(value: 'move', child: Text(l10n.moveFile)));
    if (file.locked != 0) {
      actions.add(PopupMenuItem<String>(value: 'unlock', child: Text(l10n.unlockFile)));
    } else {
      actions.add(PopupMenuItem<String>(value: 'lock', child: Text(l10n.lockFile)));
    }
  } else {
    actions.add(PopupMenuItem<String>(value: 'newRecord', child: Text(l10n.newRecord)));
    actions.add(PopupMenuItem<String>(value: 'newFolder', child: Text(l10n.newFolder)));
    if (Utils.isDesktop()) {
      actions.add(PopupMenuItem<String>(value: 'importDocument', child: Text(l10n.importDocument)));
    }
    actions.add(PopupMenuItem<String>(value: 'rename', child: Text(l10n.renameFolder)));
    actions.add(PopupMenuItem<String>(value: 'move', child: Text(l10n.moveFolder)));
  }
  actions.add(PopupMenuItem<String>(value: 'delete', child: Text(isFile ? l10n.deleteFile : l10n.deleteFolder)));

  // Calculate popup menu position
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final offset = overlay.localToGlobal(Offset.zero);
  final menuPosition = RelativeRect.fromLTRB(
    position.dx + offset.dx,
    position.dy + offset.dy,
    overlay.size.width - position.dx - offset.dx,
    overlay.size.height - position.dy - offset.dy,
  );

  final result = await showMenu<String>(
    context: context,
    position: menuPosition,
    items: actions,
    popUpAnimationStyle: AppConfig.menuAnimationStyle,
  );
  if (context.mounted == false || result == null) return;

  if (result == 'rename') {
    String oldName = file.name;
    final newName = await showInputDialog(context, l10n.rename, oldName, false);
    if (context.mounted && newName != null && newName.isNotEmpty && newName != oldName) {
      if (isFile) {
        await _renameRecord(context, file, newName);
      } else if (isFolder) {
        await _renameFolder(context, file, '${file.dir}$newName/');
      }
    }
  } else if (result == 'move' && isFile) {
    _showRecordMoveDialog(context, file);
  } else if (result == 'move' && isFolder) {
    showFolderMoveDialog(context, file);
  } else if (result == 'delete') {
    if (isFile) {
      _deleteRecord(context, file);
    } else if (isFolder) {
      _deleteFolder(context, file);
    }
  } else if (result == 'lock' && isFile) {
    showInputDialog(context, "${l10n.enterLockPassword} ${file.name}", "", false).then((pass) {
      if (pass == null || pass.isEmpty || context.mounted == false) return;
      _lockRecord(context, file, pass, true);
    });
  } else if (result == 'unlock' && isFile) {
    showInputDialog(context, "${l10n.enterUnlockPassword} ${file.name}", "", true).then((pass) async {
      if (pass == null || pass.isEmpty || context.mounted == false) return;
      await _lockRecord(context, file, pass, false);
    });
  } else if (result == 'newRecord' && isFolder) {
    RecordListBottomBar.clickOnCreateRecordButton(context, file.path, onClickFile);
  } else if (result == 'newFolder' && isFolder) {
    RecordListBottomBar.clickOnCreateFolderButton(context, file.path);
  } else if (result == 'importDocument' && isFolder) {
    RecordListBottomBar.clickOnImportDocuments(context, file.path);
  }
}

void _showRecordMoveDialog(BuildContext context, TreeContentFile file) {
  // Use RecordMoveControl for type and folder selection
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      contentPadding: EdgeInsets.zero,
      content: RecordMoveControl(
        title: l10n.moveFileTo(file.name),
        initFolder: file.path,
        onConfirm: (path) {
          moveRecordToPath(context, file, path);
        },
      ),
    ),
  );
}

void showFolderMoveDialog(BuildContext context, TreeContentFolder folder) {
  // Use RecordMoveControl for type and folder selection
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      contentPadding: EdgeInsets.zero,
      content: RecordMoveControl(
        title: l10n.moveFileTo(folder.name),
        initFolder: "/",
        onConfirm: (path) {
          _renameFolder(context, folder, "$path${folder.name}/");
        },
      ),
    ),
  );
}

Future<void> moveRecordToPath(BuildContext context, TreeContentFile file, String newPath) async {
  var newRecord = await Repository.get().editRecord(
    file.uuid,
    false,
    DateTime.now().millisecondsSinceEpoch,
    path: newPath,
  );
  if (newRecord == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.saveRecordFailed)));
    }
    return;
  }
  if (context.mounted) {
    final fileName = newRecord.localName;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.movedToPath(fileName, newPath)), duration: const Duration(seconds: 2)));
  }
}

Future<void> moveFolderToPath(BuildContext context, TreeContentFolder folder, String newParentPath) async {
  await _renameFolder(context, folder, "$newParentPath${folder.name}/");
}

Future<void> _lockRecord(BuildContext context, TreeContentFile record, String pass, bool lock) async {
  FileStore? fileStore = Repository.get().fileStore;
  if (fileStore == null) {
    return;
  }
  String? content = await _readRecordFile(record);
  if (content == null) {
    if (context.mounted) {
      // If content cannot be read, prompt user
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.cannotReadRecordContent)));
    }
    return;
  }
  String lockTips = lock ? l10n.lock : l10n.unlock;
  // Use pass to lock content
  final encryptedContent = lock ? Utils.encryptContent(content, pass) : Utils.decryptContent(content, pass);
  if (encryptedContent == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.lockUnlockFailedCheckPassword(lockTips))));
    }
    return;
  }

  // Save locked content to file
  try {
    final file = File(fileStore.getWorkFile(record.uuid));
    await file.writeAsString(encryptedContent);

    await Repository.get().editRecord(
      record.uuid,
      true,
      DateTime.now().millisecondsSinceEpoch,
      locked: lock ? 1 : 0,
      md5: Utils.generateMd5(encryptedContent),
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.recordLockUnlockCompleted(lockTips))));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.saveLockUnlockContentFailed(lockTips))));
    }
  }
}

Future<String?> _readRecordFile(TreeContentFile record) async {
  FileStore? fileStore = Repository.get().fileStore;
  if (fileStore == null) {
    return null;
  }
  File file = File(fileStore.getWorkFile(record.uuid));
  if (record.version > 0 && !file.existsSync()) {
    file = File(fileStore.getBaseFile(record.uuid));
    if (!file.existsSync()) {
      // If this is an existing record, try downloading from cloud
      await fileStore.downloadBaseFile(record.uuid);
    }
  }
  if (!file.existsSync()) {
    return null;
  }
  return file.readAsStringSync();
}

// Show password input dialog to lock/unlock records

// File/folder operation interface
Future<void> _renameRecord(BuildContext context, TreeContentFile record, String newName) async {
  String oldName = record.name;
  if (oldName == newName) return; // No actual change

  await Repository.get().editRecord(record.uuid, false, DateTime.now().millisecondsSinceEpoch, name: newName);
}

Future<void> _renameFolder(BuildContext context, TreeContentFolder folder, String newPath) async {
  final oldPath = folder.path;
  if (oldPath == newPath) return; // No actual change

  Repository.get().renameFolder(folder.path, newPath);
}

void _deleteRecord(BuildContext context, TreeContentFile file) async {
  // First save to pending-sync table, operation type is delete
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.confirmDelete),
      content: Text(l10n.confirmDeleteThisRecord),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.delete, style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  if (confirm != true || context.mounted == false) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.recordDeleted('file.name'))));
  Repository.get().deleteRecord(file.uuid);
}

void _deleteFolder(BuildContext context, TreeContentFolder folder) async {
  // First save to pending-sync table, operation type is delete
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.confirmDelete),
      content: Text(l10n.confirmDeleteThisFolderAndAllRecords),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.delete, style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  if (confirm != true || context.mounted == false) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.folderDeleted(folder.path))));

  Repository.get().deleteFolder(folder.path);
}
