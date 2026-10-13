import 'package:flutter/material.dart';
import 'package:note123/config/app_config.dart';
import 'package:note123/config/theme.dart';
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
  double? titleSpacing,
}) {
  // titleWidget takes precedence over title; one of them should be provided
  // Mobile: return standard AppBar
  if (!Utils.isDesktop()) {
    titleSpacing ??= automaticallyImplyLeading || leading != null ? 0 : AppConfig.pageHorizontalPadding;
    return AppBar(
      title: titleWidget ?? Text(title ?? ''),
      titleSpacing: titleSpacing,
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
        if (leading == null && automaticallyImplyLeading) {
          leading = IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
            color: effectiveForegroundColor,
          );
        }

        titleSpacing ??= leading != null ? 0 : AppConfig.pageHorizontalPadding;
        return Container(
          height: windowTitleBarHeight,
          color: effectiveBackgroundColor,
          child: Row(
            children: [
              // Left leading/back button
              ?leading,

              // Draggable area (includes title)
              Expanded(
                child: WindowMoveBar(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(left: titleSpacing!),
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
              if (actions != null && actions.isNotEmpty)
                IconButtonTheme(
                  data: theme.appBarIconButtonTheme,
                  child: Row(mainAxisSize: MainAxisSize.min, children: actions),
                ),

              // Window control buttons (minimize / maximize / close)
              if (showWindowButtons) const WindowManagerButtons(),
            ],
          ),
        );
      },
    ),
  );
}
