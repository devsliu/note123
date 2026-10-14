import 'package:flutter/material.dart';
import 'package:note123/filesync/record_tree.dart';
import 'package:note123/ui/base_app.dart';
import 'package:note123/ui/calendar/calendar_page.dart';
import 'package:note123/ui/files/recycler_page.dart';
import 'package:note123/config/theme.dart';
import 'package:note123/config/language_manager.dart';
import 'package:note123/ui/files/record_list_page.dart';
import 'package:note123/ui/phone/phone_app.dart';

class PadApp extends BaseApp {
  final ValueNotifier<WidgetBuilder> detailBuilder = ValueNotifier(PadApp._buildEmptyDetail);
  PadApp({super.key});

  static Widget _buildEmptyDetail(BuildContext context) {
    return Container(
      color: gAppTheme.data.colorScheme.surface,
      child: Center(
        child: Text(
          l10n.pleaseSelectRecord,
          style: TextStyle(color: gAppTheme.data.colorScheme.onSurface.withAlpha(180), fontSize: 16),
        ),
      ),
    );
  }

  @override
  State<PadApp> createState() => _PadAppState();
}

class _PadAppState extends BaseAppState<PadApp> {
  void onCloseDetail(BuildContext context) {
    widget.detailBuilder.value = PadApp._buildEmptyDetail;
  }

  @override
  void openRecord(BuildContext context, String uuid) {
    widget.detailBuilder.value = (context) {
      return PhoneRecordDetailPage(key: Key(uuid), uuid: uuid, closeCallback: onCloseDetail);
    };
  }

  @override
  void openCalendar(BuildContext context) {
    widget.detailBuilder.value = (context) {
      return CalendarPage(showAppBar: true, openRecordCallback: openRecord, closeCallback: onCloseDetail);
    };
  }

  @override
  void openRecycler(BuildContext context) {
    widget.detailBuilder.value = (context) {
      return RecyclerPage(showAppBar: true, closeCallback: onCloseDetail);
    };
  }

  @override
  Widget buildHome(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: RecordListPage(
              openRecordCallback: openRecord,
              onOpenCalendar: openCalendar,
              onOpenRecycler: openRecycler,
            ),
          ),
          VerticalDivider(width: 1, color: gAppTheme.data.colorScheme.outline.withAlpha(100)),
          Expanded(
            flex: 6,
            child: ValueListenableBuilder(
              valueListenable: widget.detailBuilder,
              builder: (context, value, child) {
                return value(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}
