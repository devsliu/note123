import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:note123/filesync/record_tree.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/ui/phone/phone_record_detail_page.dart';
import 'package:note123/ui/files/record_files_flat_control.dart';
import 'package:note123/ui/files/record_files_list_control.dart';
import 'package:note123/ui/files/record_files_tree_control.dart';
import 'package:note123/ui/files/record_list_bottom_bar.dart';
import 'package:note123/ui/files/record_list_top_bar.dart';
import 'package:note123/ui/settings/settings_button.dart';
import 'package:note123/config/layout_mode.dart';
import 'package:note123/config/theme.dart';
import 'package:note123/utils/utils.dart';
import 'package:note123/config/app_config.dart';

import '../files/sync_button.dart';

class PhoneRecordListPage extends StatelessWidget {
  final ValueCallback2<BuildContext, TreeContentFile> onClickRecordFile;
  const PhoneRecordListPage({super.key, this.onClickRecordFile = _staticOnClickRecordFile});

  static void _staticOnClickRecordFile(BuildContext context, TreeContentFile record) {
    final RecordTree recordTree = Repository.get().recordTree;
    recordTree.setOpenedFile(record.uuid);
    Navigator.push(context, MaterialPageRoute(builder: (context) => PhoneRecordDetailPage(record: record)));
  }

  Scaffold buildMainPage(BuildContext context) {
    final RecordTree recordTree = Repository.get().recordTree;
    ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: AppConfig.pageHorizontalPadding,
        // actionsPadding: EdgeInsets.zero,
        title: RecordListTopBar.buildTitleWidget(context),
        actionsPadding: const EdgeInsets.only(right: AppConfig.actionsPadding),
        actions: [
          RecordListTopBar.buildParentButton(context),
          RecordListTopBar.collapseAllButton(context),
          SyncButton(),
          SettingsButton(),
          SizedBox(width: AppConfig.pageHorizontalPadding),
        ],
      ),
      body: Column(
        children: [
          if (theme.appBarBackgroundColor == theme.colorScheme.surface)
            Divider(height: 1, color: theme.colorScheme.outline.withAlpha(80)),
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: RecordListWidgetType.notifier,
              builder: (context, type, _) {
                if (type == RecordListWidgetType.sTreeFolder) {
                  return RecordFilesTreeControl(onClickRecordAction: onClickRecordFile, shrink: false);
                } else if (type == RecordListWidgetType.sFlatFolder) {
                  return RecordFilesFlatControl(onClickRecordAction: onClickRecordFile, shrink: false);
                } else {
                  return RecordFilesListControl(
                    onClickRecordAction: onClickRecordFile,
                    showDivider: true,
                    shrink: false,
                  );
                }
              },
              //            RecordFilesFlatControl(
            ),
          ),
          SyncStateWidget(),
          Divider(height: 1, color: theme.colorScheme.outline.withAlpha(80)),
          RecordListBottomBar(
            buttonSpacing: 0,
            leftPadding: AppConfig.pageHorizontalPadding,
            rightPadding: AppConfig.pageHorizontalPadding,
            getFolder: () => recordTree.openedFolder.path,
            onClickRecordFile: onClickRecordFile,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final RecordTree recordTree = Repository.get().recordTree;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return; // Return directly if already handled
        if (recordTree.openedFolder.path == "/" ||
            RecordListWidgetType.notifier.value != RecordListWidgetType.sFlatFolder) {
          if (!Navigator.canPop(context)) {
            SystemNavigator.pop();
          } else {
            Navigator.pop(context);
          } // Manually trigger back navigation
        } else {
          recordTree.setOpenedFolder(recordTree.openedFolder.dir);
        }
      },
      child: buildMainPage(context),
    );
  }
}
