import 'package:flutter/material.dart';
import 'package:notee/config/app_config.dart';
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
  final layoutMode = AppConfig.getLayoutMode();
  final useDesktopBar = isDesktop && layoutMode == LayoutMode.desktop;

  Widget effectiveTitle = titleWidget ?? Text(title ?? '');
  if (isDesktop) {
    effectiveTitle = WindowMoveBar(child: effectiveTitle);
  }

  final effectiveLeading =
      leading ?? (onBack != null ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack) : null);
  final resolvedSpacing = titleSpacing ?? AppConfig.pageHorizontalPadding;

  return AppBar(
    title: effectiveTitle,
    leading: effectiveLeading,
    automaticallyImplyLeading: automaticallyImplyLeading && effectiveLeading == null,
    actions: [...?actions, if (isDesktop && showWindowButtons) const WindowManagerButtons()],
    backgroundColor: backgroundColor,
    foregroundColor: foregroundColor,
    titleSpacing: resolvedSpacing,
    toolbarHeight: AppConfig.getAppBarHeight(),
    elevation: useDesktopBar ? 0 : null,
    scrolledUnderElevation: useDesktopBar ? 0 : null,
    leadingWidth: useDesktopBar && effectiveLeading != null ? 48 : null,
    actionsPadding: useDesktopBar && showWindowButtons ? EdgeInsets.zero : null,
    flexibleSpace: useDesktopBar ? const WindowMoveBar() : null,
  );
}
