import 'package:flutter/material.dart';
import 'package:note123/filesync/record_ext.dart';
import 'package:note123/filesync/record_tree.dart';
import 'package:note123/ui/base_app.dart';
import 'package:note123/ui/editor/record_flow_editor_page.dart';
import 'package:note123/ui/files/record_list_page.dart';
import 'package:note123/ui/calendar/calendar_page.dart';
import 'package:note123/ui/files/record_recycler_page.dart';
import 'package:note123/utils/utils.dart';

class PhoneApp extends BaseApp {
  const PhoneApp({super.key});

  @override
  State<PhoneApp> createState() => _PhoneAppState();
}

class _PhoneAppState extends BaseAppState<PhoneApp> {
  @override
  void navigate(String uri, [dynamic arg1, dynamic arg2]) {
    switch (uri) {
      case AppNavigator.uriRecord:
        final uuid = arg1 as String;
        final keyword = arg2 as String?;
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => PhoneRecordDetailPage(uuid: uuid, keyword: keyword),
          ),
        );
        break;
      case AppNavigator.uriCalendar:
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => CalendarPage(showAppBar: true, closeCallback: Navigator.pop)),
        );
        break;
      case AppNavigator.uriRecycler:
        navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => RecordRecyclerPage()));
        break;
    }
  }

  @override
  Widget buildHome(BuildContext context) {
    return RecordListPage();
  }
}

class PhoneRecordDetailPage extends RecordFlowEditorPage {
  final ValueCallback<BuildContext> closeCallback;
  const PhoneRecordDetailPage({super.key, required super.uuid, super.keyword, this.closeCallback = Navigator.pop});

  @override
  State<PhoneRecordDetailPage> createState() => PhoneRecordDetailPageState();
}

class PhoneRecordDetailPageState<T extends PhoneRecordDetailPage> extends RecordFlowEditorPageState<T> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: buildAppBar(context, mRecord), body: super.build(context));
  }

  AppBar buildAppBar(BuildContext context, RecordEntry record) {
    return AppBar(
      leading: IconButton(onPressed: () => widget.closeCallback(context), icon: Icon(Icons.arrow_back)),
      titleSpacing: 0,
      title: StreamBuilder<RecordEvent>(
        stream: recordTree.onEvent,
        builder: (context, snapshot) =>
            Text(record.local.path + record.local.name, overflow: TextOverflow.fade, style: TextStyle(fontSize: 16.0)),
      ),
      actions: [
        if (pageState.isNormal) IconButton(onPressed: saveRecord, icon: Icon(Icons.done_outlined)),
        if (pageState.isNormal)
          PopupMenuButton<int>(
            icon: Icon(Icons.more_vert),
            onSelected: onOverflowMenuSelect,
            itemBuilder: buildOverflowMenuItems,
          ),
        SizedBox(width: 8),
      ],
    );
  }
}
