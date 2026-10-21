import 'package:flutter/material.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/ui/base_app.dart';
import 'package:notee/ui/desktop/desktop_title_bar.dart';
import 'package:notee/ui/desktop/window_state.dart';
import 'package:notee/utils/utils.dart';
import 'package:window_manager/window_manager.dart';

import 'package:notee/ui/files/record_list_page.dart';

import '../../filesync/repository.dart';
import 'desktop_tabs_page.dart';
import '../../config/prefs.dart';
import '../../model/record_opened_state.dart';
import '../calendar/calendar_page.dart';
import '../files/record_recycler_page.dart';
import '../editor/record_flow_editor_page.dart';
import '../settings/settings_page.dart';

class EditorTab extends DesktopTab {
  final String uuid;
  String? keyword;
  @override
  final String title;
  EditorTab({required this.uuid, this.keyword})
    : title = Repository.get().recordTree.findRecord(uuid)?.local.name ?? '',
      super(id: uuid);

  @override
  void select() {
    RecordOpenedState.get().openFile(uuid);
  }

  @override
  void close() {
    RecordOpenedState.get().closeFile(uuid);
  }

  @override
  void refresh(DesktopTab newTab) {
    if (newTab is EditorTab && newTab.keyword != keyword) {
      keyword = newTab.keyword;
    }
  }

  @override
  Widget buildPage(GlobalKey key, ValueCallback<BuildContext> closeCB) {
    return RecordFlowEditorPage(uuid: uuid, keyword: keyword, key: key, closePageCallback: closeCB);
  }

  @override
  List<Widget>? buildActions(GlobalKey key) {
    final state = key.currentState as RecordFlowEditorPageState?;
    if (state == null) return null;
    return [_buildOverflowButton(state)];
  }

  Widget _buildOverflowButton(RecordFlowEditorPageState state) {
    return Builder(
      builder: (context) => IconButton(
        icon: Icon(Icons.more_vert, size: 20),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        constraints: BoxConstraints.tight(Size(40, 40)),
        onPressed: () async {
          final renderBox = context.findRenderObject() as RenderBox?;
          if (renderBox == null) return;
          final result = await showMenu<int>(
            context: context,
            position: RelativeRect.fromRect(
              renderBox.localToGlobal(Offset.zero) & renderBox.size,
              Offset.zero & MediaQuery.of(context).size,
            ),
            items: state.buildOverflowMenuItems(context),
          );
          if (result != null) state.onOverflowMenuSelect(result);
        },
      ),
    );
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
        child: VerticalDivider(width: 1, thickness: 1, color: theme.colorScheme.outline.withAlpha(80)),
      ),
    );
  }

  @override
  Widget buildAppWrapper(BuildContext context, Widget child) {
    final virtualWindowFrameBuilder = VirtualWindowFrameInit();
    return virtualWindowFrameBuilder(context, child);
  }

  @override
  void navigate(String uri, [dynamic arg1, dynamic arg2]) {
    DesktopTab? tab;
    switch (uri) {
      case AppNavigator.uriRecord:
        tab = EditorTab(uuid: arg1 as String, keyword: arg2 as String?);
        break;
      case AppNavigator.uriCalendar:
        tab = DesktopTab.create(
            '__calendar__',
            l10n.calendar,
          (key, closeCB) => CalendarPage(key: key, showAppBar: false, closeCallback: closeCB),
        );
        break;
      case AppNavigator.uriRecycler:
        tab = DesktopTab.create(
            '__recycler__',
            l10n.recycler,
          (key, closeCB) => RecordRecyclerPage(key: key, showAppBar: false, closeCallback: closeCB),
        );
        break;
      case AppNavigator.uriSettings:
        tab = DesktopTab.create(
            '__settings__',
            l10n.settings,
            (key, closeCB) => Navigator(
              pages: [MaterialPage(child: SettingsPage(key: key, showAppBar: false))],
            onDidRemovePage: (page) {},
          ),
        );
        break;
    }
    if (tab != null) {
      detailKey.currentState?.openTab(tab);
    }
  }

  @override
  Widget buildHome(BuildContext context) {
    return CustomMultiChildLayout(
      delegate: _DesktopAppLayoutDelegate(leftWidth: leftWidth),
      children: [
        LayoutId(id: 'left', child: RecordListPage()),
        LayoutId(
          id: 'right',
          child: ScaffoldMessenger(child: DesktopTabsPage(key: detailKey)),
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
      layoutChild('dragger', BoxConstraints.tight(Size(4, size.height - windowTitleBarHeight)));
      positionChild('dragger', Offset(leftWidth - 2, windowTitleBarHeight));
    }
  }

  @override
  bool shouldRelayout(covariant _DesktopAppLayoutDelegate oldDelegate) {
    return leftWidth != oldDelegate.leftWidth;
  }
}
