import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:note123/config/language_manager.dart';

class FixedToolbar extends StatefulWidget {
  const FixedToolbar({
    super.key,
    required this.items,
    required this.editorState,
    this.scrollable = false,
    this.toolbarHeight = 40,
    this.iconSize = 18,
    this.iconColor,
    this.activeColor,
    this.backgroundColor,
    this.padding,
    this.decoration,
    this.tooltipBuilder,
    this.placeHolderBuilder,
  });

  final List<ToolbarItem> items;
  final EditorState editorState;
  final bool scrollable;
  final double toolbarHeight;
  final double iconSize;
  final Color? iconColor;
  final Color? activeColor;
  final Color? backgroundColor;
  final EdgeInsets? padding;
  final Decoration? decoration;
  final ToolbarTooltipBuilder? tooltipBuilder;
  final PlaceHolderItemBuilder? placeHolderBuilder;

  @override
  State<FixedToolbar> createState() => _FixedToolbarState();
}

class _FixedToolbarState extends State<FixedToolbar> {
  late final StreamSubscription _transactionSubscription;

  @override
  void initState() {
    super.initState();
    _ensureSelection();
    widget.editorState.selectionNotifier.addListener(_onSelectionChanged);
    _transactionSubscription = widget.editorState.transactionStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant FixedToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editorState != widget.editorState) {
      oldWidget.editorState.selectionNotifier.removeListener(_onSelectionChanged);
      widget.editorState.selectionNotifier.addListener(_onSelectionChanged);
    }
  }

  @override
  void dispose() {
    widget.editorState.selectionNotifier.removeListener(_onSelectionChanged);
    _transactionSubscription.cancel();
    super.dispose();
  }

  void _onSelectionChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = widget.iconColor ?? theme.colorScheme.onSurface;
    final activeColor = widget.activeColor ?? theme.colorScheme.primary;
    final backgroundColor = widget.backgroundColor ?? theme.colorScheme.surfaceContainerHighest;

    final children = widget.items.map((item) => _buildItem(item, iconColor, activeColor)).toList();

    return Container(
      color: backgroundColor,
      padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 8),
      decoration: widget.decoration,
      child: widget.scrollable
          ? SizedBox(
              height: widget.toolbarHeight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < children.length; i++) ...[
                      children[i],
                      if (i < children.length - 1) const SizedBox(width: 2),
                    ],
                  ],
                ),
              ),
            )
          : ConstrainedBox(
              constraints: BoxConstraints(minHeight: widget.toolbarHeight),
              child: Wrap(spacing: 2, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: children),
            ),
    );
  }

  Widget _buildItem(ToolbarItem item, Color iconColor, Color activeColor) {
    if (widget.editorState.selection == null) {
      return const SizedBox.shrink();
    }
    final w = item.builder?.call(context, widget.editorState, activeColor, iconColor, null);
    if (w is! SVGIconItemWidget) return const SizedBox.shrink();
    if (widget.tooltipBuilder != null) {
      return widget.tooltipBuilder!.call(context, item.id, item.tooltipsMessage, w);
    }
    return w;
  }

  void _ensureSelection() {
    final selection = widget.editorState.selection;
    if (selection != null) return;
    final nodes = widget.editorState.document.root.children;
    if (nodes.isEmpty) return;
    final len = nodes.first.delta?.toPlainText().length ?? 0;
    widget.editorState.updateSelectionWithReason(Selection.collapsed(Position(path: [0], offset: len)));
  }
}

final ToolbarItem timeToolbarItem = ToolbarItem(
  id: 'editor.time',
  group: 0,
  isActive: (_) => true,
  builder: (context, editorState, highlightColor, iconColor, tooltipBuilder) {
    final child = SVGIconItemWidget(
      iconBuilder: (_) => Icon(Icons.timer_outlined, color: iconColor, size: 18),
      isHighlight: false,
      highlightColor: highlightColor,
      iconColor: iconColor,
      onPressed: () {
        final now = DateTime.now();
        final formattedTime = DateFormat('yyyy-MM-dd HH:mm').format(now);
        final selection = editorState.selection;
        if (selection == null) return;
        final node = editorState.document.nodeAtPath(selection.end.path);
        if (node == null) return;
        final transaction = editorState.transaction
          ..insertTextDelta(node, selection.endIndex, Delta()..insert('$formattedTime '));
        editorState.apply(transaction);
      },
    );
    if (tooltipBuilder != null) {
      return tooltipBuilder(context, 'editor.time', 'Insert Time', child);
    }
    return child;
  },
);

final ToolbarItem todoListItem = ToolbarItem(
  id: 'editor.todo_list',
  group: 3,
  isActive: (editorState) => editorState.selection != null,
  builder: (context, editorState, highlightColor, iconColor, tooltipBuilder) {
    final selection = editorState.selection;
    final node = selection != null ? editorState.getNodeAtPath(selection.start.path) : null;
    final isHighlight = node?.type == TodoListBlockKeys.type;
    final child = SVGIconItemWidget(
      iconBuilder: (_) => Icon(Icons.check_box_outlined, size: 18, color: isHighlight ? highlightColor : iconColor),
      isHighlight: isHighlight,
      highlightColor: highlightColor,
      iconColor: iconColor,
      onPressed: () {
        final selection = editorState.selection;
        if (selection == null) return;
        final node = editorState.getNodeAtPath(selection.start.path);
        if (node == null) return;
        if (node.type == TodoListBlockKeys.type) {
          editorState.formatNode(
            selection,
            (node) => node.copyWith(
              type: ParagraphBlockKeys.type,
              attributes: {ParagraphBlockKeys.delta: (node.delta ?? Delta()).toJson()},
            ),
          );
        } else {
          editorState.formatNode(
            selection,
            (node) => node.copyWith(
              type: TodoListBlockKeys.type,
              attributes: {TodoListBlockKeys.checked: false, blockComponentDelta: (node.delta ?? Delta()).toJson()},
            ),
          );
        }
      },
    );
    if (tooltipBuilder != null) {
      return tooltipBuilder(context, 'editor.todo_list', 'Todo', child);
    }
    return child;
  },
);

final ToolbarItem copyToolbarItem = ToolbarItem(
  id: 'editor.copy',
  group: 10,
  isActive: (editorState) {
    final selection = editorState.selection;
    return selection != null && !selection.isCollapsed;
  },
  builder: (context, editorState, highlightColor, iconColor, tooltipBuilder) {
    final selection = editorState.selection;
    final canCopy = selection != null && !selection.isCollapsed;
    final child = SVGIconItemWidget(
      iconBuilder: (_) => Icon(Icons.content_copy, size: 18, color: canCopy ? iconColor : iconColor?.withAlpha(100)),
      isHighlight: false,
      highlightColor: highlightColor,
      iconColor: iconColor,
      onPressed: canCopy ? () => copyCommand.handler(editorState) : null,
    );
    if (tooltipBuilder != null) {
      return tooltipBuilder(context, 'editor.copy', l10n.copy, child);
    }
    return child;
  },
);

final ToolbarItem cutToolbarItem = ToolbarItem(
  id: 'editor.cut',
  group: 10,
  isActive: (editorState) {
    final selection = editorState.selection;
    return selection != null && !selection.isCollapsed;
  },
  builder: (context, editorState, highlightColor, iconColor, tooltipBuilder) {
    final selection = editorState.selection;
    final canCut = selection != null && !selection.isCollapsed;
    final child = SVGIconItemWidget(
      iconBuilder: (_) => Icon(Icons.content_cut, size: 18, color: canCut ? iconColor : iconColor?.withAlpha(100)),
      isHighlight: false,
      highlightColor: highlightColor,
      iconColor: iconColor,
      onPressed: canCut ? () => cutCommand.handler(editorState) : null,
    );
    if (tooltipBuilder != null) {
      return tooltipBuilder(context, 'editor.cut', l10n.cut, child);
    }
    return child;
  },
);

final ToolbarItem pasteToolbarItem = ToolbarItem(
  id: 'editor.paste',
  group: 10,
  isActive: (editorState) => editorState.selection != null,
  builder: (context, editorState, highlightColor, iconColor, tooltipBuilder) {
    final canPaste = editorState.selection != null;
    final child = SVGIconItemWidget(
      iconBuilder: (_) => Icon(Icons.content_paste, size: 18, color: canPaste ? iconColor : iconColor?.withAlpha(100)),
      isHighlight: false,
      highlightColor: highlightColor,
      iconColor: iconColor,
      onPressed: canPaste ? () => pasteCommand.handler(editorState) : null,
    );
    if (tooltipBuilder != null) {
      return tooltipBuilder(context, 'editor.paste', l10n.paste, child);
    }
    return child;
  },
);

final ToolbarItem undoToolbarItem = ToolbarItem(
  id: 'editor.undo',
  group: 10,
  isActive: (_) => true,
  builder: (context, editorState, highlightColor, iconColor, tooltipBuilder) {
    final canUndo = editorState.undoManager.undoStack.isNonEmpty;
    final child = SVGIconItemWidget(
      iconBuilder: (_) => Icon(Icons.undo, size: 18, color: canUndo ? iconColor : iconColor?.withAlpha(100)),
      isHighlight: false,
      highlightColor: highlightColor,
      iconColor: iconColor,
      onPressed: canUndo ? () => editorState.undoManager.undo() : null,
    );
    if (tooltipBuilder != null) {
      return tooltipBuilder(context, 'editor.undo', l10n.undo, child);
    }
    return child;
  },
);

final ToolbarItem redoToolbarItem = ToolbarItem(
  id: 'editor.redo',
  group: 10,
  isActive: (_) => true,
  builder: (context, editorState, highlightColor, iconColor, tooltipBuilder) {
    final canRedo = editorState.undoManager.redoStack.isNonEmpty;
    final child = SVGIconItemWidget(
      iconBuilder: (_) => Icon(Icons.redo, size: 18, color: canRedo ? iconColor : iconColor?.withAlpha(100)),
      isHighlight: false,
      highlightColor: highlightColor,
      iconColor: iconColor,
      onPressed: canRedo ? () => editorState.undoManager.redo() : null,
    );
    if (tooltipBuilder != null) {
      return tooltipBuilder(context, 'editor.redo', l10n.redo, child);
    }
    return child;
  },
);
