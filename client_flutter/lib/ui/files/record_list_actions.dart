import 'dart:typed_data';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:note123/filesync/database.dart';
import 'package:note123/filesync/record_tree.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/model/record_opened_state.dart';
import 'package:note123/filesync/user.dart';
import 'package:note123/model/record_utils.dart';
import 'package:note123/ui/common/input_dialog.dart';
import 'package:note123/ui/files/record_export_dialog.dart';
import 'package:note123/ui/files/record_files_tree_control.dart';
import 'package:note123/ui/settings/login_dialog.dart';
import 'package:note123/ui/settings/theme_selector_dialog.dart';
import 'package:note123/config/language_manager.dart';
import 'package:note123/config/layout_mode.dart';
import 'package:note123/config/prefs.dart';

import 'package:note123/config/theme.dart';

import '../../utils/utils.dart';

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:charset_converter/charset_converter.dart';
import 'package:note123/ui/editor/flow_editor/custom_code_block_parser.dart';

/// Static action helpers shared by the record list page.
/// Actions are distributed between the top app bar (title, new note/folder,
/// parent, collapse) and the left side rail (sort, import/export).
class RecordListActions {
  static Widget sortTypeButton(BuildContext context) {
    int type = RecordListWidgetType.notifier.value;
    ThemeData theme = Theme.of(context);
    final isPad = LayoutMode.resolve() == LayoutMode.pad;
    return PopupMenuButton<dynamic>(
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
        if (value == LayoutMode.pad || value == LayoutMode.phone) {
          await LayoutMode.setMode(value);
          return;
        }
        Repository.get().recordTree.setSortListType(value);
        if (value != 0) RecordOpenedState.get().setOpenedFolder("/");
        RecordListWidgetType.notifier.value = value;
        await Prefs.instance.setInt(PrefKeys.listType, value);
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: RecordListWidgetType.sFlatFolder,
          child: ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: Text(l10n.sortTypeFlatFolder),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: RecordListWidgetType.sTreeFolder,
          child: ListTile(
            leading: const Icon(Icons.account_tree_outlined),
            title: Text(l10n.sortTypeTreeFolder),
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
        if (!Utils.isDesktop())
          PopupMenuItem(
            value: isPad ? LayoutMode.phone : LayoutMode.pad,
            child: ListTile(
              leading: Icon(isPad ? Icons.phone_iphone : Icons.tablet),
              title: Text(isPad ? l10n.switchToPhone : l10n.switchToPad),
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }

  static Widget importExportButton(BuildContext context, ReturnCallback<String> getFolder) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.upload_file_outlined),
      tooltip: l10n.importExport,
      onSelected: (value) {
        if (value == 'import') {
          clickOnImportDocuments(context, getFolder());
        } else if (value == 'export') {
          RecordExport.start(context, getFolder());
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'export',
          child: ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: Text(l10n.exportMd),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'import',
          child: ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: Text(l10n.importDocument),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  static Future<void> clickOnCreateRecordButton(
    BuildContext context,
    String folder,
    ValueCallback<TreeContentFile> onContentPressed,
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
    if (file != null && context.mounted) onContentPressed(file);
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

  static Widget collapseAllButton(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: RecordListWidgetType.notifier,
      builder: (context, sortType, _) {
        if (sortType != RecordListWidgetType.sTreeFolder) {
          return SizedBox.shrink();
        }
        return IconButton(
          onPressed: () {
            RecordFilesTreeControl.collapseAll.value = RecordFilesTreeControl.collapseAll.value + 1;
          },
          icon: const Icon(Icons.unfold_less_outlined),
          tooltip: l10n.collapseAll,
        );
      },
    );
  }

  static Widget newRecordButton(
    BuildContext context,
    ReturnCallback<String> getFolder,
    ValueCallback<TreeContentFile> onContentPressed,
  ) {
    return IconButton(
      onPressed: () async {
        await clickOnCreateRecordButton(context, getFolder(), onContentPressed);
      },
      icon: const Icon(Icons.edit_note_outlined),
      tooltip: l10n.newRecord,
    );
  }

  static Widget newFolderButton(BuildContext context, ReturnCallback<String> getFolder) {
    return ValueListenableBuilder<int>(
      valueListenable: RecordListWidgetType.notifier,
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
    );
  }

  static Widget themeButton(BuildContext context) {
    return IconButton(
      onPressed: () => showThemeSelector(context),
      icon: const Icon(Icons.brightness_6_outlined),
      tooltip: l10n.theme,
    );
  }

  static Widget languageButton(BuildContext context) {
    return PopupMenuButton<LanguageOption>(
      icon: const Icon(Icons.language_outlined),
      tooltip: l10n.language,
      onSelected: (option) async {
        if (option != LanguageManager.getCurrentLanguage()) {
          await LanguageManager.setLanguage(option);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: LanguageOption.system, child: Text(l10n.followSystem)),
        PopupMenuItem(value: LanguageOption.chinese, child: Text(l10n.chinese)),
        PopupMenuItem(value: LanguageOption.english, child: Text(l10n.english)),
      ],
    );
  }

  static Widget calendarButton(BuildContext context, ValueCallback<BuildContext> onTap) {
    final theme = Theme.of(context);
    final icon = Icon(Icons.calendar_today_outlined, color: theme.colorScheme.primary);
    return ValueListenableBuilder<int>(
      valueListenable: Repository.get().reminderTree.todayCountNotifier,
      builder: (context, count, _) {
        return IconButton(
          onPressed: () => onTap(context),
          tooltip: l10n.calendarTasks,
          icon: _wrapCountBadge(icon, count),
        );
      },
    );
  }

  static Widget recyclerButton(BuildContext context, ValueCallback<BuildContext> onTap) {
    return ValueListenableBuilder<int>(
      valueListenable: Repository.get().recyclerCountNotifier,
      builder: (context, count, _) {
        final icon = Icon(Icons.delete_outline);
        return IconButton(onPressed: () => onTap(context), tooltip: l10n.recycler, icon: _wrapCountBadge(icon, count));
      },
    );
  }

  static Widget _wrapCountBadge(Widget icon, int count) {
    if (count <= 0) return icon;
    return Badge(
      alignment: Alignment.bottomRight,
      offset: const Offset(0, -8),
      largeSize: 12,
      textStyle: const TextStyle(fontSize: 10, height: 1.0),
      label: Text('$count'),
      child: icon,
    );
  }

  static Widget recordsCountIndicator(BuildContext context) {
    final recordTree = Repository.get().recordTree;
    final theme = Theme.of(context);
    return ValueListenableBuilder<List<RecordEvent>>(
      valueListenable: recordTree.refreshNotifier,
      builder: (context, _, _) {
        final count = recordTree.recordsCount;
        return Tooltip(
          message: "$count ${l10n.files}",
          child: IconButton(
            onPressed: () {},
            style: const ButtonStyle(
              shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.zero)),
            ),
            icon: Text("$count", style: TextStyle(fontSize: 14, color: theme.colorScheme.primary)),
          ),
        );
      },
    );
  }
}
