import 'package:flutter/material.dart';
import 'package:note123/filesync/record_tree.dart';
import 'package:note123/ui/base_app.dart';
import 'package:note123/ui/editor/record_flow_editor_page.dart';
import 'package:note123/ui/files/record_list_page.dart';
import 'package:note123/ui/calendar/calendar_page.dart';
import 'package:note123/ui/files/recycler_page.dart';
import 'package:note123/utils/utils.dart';

class PhoneApp extends BaseApp {
  const PhoneApp({super.key});

  @override
  State<PhoneApp> createState() => _PhoneAppState();
}

class _PhoneAppState extends BaseAppState<PhoneApp> {
  @override
  void openRecord(BuildContext context, TreeContentFile record) {
    navigatorKey.currentState?.push(MaterialPageRoute(builder: (context) => PhoneRecordDetailPage(record: record)));
  }

  @override
  void openCalendar(BuildContext context) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => CalendarPage(showAppBar: true, openRecordCallback: openRecord, closeCallback: Navigator.pop),
      ),
    );
  }

  @override
  void openRecycler(BuildContext context) {
    navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => RecyclerPage()));
  }

  @override
  Widget buildHome(BuildContext context) {
    return RecordListPage(openRecordCallback: openRecord, onOpenCalendar: openCalendar, onOpenRecycler: openRecycler);
  }
}

class PhoneRecordDetailPage extends RecordFlowEditorPage {
  final ValueCallback<BuildContext> closeCallback;
  const PhoneRecordDetailPage({super.key, required super.record, this.closeCallback = Navigator.pop});

  @override
  State<PhoneRecordDetailPage> createState() => PhoneRecordDetailPageState();
}

class PhoneRecordDetailPageState<T extends PhoneRecordDetailPage> extends RecordFlowEditorPageState<T> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: buildAppBar(context, widget.record, this), body: super.build(context));
  }

  AppBar buildAppBar(BuildContext context, TreeContentFile record, RecordFlowEditorPageState state) {
    return AppBar(
      leading: IconButton(onPressed: () => widget.closeCallback(context), icon: Icon(Icons.close_outlined)),
      titleSpacing: 0,
      title: ValueListenableBuilder<List<RecordEvent>>(
        valueListenable: recordTree.refreshNotifier,
        builder: (context, value, child) =>
            Text(record.path + record.name, overflow: TextOverflow.fade, style: TextStyle(fontSize: 16.0)),
      ),
      actions: [
        if (pageState.isNormal) IconButton(onPressed: () => {state.saveRecord()}, icon: Icon(Icons.done_outlined)),
        SizedBox(width: 8),
      ],
    );
  }
}
