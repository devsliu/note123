import 'dart:math';
import 'dart:math' as math;

import 'package:note123/filesync/record_tree.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/config/language_manager.dart';
import 'package:note123/config/theme.dart';
import 'package:note123/config/app_config.dart';
import 'package:note123/ui/desktop/window_state.dart';
import 'package:flutter/material.dart';
import 'package:note123/ui/desktop/desktop_record_tabbar.dart';

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
  final String id;

  /// Display title. Subclasses may override to provide a localized value.
  String get title;

  DesktopTab({required this.id});

  /// Whether this tab is considered the same as [other] for the purpose of
  /// deduping open tabs (e.g. opening an already-open record focuses it
  /// instead of creating a second tab). Default compares runtime type and id.
  bool equal(DesktopTab other) => runtimeType == other.runtimeType && id == other.id;

  /// Called when this tab becomes the selected one. Subclasses update the
  /// record tree to reflect what is currently open (e.g. an editor tab opens
  /// its record; the calendar tab clears the selection).
  void setSelected(RecordTree recordTree);

  /// Build the page widget for this tab. [key] is the state key the detail
  /// page reserves for this tab, used to look up the page state for
  /// foreground/background lifecycle signals. Callbacks the page may use
  /// (close on remote delete, open a record) are supplied by the caller;
  /// subclasses pick the ones they need. The result is cached by the caller.
  Widget buildPage(GlobalKey key, {VoidCallback? onRecordDeleted, ValueChanged<TreeContentFile>? onOpenRecord});

  @override
  String toString() => title;
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
  /// Called when a page (e.g. the calendar) wants to open a record. The
  /// parent is responsible for turning [record] into a [DesktopTab] and
  /// calling [openTab], since tab subclasses live outside this file.
  final ValueChanged<TreeContentFile>? onOpenRecord;

  const DesktopTabsPage({super.key, this.onOpenRecord});

  @override
  DesktopTabsPageState createState() => DesktopTabsPageState();
}

class DesktopTabsPageState extends State<DesktopTabsPage> {
  final List<_DesktopTabImpl> _tabs = [];
  int currentIndex = 0;
  final RecordTree recordTree = Repository.get().recordTree;
  Size _lockedEditorSize = Size.zero;
  bool _wasAnimating = false;

  @override
  void initState() {
    super.initState();
    isWindowAnimatingNotifier.addListener(_onAnimatingChanged);
  }

  @override
  void dispose() {
    isWindowAnimatingNotifier.removeListener(_onAnimatingChanged);
    recordTree.setOpenedFile("");
    _tabs.clear();
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
      selectTab(idx);
      return;
    }
    _tabs.add(_DesktopTabImpl(tab: tab));
    _buildTabPage(_tabs.last);
    selectTab(_tabs.length - 1);
  }

  void closeTab(int index) {
    if (index < 0 || index >= _tabs.length) return;

    _tabs.removeAt(index);
    int newIndex = currentIndex;
    if (newIndex > index) {
      newIndex--;
    }
    newIndex = newIndex.clamp(0, max(0, _tabs.length - 1));
    selectTab(newIndex);
  }

  void closeOtherTabs(int keepIndex) {
    if (keepIndex < 0 || keepIndex >= _tabs.length) return;

    final keepTab = _tabs[keepIndex];

    _tabs.clear();
    _tabs.add(keepTab);

    selectTab(0);
  }

  void closeAllTabs() {
    _tabs.clear();
    selectTab(-1);
  }

  void closeTabsToRight(int startIndex) {
    if (startIndex < 0 || startIndex >= _tabs.length - 1) return;

    _tabs.removeRange(startIndex + 1, _tabs.length);

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

    _tabs.removeRange(0, startIndex);

    selectTab(newIndex.clamp(0, max(0, _tabs.length - 1)));
  }

  void selectTab(int index) {
    // Save currently editing content before switching tabs
    if (currentIndex >= 0 && currentIndex < _tabs.length) {
      final state = _tabs[currentIndex].key.currentState;
      final tabState = state as DesktopTabPageState?;
      if (tabState?.mounted ?? false) {
        tabState!.setInForeground(false);
      }
    }

    if (index >= 0 && index < _tabs.length) {
      _tabs[index].tab.setSelected(recordTree);
    } else {
      recordTree.setOpenedFile("");
    }
    setState(() {
      currentIndex = index;
    });

    if (index >= 0 && index < _tabs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final state = _tabs[index].key.currentState;
        final tabState = state as DesktopTabPageState?;
        if (tabState?.mounted ?? false) {
          tabState!.setInForeground(true);
        }
      });
    }
  }

  void _buildTabPage(_DesktopTabImpl impl) {
    impl.page = impl.tab.buildPage(
      impl.key,
      onRecordDeleted: () {
        final idx = _tabs.indexWhere((t) => t.tab.equal(impl.tab));
        if (idx != -1) closeTab(idx);
      },
      onOpenRecord: widget.onOpenRecord,
    );
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
      color: Colors.transparent,
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
            child: WindowMoveBar(color: theme.appBarBackgroundColor),
          ),
          // Tab bar
          LayoutId(
            id: 'tabBar',
            child: DesktopRecordTabBar(
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
          // Editor area
          LayoutId(
            id: 'editorStack',
            child: _tabs.isEmpty
                ? Center(child: Text(l10n.noOpenRecords))
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
      icon: const Icon(Icons.keyboard_arrow_down, size: 16),
      iconSize: 16,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
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
    final double titleBarHeight = windowTitleBarHeight;
    final double windowButtonsWidth = windowButtonWidth * 3;
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
      final dropdownSize = layoutChild('tabDropdown', BoxConstraints.loose(Size(size.width, titleBarHeight)));
      positionChild(
        'tabDropdown',
        Offset(size.width - windowButtonsWidth - dropdownSize.width, (titleBarHeight - dropdownSize.height) / 2),
      );
    }
    if (hasChild('tabBar')) {
      final left = 2.0;
      final top = 8.0;
      final right = showDropdown ? windowButtonsWidth + 40.0 : windowButtonsWidth;
      final width = math.max(0.0, size.width - left - right);
      final height = titleBarHeight - top;
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
