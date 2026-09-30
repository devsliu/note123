import 'package:flutter/material.dart';
import 'package:note123/ui/desktop/window_state.dart';
import 'package:window_manager/window_manager.dart';

import '../../config/language_manager.dart';
import '../../utils/app_logger.dart';

final double windowTitleBarHeight = 40;
final double windowButtonHeight = 40;
final double windowButtonWidth = 40;

class WindowMoveBar extends StatelessWidget {
  final Color color;
  final Widget? child;
  final double? titleBarHeight;
  const WindowMoveBar({super.key, this.color = Colors.transparent, this.child, this.titleBarHeight});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: titleBarHeight ?? windowTitleBarHeight,
      color: color,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (details) {
          windowManager.startDragging();
        },
        onDoubleTap: () async {
          bool isMax = await windowManager.isMaximized();
          isWindowAnimatingNotifier.value = true;
          await WidgetsBinding.instance.endOfFrame;
          if (isMax) {
            await windowManager.unmaximize();
          } else {
            await windowManager.maximize();
          }
        },
        child: child,
      ),
    );
  }
}

class _WindowButtonColors {
  final Color iconNormal;
  final Color mouseOver;
  final Color mouseDown;
  final Color iconMouseOver;
  final Color iconMouseDown;

  const _WindowButtonColors({
    required this.iconNormal,
    required this.mouseOver,
    required this.mouseDown,
    required this.iconMouseOver,
    required this.iconMouseDown,
  });
}

class _WindowControlButton extends StatefulWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final _WindowButtonColors colors;
  final String tooltip;

  const _WindowControlButton({
    required this.onPressed,
    required this.icon,
    required this.colors,
    required this.tooltip,
  });

  @override
  State<_WindowControlButton> createState() => _WindowControlButtonState();
}

class _WindowControlButtonState extends State<_WindowControlButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    Color bgColor = Colors.transparent;
    Color iconColor = widget.colors.iconNormal;
    if (_pressed) {
      bgColor = widget.colors.mouseDown;
      iconColor = widget.colors.iconMouseDown;
    } else if (_hover) {
      bgColor = widget.colors.mouseOver;
      iconColor = widget.colors.iconMouseOver;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTap: widget.onPressed,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: Container(
          width: windowButtonWidth,
          height: windowButtonHeight,
          color: bgColor,
          child: Tooltip(
            message: widget.tooltip,
            child: Icon(widget.icon, color: iconColor, size: 20),
          ),
        ),
      ),
    );
  }
}

class _MyWindowListener extends WindowListener {
  final VoidCallback onEvent;
  _MyWindowListener(this.onEvent);

  @override
  void onWindowMaximize() => onEvent();

  @override
  void onWindowUnmaximize() => onEvent();
}

class WindowManagerButtons extends StatefulWidget {
  const WindowManagerButtons({super.key});

  @override
  State<WindowManagerButtons> createState() => _WindowManagerButtonsState();
}

class _WindowManagerButtonsState extends State<WindowManagerButtons> {
  bool isMaximized = false;
  late final WindowListener _windowListener = _MyWindowListener(_onWindowEvent);

  @override
  void initState() {
    super.initState();
    windowManager.isMaximized().then((v) {
      setState(() {
        isMaximized = v;
      });
    });
    windowManager.addListener(_windowListener);
  }

  @override
  void dispose() {
    windowManager.removeListener(_windowListener);
    super.dispose();
  }

  void _onWindowEvent() async {
    bool max = await windowManager.isMaximized();
    if (max != isMaximized) {
      setState(() {
        isMaximized = max;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appBarIconColor = theme.appBarTheme.iconTheme?.color ?? theme.iconTheme.color ?? const Color(0xFF666666);
    final buttonColors = _WindowButtonColors(
      iconNormal: appBarIconColor,
      mouseOver: const Color(0x33AAAAAA), // 20% transparent
      mouseDown: const Color(0x55888888), // 33% transparent
      iconMouseOver: appBarIconColor,
      iconMouseDown: appBarIconColor,
    );

    final closeButtonColors = _WindowButtonColors(
      iconNormal: appBarIconColor,
      mouseOver: const Color(0x99D32F2F), // 20% transparent
      mouseDown: const Color(0xaaB71C1C), // 33% transparent
      iconMouseOver: Colors.white,
      iconMouseDown: Colors.white,
    );

    return Row(
      children: [
        _WindowControlButton(
          icon: Icons.remove,
          colors: buttonColors,
          tooltip: l10n.minimize,
          onPressed: () => windowManager.minimize(),
        ),
        _WindowControlButton(
          icon: isMaximized ? Icons.fullscreen_exit : Icons.fullscreen,
          colors: buttonColors,
          tooltip: isMaximized ? l10n.restore : l10n.maximize,
          onPressed: () async {
            isWindowAnimatingNotifier.value = true;
            AppLogger.i("WindowManagerButtons: onPressed maximize/restore");
            await WidgetsBinding.instance.endOfFrame;
            if (isMaximized) {
              await windowManager.unmaximize();
            } else {
              await windowManager.maximize();
            }
            AppLogger.i("WindowManagerButtons: onPressed maximize/restore end");
          },
        ),
        _WindowControlButton(
          icon: Icons.close,
          colors: closeButtonColors,
          tooltip: l10n.windowClose,
          onPressed: () => windowManager.close(),
        ),
      ],
    );
  }
}
