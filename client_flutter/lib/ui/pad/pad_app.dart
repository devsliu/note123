import 'package:flutter/material.dart';
import 'package:notee/ui/base_app.dart';
import 'package:notee/ui/calendar/calendar_page.dart';
import 'package:notee/ui/common/empty_detail_placeholder.dart';
import 'package:notee/ui/common/platform_app_bar.dart';
import 'package:notee/ui/common/split_layout.dart';
import 'package:notee/ui/files/record_recycler_page.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/config/app_config.dart';

import 'package:notee/ui/files/record_list_page.dart';
import 'package:notee/ui/phone/phone_app.dart';
import 'package:notee/ui/settings/settings_page.dart';

class PadApp extends BaseApp {
  const PadApp({super.key});

  @override
  State<PadApp> createState() => _PadAppState();
}

class _PadAppState extends BaseAppState<PadApp> {
  static const double minLeftWidth = 300;
  static const double maxLeftWidth = 500;
  static const String _rootRoute = '/';
  static const int _maxRoutes = 5;
  double leftWidth = minLeftWidth;
  final GlobalKey<NavigatorState> _rightNavKey = GlobalKey();
  final _RouteObserver _observer = _RouteObserver();

  Widget _buildEmptyDetail() {
    return Scaffold(
      appBar: createPlatformAppBar(showWindowButtons: false),
      body: EmptyDetailPlaceholder(title: l10n.pleaseSelectRecord),
    );
  }

  @override
  void initState() {
    super.initState();
    leftWidth = AppConfig.prefs.getDouble(PrefKeys.windowLeftWidth) ?? 0;
    if (leftWidth == 0) {
      final w = WidgetsBinding.instance.platformDispatcher.views.first;
      leftWidth = (w.physicalSize.width / w.devicePixelRatio / 3).clamp(minLeftWidth, maxLeftWidth);
    }
  }

  Route? _generateRoute(RouteSettings settings) {
    if (settings.name == _rootRoute) {
      return MaterialPageRoute(builder: (_) => _buildEmptyDetail(), settings: settings);
    }
    final parsed = AppNavigatorUri.parse(settings.name!);
    Widget page;
    switch (parsed.uri) {
      case AppNavigator.uriRecord:
        final uuid = parsed.firstPath ?? '';
        final keyword = parsed.queryParam('keyword');
        page = PhoneRecordDetailPage(key: Key(uuid), uuid: uuid, keyword: keyword);
        break;
      case AppNavigator.uriCalendar:
        page = CalendarPage(showAppBar: true);
        break;
      case AppNavigator.uriRecycler:
        page = RecordRecyclerPage(showAppBar: true);
        break;
      case AppNavigator.uriSettings:
        page = SettingsPage(showAppBar: true);
        break;
      default:
        return null;
    }
    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }

  @override
  void navigate(String uri) {
    final nav = _rightNavKey.currentState;
    if (nav == null) return;
    final parsed = AppNavigatorUri.parse(uri);
    final existing = _observer.findWhere((r) {
      final name = r.settings.name;
      if (name == null) return false;
      final p = AppNavigatorUri.parse(name);
      return p.uri == parsed.uri && p.firstPath == parsed.firstPath;
    });
    if (existing != null) {
      nav.removeRoute(existing);
    }
    while (_observer.history.length > _maxRoutes) {
      nav.removeRoute(_observer.history[1]);
    }
    nav.pushNamed(uri);
  }

  @override
  Widget buildHome(BuildContext context) {
    return SplitLayout(
      leftWidth: leftWidth,
      minLeftWidth: minLeftWidth,
      maxLeftWidth: maxLeftWidth,
      draggerTopOffset: AppConfig.getAppBarHeight(),
      onLeftWidthChanged: (w) {
        leftWidth = w;
        AppConfig.prefs.setDouble(PrefKeys.windowLeftWidth, w);
      },
      leftChild: RecordListPage(),
      rightChild: ScaffoldMessenger(
        child: Navigator(
          key: _rightNavKey,
          initialRoute: _rootRoute,
          onGenerateRoute: _generateRoute,
          observers: [_observer],
        ),
      ),
    );
  }
}

class _RouteObserver extends NavigatorObserver {
  final List<Route> history = [];

  Route? findWhere(bool Function(Route) test) {
    for (final r in history.reversed) {
      if (test(r)) return r;
    }
    return null;
  }

  @override
  void didPush(Route route, Route? previousRoute) => history.add(route);
  @override
  void didPop(Route route, Route? previousRoute) => history.remove(route);
  @override
  void didRemove(Route route, Route? previousRoute) => history.remove(route);
  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    if (oldRoute != null) history.remove(oldRoute);
    if (newRoute != null) history.add(newRoute);
  }
}
