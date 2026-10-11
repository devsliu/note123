import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:note123/filesync/record_tree.dart';
import 'package:note123/model/record_opened_state.dart';
import 'package:note123/ui/common/platform_app_bar.dart';
import 'package:note123/ui/files/record_files_flat_control.dart';
import 'package:note123/ui/files/record_files_list_control.dart';
import 'package:note123/ui/files/record_files_tree_control.dart';
import 'package:note123/ui/files/record_search_box.dart';
import 'package:note123/ui/files/record_list_bottom_bar.dart';
import 'package:note123/ui/files/record_list_top_bar.dart';
import 'package:note123/ui/settings/settings_button.dart';
import 'package:note123/ui/calendar/calendar_task_item.dart';
import 'package:note123/ui/files/recycler_page.dart';
import 'package:note123/config/layout_mode.dart';
import 'package:note123/config/theme.dart';
import 'package:note123/utils/utils.dart';
import 'package:note123/config/app_config.dart';

import 'sync_button.dart';

class RecordListPage extends StatelessWidget {
  final ValueCallback2<BuildContext, TreeContentFile> openRecordCallback;
  final ValueCallback<BuildContext> onOpenCalendar;
  final ValueCallback<BuildContext> onOpenRecycler;

  const RecordListPage({
    super.key,
    required this.openRecordCallback,
    required this.onOpenCalendar,
    required this.onOpenRecycler,
  });

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return createPlatformAppBar(
      automaticallyImplyLeading: false,
      showWindowButtons: false,
      titleWidget: RecordListTopBar.buildTitleWidget(context),
      actions: [
        ..._buildTopActions(context),
        SizedBox(width: AppConfig.pageHorizontalPadding),
      ],
    );
  }

  List<Widget> _buildTopActions(BuildContext context) {
    return [
      RecordListTopBar.buildParentButton(context),
      RecordListTopBar.collapseAllButton(context),
      SyncButton(),
      SettingsButton(),
    ];
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    final bool desktop = Utils.isDesktop();
    return Column(
      children: [
        if (theme.appBarBackgroundColor == theme.colorScheme.surface)
          Divider(height: 1, color: theme.colorScheme.outline.withAlpha(80)),
        Row(
          children: [
            SizedBox(width: AppConfig.pageHorizontalPadding),
            Expanded(child: CalendarTaskItem(onTap: onOpenCalendar)),
            SizedBox(width: 6),
            Expanded(child: RecyclerEntryItem(onTap: onOpenRecycler)),
            SizedBox(width: AppConfig.pageHorizontalPadding),
          ],
        ),
        SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppConfig.pageHorizontalPadding),
          child: RecordSearchBox(shrink: desktop),
        ),
        Expanded(
          child: ValueListenableBuilder<String>(
            valueListenable: RecordOpenedState.get().searchQueryNotifier,
            builder: (context, query, _) {
              if (query.isNotEmpty) {
                return RecordSearchResultsControl(openRecordCallback: openRecordCallback, shrink: desktop);
              }
              return ValueListenableBuilder<int>(
                valueListenable: RecordListWidgetType.notifier,
                builder: (context, type, _) {
                  if (type == RecordListWidgetType.sTreeFolder) {
                    return RecordFilesTreeControl(openRecordCallback: openRecordCallback, shrink: desktop);
                  } else if (type == RecordListWidgetType.sFlatFolder) {
                    return RecordFilesFlatControl(openRecordCallback: openRecordCallback, shrink: desktop);
                  } else {
                    return RecordFilesListControl(
                      openRecordCallback: openRecordCallback,
                      showDivider: true,
                      shrink: desktop,
                    );
                  }
                },
              );
            },
          ),
        ),
        SyncStateWidget(),
        Divider(height: 1, color: theme.colorScheme.outline.withAlpha(80)),
        RecordListBottomBar(
          buttonSpacing: 0,
          leftPadding: AppConfig.pageHorizontalPadding,
          rightPadding: AppConfig.pageHorizontalPadding,
          getFolder: () => RecordOpenedState.get().openedFolder.path,
          openRecordCallback: openRecordCallback,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return; // Return directly if already handled
        if (RecordOpenedState.get().openedFolder.path == "/" ||
            RecordListWidgetType.notifier.value != RecordListWidgetType.sFlatFolder) {
          if (!Navigator.canPop(context)) {
            SystemNavigator.pop();
          } else {
            Navigator.pop(context);
          } // Manually trigger back navigation
        } else {
          RecordOpenedState.get().setOpenedFolder(RecordOpenedState.get().openedFolder.dir);
        }
      },
      child: Scaffold(appBar: _buildAppBar(context), body: _buildBody(context)),
    );
  }
}
