import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:note123/config/language_manager.dart';
import 'package:note123/utils/utils.dart';
import 'package:note123/ui/desktop/window_state.dart';
import 'package:window_manager/window_manager.dart';

import '../../config/theme.dart';
import 'desktop_record_list_page.dart';
import 'desktop_tabs_page.dart';
import '../../config/prefs.dart';
import '../../l10n/app_localizations.dart';
import '../conflict/conflict_auto_pop.dart';
import '../../filesync/record_tree.dart';
import '../../model/record_opened_state.dart';
import '../calendar/calendar_page.dart';
import '../editor/record_flow_editor_page.dart';

class EditorTab extends DesktopTab {
  final TreeContentFile record;
  @override
  final String title;
  EditorTab({required super.id, required this.title, required this.record});

  @override
  void select() {
    RecordOpenedState.get().openFile(record.uuid);
  }

  @override
  void close() {
    RecordOpenedState.get().closeFile(record.uuid);
  }

  @override
  Widget buildPage(GlobalKey key, {VoidCallback? closePageCallback}) {
    return RecordFlowEditorPage(record: record, key: key, closePageCallback: closePageCallback);
  }
}

class CalendarTab extends DesktopTab {
  final ValueChanged<TreeContentFile>? onOpenRecord;
  CalendarTab({this.onOpenRecord}) : super(id: '__calendar__');

  @override
  String get title => l10n.calendarTasks;

  @override
  void select() {
    RecordOpenedState.get().closeFile(RecordOpenedState.get().openedFileNotifier.value);
  }

  @override
  void close() {
    // The calendar tab does not hold a record, so nothing to release.
  }

  @override
  Widget buildPage(GlobalKey key, {VoidCallback? closePageCallback}) {
    return CalendarPage(key: key, showAppBar: false, onOpenRecord: onOpenRecord);
  }
}

class DesktopApp extends StatefulWidget {
  final ValueCallback<BuildContext> initCallback;
  const DesktopApp({super.key, required this.initCallback});

  @override
  State<DesktopApp> createState() => _DesktopAppState();
}

class _DesktopAppState extends State<DesktopApp> with WidgetsBindingObserver, WindowListener {
  static const double minLeftWidth = 300;
  static const double maxLeftWidth = 500;
  double leftWidth = minLeftWidth;
  final GlobalKey<DesktopTabsPageState> detailKey = GlobalKey<DesktopTabsPageState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    windowManager.addListener(this);
    leftWidth = loadLeftWidth();
  }

  double loadLeftWidth() {
    double saved = Prefs.instance.getDouble(PrefKeys.windowLeftWidth) ?? 0;
    if (saved == 0) {
      saved = minLeftWidth;
    }
    return saved;
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {}

  @override
  void onWindowMaximize() {
    isMaximizedNotifier.value = true;
    _startWindowAnimation();
  }

  @override
  void onWindowUnmaximize() {
    isMaximizedNotifier.value = false;
    _startWindowAnimation();
  }

  void _startWindowAnimation() {
    isWindowAnimatingNotifier.value = true;
    Future.delayed(const Duration(milliseconds: 100), () {
      isWindowAnimatingNotifier.value = false;
    });
  }

  @override
  void onWindowResized() {}

  Widget buildLeftSideDragger() {
    var theme = Theme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (details) {
        setState(() {
          leftWidth += details.delta.dx;
          if (leftWidth < minLeftWidth) leftWidth = minLeftWidth;
          if (leftWidth > maxLeftWidth) leftWidth = maxLeftWidth;
        });
        Prefs.instance.setDouble(PrefKeys.windowLeftWidth, leftWidth);
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: VerticalDivider(width: 1, color: theme.colorScheme.outline.withAlpha(80)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final virtualWindowFrameBuilder = VirtualWindowFrameInit();

    return MaterialApp(
      theme: gAppTheme.data,
      debugShowCheckedModeBanner: false,
      locale: LanguageManager.getCurrentLocale(),
      localizationsDelegates: AppLocalizations.localizationsDelegates + [AppFlowyEditorLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        widget.initCallback(context);
        child = virtualWindowFrameBuilder(context, child);
        return child;
      },
      navigatorObservers: [],
      home: ConflictAutoPopListener(
        child: Scaffold(
          body: CustomMultiChildLayout(
            delegate: _DesktopAppLayoutDelegate(leftWidth: leftWidth),
            children: [
              LayoutId(
                id: 'left',
                child: DesktopRecordListPage(
                  onClickRecordAction: (context, record) {
                    detailKey.currentState?.openTab(EditorTab(id: record.uuid, title: record.name, record: record));
                  },
                  onOpenCalendar: () {
                    detailKey.currentState?.openTab(
                      CalendarTab(
                        onOpenRecord: (record) {
                          detailKey.currentState?.openTab(
                            EditorTab(id: record.uuid, title: record.name, record: record),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              LayoutId(
                id: 'right',
                child: DesktopTabsPage(key: detailKey),
              ),
              LayoutId(id: 'dragger', child: buildLeftSideDragger()),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopAppLayoutDelegate extends MultiChildLayoutDelegate {
  final double leftWidth;

  _DesktopAppLayoutDelegate({required this.leftWidth});

  @override
  void performLayout(Size size) {
    if (hasChild('left')) {
      layoutChild('left', BoxConstraints.tight(Size(leftWidth, size.height)));
      positionChild('left', Offset.zero);
    }
    if (hasChild('right')) {
      layoutChild('right', BoxConstraints.tight(Size(size.width - leftWidth, size.height)));
      positionChild('right', Offset(leftWidth, 0));
    }
    if (hasChild('dragger')) {
      layoutChild('dragger', BoxConstraints.tight(Size(4, size.height)));
      positionChild('dragger', Offset(leftWidth - 2, 0));
    }
  }

  @override
  bool shouldRelayout(covariant _DesktopAppLayoutDelegate oldDelegate) {
    return leftWidth != oldDelegate.leftWidth;
  }
}
