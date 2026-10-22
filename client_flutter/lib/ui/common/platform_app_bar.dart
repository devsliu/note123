import 'package:flutter/material.dart';
import 'package:notee/config/app_config.dart';
import 'package:notee/config/layout_mode.dart';
import 'package:notee/ui/desktop/desktop_title_bar.dart';

import '../../utils/utils.dart';

PreferredSizeWidget createPlatformAppBar({
  String? title,
  Widget? titleWidget,
  List<Widget>? actions,
  Widget? leading,
  VoidCallback? onBack,
  bool automaticallyImplyLeading = true,
  Color? backgroundColor,
  Color? foregroundColor,
  bool showWindowButtons = true,
  double? titleSpacing,
}) {
  final isDesktop = Utils.isDesktop();
  final layoutMode = LayoutMode.resolve();
  final useDesktopBar = isDesktop && layoutMode == LayoutMode.desktop;

  Widget? effectiveTitle = titleWidget;
  if (effectiveTitle == null && isDesktop) {
    // Text glyphs absorb hit tests and would block the flexibleSpace
    // drag detector below them, so the plain title joins the drag area.
    effectiveTitle = WindowMoveBar(child: Text(title ?? ''));
  }

  final effectiveLeading =
      leading ?? (onBack != null ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack) : null);
  final resolvedSpacing = titleSpacing ?? AppConfig.pageHorizontalPadding;

  return AppBar(
    title: effectiveTitle ?? Text(title ?? ''),
    leading: effectiveLeading,
    automaticallyImplyLeading: automaticallyImplyLeading && effectiveLeading == null,
    actions: [...?actions, if (isDesktop && showWindowButtons) const WindowManagerButtons()],
    backgroundColor: backgroundColor,
    foregroundColor: foregroundColor,
    titleSpacing: resolvedSpacing,
    toolbarHeight: useDesktopBar ? windowTitleBarHeight : null,
    elevation: useDesktopBar ? 0 : null,
    scrolledUnderElevation: useDesktopBar ? 0 : null,
    leadingWidth: useDesktopBar && effectiveLeading != null ? 48 : null,
    actionsPadding: useDesktopBar && showWindowButtons ? EdgeInsets.zero : null,
    flexibleSpace: useDesktopBar ? const WindowMoveBar() : null,
  );
}
