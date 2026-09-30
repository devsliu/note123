import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:note123/config/language_manager.dart';

const String disableFloatingToolbarKey = 'disableFloatingToolbar';

class MobileFloatingToolbarBuilder {
  static Widget build({
    required BuildContext context,
    required EditorState editorState,
    required EditorScrollController editorScrollController,
    required Widget editor,
  }) {
    return MobileFloatingToolbar(
      editorState: editorState,
      editorScrollController: editorScrollController,
      floatingToolbarHeight: 48,
      toolbarBuilder: (context, anchor, closeToolbar) {
        return _buildToolbar(context, anchor, closeToolbar, editorState);
      },
      child: editor,
    );
  }

  static Widget _buildToolbar(BuildContext context, Offset anchor, VoidCallback closeToolbar, EditorState editorState) {
    final theme = Theme.of(context);
    const toolbarHeight = 48.0;
    const toolbarWidth = 220.0;

    final rects = editorState.selectionRects();
    if (rects.isEmpty) {
      return const SizedBox.shrink();
    }

    final renderBox = editorState.renderBox;

    double minLeft, maxRight, minTop, maxBottom;

    if (renderBox != null) {
      final offset = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      minLeft = offset.dx + 4.0;
      maxRight = offset.dx + size.width - toolbarWidth - 4.0;
      minTop = offset.dy + 4.0;
      maxBottom = offset.dy + size.height - toolbarHeight - 4.0;
    } else {
      final screenSize = MediaQuery.of(context).size;
      final padding = MediaQuery.of(context).padding;
      minLeft = padding.left + 4.0;
      maxRight = screenSize.width - padding.right - toolbarWidth - 4.0;
      minTop = padding.top + 4.0;
      maxBottom = screenSize.height - padding.bottom - toolbarHeight - 4.0;
    }

    double top;
    if (anchor.dy < toolbarHeight) {
      top = anchor.dy + 4;
    } else {
      top = anchor.dy - toolbarHeight - 4;
    }
    top = top.clamp(minTop, maxBottom);

    double left = (anchor.dx - toolbarWidth / 2).clamp(minLeft, maxRight);

    return Positioned(
      left: left,
      top: top,
      child: _buildToolbarContainer(theme, closeToolbar, editorState, toolbarHeight),
    );
  }

  static Widget _buildToolbarContainer(
    ThemeData theme,
    VoidCallback closeToolbar,
    EditorState editorState,
    double toolbarHeight,
  ) {
    return Container(
      height: toolbarHeight,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: DefaultTextStyle(
        style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 15),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildButton(
              label: l10n.copy,
              onTap: () {
                copyCommand.handler(editorState);
                _disableToolbarAndClose(editorState, closeToolbar);
              },
            ),
            _buildDivider(theme),
            _buildButton(
              label: l10n.cut,
              onTap: () {
                cutCommand.handler(editorState);
                _disableToolbarAndClose(editorState, closeToolbar);
              },
            ),
            _buildDivider(theme),
            _buildButton(
              label: l10n.paste,
              onTap: () {
                pasteCommand.handler(editorState);
                _disableToolbarAndClose(editorState, closeToolbar);
              },
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildDivider(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: VerticalDivider(width: 1, thickness: 1, color: theme.colorScheme.outline.withAlpha(50)),
    );
  }

  static void _disableToolbarAndClose(EditorState editorState, VoidCallback closeToolbar) {
    editorState.selectionExtraInfo?[disableFloatingToolbarKey] = true;
    closeToolbar();
    Future.delayed(const Duration(milliseconds: 100), () {
      editorState.selectionExtraInfo?.remove(disableFloatingToolbarKey);
    });
  }

  static Widget _buildButton({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), child: Text(label)),
    );
  }
}
