import 'package:flutter/material.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/filesync/record_tree.dart';
import 'package:note123/config/language_manager.dart';
import 'package:note123/config/layout_mode.dart';
import 'package:note123/config/app_config.dart';
import 'package:note123/ui/files/record_files_tree_control.dart';

class RecordListTopBar {
  static Widget buildTitleWidget(BuildContext context) {
    var theme = Theme.of(context);
    final RecordTree recordTree = Repository.get().recordTree;
    return ValueListenableBuilder<int>(
      valueListenable: RecordListWidgetType.notifier,
      builder: (context, sortType, _) {
        if (sortType != RecordListWidgetType.sFlatFolder) {
          return Text(AppConfig.appTitle, overflow: TextOverflow.fade, style: theme.appBarTheme.titleTextStyle);
        }

        return ValueListenableBuilder<String>(
          valueListenable: recordTree.openedFolderNotifier,
          builder: (context, path, _) {
            return Text(
              path == "/" ? AppConfig.appTitle : path,
              overflow: TextOverflow.fade,
              style: theme.appBarTheme.titleTextStyle,
            );
          },
        );
      },
    );
  }

  static Widget buildParentButton(BuildContext context) {
    final RecordTree recordTree = Repository.get().recordTree;
    return ValueListenableBuilder<int>(
      valueListenable: RecordListWidgetType.notifier,
      builder: (context, sortType, _) {
        if (sortType != RecordListWidgetType.sFlatFolder) {
          return SizedBox.shrink();
        }
        return ValueListenableBuilder<String>(
          valueListenable: recordTree.openedFolderNotifier,
          builder: (context, path, _) {
            if (path == "/") return SizedBox.shrink();
            return IconButton(
              icon: Icon(Icons.arrow_upward),
              tooltip: l10n.upperLevel,
              onPressed: () {
                recordTree.setOpenedFolder(dirname(path));
              },
            );
          },
        );
      },
    );
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
}
