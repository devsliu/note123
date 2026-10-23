import 'package:flutter/material.dart';
import 'package:notee/config/theme.dart';
import 'package:notee/config/app_config.dart';

import '../../config/language_manager.dart';

class DesktopTabBar extends StatefulWidget {
  final List<dynamic> tabs;
  final int currentIndex;
  final Function(int) onSelectTab;
  final Function(int) onCloseTab;
  final Function(int)? onCloseOtherTabs;
  final Function()? onCloseAllTabs;
  final Function(int)? onCloseTabsToRight;
  final Function(int)? onCloseTabsToLeft;

  const DesktopTabBar({
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
  State<DesktopTabBar> createState() => _DesktopTabBarState();
}

class _DesktopTabBarState extends State<DesktopTabBar> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      child: Row(
        spacing: 0.8,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(widget.tabs.length, (i) {
          final tab = widget.tabs[i];
          final selected = i == widget.currentIndex;
          return _TabItem(
            key: ValueKey(tab),
            title: tab.toString(),
            selected: selected,
            onTap: () => widget.onSelectTab(i),
            onClose: () => widget.onCloseTab(i),
            height: selected ? tabHeight : tabHeight - 1,
            index: i,
            totalCount: widget.tabs.length,
            onCloseOtherTabs: widget.onCloseOtherTabs,
            onCloseAllTabs: widget.onCloseAllTabs,
            onCloseTabsToRight: widget.onCloseTabsToRight,
            onCloseTabsToLeft: widget.onCloseTabsToLeft,
          );
        }),
      ),
    );
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

  @override
  void didUpdateWidget(covariant _TabItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.selected && widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Scrollable.ensureVisible(context, duration: const Duration(milliseconds: 200), curve: Curves.ease);
        }
      });
    }
  }

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
      popUpAnimationStyle: AppEnv.menuAnimationStyle,
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
        : Color.lerp(theme.appBarBackgroundColor, theme.colorScheme.onSurface, 0.2);

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
          constraints: BoxConstraints(minWidth: DesktopTabBar.minTabWidth, maxWidth: DesktopTabBar.maxTabWidth),
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
