import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:note123/filesync/record_tree.dart';
import 'package:note123/model/record_opened_state.dart';
import 'package:note123/ui/phone/phone_record_detail_page.dart';
import 'package:note123/ui/files/record_files_flat_control.dart';
import 'package:note123/ui/files/record_files_list_control.dart';
import 'package:note123/ui/files/record_files_tree_control.dart';
import 'package:note123/ui/files/record_search_box.dart';
import 'package:note123/ui/files/record_list_bottom_bar.dart';
import 'package:note123/ui/files/record_list_top_bar.dart';
import 'package:note123/ui/settings/settings_button.dart';
import 'package:note123/ui/calendar/calendar_task_item.dart';
import 'package:note123/ui/files/recycler_page.dart';
import 'package:note123/ui/calendar/calendar_page.dart';
import 'package:note123/config/layout_mode.dart';
import 'package:note123/config/theme.dart';
import 'package:note123/utils/utils.dart';
import 'package:note123/config/app_config.dart';

import '../files/sync_button.dart';

class PhoneRecordListPage extends StatelessWidget {
  final ValueCallback2<BuildContext, TreeContentFile> onClickRecordFile;
  final ValueCallback<BuildContext> onOpenCalendar;
  final ValueCallback<BuildContext> onOpenRecycler;
  const PhoneRecordListPage({
    super.key,
    this.onClickRecordFile = _staticOnClickRecordFile,
    this.onOpenCalendar = _staticOnOpenCalendar,
    this.onOpenRecycler = _staticOnOpenRecycler,
  });

  static void _staticOnClickRecordFile(BuildContext context, TreeContentFile record) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => PhoneRecordDetailPage(record: record)));
  }

  static void _staticOnOpenCalendar(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CalendarPage(showAppBar: true, openRecordCallback: _staticOnClickRecordFile, closeCallback: Navigator.pop),
      ),
    );
  }

  static void _staticOnOpenRecycler(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => RecyclerPage()));
  }

  Scaffold buildMainPage(BuildContext context) {
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
          Row(
            children: [
              Expanded(child: CalendarTaskItem(onTap: onOpenCalendar)),
              Expanded(child: RecyclerEntryItem(onTap: onOpenRecycler)),
            ],
          ),
          RecordSearchBox(shrink: false),
          Expanded(
            child: ValueListenableBuilder<String>(
              valueListenable: RecordOpenedState.get().searchQueryNotifier,
              builder: (context, query, _) {
                if (query.isNotEmpty) {
                  return RecordSearchResultsControl(openRecordCallback: onClickRecordFile, shrink: false);
                }
                return ValueListenableBuilder<int>(
                  valueListenable: RecordListWidgetType.notifier,
                  builder: (context, type, _) {
                    if (type == RecordListWidgetType.sTreeFolder) {
                      return RecordFilesTreeControl(openRecordCallback: onClickRecordFile, shrink: false);
                    } else if (type == RecordListWidgetType.sFlatFolder) {
                      return RecordFilesFlatControl(openRecordCallback: onClickRecordFile, shrink: false);
                    } else {
                      return RecordFilesListControl(
                        openRecordCallback: onClickRecordFile,
                        showDivider: true,
                        shrink: false,
                      );
                    }
                  },
                  //            RecordFilesFlatControl(
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
            openRecordCallback: onClickRecordFile,
          ),
        ],
      ),
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
      child: buildMainPage(context),
    );
  }
}
