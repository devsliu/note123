import 'package:flutter/material.dart';
import 'package:note123/utils/utils.dart';

/// A pill-shaped breadcrumb bar that renders [path] segments separated by
/// chevrons. The home icon and first chevron stay fixed on the left; the
/// trailing segments scroll horizontally when the path is deep. The most
/// recent segment (rightmost) is highlighted in the theme's primary color.
class BreadcrumbBar extends StatefulWidget {
  /// Absolute path (e.g. "/internal storage/downloads/projects").
  final String path;

  /// Called when the user taps a navigable breadcrumb segment.
  /// Receives the path that the tap navigates to.
  final ValueCallback<String> onNavigate;

  const BreadcrumbBar({super.key, required this.path, required this.onNavigate});

  @override
  State<BreadcrumbBar> createState() => _BreadcrumbBarState();
}

class _BreadcrumbBarState extends State<BreadcrumbBar> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant BreadcrumbBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final segments = widget.path.split('/').where((s) => s.isNotEmpty).toList();
    String segmentPath(int i) => '/${segments.sublist(0, i + 1).join('/')}';

    // Initial scroll to end so the current directory is visible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });

    return SizedBox(
      height: 32,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            // Fixed: home icon (never scrolls out of view).
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => widget.onNavigate('/'),
                child: Icon(Icons.home_outlined, size: 18, color: theme.colorScheme.onSurface),
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: theme.colorScheme.onSurfaceVariant),
            // Scrollable trailing segments.
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < segments.length; i++) ...[
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: i < segments.length - 1 ? () => widget.onNavigate(segmentPath(i)) : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: i < segments.length - 1
                                ? Text(segments[i])
                                : Text(
                                    segments[i],
                                    style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                                  ),
                          ),
                        ),
                      ),
                      if (i < segments.length - 1)
                        Icon(Icons.chevron_right, size: 16, color: theme.colorScheme.onSurfaceVariant),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
