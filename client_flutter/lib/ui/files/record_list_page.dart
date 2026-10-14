import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:note123/model/record_opened_state.dart';
import 'package:note123/ui/common/platform_app_bar.dart';
import 'package:note123/ui/files/record_files_flat_control.dart';
import 'package:note123/ui/files/record_files_list_control.dart';
import 'package:note123/ui/files/record_files_tree_control.dart';
import 'package:note123/ui/files/tag_files_control.dart';
import 'package:note123/ui/files/search_page.dart';
import 'package:note123/ui/files/record_list_actions.dart';
import 'package:note123/ui/settings/settings_button.dart';
import 'package:note123/config/language_manager.dart';
import 'package:note123/config/layout_mode.dart';
import 'package:note123/config/theme.dart';
import 'package:note123/utils/utils.dart';
import 'package:note123/config/app_config.dart';

import 'sync_button.dart';

class RecordListPage extends StatefulWidget {
  final ValueCallback2<BuildContext, String> openRecordCallback;
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

  String _getFolder() {
    if (RecordListWidgetType.notifier.value == RecordListWidgetType.sTreeFolder) {
      return "/";
    }
    return RecordOpenedState.get().openedFolder.path;
  }

  PreferredSizeWidget _buildTitleBar(BuildContext context) {
    final bool desktop = Utils.isDesktop();
    return createPlatformAppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 12,
      showWindowButtons: false,
      title: AppConfig.appTitle,
      actions: [
        SyncButton(),
        IconButton(
          onPressed: () => setState(() => _showSearch = true),
          icon: const Icon(Icons.search),
          tooltip: l10n.searchRecords,
        ),
        SettingsButton(),
        SizedBox(width: desktop ? 4 : AppConfig.pageHorizontalPadding),
      ],
    );
  }

  Widget _buildTabBar(BuildContext context) {
    final theme = Theme.of(context);
    final bool desktop = Utils.isDesktop();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: desktop ? 4 : 8),
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(4),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(child: RecordListActions.allNotesButton(context)),
            Expanded(child: RecordListActions.tagsButton(context)),
            Expanded(child: RecordListActions.calendarButton(context, widget.onOpenCalendar)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final theme = Theme.of(context);
    final bool desktop = Utils.isDesktop();
    return Container(
      color: theme.appBarBackgroundColor,
      padding: EdgeInsets.symmetric(horizontal: desktop ? 4 : AppConfig.pageHorizontalPadding, vertical: 2.0),
      child: IconButtonTheme(
        data: theme.appBarIconButtonTheme,
        child: Row(
          spacing: 4,
          children: [
            RecordListActions.themeButton(context),
            RecordListActions.importExportButton(context, _getFolder),
            RecordListActions.recyclerButton(context, widget.onOpenRecycler),
            RecordListActions.viewToggleButton(context),
            Spacer(),
            RecordListActions.newRecordButton(
              context,
              _getFolder,
              (record) => widget.openRecordCallback(context, record.uuid),
            ),
            RecordListActions.newFolderButton(context, _getFolder),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final bool desktop = Utils.isDesktop();
    return ValueListenableBuilder<int>(
      valueListenable: ListActiveTab.notifier,
      builder: (context, tab, _) {
        if (tab == ListActiveTab.tags) {
          return TagFilesControl(shrink: desktop, openRecordCallback: widget.openRecordCallback);
        }
        return ValueListenableBuilder<int>(
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
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
          }
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
          : Scaffold(
              appBar: _buildTitleBar(context),
              body: Column(
                children: [
                  _buildTabBar(context),
                  Expanded(child: _buildContent(context)),
                  const SyncStateWidget(),
                ],
              ),
              bottomNavigationBar: _buildBottomBar(context),
            ),
    );
  }
}
