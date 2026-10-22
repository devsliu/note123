import 'package:flutter/material.dart';
import 'package:notee/config/language_manager.dart';
import 'package:notee/ui/base_app.dart';
import 'package:notee/ui/desktop/desktop_title_bar.dart';
import 'package:notee/ui/desktop/window_state.dart';
import 'package:notee/ui/editor/editor_save_coordinator.dart';
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
      super(uri: '${AppNavigator.uriRecord}$uuid');

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
  bool _tabsRestored = false;
  final DateTime _appStartTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    leftWidth = loadLeftWidth();
    Repository.get().recordTree.countNotifier.addListener(_onRecordTreeCountChanged);
    _onRecordTreeCountChanged(); // 立即检查一次
  }

  @override
  void dispose() {
    Repository.get().recordTree.countNotifier.removeListener(_onRecordTreeCountChanged);
    windowManager.removeListener(this);
    super.dispose();
  }

  void _onRecordTreeCountChanged() {
    if (_tabsRestored) return;
    if (!(Prefs.instance.getBool(PrefKeys.rememberOpenTabs) ?? true)) {
      _tabsRestored = true;
      return;
    }
    if (DateTime.now().difference(_appStartTime).inSeconds > 10) {
      _tabsRestored = true; // 超时不再尝试
      return;
    }
    if (Repository.get().recordTree.countNotifier.value <= 0) return;
    _tabsRestored = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreTabs());
  }

  void _saveTabs() {
    if (!(Prefs.instance.getBool(PrefKeys.rememberOpenTabs) ?? true)) {
      Prefs.instance.remove(PrefKeys.openTabs);
      return;
    }
    final state = detailKey.currentState;
    if (state == null || state.tabCount == 0) {
      Prefs.instance.remove(PrefKeys.openTabs);
      return;
    }
    final data = {'index': state.currentIndex, 'tabs': state.tabs.map((t) => t.toMap()).toList()};
    Prefs.instance.setMap(PrefKeys.openTabs, data);
  }

  void _restoreTabs() {
    final raw = Prefs.instance.getMap(PrefKeys.openTabs);
    if (raw == null) return;
    final state = detailKey.currentState;
    if (state == null || !state.mounted) return;
    try {
      final list = (raw['tabs'] as List).cast<Map<String, dynamic>>();
      for (final m in list) {
        final tab = _tabFromMap(m);
        if (tab is EditorTab && Repository.get().recordTree.findRecord(tab.uuid) == null) {
          continue;
        }
        state.openTab(tab);
      }
      final idx = (raw['index'] as int?) ?? 0;
      if (state.tabCount > 0) {
        state.selectTab(idx.clamp(0, state.tabCount - 1));
      }
    } catch (_) {}
  }

  /// 初始化桌面窗口（大小、标题栏、显示等），仅执行一次。

  double loadLeftWidth() {
    double saved = Prefs.instance.getDouble(PrefKeys.windowLeftWidth) ?? 0;
    if (saved == 0) saved = minLeftWidth;
    return saved;
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
  void onWindowResized() async {
    final size = await windowManager.getSize();
    Prefs.instance
      ..setDouble(PrefKeys.windowWidth, size.width)
      ..setDouble(PrefKeys.windowHeight, size.height);
  }

  @override
  void onAppTerminating() {
    _saveTabs();
    Prefs.instance
      ..setBool(PrefKeys.windowMaximized, isMaximizedNotifier.value)
      ..setDouble(PrefKeys.windowLeftWidth, leftWidth)
      ..save();
    super.onAppTerminating();
  }

  @override
  void onWindowClose() {
    performAppTerminate();
  }

  @override
  void onWindowMoved() async {
    final pos = await windowManager.getPosition();
    Prefs.instance
      ..setDouble(PrefKeys.windowPosX, pos.dx)
      ..setDouble(PrefKeys.windowPosY, pos.dy);
  }

  @override
  void onWindowResize() async {
    final size = await windowManager.getSize();
    Prefs.instance
      ..setDouble(PrefKeys.windowWidth, size.width)
      ..setDouble(PrefKeys.windowHeight, size.height);
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
  void navigate(String uri) {
    final tab = _createTab(uri);
    if (tab != null) {
      detailKey.currentState?.openTab(tab);
    }
  }

  DesktopTab? _createTab(String uri) {
    final parsed = AppNavigatorUri.parse(uri);
    switch (parsed.uri) {
      case AppNavigator.uriRecord:
        return EditorTab(uuid: parsed.firstPath ?? '', keyword: parsed.queryParam('keyword'));
      case AppNavigator.uriCalendar:
        return DesktopTab.create(
          AppNavigator.uriCalendar,
          l10n.calendar,
          (key, closeCB) => CalendarPage(key: key, showAppBar: false, closeCallback: closeCB),
        );
      case AppNavigator.uriRecycler:
        return DesktopTab.create(
          AppNavigator.uriRecycler,
          l10n.recycler,
          (key, closeCB) => RecordRecyclerPage(key: key, showAppBar: false, closeCallback: closeCB),
        );
      case AppNavigator.uriSettings:
        return DesktopTab.create(
          AppNavigator.uriSettings,
          l10n.settings,
          (key, closeCB) => Navigator(
            pages: [MaterialPage(child: SettingsPage(key: key, showAppBar: false))],
            onDidRemovePage: (page) {},
          ),
        );
    }
    return null;
  }

  DesktopTab _tabFromMap(Map<String, dynamic> map) {
    return _createTab(map['uri'] as String)!;
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

