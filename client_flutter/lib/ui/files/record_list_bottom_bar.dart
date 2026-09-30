import 'dart:typed_data';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:note123/filesync/database.dart';
import 'package:note123/filesync/record_tree.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/filesync/user.dart';
import 'package:note123/model/record_utils.dart';
import 'package:note123/ui/common/global_value_notify.dart';
import 'package:note123/ui/common/input_dialog.dart';
import 'package:note123/ui/settings/login_dialog.dart';
import 'package:note123/config/language_manager.dart';
import 'package:note123/config/prefs.dart';

import 'package:note123/config/theme.dart';

import '../../utils/utils.dart';

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:charset_converter/charset_converter.dart';
import 'package:note123/ui/editor/flow_editor/custom_code_block_parser.dart';

class RecordListBottomBar extends StatelessWidget {
  final double buttonSpacing;
  final double leftPadding;
  final double rightPadding;
  final ReturnCallback<String> getFolder;
  final ValueCallback2<BuildContext, TreeContentFile> onClickRecordFile;
  const RecordListBottomBar({
    super.key,
    required this.getFolder,
    required this.onClickRecordFile,
    required this.buttonSpacing,
    required this.leftPadding,
    required this.rightPadding,
  });

  @override
  Widget build(BuildContext context) {
    final RecordTree recordTree = Repository.get().recordTree;
    ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(left: leftPadding, right: rightPadding, top: 2, bottom: 2),
      color: theme.appBarBackgroundColor,
      child: IconButtonTheme(
        data: theme.appBarIconButtonTheme,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: buttonSpacing,
          children: [
            ValueListenableBuilder<List<RecordEvent>>(
              valueListenable: recordTree.refreshNotifier,
              builder: (context, count, _) {
                return Text(
                  "${recordTree.recordsCount} ${l10n.files}",
                  style: TextStyle(fontSize: 16, color: theme.appBarForegroundColor),
                );
              },
            ),
            Expanded(child: SizedBox()),
            ...staticButtons(context, () {
              if (GlobalValueNotify.recordListWidgetType.value == RecordListWidgetType.sTreeFolder) {
                return "/";
              }
              return recordTree.openedFolder.path;
            }, (record) => onClickRecordFile(context, record)),
          ],
        ),
      ),
    );
  }

  static Widget sortTypeButton(BuildContext context) {
    int type = GlobalValueNotify.recordListWidgetType.value;
    ThemeData theme = Theme.of(context);
    return PopupMenuButton(
      iconColor: theme.appBarIconColor,
      icon: Icon(
        type == RecordListWidgetType.sFlatFolder
            ? Icons.folder_outlined
            : type == RecordListWidgetType.sOrderByName
            ? Icons.sort_by_alpha_outlined
            : type == RecordListWidgetType.sOrderByByTime
            ? Icons.timer_outlined
            : Icons.account_tree_outlined,
      ),
      tooltip: l10n.sortType,
      onSelected: (value) async {
        Repository.get().recordTree.setSortListType(value);
        GlobalValueNotify.recordListWidgetType.value = value;
        await Prefs.instance.setInt(PrefKeys.listType, value);
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: RecordListWidgetType.sTreeFolder,
          child: ListTile(
            leading: const Icon(Icons.account_tree_outlined),
            title: Text(l10n.sortTypeTreeFolder),
            contentPadding: EdgeInsets.zero,
          ),
        ),

        PopupMenuItem(
          value: RecordListWidgetType.sFlatFolder,
          child: ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: Text(l10n.sortTypeFlatFolder),
            contentPadding: EdgeInsets.zero,
          ),
        ),

        PopupMenuItem(
          value: RecordList.sSortTypeName,
          child: ListTile(
            leading: const Icon(Icons.sort_by_alpha_outlined),
            title: Text(l10n.sortTypeName),
            contentPadding: EdgeInsets.zero,
          ),
        ),

        PopupMenuItem(
          value: RecordList.sSortTypeByTime,
          child: ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: Text(l10n.sortTypeTime),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  static List<Widget> staticButtons(
    BuildContext context,
    ReturnCallback<String> getFolder,
    ValueCallback<TreeContentFile>? onClickFile,
  ) {
    return [
      IconButton(
        onPressed: () async {
          await clickOnCreateRecordButton(context, getFolder(), onClickFile);
        },
        icon: const Icon(Icons.edit_note_outlined),
        tooltip: l10n.newRecord,
      ),
      ValueListenableBuilder<int>(
        valueListenable: GlobalValueNotify.recordListWidgetType,
        builder: (context, type, _) {
          if (type == RecordListWidgetType.sFlatFolder || type == RecordListWidgetType.sTreeFolder) {
            return IconButton(
              onPressed: () {
                clickOnCreateFolderButton(context, getFolder());
              },
              icon: const Icon(Icons.create_new_folder_outlined),
              tooltip: l10n.newFolder,
            );
          }
          return SizedBox.shrink();
        },
      ),

      IconButton(
        onPressed: () {
          clickOnImportDocuments(context, getFolder());
        },
        icon: const Icon(Icons.upload_file_outlined),
        tooltip: l10n.importDocument,
      ),
      ValueListenableBuilder<int>(
        valueListenable: GlobalValueNotify.recordListWidgetType,
        builder: (context, type, _) {
          return sortTypeButton(context);
        },
      ),
    ];
  }

  static Future<void> clickOnCreateRecordButton(
    BuildContext context,
    String folder,
    ValueCallback<TreeContentFile>? onClickFile,
  ) async {
    if (!User.instance.isLogin.value) {
      final result = await LoginDialog.show(context);
      if (result != true) return;
    }
    RecordTree recordTree = Repository.get().recordTree;

    LocalRecord? record = await Repository.get().createRecord(folder, RecordUtils.generateRecordName(), true, 0);
    if (record == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.saveRecordFailed)));
      }
      return;
    }

    TreeContentFile? file = recordTree.findFile(record.uuid);
    if (file != null && onClickFile != null) onClickFile(file);
  }

  static void clickOnCreateFolderButton(BuildContext context, String path) async {
    if (!User.instance.isLogin.value) {
      final result = await LoginDialog.show(context);
      if (result != true) return;
    }
    if (!context.mounted) return;
    String? folder = await showInputDialog(context, l10n.newFolder, "", false);
    if (folder == null) return;

    Repository.get().recordTree.createFolder(path + folder);
  }

  static Future<String> decodeBytesWithFallback(Uint8List bytes) async {
    try {
      return utf8.decode(bytes);
    } catch (e) {
      try {
        return await CharsetConverter.decode("GBK", bytes);
      } catch (e) {
        return latin1.decode(bytes);
      }
    }
  }

  static Future<void> saveImportDocument(String path, Document document) async {
    String name = RecordUtils.getTitleFromDelta(document);
    if (name.isEmpty) {
      name = RecordUtils.generateRecordName();
    }
    final String jsonString = jsonEncode(document.toJson());
    var record = await Repository.get().createRecord(path, name, false, DateTime.now().millisecondsSinceEpoch);
    if (record == null) return;
    try {
      await Repository.get().fileStore?.createWorkFile(record.uuid, jsonString);
    } catch (e) {
      await Repository.get().purgeUnsyncedRecord(record.uuid);
      rethrow;
    }
  }

  static void clickOnImportDocuments(BuildContext context, String path) async {
    if (!User.instance.isLogin.value) {
      final result = await LoginDialog.show(context);
      if (result != true) return;
    }
    if (!context.mounted) return;
    int importCount = 0;
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: true,
        allowedExtensions: ['md', 'txt'],
      );

      if (result != null) {
        for (PlatformFile file in result.files) {
          var bytes = file.bytes;
          if (bytes == null && file.path != null) {
            bytes = await File(file.path!).readAsBytes();
          }
          if (bytes == null) continue;
          String content = await decodeBytesWithFallback(bytes);
          if (content.isEmpty) continue;
          final ext = file.extension?.toLowerCase();
          if (ext == 'md' || ext == 'txt') {
            Document delta = markdownToDocument(content, markdownParsers: const [CustomMarkdownCodeBlockParser()]);
            await saveImportDocument(path, delta);
            importCount++;
          }
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.importSuccess)));
        }
      } else {}
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${l10n.importFailed} $e")));
      }
    } finally {
      if (importCount > 0) {
        Repository.get().syncRecords(false);
      }
    }
  }
}
