import 'package:flutter/material.dart';
import 'package:note123/filesync/record_tree.dart';
import 'package:note123/ui/base_app.dart';
import 'package:note123/ui/phone/phone_record_list_page.dart';
import 'package:note123/ui/phone/phone_record_detail_page.dart';
import 'package:note123/ui/calendar/calendar_page.dart';

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
  Widget buildHome(BuildContext context) {
    return PhoneRecordListPage(onClickRecordFile: openRecord, onOpenCalendar: openCalendar);
  }
}
