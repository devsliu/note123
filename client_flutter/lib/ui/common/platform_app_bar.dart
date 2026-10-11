import 'package:flutter/material.dart';
import 'package:note123/config/app_config.dart';
import 'package:note123/ui/desktop/desktop_title_bar.dart';

import '../../utils/utils.dart';

PreferredSizeWidget createPlatformAppBar({
  String? title,
  Widget? titleWidget,
  List<Widget>? actions,
  Widget? leading,
  bool automaticallyImplyLeading = true,
  Color? backgroundColor,
  Color? foregroundColor,
  bool showWindowButtons = true,
}) {
  // titleWidget takes precedence over title; one of them should be provided
  final Widget effectiveTitle = titleWidget ?? Text(title ?? '');
  // Mobile: return standard AppBar
  if (!Utils.isDesktop()) {
    return AppBar(
      title: effectiveTitle,
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
              else
                ?leading,

              // Draggable area (includes title)
              Expanded(
                child: WindowMoveBar(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: AppConfig.pageHorizontalPadding),
                      child:
                          titleWidget ??
                          Text(
                            title ?? '',
                            style:
                                appBarTheme.titleTextStyle?.copyWith(color: effectiveForegroundColor) ??
                                theme.textTheme.titleMedium?.copyWith(color: effectiveForegroundColor),
                          ),
                    ),
                  ),
                ),
              ),

              // Right-side actions
              ...?actions,

              // Window control buttons (minimize / maximize / close)
              if (showWindowButtons) const WindowManagerButtons(),
            ],
          ),
        );
      },
    ),
  );
}
