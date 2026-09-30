import 'package:flutter/material.dart';
import 'package:note123/config/theme.dart';
import 'package:note123/config/app_config.dart';

import '../../config/language_manager.dart';

class DesktopRecordTabBar extends StatelessWidget {
  final List<dynamic> tabs;
  final int currentIndex;
  final Function(int) onSelectTab;
  final Function(int) onCloseTab;
  final Function(int)? onCloseOtherTabs;
  final Function()? onCloseAllTabs;
  final Function(int)? onCloseTabsToRight;
  final Function(int)? onCloseTabsToLeft;

  const DesktopRecordTabBar({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onSelectTab,
    required this.onCloseTab,
    this.onCloseOtherTabs,
    this.onCloseAllTabs,
    this.onCloseTabsToRight,
    this.onCloseTabsToLeft,
  });

  static final minTabWidth = 70.0;
  static final maxTabWidth = 180.0;

  @override
  Widget build(BuildContext context) {
    var tabHeight = 32.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        tabHeight = constraints.minHeight;
        return _buildTabBar(context, tabHeight);
      },
    );
  }

  Widget _buildTabBar(BuildContext context, double tabHeight) {
    final scrollController = ScrollController();
    final List<GlobalKey> tabKeys = List.generate(tabs.length, (index) => GlobalKey());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients && currentIndex >= 0 && currentIndex < tabs.length) {
        _scrollToCurrentTab(scrollController, tabKeys);
      }
    });

    return SingleChildScrollView(
      controller: scrollController,
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(tabs.length, (i) {
          final tab = tabs[i];
          final selected = i == currentIndex;
          return _TabItem(
            key: tabKeys[i],
            title: tab.toString(),
            selected: selected,
            onTap: () => onSelectTab(i),
            onClose: () => onCloseTab(i),
            height: tabHeight,
            index: i,
            totalCount: tabs.length,
            onCloseOtherTabs: onCloseOtherTabs,
            onCloseAllTabs: onCloseAllTabs,
            onCloseTabsToRight: onCloseTabsToRight,
            onCloseTabsToLeft: onCloseTabsToLeft,
          );
        }),
      ),
    );
  }

  void _scrollToCurrentTab(ScrollController controller, List<GlobalKey> tabKeys) {
    if (currentIndex < 0 || currentIndex >= tabKeys.length) return;

    final currentTabKey = tabKeys[currentIndex];
    final RenderBox? renderBox = currentTabKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    // Get current tab position
    final tabPosition = renderBox.localToGlobal(Offset.zero);
    final tabWidth = renderBox.size.width;

    // Get scroll container position
    final scrollViewContext = controller.position.context.storageContext;
    final RenderBox? scrollViewRenderBox = scrollViewContext.findRenderObject() as RenderBox?;
    if (scrollViewRenderBox == null) return;

    final scrollViewPosition = scrollViewRenderBox.localToGlobal(Offset.zero);
    final scrollViewWidth = scrollViewRenderBox.size.width;

    // Calculate relative position
    final relativePosition = tabPosition.dx - scrollViewPosition.dx;
    final currentOffset = controller.offset;
    final tabLeft = relativePosition + currentOffset;
    final tabRight = tabLeft + tabWidth;

    // Calculate scroll target position
    double targetOffset = currentOffset;
    const padding = 0; // Add some padding

    if (tabLeft < currentOffset + padding) {
      // Tab not visible on left side, scroll left
      targetOffset = tabLeft - padding;
    } else if (tabRight > currentOffset + scrollViewWidth - padding) {
      // Tab not visible on right side, scroll right
      targetOffset = tabRight - scrollViewWidth + padding;
    }

    // Ensure not out of bounds
    targetOffset = targetOffset.clamp(0.0, controller.position.maxScrollExtent);

    // Scroll to target position
    if (targetOffset != currentOffset) {
      controller.animateTo(targetOffset, duration: const Duration(milliseconds: 200), curve: Curves.ease);
    }
  }
}

// Obsidian-style TabItem, supports hover color change and x button
class _TabItem extends StatefulWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final double height;
  final int index;
  final int totalCount;
  final Function(int)? onCloseOtherTabs;
  final Function()? onCloseAllTabs;
  final Function(int)? onCloseTabsToRight;
  final Function(int)? onCloseTabsToLeft;

  const _TabItem({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    required this.onClose,
    required this.height,
    required this.index,
    required this.totalCount,
    this.onCloseOtherTabs,
    this.onCloseAllTabs,
    this.onCloseTabsToRight,
    this.onCloseTabsToLeft,
  });

  @override
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem> {
  bool _hover = false;

  Future<void> _showContextMenu(TapUpDetails details) async {
    final menuItems = <PopupMenuEntry<int>>[];

    // Close other tabs
    if (widget.onCloseOtherTabs != null && widget.totalCount > 1) {
      menuItems.add(PopupMenuItem(value: 0, child: Text(l10n.closeOtherTabs)));
    }

    // Close all tabs
    if (widget.onCloseAllTabs != null && widget.totalCount > 0) {
      menuItems.add(PopupMenuItem(value: 1, child: Text(l10n.closeAllTabs)));
    }

    // Close tabs to the right
    if (widget.onCloseTabsToRight != null && widget.index < widget.totalCount - 1) {
      menuItems.add(PopupMenuItem(value: 2, child: Text(l10n.closeTabsToRight)));
    }

    // Close tabs to the left
    if (widget.onCloseTabsToLeft != null && widget.index > 0) {
      menuItems.add(PopupMenuItem(value: 3, child: Text(l10n.closeTabsToLeft)));
    }

    if (menuItems.isEmpty) return;

    var position = details.globalPosition;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final offset = overlay.localToGlobal(Offset.zero);
    final menuPosition = RelativeRect.fromLTRB(
      position.dx + offset.dx,
      position.dy + offset.dy,
      overlay.size.width - position.dx - offset.dx,
      overlay.size.height - position.dy - offset.dy,
    );

    final value = await showMenu<int>(
      context: context,
      position: menuPosition,
      items: menuItems,
      popUpAnimationStyle: AppConfig.menuAnimationStyle,
    );

    switch (value) {
      case 0:
        widget.onCloseOtherTabs?.call(widget.index);
        break;
      case 1:
        widget.onCloseAllTabs?.call();
        break;
      case 2:
        widget.onCloseTabsToRight?.call(widget.index);
        break;
      case 3:
        widget.onCloseTabsToLeft?.call(widget.index);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = widget.selected;
    final baseColor = selected
        ? theme.colorScheme.surface
        : Color.lerp(
            Color.lerp(theme.colorScheme.surface, theme.appBarBackgroundColor, 0.9),
            theme.colorScheme.secondary,
            0.4,
          );

    // Improved hover color calculation, ensure consistent effect across all themes
    final hoverColor = selected
        ? baseColor
        : theme.brightness == Brightness.dark
        ? Colors.white.withAlpha(80) // Dark theme uses white transparent
        : Colors.black.withAlpha(80); // Light theme uses black transparent

    final textColor = selected
        ? theme.colorScheme.onSurface
        : theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;
    final showCloseButton = selected || _hover;
    final borderColor = selected ? theme.colorScheme.outline : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapUp: (details) => _showContextMenu(details),
        child: Container(
          decoration: BoxDecoration(
            color: _hover ? hoverColor : baseColor,
            border: Border(
              left: BorderSide(width: 1, color: borderColor),
              top: BorderSide(width: 1, color: borderColor),
              right: BorderSide(width: 1, color: borderColor),
              bottom: BorderSide.none,
            ),
          ),
          constraints: BoxConstraints(
            minWidth: DesktopRecordTabBar.minTabWidth,
            maxWidth: DesktopRecordTabBar.maxTabWidth,
          ),
          height: widget.height,
          padding: const EdgeInsets.only(left: 8, right: 2, top: 2, bottom: 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TextStyle(color: textColor),
                ),
              ),
              // Always show close button position, just make transparent when not selected/not hovered
              Opacity(
                opacity: showCloseButton ? 1.0 : 0.0,
                child: IconButton(
                  icon: Icon(Icons.close, size: 16),
                  padding: EdgeInsets.all(3),
                  constraints: const BoxConstraints(),
                  splashRadius: 16,
                  tooltip: showCloseButton ? l10n.close : null,
                  color: textColor,
                  onPressed: showCloseButton ? widget.onClose : null,
                  mouseCursor: showCloseButton ? SystemMouseCursors.click : SystemMouseCursors.basic,
                  highlightColor: Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
