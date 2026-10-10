import 'package:note123/config/prefs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:note123/utils/reboot.dart';

import '../l10n/app_localizations.dart';

// primary: primary color (e.g., buttons, AppBar background)
// secondary: secondary color (emphasis, floating buttons, etc.)
// background: main background color
// surface: surface color (background for cards, dialogs, etc.)
// primaryContainer: primary container (variant of primary, used for large-area backgrounds)
// secondaryContainer: secondary container
// onPrimary: content color on primary (e.g., text/icon color on primary buttons)
// onSecondary: content color on secondary
// onBackground: content color on background
// onSurface: content color on surface
// Generally, the recommended main background color for pages is surface, because surface
// represents the background of "surfaces" like cards and pages, suitable for most content areas.
// primaryContainer is usually used for containers that need a large area rendered with the primary
// color (e.g., emphasis blocks, button backgrounds), not for regular page backgrounds.
// Summary:
//   Page background color: use surface
//   Emphasis blocks / primary color large containers: use primaryContainer
// In Flutter's ColorScheme:
//
// primary represents the primary color, usually used as the background for components like
// buttons and AppBars.
// onPrimary represents the content color on the primary (primary), e.g., the text or icon
// color on primary buttons.
// Example explanation:
//
// If the button background uses primary, the button text color will be onPrimary.
// Your theme file comments also explain this.
// onPrimary: content color on primary (e.g., text/icon color on primary buttons)
//
// TextButton uses primary as text color by default; only "primary buttons" like ElevatedButton
// use onPrimary as text color.
// Theme color scheme list

class AppTheme {
  final String key;
  final String Function(AppLocalizations) nameBuilder;
  final ThemeData data;

  AppTheme({required this.key, required this.nameBuilder, required this.data});

  String getName(AppLocalizations l10n) => nameBuilder(l10n);
}

final appThemes = [
  // Light theme
  AppTheme(
    key: 'light',
    nameBuilder: (l10n) => l10n.themeLight,
    data: ThemeData(
      scaffoldBackgroundColor: Color(0xFFFFFFFF),
      colorScheme: ColorScheme.light(
        primary: Color(0xFF8E24AA),
        secondary: Color(0xFFE7E7E7),
        surface: Color(0xFFFFFFFF),
        surfaceContainer: Color(0xFFE7E7E7),
        surfaceContainerHigh: Color(0xFFE7E7E7),
        surfaceContainerLowest: Color(0xFFF3F3F3),
        primaryContainer: Color(0xFFE7E7E7),
        secondaryContainer: Color(0xFFc7c7c7),
        onPrimary: Color(0xFFFFFFFF),
        onSecondary: Color(0xFF333333),
        onSurface: Color(0xFF333333),
        onSurfaceVariant: Color(0xFF999999),
        outline: Color(0xFFD1D1D1),
      ),
      iconTheme: IconThemeData(color: Color(0xFF222222)), // Use dark icons
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFFFFFFFF), // primaryContainer
        foregroundColor: Color(0xFF222222),
        iconTheme: IconThemeData(color: Color(0xFF666666)),
        actionsIconTheme: IconThemeData(color: Color(0xFF333333)), // Action buttons slightly darker
      ),
      // Ensure all IconButtons use the correct color
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: Color(0xFF333333), // Changed to a darker color for visibility on white background
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: Color(0xFF999999)), // Use gray consistently
        labelStyle: TextStyle(color: Color(0xFF666666)),
        floatingLabelStyle: TextStyle(color: Color(0xFF8E24AA)),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF333333)), // Changed to a darker color
        bodyMedium: TextStyle(color: Color(0xFF333333)), // Changed to a darker color
      ),
      listTileTheme: ListTileThemeData(textColor: Color(0xFF333333), iconColor: Color(0xFF222222)),
      dialogTheme: DialogThemeData(backgroundColor: Colors.white),
      popupMenuTheme: PopupMenuThemeData(
        color: Color(0xFFFFFFFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(color: Color(0xFFD1D1D1).withAlpha(250), width: 1),
        ),
      ),
    ),
  ),
  // Dark theme
  AppTheme(
    key: 'dark',
    nameBuilder: (l10n) => l10n.themeDark,
    data: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Color(0xFF1E1E1E),
      colorScheme: ColorScheme.dark(
        primary: Color(0xFFbb4081),
        secondary: Color(0xFF2C2C32),
        surface: Color(0xFF1E1E1E),
        surfaceContainer: Color(0xFF232323),
        surfaceContainerHigh: Color(0xFF2C2C32),
        surfaceContainerLowest: Color(0xFF232323),
        primaryContainer: Color(0xFF2C2C32),
        secondaryContainer: Color(0xFF333333),
        onPrimary: Color(0xFFD4D4D4),
        onSecondary: Color(0xFFD4D4D4),
        onSurface: Color(0xFFD4D4D4),
        onSurfaceVariant: Color(0xFF666666),
        outline: Color(0xFF333337),
      ),
      iconTheme: IconThemeData(color: Color(0xFFD4D4D4)),
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E), // primaryContainer
        foregroundColor: Color(0xFFD4D4D4),
        iconTheme: IconThemeData(color: Color(0xFFB0B5BD)),
        titleTextStyle: TextStyle(fontSize: 18, color: Color(0xFFD4D4D4)),
      ),
      // Ensure all IconButtons use the correct color
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: Color(0xFFB0B5BD), // Restored to a color suitable for dark backgrounds
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: Color(0xFF666666)), // Use dark gray consistently
        labelStyle: TextStyle(color: Color(0xFF999999)),
        floatingLabelStyle: TextStyle(color: Color(0xFFFF4081)),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: Color(0xFFD4D4D4)), // Input text color set to light
        bodyMedium: TextStyle(color: Color(0xFFD4D4D4)),
      ),
      listTileTheme: ListTileThemeData(textColor: Color(0xFFD4D4D4), iconColor: Color(0xFFD4D4D4)),
      dialogTheme: DialogThemeData(backgroundColor: Color(0xFF232323)),
      popupMenuTheme: PopupMenuThemeData(
        color: Color(0xFF232323),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(color: Color(0xFF333337).withAlpha(250), width: 1),
        ),
      ),
    ),
  ),
  // Neon (vibrant mix, editor cyan, everything else pink) - dark
  AppTheme(
    key: 'neon',
    nameBuilder: (l10n) => l10n.themeFlat,
    data: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Color(0xFF14142B),
      colorScheme: ColorScheme.dark(
        primary: Color(0xFF4FC3F7),
        secondary: Color(0xFFFF4081),
        surface: Color(0xFF1E1E3A),
        surfaceContainer: Color(0xFF262645),
        surfaceContainerHigh: Color(0xFF30304F),
        surfaceContainerLowest: Color(0xFF14142B),
        primaryContainer: Color(0xFF30304F),
        secondaryContainer: Color(0xFF3A1F2E),
        onPrimary: Color(0xFF14142B),
        onSecondary: Color(0xFFFFF0F5),
        onSurface: Color(0xFF4FC3F7),
        onSurfaceVariant: Color(0xFF5C5280),
        outline: Color(0xFF4A4270),
      ),
      iconTheme: IconThemeData(color: Color(0xFF4FC3F7)),
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFFFF4081),
        foregroundColor: Color(0xFFFFF3E0),
        iconTheme: IconThemeData(color: Color(0xFFFFF3E0)),
        titleTextStyle: TextStyle(fontSize: 18, color: Color(0xFFFFF3E0), letterSpacing: 1.2),
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: Color(0xFF4FC3F7))),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: Color(0xFF5C5280)),
        labelStyle: TextStyle(color: Color(0xFFFF4081)),
        floatingLabelStyle: TextStyle(color: Color(0xFFFF4081)),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: Color(0xFFFF4081)),
        bodyMedium: TextStyle(color: Color(0xFFFF4081)),
      ),
      listTileTheme: ListTileThemeData(textColor: Color(0xFFFF4081), iconColor: Color(0xFFFF4081)),
      dialogTheme: DialogThemeData(
        backgroundColor: Color(0xFF262645),
        titleTextStyle: TextStyle(color: Color(0xFFFF4081)),
        contentTextStyle: TextStyle(color: Color(0xFFFF4081)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Color(0xFF262645),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(color: Color(0xFFFF4081).withAlpha(180), width: 1),
        ),
      ),
    ),
  ),
  // Neon flat (same as neon, AppBar matches page background) - dark
  AppTheme(
    key: 'neonFlat',
    nameBuilder: (l10n) => l10n.themeFlat,
    data: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Color(0xFF14142B),
      colorScheme: ColorScheme.dark(
        primary: Color(0xFF4FC3F7),
        secondary: Color(0xFFFF4081),
        surface: Color(0xFF1E1E3A),
        surfaceContainer: Color(0xFF262645),
        surfaceContainerHigh: Color(0xFF30304F),
        surfaceContainerLowest: Color(0xFF14142B),
        primaryContainer: Color(0xFF30304F),
        secondaryContainer: Color(0xFF3A1F2E),
        onPrimary: Color(0xFF14142B),
        onSecondary: Color(0xFFFFF0F5),
        onSurface: Color(0xFF4FC3F7),
        onSurfaceVariant: Color(0xFF5C5280),
        outline: Color(0xFF4A4270),
      ),
      iconTheme: IconThemeData(color: Color(0xFF4FC3F7)),
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFF14142B),
        foregroundColor: Color(0xFFFFF3E0),
        iconTheme: IconThemeData(color: Color(0xFFFFF3E0)),
        titleTextStyle: TextStyle(fontSize: 18, color: Color(0xFFFFF3E0), letterSpacing: 1.2),
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: Color(0xFF4FC3F7))),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: Color(0xFF5C5280)),
        labelStyle: TextStyle(color: Color(0xFFFF4081)),
        floatingLabelStyle: TextStyle(color: Color(0xFFFF4081)),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: Color(0xFFFF4081)),
        bodyMedium: TextStyle(color: Color(0xFFFF4081)),
      ),
      listTileTheme: ListTileThemeData(textColor: Color(0xFFFF4081), iconColor: Color(0xFFFF4081)),
      dialogTheme: DialogThemeData(
        backgroundColor: Color(0xFF262645),
        titleTextStyle: TextStyle(color: Color(0xFFFF4081)),
        contentTextStyle: TextStyle(color: Color(0xFFFF4081)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Color(0xFF262645),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(color: Color(0xFFFF4081).withAlpha(180), width: 1),
        ),
      ),
    ),
  ),
  // Purple (elegant) - light
  AppTheme(
    key: 'deepPurple',
    nameBuilder: (l10n) => l10n.themePurple,
    data: ThemeData(
      scaffoldBackgroundColor: Color(0xFFF8F4FF),
      colorScheme: ColorScheme.light(
        primary: Color(0xFF6A1B9A),
        secondary: Color(0xFFE1BEE7),
        surface: Colors.white,
        surfaceContainer: Color(0xFFF3E5F5),
        surfaceContainerHigh: Color(0xFFE1BEE7),
        surfaceContainerLowest: Color(0xFFF8F4FF),
        primaryContainer: Color(0xFF6A1B9A),
        secondaryContainer: Color(0xFFF3E5F5),
        onPrimary: Color(0xFFFFFFFF),
        onSecondary: Color(0xFF4A148C),
        onSurface: Color(0xFF4A148C),
        onSurfaceVariant: Color(0xFF999999),
        outline: Color(0xFFBA68C8),
      ),
      iconTheme: IconThemeData(color: Color(0xFF4A148C)),
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFF6A1B9A), // Use primary color
        foregroundColor: Color(0xFFFFFFFF), // White text on dark background
        iconTheme: IconThemeData(color: Color(0xFFFFFFFF)), // White icons
        actionsIconTheme: IconThemeData(color: Color(0xFFFFFFFF)), // Changed to white action buttons
        systemOverlayStyle: SystemUiOverlayStyle.light, // Status bar uses light style (white icons and text)
        titleTextStyle: TextStyle(fontSize: 18, color: Color(0xFFFFFFFF)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: Color(0xFF999999)), // Use gray consistently
        labelStyle: TextStyle(color: Color(0xFF8E24AA)),
        floatingLabelStyle: TextStyle(color: Color(0xFF6A1B9A)),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF4A148C)), // Input text color set to dark purple
        bodyMedium: TextStyle(color: Color(0xFF4A148C)),
      ),
      listTileTheme: ListTileThemeData(textColor: Color(0xFF4A148C), iconColor: Color(0xFF4A148C)),
      dialogTheme: DialogThemeData(backgroundColor: Colors.white),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(color: Color(0xFFBA68C8).withAlpha(250), width: 1),
        ),
      ),
      // Ensure sufficient contrast for icons in popups/dialogs
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: Color(0xFF4A148C), // Icon buttons use dark purple for visibility on white background
        ),
      ),
    ),
  ),
  // Red - dark
  AppTheme(
    key: 'darkRed',
    nameBuilder: (l10n) => l10n.themeDarkRed,
    data: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Color(0xFF1E1E1E),
      colorScheme: ColorScheme.dark(
        primary: Color(0xFFFF8A80),
        secondary: Color(0xFF2C2C32),
        surface: Color(0xFF1E1E1E),
        surfaceContainer: Color(0xFF232323),
        surfaceContainerHigh: Color(0xFF2C2C32),
        surfaceContainerLowest: Color(0xFF232323),
        primaryContainer: Color(0xFF2C2C32),
        secondaryContainer: Color(0xFF333333),
        onPrimary: Color(0xFF1E1E1E),
        onSecondary: Color(0xFFFF8A80),
        onSurface: Color(0xFFFF8A80),
        onSurfaceVariant: Color(0xFF666666),
        outline: Color(0xFF333337),
      ),
      iconTheme: IconThemeData(color: Color(0xFFFF8A80)),
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        foregroundColor: Color(0xFFFF8A80),
        iconTheme: IconThemeData(color: Color(0xFFFF8A80)),
        titleTextStyle: TextStyle(fontSize: 18, color: Color(0xFFFF8A80)),
      ),
      // Ensure all IconButtons use the correct color
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: Color(0xFFFF8A80))),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: Color(0xFF666666)),
        labelStyle: TextStyle(color: Color(0xFFFF8A80)),
        floatingLabelStyle: TextStyle(color: Color(0xFFFF8A80)),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: Color(0xFFFF8A80)), // Red text
        bodyMedium: TextStyle(color: Color(0xFFFF8A80)),
      ),
      listTileTheme: ListTileThemeData(textColor: Color(0xFFFF8A80), iconColor: Color(0xFFFF8A80)),
      dialogTheme: DialogThemeData(backgroundColor: Color(0xFF232323)),
      popupMenuTheme: PopupMenuThemeData(
        color: Color(0xFF232323),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(color: Color(0xFF333337).withAlpha(250), width: 1),
        ),
      ),
    ),
  ),
  // Warm clay (earthy) - dark
  AppTheme(
    key: 'earth',
    nameBuilder: (l10n) => l10n.themeEarth,
    data: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Color(0xFF1E1814),
      colorScheme: ColorScheme.dark(
        primary: Color(0xFFFFB74D),
        secondary: Color(0xFFFF7043),
        surface: Color(0xFF2A211C),
        surfaceContainer: Color(0xFF332822),
        surfaceContainerHigh: Color(0xFF40332A),
        surfaceContainerLowest: Color(0xFF1E1814),
        primaryContainer: Color(0xFF40332A),
        secondaryContainer: Color(0xFF4A2A20),
        onPrimary: Color(0xFF1E1814),
        onSecondary: Color(0xFFFFECE3),
        onSurface: Color(0xFFFFB74D),
        onSurfaceVariant: Color(0xFF7A6248),
        outline: Color(0xFF5A4838),
      ),
      iconTheme: IconThemeData(color: Color(0xFFFFB74D)),
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFF1E1814),
        foregroundColor: Color(0xFFFFB74D),
        iconTheme: IconThemeData(color: Color(0xFFFFB74D)),
        titleTextStyle: TextStyle(fontSize: 18, color: Color(0xFFFFB74D), letterSpacing: 1.2),
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: Color(0xFFFFB74D))),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: Color(0xFF7A6248)),
        labelStyle: TextStyle(color: Color(0xFFFFB74D)),
        floatingLabelStyle: TextStyle(color: Color(0xFFFF7043)),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: Color(0xFFFFB74D)),
        bodyMedium: TextStyle(color: Color(0xFFFFB74D)),
      ),
      listTileTheme: ListTileThemeData(textColor: Color(0xFFFFB74D), iconColor: Color(0xFFFFB74D)),
      dialogTheme: DialogThemeData(backgroundColor: Color(0xFF332822)),
      popupMenuTheme: PopupMenuThemeData(
        color: Color(0xFF332822),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(color: Color(0xFFFFB74D).withAlpha(180), width: 1),
        ),
      ),
    ),
  ),
  // Classic elegant (sepia) - light
  AppTheme(
    key: 'classic',
    nameBuilder: (l10n) => l10n.themeClassic,
    data: ThemeData(
      scaffoldBackgroundColor: Color(0xFFFFF8DC), // Warm ivory background
      colorScheme: ColorScheme.light(
        primary: Color(0xFF8B4513),
        secondary: Color(0xFFD2B48C),
        surface: Color(0xFFFFF8DC),
        surfaceContainer: Color(0xFFDEB887),
        surfaceContainerHigh: Color(0xFFD2B48C),
        surfaceContainerLowest: Color(0xFFFAF8F3),
        primaryContainer: Color(0xFFD2B48C),
        secondaryContainer: Color(0xFFF5DEB3),
        onPrimary: Color(0xFFFFFFFF),
        onSecondary: Color(0xFF654321),
        onSurface: Color(0xFF3C2414),
        onSurfaceVariant: Color(0xFF999999),
        outline: Color(0xFFaB6563),
      ),
      iconTheme: IconThemeData(
        color: Color(0xFF3C2414),
      ), // Changed to dark brown icons for visibility on light background
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFF8B4513), // Dark brown AppBar
        foregroundColor: Color(0xFFFFFFFF),
        iconTheme: IconThemeData(color: Color(0xFFFFFFFF)), // White icons
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(fontSize: 18, color: Color(0xFFFFFFFF)),
        actionsIconTheme: IconThemeData(
          color: Color(0xFFFFFFFF),
        ), // Changed to white action buttons to match title text
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: Color(0xFF999999)), // Use gray consistently
        labelStyle: TextStyle(color: Color(0xFF8B4513), fontWeight: FontWeight.w500),
        floatingLabelStyle: TextStyle(color: Color(0xFF8B4513), fontWeight: FontWeight.w600),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF3C2414)),
        bodyMedium: TextStyle(color: Color(0xFF3C2414)),
      ),
      listTileTheme: ListTileThemeData(textColor: Color(0xFF3C2414), iconColor: Color(0xFF3C2414)),
      dialogTheme: DialogThemeData(backgroundColor: Color(0xFFFFF8DC)),
      popupMenuTheme: PopupMenuThemeData(
        color: Color(0xFFFFF8DC),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(color: Color(0xFF8B4513).withAlpha(250), width: 1),
        ),
      ),
      // Ensure sufficient contrast for icons in popups/dialogs
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: Color(0xFF3C2414), // Dark brown icon buttons
        ),
      ),
    ),
  ),
];
// Persistence of theme key
const String _kThemeKey = 'theme_key';

/// Universally override "color-independent" common properties across all themes
/// — executed once each during load and switch.
/// Corresponding redundant lines can be removed from individual theme definitions,
/// keeping only color-related fields.
AppTheme _applyUniversalThemePatch(AppTheme theme) {
  final data = theme.data;
  final cs = data.colorScheme;
  // Unified derivations (brightness-agnostic) — source fields are required in each theme;
  // these derived fields are auto-filled here so they needn't appear in every theme.
  final patchedScheme = cs.copyWith(
    background: data.scaffoldBackgroundColor,
    onBackground: cs.onSurface,
    surfaceVariant: cs.surfaceContainer,
    onPrimaryContainer: cs.onPrimary,
    onSecondaryContainer: cs.onSecondary,
    tertiary: cs.primary,
    onTertiary: cs.onPrimary,
    tertiaryContainer: cs.primaryContainer,
    onTertiaryContainer: cs.onPrimary,
    outlineVariant: cs.outline,
  );
  return AppTheme(
    key: theme.key,
    nameBuilder: theme.nameBuilder,
    data: data.copyWith(
      colorScheme: patchedScheme,
      dialogTheme: data.dialogTheme.copyWith(
        insetPadding: EdgeInsets.zero,
        actionsPadding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(2.0))),
      ),
      popupMenuTheme: data.popupMenuTheme.copyWith(menuPadding: EdgeInsets.zero),
      appBarTheme: data.appBarTheme.copyWith(elevation: 0, scrolledUnderElevation: 0),
    ),
  );
}

AppTheme _getSavedTheme() {
  final keyStr = Prefs.instance.getString(_kThemeKey) ?? 'light';
  final theme = appThemes.firstWhere((t) => t.key == keyStr, orElse: () => appThemes[0]);
  return _applyUniversalThemePatch(theme);
}

AppTheme _currentTheme = _getSavedTheme();
AppTheme get gAppTheme => _currentTheme;
ThemeData get gAppThemeData => _currentTheme.data;

Future<void> switchAppTheme(AppTheme theme) async {
  if (_currentTheme != theme) {
    await Prefs.instance.setString(_kThemeKey, theme.key);
    _currentTheme = _applyUniversalThemePatch(theme);
    // Trigger app reboot
    Reboot.trigger();
  }
}

// Extension for AppTheme - similar to Kotlin extension functions
extension AppThemeExtensions on ThemeData {
  ButtonStyle get appBarIconButtonStyle {
    var color = appBarIconColor;
    return IconButton.styleFrom(
      foregroundColor: color,
      disabledForegroundColor: color.withAlpha(100), // Icon color when disabled
    );
  }

  Color get appBarIconColor =>
      appBarTheme.iconTheme?.color ?? iconTheme.color ?? appBarTheme.foregroundColor ?? colorScheme.onPrimary;

  Color get appBarBackgroundColor => appBarTheme.backgroundColor ?? colorScheme.primary;

  Color get appBarForegroundColor => appBarTheme.foregroundColor ?? colorScheme.onPrimary;

  /// Get IconButton theme data for the AppBar area
  IconButtonThemeData get appBarIconButtonTheme {
    return IconButtonThemeData(style: appBarIconButtonStyle);
  }

  IconButtonThemeData get appBarIconButtonThemeShrink {
    return IconButtonThemeData(
      // 1. Extract and copy the original style from the theme (since it supports copyWith)
      style:
          appBarIconButtonTheme.style?.copyWith(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Fix spacing issues on mobile
            padding: WidgetStateProperty.all(EdgeInsets.zero),
          ) ??
          // 2. If the original style is null, create a new one directly
          IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap, padding: EdgeInsets.zero),
    );
  }
}
