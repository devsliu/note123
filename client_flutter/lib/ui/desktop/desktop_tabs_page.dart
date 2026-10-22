import 'dart:math';
import 'dart:math' as math;

import 'package:notee/config/language_manager.dart';
import 'package:notee/config/theme.dart';
import 'package:notee/config/app_config.dart';
import 'package:notee/ui/desktop/window_state.dart';
import 'package:flutter/material.dart';
import 'package:notee/ui/desktop/desktop_tabbar.dart';
import 'package:notee/utils/utils.dart';

import 'desktop_title_bar.dart';

/// Interface for states that live inside a [DesktopTabsPage] tab and need
/// foreground/background lifecycle signals when the user switches tabs.
/// Both editor pages (BaseRecordEditPageState) and the calendar page implement
/// this so the detail page can manage them uniformly.
abstract class DesktopTabPageState {
  bool get mounted;
  void setInForeground(bool value);
}

/// Base class for tabs shown in [DesktopTabsPage].
///
/// [DesktopTab] is a pure model: it carries identity, title, and the logic for
/// building its page, but it does not own the page widget or its state key.
/// Those runtime objects are held by a [_DesktopTabImpl] wrapper, and the
/// detail page keeps a list of those wrappers in `_tabs`.
abstract class DesktopTab {
  final String uri;

  /// Display title. Subclasses may override to provide a localized value.
  String get title;

  DesktopTab({required this.uri});

  /// Serialize this tab's identity for persistence.
  /// [uri] already carries the full route (with query), subclasses only need
  /// to override if extra fields are needed.
  Map<String, dynamic> toMap() => {'uri': uri};

  /// Whether this tab is considered the same as [other] for the purpose of
  /// deduping open tabs (e.g. opening an already-open record focuses it
  /// instead of creating a second tab). Default compares runtime type and uri.
  bool equal(DesktopTab other) => runtimeType == other.runtimeType && uri == other.uri;

  /// Called when this tab becomes the selected one. Subclasses update the
  /// record opened state to reflect what is currently open (e.g. an editor
  /// tab opens its record; the calendar tab clears the selection).
  void select() {}

  /// Called when this tab is being closed. Subclasses release whatever
  /// [select] claimed (e.g. an editor tab closes its record from the
  /// opened-file stack).
  void close() {}

  /// Called when [openTab] finds an existing equal tab. Subclasses can pull
  /// updated data from [newTab] (e.g. a new search keyword) so the existing
  /// page can react instead of opening a duplicate tab.
  void refresh(DesktopTab newTab) {}

  /// Build the page widget for this tab. [key] is the state key the detail
  /// closePageCallback page ifself can close the tab.
  Widget buildPage(GlobalKey key, ValueCallback<BuildContext> closePageCallback);

  /// Build per-tab action widgets rendered in the tab bar's fixed right-side
  /// slot (e.g. share icon + overflow menu). Return null to contribute nothing.
  /// [key] is the same key passed to [buildPage]; subclasses cast it to their
  /// page state type to read live state (canUndo, showOutline, …).
  List<Widget>? buildActions(GlobalKey key) => null;

  @override
  String toString() => title;

  static DesktopTab create(
    String uri,
    String tabTitle,
    Widget Function(GlobalKey key, ValueCallback<BuildContext> closePageCallback) pageBuilder,
  ) {
    return _SimpleDesktopTab(uri: uri, tabTitle: tabTitle, pageBuilder: pageBuilder);
  }
}

class _SimpleDesktopTab extends DesktopTab {
  final String tabTitle;
  final Widget Function(GlobalKey key, ValueCallback<BuildContext> closePageCallback) pageBuilder;

  _SimpleDesktopTab({required super.uri, required this.tabTitle, required this.pageBuilder});

  @override
  String get title => tabTitle;

  @override
  Widget buildPage(GlobalKey key, ValueCallback<BuildContext> closePageCallback) => pageBuilder(key, closePageCallback);
}

/// Wrapper pairing a [DesktopTab] model with its runtime page state. The
/// detail page keeps a list of these in `_tabs`; each holds the widget's
/// [GlobalKey] and the built [page] widget.
class _DesktopTabImpl {
  final DesktopTab tab;
  final GlobalKey key = GlobalKey();
  Widget? page;

  _DesktopTabImpl({required this.tab});
}

class DesktopTabsPage extends StatefulWidget {
  const DesktopTabsPage({super.key});

  @override
  DesktopTabsPageState createState() => DesktopTabsPageState();
}

class DesktopTabsPageState extends State<DesktopTabsPage> {
  final List<_DesktopTabImpl> _tabs = [];
  int get tabCount => _tabs.length;
  int currentIndex = 0;
  final ValueNotifier<int> _pageReadyNotifier = ValueNotifier<int>(-1);
  Size _lockedEditorSize = Size.zero;
  bool _wasAnimating = false;

  @override
  void initState() {
    super.initState();
    isWindowAnimatingNotifier.addListener(_onAnimatingChanged);
  }

  List<DesktopTab> get tabs => _tabs.map((impl) => impl.tab).toList();

  @override
  void dispose() {
    isWindowAnimatingNotifier.removeListener(_onAnimatingChanged);
    _pageReadyNotifier.dispose();
    // Remove in three segments so the currently selected tab is closed last.
    final idx = currentIndex.clamp(0, max(0, _tabs.length - 1)).toInt();
    removeTabs(idx + 1, _tabs.length);
    removeTabs(0, idx);
    removeTabs(0, 1);
    super.dispose();
  }

  void _onAnimatingChanged() {
    final nowAnimating = isWindowAnimatingNotifier.value;
    if (nowAnimating && !_wasAnimating) {
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        _lockedEditorSize = Size(renderBox.size.width, renderBox.size.height - windowTitleBarHeight);
      }
    }
    _wasAnimating = nowAnimating;
    setState(() {});
  }

  /// Open (or focus) [tab]. If an equal tab is already open it is focused
  /// instead of creating a duplicate; otherwise [tab] is added, its page is
  /// built, and it is selected.
  void openTab(DesktopTab tab) {
    final idx = _tabs.indexWhere((impl) => impl.tab.equal(tab));
    if (idx != -1) {
      _tabs[idx].tab.refresh(tab);
      _buildTabPage(_tabs[idx]);
      selectTab(idx);
      return;
    }
    _tabs.add(_DesktopTabImpl(tab: tab));
    _buildTabPage(_tabs.last);
    selectTab(_tabs.length - 1);
  }

  /// Remove tabs in the half-open range [from, to), closing each one.
  /// Out-of-range arguments are clamped to the list bounds.
  void removeTabs(int from, int to) {
    final start = from.clamp(0, _tabs.length).toInt();
    final end = to.clamp(start, _tabs.length).toInt();
    for (int i = start; i < end; i++) {
      _tabs[i].tab.close();
    }
    _tabs.removeRange(start, end);
  }

  void closeTab(int index) {
    if (index < 0 || index >= _tabs.length) return;

    removeTabs(index, index + 1);
    int newIndex = currentIndex;
    if (newIndex > index) {
      newIndex--;
    }
    newIndex = newIndex.clamp(0, max(0, _tabs.length - 1));
    selectTab(newIndex);
  }

  void closeOtherTabs(int keepIndex) {
    if (keepIndex < 0 || keepIndex >= _tabs.length) return;

    // Remove the right part first so keepIndex stays valid for the left part.
    removeTabs(keepIndex + 1, _tabs.length);
    removeTabs(0, keepIndex);

    selectTab(0);
  }

  void closeAllTabs() {
    removeTabs(0, _tabs.length);
    selectTab(-1);
  }

  void closeTabsToRight(int startIndex) {
    if (startIndex < 0 || startIndex >= _tabs.length - 1) return;

    removeTabs(startIndex + 1, _tabs.length);

    if (currentIndex > startIndex) {
      selectTab(startIndex);
    }
  }

  void closeTabsToLeft(int startIndex) {
    if (startIndex <= 0) return;

    int newIndex = currentIndex;

    if (currentIndex < startIndex) {
      newIndex = 0;
    } else {
      newIndex = currentIndex - startIndex;
    }

    removeTabs(0, startIndex);

    selectTab(newIndex.clamp(0, max(0, _tabs.length - 1)));
  }

  void selectTab(int index) {
    // Save currently editing content before switching tabs
    if (currentIndex >= 0 && currentIndex < _tabs.length) {
      final state = _tabs[currentIndex].key.currentState;
      final tabState = state is DesktopTabPageState ? state as DesktopTabPageState : null;
      if (tabState != null && tabState.mounted) {
        tabState.setInForeground(false);
      }
    }

    if (index >= 0 && index < _tabs.length) {
      _tabs[index].tab.select();
    }
    setState(() {
      currentIndex = index;
    });

    if (index >= 0 && index < _tabs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (index < 0 || index >= _tabs.length) return;
        final state = _tabs[index].key.currentState;
        final tabState = state is DesktopTabPageState ? state as DesktopTabPageState : null;
        if (tabState != null && tabState.mounted) {
          tabState.setInForeground(true);
        }
        _pageReadyNotifier.value = index;
      });
    }
  }

  void _buildTabPage(_DesktopTabImpl impl) {
    impl.page = impl.tab.buildPage(impl.key, (ctx) {
      final idx = _tabs.indexWhere((t) => t.tab.equal(impl.tab));
      if (idx != -1) closeTab(idx);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabCount = _tabs.length;
    final showDropdown = tabCount > 1;
    final isAnimating = isWindowAnimatingNotifier.value;
    if (!isAnimating) {
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {}
    }
    var theme = Theme.of(context);
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: CustomMultiChildLayout(
        delegate: _DesktopRightSideAllLayoutDelegate(
          showDropdown: showDropdown,
          isWindowAnimating: isAnimating,
          lockedEditorSize: isAnimating ? _lockedEditorSize : null,
        ),
        children: [
          // Title bar
          LayoutId(
            id: 'moveBar',
            child: Column(
              children: [
                WindowMoveBar(color: theme.appBarBackgroundColor),
                Divider(height: 1, thickness: 1, color: theme.colorScheme.outline.withAlpha(80)),
              ],
            ),
          ),

          
          // Tab bar
          LayoutId(
            id: 'tabBar',
            child: DesktopTabBar(
              tabs: _tabs.map((impl) => impl.tab).toList(),
              currentIndex: currentIndex,
              onSelectTab: selectTab,
              onCloseTab: closeTab,
              onCloseOtherTabs: closeOtherTabs,
              onCloseAllTabs: closeAllTabs,
              onCloseTabsToRight: closeTabsToRight,
              onCloseTabsToLeft: closeTabsToLeft,
            ),
          ),
          if (showDropdown)
            LayoutId(
              id: 'tabDropdown',
              child: IconButtonTheme(
                data: theme.appBarIconButtonTheme,
                child: _TabDropdown(
                  tabs: _tabs.map((impl) => impl.tab).toList(),
                  currentIndex: currentIndex,
                  onSelect: selectTab,
                  onCloseTab: closeTab,
                ),
              ),
            ),
          LayoutId(id: 'windowButtons', child: WindowManagerButtons()),
          // Fixed-width per-tab actions slot (share + ⋯ menu), between tabDropdown and windowButtons.
          // Only this zone rebuilds when a page finishes mounting, not the whole shell.
          LayoutId(
            id: 'actions',
            child: ValueListenableBuilder<int>(
              valueListenable: _pageReadyNotifier,
              builder: (context, readyIndex, _) {
                if (_tabs.isEmpty || currentIndex < 0 || currentIndex >= _tabs.length) {
                  return const SizedBox.shrink();
                }
                final actions = _tabs[currentIndex].tab.buildActions(_tabs[currentIndex].key);
                if (actions == null || actions.isEmpty) return const SizedBox.shrink();
                return IconButtonTheme(
                  data: theme.appBarIconButtonTheme,
                  child: Row(mainAxisSize: MainAxisSize.min, children: actions),
                );
              },
            ),
          ),

          LayoutId(
            id: 'editorStack',
            child: _tabs.isEmpty
                ? Container(
                    color: theme.colorScheme.surface,
                    alignment: Alignment.center,
                    child: Text(l10n.noOpenRecords),
                  )
                : IndexedStack(index: currentIndex, children: _tabs.map((impl) => impl.page!).toList()),
          ),
        ],
      ),
    );
  }
}

class _TabDropdown extends StatefulWidget {
  final List<DesktopTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onCloseTab;

  const _TabDropdown({
    required this.tabs,
    required this.currentIndex,
    required this.onSelect,
    required this.onCloseTab,
  });

  @override
  State<_TabDropdown> createState() => _TabDropdownState();
}

class _TabDropdownState extends State<_TabDropdown> {
  final GlobalKey _arrowKey = GlobalKey();

  void _showPopupMenu() async {
    setState(() {});
    final RenderBox renderBox = _arrowKey.currentContext!.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final size = renderBox.size;
    final selected = await showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy + size.height, position.dx + size.width, position.dy),
      popUpAnimationStyle: AppConfig.menuAnimationStyle,
      items: [
        for (int i = 0; i < widget.tabs.length; i++)
          PopupMenuItem<int>(
            height: 30,
            value: i,
            child: Row(
              children: [
                if (i == widget.currentIndex) Icon(Icons.check, size: 16, color: Theme.of(context).colorScheme.primary),
                if (i != widget.currentIndex) const SizedBox(width: 16), // Placeholder for alignment
                const SizedBox(width: 4),
                Expanded(child: Text(widget.tabs[i].title, overflow: TextOverflow.ellipsis)),
                GestureDetector(
                  onTap: () {
                    // Close current tab
                    widget.onCloseTab(i);
                    // Close current menu
                    Navigator.pop(context);
                    // If there are still tabs, re-show menu
                    if (widget.tabs.length > 1) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          _showPopupMenu();
                        }
                      });
                    }
                  },
                  child: Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    child: const Icon(Icons.close, size: 14),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    // Control may have been destroyed along with tab closure while menu was waiting
    if (!mounted) return;
    setState(() {});
    if (selected != null) {
      widget.onSelect(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: _arrowKey,
      icon: const Icon(Icons.keyboard_arrow_down, size: 22),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: BoxConstraints.tight(Size(40, 40)),
      tooltip: l10n.showAllTabs,
      onPressed: _showPopupMenu,
    );
  }
}

// New CustomMultiChildLayout Delegate, handles overall layout of top bars and editor area
class _DesktopRightSideAllLayoutDelegate extends MultiChildLayoutDelegate {
  final bool showDropdown;
  final bool isWindowAnimating;
  final Size? lockedEditorSize;

  _DesktopRightSideAllLayoutDelegate({
    required this.showDropdown,
    required this.isWindowAnimating,
    this.lockedEditorSize,
  });

  @override
  void performLayout(Size size) {
    final double titleBarHeight = windowTitleBarHeight + 1; //1 for divider
    final double windowButtonsWidth = windowButtonWidth * 3;

    // Actions slot size (computed once below; only reserves space if present)
    Size? actionsSize;
    Size? dropdownSize;

    if (hasChild('moveBar')) {
      layoutChild('moveBar', BoxConstraints.tight(Size(size.width, titleBarHeight)));
      positionChild('moveBar', Offset.zero);
    }
    if (hasChild('windowButtons')) {
      final btnSize = Size(windowButtonsWidth, titleBarHeight);
      layoutChild('windowButtons', BoxConstraints.tight(btnSize));
      positionChild('windowButtons', Offset(size.width - btnSize.width, 0));
    }
    if (showDropdown && hasChild('tabDropdown')) {
      dropdownSize = layoutChild('tabDropdown', BoxConstraints.loose(Size(size.width, titleBarHeight)));
      positionChild(
        'tabDropdown',
        Offset(size.width - windowButtonsWidth - dropdownSize.width, (titleBarHeight - dropdownSize.height) / 2),
      );
    }
    if (hasChild('actions')) {
      double actionsRightEdge = size.width - windowButtonsWidth - (dropdownSize?.width ?? 0);
      actionsSize = layoutChild('actions', BoxConstraints.loose(Size(size.width, titleBarHeight)));
        positionChild(
          'actions',
          Offset(actionsRightEdge - actionsSize.width, (titleBarHeight - actionsSize.height) / 2),
        );
    }

    if (hasChild('tabBar')) {
      final left = 0.0;
      final top = 8.0;
      // Reserve right margin for: actions slot (actual width only if present)
      // + optional tabDropdown (40 for the button + its left padding) + windowButtons
      final right =
          windowButtonsWidth +
          (actionsSize != null ? actionsSize.width + 4.0 : 0.0) +
          (dropdownSize != null ? dropdownSize.width + 4.0 : 0.0);
      final width = math.max(0.0, size.width - left - right);
      final height = titleBarHeight - top + 0.5; //0.5 for total cover the divider
      layoutChild('tabBar', BoxConstraints(maxWidth: width, maxHeight: height, minHeight: height));
      positionChild('tabBar', Offset(left, top));
    }
    if (hasChild('editorStack')) {
      final effectiveEditorSize =
          (isWindowAnimating && lockedEditorSize != null && lockedEditorSize!.width > 0 && lockedEditorSize!.height > 0)
          ? lockedEditorSize!
          : Size(size.width, size.height - titleBarHeight);
      layoutChild('editorStack', BoxConstraints.tight(effectiveEditorSize));
      positionChild('editorStack', Offset(0, titleBarHeight));
    }
  }

  @override
  bool shouldRelayout(covariant _DesktopRightSideAllLayoutDelegate oldDelegate) {
    return showDropdown != oldDelegate.showDropdown ||
        isWindowAnimating != oldDelegate.isWindowAnimating ||
        lockedEditorSize != oldDelegate.lockedEditorSize;
  }
}
