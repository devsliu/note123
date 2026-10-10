import 'package:flutter/material.dart';
import 'package:note123/utils/app_logger.dart';
import 'package:path_provider/path_provider.dart';

/// Global app configuration + directory initialization.
/// Project-specific constants/initialization, not generic.
class AppConfig {
  static const String appTitle = "Note123";

  /// Build info injected at compile time via --dart-define (empty when not provided)
  static const String buildGitCommit = String.fromEnvironment('GIT_COMMIT');
  static const String buildTime = String.fromEnvironment('BUILD_TIME');

  // UI padding
  static const double pageHorizontalPadding = 12;
  static const double pageVerticalPadding = 12;
  static const double itemVerticalPadding = 4;
  static const double actionsPadding = 0;

  /// ApplicationSupport root directory, set by init() at startup.
  static late final String appRootDir;

  static final itemPadding = EdgeInsets.only(
    left: pageHorizontalPadding,
    right: pageHorizontalPadding,
    top: itemVerticalPadding,
    bottom: itemVerticalPadding,
  );

  static final pagePadding = EdgeInsets.only(
    left: pageHorizontalPadding,
    right: pageHorizontalPadding,
    top: pageVerticalPadding,
    bottom: pageVerticalPadding,
  );

  /// Called at startup to initialize the application root directory.
  static Future<void> init() async {
    final dir = await getApplicationSupportDirectory();
    AppLogger.i("getApplicationSupportDirectory ${dir.path}");
    appRootDir = dir.path;
  }

  /// Generic list divider (UI-related, placed here).
  static Widget listViewDivider(BuildContext context) {
    return Divider(height: 1, color: Theme.of(context).colorScheme.outline.withAlpha(80));
  }

  /// Unified menu animation.
  static AnimationStyle get menuAnimationStyle =>
      const AnimationStyle(duration: Duration(milliseconds: 80), curve: Curves.fastLinearToSlowEaseIn);
}
