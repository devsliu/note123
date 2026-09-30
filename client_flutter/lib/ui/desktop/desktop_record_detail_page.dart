import 'dart:math';
import 'dart:math' as math;

import 'package:note123/filesync/record_tree.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/ui/editor/base_record_edit_page.dart';
import 'package:note123/ui/editor/record_flow_editor_page.dart';
import 'package:note123/config/language_manager.dart';
import 'package:note123/config/theme.dart';
import 'package:note123/config/app_config.dart';
import 'package:note123/ui/desktop/window_state.dart';
import 'package:flutter/material.dart';
import 'package:note123/ui/desktop/desktop_record_tabbar.dart';

import 'desktop_title_bar.dart';

class EditorTab {
  final String id;
  final String title;
  final TreeContentFile record;

  EditorTab({required this.id, required this.title, required this.record});

  @override
  String toString() {
    return title;
  }
}

class DesktopRecordDetailPage extends StatefulWidget {
  const DesktopRecordDetailPage({super.key});

  @override
  DesktopRecordDetailPageState createState() => DesktopRecordDetailPageState();
}

class DesktopRecordDetailPageState extends State<DesktopRecordDetailPage> {
  final List<EditorTab> tabs = [];
  final List<BaseRecordEditPage> _tabPages = [];
  int currentIndex = 0;
  final RecordTree recordTree = Repository.get().recordTree;
  TreeContentFile? currentRecord;
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
    tabs.clear();
    _tabPages.clear();
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

  void openRecordTab(TreeContentFile record) {
    final idx = tabs.indexWhere((t) => t.id == record.uuid);
    if (idx != -1) {
      selectTab(idx);
      return;
    }
    tabs.add(EditorTab(id: record.uuid, title: record.name, record: record));
    _tabPages.add(_buildEditorPageWidget(tabs.last));
    selectTab(tabs.length - 1);
  }

  void closeTab(int index) {
    if (index < 0 || index >= tabs.length) return;

    // Remove the tab and its corresponding widget
    tabs.removeAt(index);
    _tabPages.removeAt(index);
    int newIndex = currentIndex;
    if (newIndex > index) {
      newIndex--;
    }
    newIndex = newIndex.clamp(0, max(0, tabs.length - 1));
    selectTab(newIndex);
  }

  void closeOtherTabs(int keepIndex) {
    // Close all tabs except the specified one
    if (keepIndex < 0 || keepIndex >= tabs.length) return;

    // First save info about the tab to keep
    final keepTab = tabs[keepIndex];
    final keepPage = _tabPages[keepIndex];

    // Clear all tabs
    tabs.clear();
    _tabPages.clear();

    // Add back the kept tab
    tabs.add(keepTab);
    _tabPages.add(keepPage);

    // Select the only tab
    selectTab(0);
  }

  void closeAllTabs() {
    // Close all tabs
    tabs.clear();
    _tabPages.clear();
    currentRecord = null;
    recordTree.setOpenedFile("");
    selectTab(-1);
  }

  void closeTabsToRight(int startIndex) {
    // Close all tabs to the right of the specified tab
    if (startIndex < 0 || startIndex >= tabs.length - 1) return;

    tabs.removeRange(startIndex + 1, tabs.length);
    _tabPages.removeRange(startIndex + 1, _tabPages.length);

    // If current selected tab is in removed range, select the last kept tab
    if (currentIndex > startIndex) {
      selectTab(startIndex);
    }
  }

  void closeTabsToLeft(int startIndex) {
    // Close all tabs to the left of the specified tab
    if (startIndex <= 0) return;

    // Record current selected index
    int newIndex = currentIndex;

    // If current selected tab is in removed range, adjust index
    if (currentIndex < startIndex) {
      newIndex = 0;
    } else {
      newIndex = currentIndex - startIndex;
    }

    tabs.removeRange(0, startIndex);
    _tabPages.removeRange(0, startIndex);

    selectTab(newIndex.clamp(0, max(0, tabs.length - 1)));
  }

  void selectTab(int index) {
    // Save currently editing content before switching tabs
    if (currentIndex >= 0 && currentIndex < _tabPages.length) {
      final currentWidget = _tabPages[currentIndex];
      final state = (currentWidget.key as GlobalKey?)?.currentState;
      if (state != null && state.mounted) {
        if (state is BaseRecordEditPageState) {
          state.setInForeground(false);
        }
      }
    }

    if (index >= 0 && index < tabs.length) {
      currentRecord = tabs[index].record;
      recordTree.setOpenedFile(currentRecord?.uuid ?? "");
    } else if (tabs.isEmpty) {
      currentRecord = null;
      recordTree.setOpenedFile("");
    }
    setState(() {
      currentIndex = index;
    });

    if (index >= 0 && index < _tabPages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final newWidget = _tabPages[index];
        final state = (newWidget.key as GlobalKey?)?.currentState;
        if (state != null && state.mounted && state is BaseRecordEditPageState) {
          state.setInForeground(true);
        }
      });
    }
  }

  BaseRecordEditPage _buildEditorPageWidget(EditorTab tab) {
    // Add GlobalKey for each edit page so we can access their state
    final key = GlobalKey();
    return RecordFlowEditorPage(
      record: tab.record,
      key: key,
      // Close corresponding tab when record is deleted remotely
      onRecordDeleted: () {
        final idx = tabs.indexWhere((t) => t.id == tab.id);
        if (idx != -1) closeTab(idx);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabCount = tabs.length;
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
              tabs: tabs,
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
                child: _TabDropdown(tabs: tabs, currentIndex: currentIndex, onSelect: selectTab, onCloseTab: closeTab),
              ),
            ),
          LayoutId(id: 'windowButtons', child: WindowManagerButtons()),
          // Editor area
          LayoutId(
            id: 'editorStack',
            child: tabs.isEmpty
                ? Center(child: Text(l10n.noOpenRecords))
                : IndexedStack(index: currentIndex, children: _tabPages),
          ),
        ],
      ),
    );
  }
}

class _TabDropdown extends StatefulWidget {
  final List<EditorTab> tabs;
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
