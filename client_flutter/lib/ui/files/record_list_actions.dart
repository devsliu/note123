import 'dart:math';
import 'dart:typed_data';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:note123/filesync/record_ext.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/model/record_opened_state.dart';
import 'package:note123/model/record_utils.dart';
import 'package:note123/ui/common/input_dialog.dart';
import 'package:note123/ui/base_app.dart';
import 'package:note123/ui/files/record_export_dialog.dart';
import 'package:note123/ui/settings/theme_selector_dialog.dart';
import 'package:note123/config/language_manager.dart';
import 'package:note123/config/layout_mode.dart';

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
  static List<PopupMenuEntry<String>> _noteListMenuItems() => [
    PopupMenuItem(
      value: ListPageType.typeFlat,
      child: ListTile(
        leading: const Icon(Icons.folder_outlined),
        title: Text(l10n.sortTypeFlatFolder),
        contentPadding: EdgeInsets.zero,
      ),
    ),
    PopupMenuItem(
      value: ListPageType.typeTree,
      child: ListTile(
        leading: const Icon(Icons.account_tree_outlined),
        title: Text(l10n.sortTypeTreeFolder),
        contentPadding: EdgeInsets.zero,
      ),
    ),
    PopupMenuItem(
      value: ListPageType.typeName,
      child: ListTile(
        leading: const Icon(Icons.sort_by_alpha_outlined),
        title: Text(l10n.sortTypeName),
        contentPadding: EdgeInsets.zero,
      ),
    ),
    PopupMenuItem(
      value: ListPageType.typeTime,
      child: ListTile(
        leading: const Icon(Icons.timer_outlined),
        title: Text(l10n.sortTypeTime),
        contentPadding: EdgeInsets.zero,
      ),
    ),
  ];

  /// Calendar button: opens the calendar page, shows today's reminder count.
  static Widget calendarButton(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: Repository.get().reminderTree.countNotifier,
      builder: (context, count, _) {
        return _TabButton(
          label: l10n.calendar,
          count: count,
          onTap: () => AppNavigator.of(context).navigate(AppNavigator.uriCalendar),
        );
      },
    );
  }

  /// AllNotes tab button: click to switch to the notes panel. Shows the total
  /// note count.
  static Widget allNotesButton(BuildContext context) {
    final recordTree = Repository.get().recordTree;
    return ListenableBuilder(
      listenable: Listenable.merge([recordTree.countNotifier, ListPageType.notifier]),
      builder: (context, _) {
        return _TabButton(
          label: l10n.allNotes,
          active: ListPageType.value.tab == ListPageType.tabList,
          count: max(0, recordTree.countNotifier.value),
          onTap: () => ListPageType.setTab(ListPageType.tabList),
        );
      },
    );
  }

  /// Tags tab button: click to switch to the tags panel. Shows the total tag
  /// count.
  static Widget tagsButton(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([Repository.get().tagTree.tagCountNotifier, ListPageType.notifier]),
      builder: (context, _) {
        return _TabButton(
          label: l10n.tags,
          active: ListPageType.value.tab == ListPageType.tabTag,
          count: Repository.get().tagTree.tagCountNotifier.value,
          onTap: () => ListPageType.setTab(ListPageType.tabTag),
        );
      },
    );
  }

  /// View toggle button on the bottom bar. Shows the notes list view/sort
  /// options when the AllNotes tab is active, or the tags tree/flat toggle
  /// when the Tags tab is active.
  static Widget viewToggleButton(BuildContext context) {
    return ValueListenableBuilder<ListPageType>(
      valueListenable: ListPageType.notifier,
      builder: (context, _, _) {
        if (ListPageType.value.tab == ListPageType.tabTag) return SizedBox.shrink();
        return PopupMenuButton<String>(
          icon: Icon(_listTypeIcon(ListPageType.value.listType)),
          iconColor: Theme.of(context).appBarIconColor,
          tooltip: l10n.sortType,
          onSelected: (value) {
            ListPageType.setListType(value);
            Repository.get().recordTree.setSortListType(ListPageType.value.sortType);
            RecordOpenedState.get().setOpenedFolder("/");
          },
          itemBuilder: (context) => _noteListMenuItems(),
        );
      },
    );
  }

  static IconData _listTypeIcon(String type) {
    if (type == ListPageType.typeFlat) return Icons.folder_outlined;
    if (type == ListPageType.typeName) return Icons.sort_by_alpha_outlined;
    if (type == ListPageType.typeTime) return Icons.timer_outlined;
    return Icons.account_tree_outlined;
  }

  static Widget importExportButton(BuildContext context, ReturnCallback<String> getFolder) {
    return PopupMenuButton<String>(
      iconColor: Theme.of(context).appBarIconColor,
      icon: const Icon(Icons.import_export_outlined),
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
            leading: const Icon(Icons.download_outlined),
            title: Text(l10n.exportMd),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'import',
          child: ListTile(
            leading: const Icon(Icons.upload_outlined),
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
    ValueCallback<RecordEntry> onRecordCreate,
  ) async {
    RecordEntry? record = await Repository.get().createRecord(folder, RecordUtils.generateRecordName(), true, 0);
    if (record == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.saveRecordFailed)));
      }
      return;
    }

    if (context.mounted) onRecordCreate(record);
  }

  static void clickOnCreateFolderButton(BuildContext context, String path) async {
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
    String name = RecordUtils.getDocumentTitle(document);
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

  static Widget newRecordButton(
    BuildContext context,
    ReturnCallback<String> getFolder,
    ValueCallback<RecordEntry> onContentPressed,
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
    return ValueListenableBuilder<ListPageType>(
      valueListenable: ListPageType.notifier,
      builder: (context, _, _) {
        final type = ListPageType.value.listType;
        if (type == ListPageType.typeFlat || type == ListPageType.typeTree) {
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
      iconColor: Theme.of(context).appBarIconColor,
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

  static Widget recyclerButton(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: Repository.get().recyclerCountNotifier,
      builder: (context, count, _) {
        final icon = Icon(Icons.delete_outline);
        return IconButton(
          onPressed: () => AppNavigator.of(context).navigate(AppNavigator.uriRecycler),
          tooltip: l10n.recycler,
          icon: _wrapCountBadge(icon, count),
        );
      },
    );
  }

  static Widget _wrapCountBadge(Widget icon, int count) {
    if (count <= 0) return icon;
    return Badge(
      alignment: Alignment.bottomRight,
      offset: const Offset(0, -12),
      largeSize: 12,
      textStyle: const TextStyle(fontSize: 10, height: 1.0),
      label: Text('$count'),
      child: icon,
    );
  }

}

/// Tab segment used inside the combined capsule tab bar. Tapping triggers
/// [onTap]; the active segment is highlighted in the primary color and bold.
/// An optional [count] is appended to the label when > 0.
class _TabButton extends StatelessWidget {
  final String label;
  final bool active;
  final int count;
  final VoidCallback onTap;

  const _TabButton({required this.label, this.active = false, this.count = 0, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = active ? theme.colorScheme.primary : theme.colorScheme.onSurface;
    final bgColor = active ? theme.colorScheme.primary.withAlpha(70) : null;
    final isDesktop = Utils.isDesktop();
    return InkWell(
      onTap: onTap,
      hoverColor: theme.colorScheme.primary.withAlpha(25),
      child: Container(
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(vertical: isDesktop ? 8 : 10),
        decoration: BoxDecoration(color: bgColor),
        child: Text(
          '$label${count > 0 ? ' ($count)' : ''}',
          style: TextStyle(fontSize: 14, color: color, fontWeight: active ? FontWeight.w600 : FontWeight.normal),
        ),
      ),
    );
  }
}
