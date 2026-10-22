import 'package:flutter/material.dart';
import 'package:notee/ui/base_app.dart';
import 'package:notee/ui/calendar/calendar_page.dart';
import 'package:notee/ui/common/empty_detail_placeholder.dart';
import 'package:notee/ui/common/platform_app_bar.dart';
import 'package:notee/ui/common/split_layout.dart';
import 'package:notee/ui/files/record_recycler_page.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/config/prefs.dart';
import 'package:notee/ui/files/record_list_page.dart';
import 'package:notee/ui/phone/phone_app.dart';
import 'package:notee/ui/settings/settings_page.dart';

class PadApp extends BaseApp {
  final ValueNotifier<WidgetBuilder> detailBuilder = ValueNotifier(PadApp._buildEmptyDetail);
  PadApp({super.key});

  static Widget _buildEmptyDetail(BuildContext context) {
    return Scaffold(
      appBar: createPlatformAppBar(showWindowButtons: false),
      body: EmptyDetailPlaceholder(title: l10n.pleaseSelectRecord),
    );
  }

  @override
  State<PadApp> createState() => _PadAppState();
}

class _PadAppState extends BaseAppState<PadApp> {
  static const double minLeftWidth = 300;
  static const double maxLeftWidth = 500;
  double leftWidth = minLeftWidth;

  @override
  void initState() {
    super.initState();
    leftWidth = Prefs.instance.getDouble(PrefKeys.windowLeftWidth) ?? 0;
    if (leftWidth == 0) {
      final w = WidgetsBinding.instance.platformDispatcher.views.first;
      leftWidth = (w.physicalSize.width / w.devicePixelRatio / 3).clamp(minLeftWidth, maxLeftWidth);
    }
  }

  void onCloseDetail(BuildContext context) {
    widget.detailBuilder.value = PadApp._buildEmptyDetail;
  }

  @override
  void navigate(String uri) {
    final parsed = AppNavigatorUri.parse(uri);
    switch (parsed.uri) {
      case AppNavigator.uriRecord:
        final uuid = parsed.firstPath ?? '';
        final keyword = parsed.queryParam('keyword');
        widget.detailBuilder.value = (context) {
          return PhoneRecordDetailPage(key: Key(uuid), uuid: uuid, keyword: keyword, closeCallback: onCloseDetail);
        };
        break;
      case AppNavigator.uriCalendar:
        widget.detailBuilder.value = (context) {
          return CalendarPage(showAppBar: true, closeCallback: onCloseDetail);
        };
        break;
      case AppNavigator.uriRecycler:
        widget.detailBuilder.value = (context) {
          return RecordRecyclerPage(showAppBar: true, closeCallback: onCloseDetail);
        };
        break;
      case AppNavigator.uriSettings:
        widget.detailBuilder.value = (context) => Navigator(
          pages: [MaterialPage(child: SettingsPage(showAppBar: true))],
          onDidRemovePage: (page) {},
        );
        break;
    }
  }

  @override
  Widget buildHome(BuildContext context) {
    return SplitLayout(
      leftWidth: leftWidth,
      minLeftWidth: minLeftWidth,
      maxLeftWidth: maxLeftWidth,
      onLeftWidthChanged: (w) {
        leftWidth = w;
        Prefs.instance.setDouble(PrefKeys.windowLeftWidth, w);
      },
      leftChild: RecordListPage(),
      rightChild: ScaffoldMessenger(
        child: ValueListenableBuilder(
          valueListenable: widget.detailBuilder,
          builder: (context, value, child) {
            return value(context);
          },
        ),
      ),
    );
  }
}
