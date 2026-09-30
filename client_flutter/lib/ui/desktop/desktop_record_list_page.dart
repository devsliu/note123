import 'package:flutter/material.dart';
import 'package:note123/ui/desktop/desktop_title_bar.dart';
import 'package:note123/filesync/record_tree.dart';
import 'package:note123/ui/common/global_value_notify.dart';
import 'package:note123/ui/files/record_files_flat_control.dart';
import 'package:note123/ui/files/record_files_list_control.dart';
import 'package:note123/ui/files/record_list_bottom_bar.dart';
import 'package:note123/ui/files/record_list_top_bar.dart';
import 'package:note123/ui/settings/settings_button.dart';
import 'package:note123/ui/files/sync_button.dart';
import 'package:note123/config/prefs.dart';
import 'package:note123/config/theme.dart';
import 'package:note123/utils/utils.dart';
import 'package:note123/config/app_config.dart';

import 'package:note123/ui/files/record_files_tree_control.dart';

class DesktopRecordListPage extends StatelessWidget {
  final ValueCallback2<BuildContext, TreeContentFile> onClickRecordAction;

  const DesktopRecordListPage({super.key, required this.onClickRecordAction});

  Widget buildTitleBar(BuildContext context) {
    var theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 16),
        Expanded(child: IgnorePointer(child: RecordListTopBar.buildTitleWidget(context))),
        IconButtonTheme(
          data: IconButtonThemeData(
            style: theme.appBarIconButtonStyle.copyWith(iconSize: WidgetStateProperty.all(20.0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RecordListTopBar.buildParentButton(context),
              RecordListTopBar.collapseAllButton(context),
              SyncButton(),
              SettingsButton(),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          SizedBox(
            height: windowTitleBarHeight,
            child: Stack(
              children: [
                Positioned.fill(child: WindowMoveBar(color: theme.appBarBackgroundColor)), // Title bar
                Positioned.fill(child: buildTitleBar(context)),
              ],
            ),
          ),
          if (theme.appBarBackgroundColor == theme.colorScheme.surface)
            Divider(height: 1, color: theme.colorScheme.outline.withAlpha(80)),
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: GlobalValueNotify.recordListWidgetType,
              builder: (context, type, _) {
                if (type == RecordListWidgetType.sTreeFolder) {
                  return RecordFilesTreeControl(onClickRecordAction: onClickRecordAction, shrink: true);
                } else if (type == RecordListWidgetType.sFlatFolder) {
                  return RecordFilesFlatControl(onClickRecordAction: onClickRecordAction, shrink: true);
                } else {
                  return RecordFilesListControl(
                    onClickRecordAction: onClickRecordAction,
                    showDivider: true,
                    shrink: true,
                  );
                }
              },
            ),
          ),
          SyncStateWidget(),
          RecordListBottomBar(
            buttonSpacing: 0,
            leftPadding: AppConfig.pageHorizontalPadding,
            rightPadding: 0,
            getFolder: () => "/",
            onClickRecordFile: onClickRecordAction,
          ),
        ],
      ),
    );
  }
}
