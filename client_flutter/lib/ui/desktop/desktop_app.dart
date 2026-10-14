import 'package:flutter/material.dart';
import 'package:note123/ui/base_app.dart';
import 'package:note123/ui/desktop/window_state.dart';
import 'package:note123/utils/utils.dart';
import 'package:note123/config/language_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'package:note123/ui/files/record_list_page.dart';

import '../../filesync/repository.dart';
import 'desktop_tabs_page.dart';
import '../../config/prefs.dart';
import '../../model/record_opened_state.dart';
import '../calendar/calendar_page.dart';
import '../files/recycler_page.dart';
import '../editor/record_flow_editor_page.dart';

class EditorTab extends DesktopTab {
  final String uuid;
  @override
  final String title;
  EditorTab({required super.id, required this.title, required this.uuid});

  @override
  void select() {
    RecordOpenedState.get().openFile(uuid);
  }

  @override
  void close() {
    RecordOpenedState.get().closeFile(uuid);
  }

  @override
  Widget buildPage(GlobalKey key, VoidCallback closePageCallback) {
    return RecordFlowEditorPage(uuid: uuid, key: key, closePageCallback: closePageCallback);
  }
}

class CalendarTab extends DesktopTab {
  final ValueCallback2<BuildContext, String> openRecordCallback;
  CalendarTab({required this.openRecordCallback}) : super(id: '__calendar__');

  @override
  String get title => l10n.calendar;

  @override
  void select() {}

  @override
  void close() {}

  @override
  Widget buildPage(GlobalKey key, VoidCallback closePageCallback) {
    return CalendarPage(
      key: key,
      showAppBar: false,
      openRecordCallback: openRecordCallback,
      closeCallback: Navigator.pop,
    );
  }
}

class RecyclerTab extends DesktopTab {
  RecyclerTab() : super(id: '__recycler__');

  @override
  String get title => l10n.recycler;

  @override
  void select() {}

  @override
  void close() {}

  @override
  Widget buildPage(GlobalKey key, VoidCallback closePageCallback) {
    return RecyclerPage(key: key, showAppBar: false);
  }
}

class DesktopApp extends BaseApp {
  const DesktopApp({super.key});

  @override
  State<DesktopApp> createState() => _DesktopAppState();
}

class _DesktopAppState extends BaseAppState<DesktopApp> with WindowListener {
  static const double minLeftWidth = 300;
  static const double maxLeftWidth = 500;
  double leftWidth = minLeftWidth;
  final GlobalKey<DesktopTabsPageState> detailKey = GlobalKey<DesktopTabsPageState>();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    leftWidth = loadLeftWidth();
  }

  /// 初始化桌面窗口（大小、标题栏、显示等），仅执行一次。

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
    super.dispose();
  }

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
    Future.delayed(const Duration(milliseconds: 300), () {
      isWindowAnimatingNotifier.value = false;
    });
  }

  @override
  void onWindowResized() {}

  @override
  void onWindowResize() async {
    final size = await windowManager.getSize();
    await Prefs.instance.setDouble(PrefKeys.windowWidth, size.width);
    await Prefs.instance.setDouble(PrefKeys.windowHeight, size.height);
  }

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
  Widget buildAppWrapper(BuildContext context, Widget child) {
    final virtualWindowFrameBuilder = VirtualWindowFrameInit();
    return virtualWindowFrameBuilder(context, child);
  }

  @override
  void openRecord(BuildContext context, String uuid) {
    final name = Repository.get().recordTree.findFile(uuid)?.name ?? '';
    detailKey.currentState?.openTab(EditorTab(id: uuid, title: name, uuid: uuid));
  }

  @override
  void openCalendar(BuildContext context) {
    detailKey.currentState?.openTab(CalendarTab(openRecordCallback: openRecord));
  }

  @override
  void openRecycler(BuildContext context) {
    detailKey.currentState?.openTab(RecyclerTab());
  }

  @override
  Widget buildHome(BuildContext context) {
    return CustomMultiChildLayout(
      delegate: _DesktopAppLayoutDelegate(leftWidth: leftWidth),
      children: [
        LayoutId(
          id: 'left',
          child: RecordListPage(
            openRecordCallback: openRecord,
            onOpenCalendar: openCalendar,
            onOpenRecycler: openRecycler,
          ),
        ),
        LayoutId(
          id: 'right',
          child: DesktopTabsPage(key: detailKey),
        ),
        LayoutId(id: 'dragger', child: buildLeftSideDragger()),
      ],
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
