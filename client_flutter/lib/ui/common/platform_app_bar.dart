import 'package:flutter/material.dart';
import 'package:note123/ui/desktop/desktop_title_bar.dart';

import '../../utils/utils.dart';

PreferredSizeWidget createPlatformAppBar({
  required String title,
  List<Widget>? actions,
  Widget? leading,
  bool automaticallyImplyLeading = true,
  Color? backgroundColor,
  Color? foregroundColor,
}) {
  // Mobile: return standard AppBar
  if (!Utils.isDesktop()) {
    return AppBar(
      title: Text(title),
      titleSpacing: 0,
      actions: actions,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
    );
  }

  // Desktop: return custom layout
  return PreferredSize(
    preferredSize: Size.fromHeight(windowTitleBarHeight),
    child: Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final appBarTheme = theme.appBarTheme;
        final effectiveBackgroundColor = backgroundColor ?? appBarTheme.backgroundColor ?? theme.primaryColor;
        final effectiveForegroundColor = foregroundColor ?? appBarTheme.foregroundColor ?? Colors.white;

        return Container(
          height: windowTitleBarHeight,
          color: effectiveBackgroundColor,
          child: Row(
            children: [
              // Left leading/back button
              if (automaticallyImplyLeading && Navigator.canPop(context))
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                  color: effectiveForegroundColor,
                )
              else if (leading != null)
                leading,

              // Draggable area (includes title)
              Expanded(
                child: WindowMoveBar(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(
                        title,
                        style:
                            appBarTheme.titleTextStyle?.copyWith(color: effectiveForegroundColor) ??
                            theme.textTheme.titleLarge?.copyWith(color: effectiveForegroundColor),
                      ),
                    ),
                  ),
                ),
              ),

              // Right-side actions
              if (actions != null) ...actions,

              // Window control buttons
              const WindowManagerButtons(),
            ],
          ),
        );
      },
    ),
  );
}
