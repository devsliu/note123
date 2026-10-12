import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:note123/filesync/record_tree.dart';
import 'package:note123/model/record_opened_state.dart';
import 'package:note123/ui/calendar/calendar_task_item.dart';
import 'package:note123/ui/common/platform_app_bar.dart';
import 'package:note123/ui/files/record_files_flat_control.dart';
import 'package:note123/ui/files/record_files_list_control.dart';
import 'package:note123/ui/files/record_files_tree_control.dart';
import 'package:note123/ui/files/search_page.dart';
import 'package:note123/ui/files/record_list_bottom_bar.dart';
import 'package:note123/ui/files/record_list_top_bar.dart';
import 'package:note123/ui/files/recycler_page.dart';
import 'package:note123/ui/settings/settings_button.dart';
import 'package:note123/config/layout_mode.dart';
import 'package:note123/config/theme.dart';
import 'package:note123/utils/utils.dart';
import 'package:note123/config/app_config.dart';

import 'sync_button.dart';

class RecordListPage extends StatefulWidget {
  final ValueCallback2<BuildContext, TreeContentFile> openRecordCallback;
  final ValueCallback<BuildContext> onOpenCalendar;
  final ValueCallback<BuildContext> onOpenRecycler;

  const RecordListPage({
    super.key,
    required this.openRecordCallback,
    required this.onOpenCalendar,
    required this.onOpenRecycler,
  });

  @override
  State<RecordListPage> createState() => _RecordListPageState();
}

class _RecordListPageState extends State<RecordListPage> {
  bool _showSearch = false;

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
      IconButton(onPressed: () => setState(() => _showSearch = true), icon: const Icon(Icons.search)),
    ];
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    final bool desktop = Utils.isDesktop();
    return Column(
      children: [
        SizedBox(height: 4),
        if (theme.appBarBackgroundColor == theme.colorScheme.surface)
          Divider(height: 1, color: theme.colorScheme.outline.withAlpha(80)),
        Row(
          children: [
            SizedBox(width: AppConfig.pageHorizontalPadding),
            Expanded(child: CalendarTaskItem(onTap: widget.onOpenCalendar)),
            SizedBox(width: 6),
            Expanded(child: RecyclerEntryItem(onTap: widget.onOpenRecycler)),
            SizedBox(width: AppConfig.pageHorizontalPadding),
          ],
        ),
        SizedBox(height: 4),
        Expanded(
          child: ValueListenableBuilder<int>(
            valueListenable: RecordListWidgetType.notifier,
            builder: (context, type, _) {
              if (type == RecordListWidgetType.sTreeFolder) {
                return RecordFilesTreeControl(openRecordCallback: widget.openRecordCallback, shrink: desktop);
              } else if (type == RecordListWidgetType.sFlatFolder) {
                return RecordFilesFlatControl(openRecordCallback: widget.openRecordCallback, shrink: desktop);
              } else {
                return RecordFilesListControl(
                  openRecordCallback: widget.openRecordCallback,
                  showDivider: true,
                  shrink: desktop,
                );
              }
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
          openRecordCallback: widget.openRecordCallback,
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
        // Search page: back first returns to the list page
        if (_showSearch) {
          setState(() => _showSearch = false);
          return;
        }
        final state = RecordOpenedState.get();
        if (state.openedFolder.path == "/" || RecordListWidgetType.notifier.value != RecordListWidgetType.sFlatFolder) {
          if (!Navigator.canPop(context)) {
            SystemNavigator.pop();
          } else {
            Navigator.pop(context);
          } // Manually trigger back navigation
        } else {
          state.setOpenedFolder(state.openedFolder.dir);
        }
      },
      child: _showSearch
          ? SearchPage(
              shrink: Utils.isDesktop(),
              onBack: () => setState(() => _showSearch = false),
              openRecordCallback: widget.openRecordCallback,
            )
          : Scaffold(appBar: _buildAppBar(context), body: _buildBody(context)),
    );
  }
}
