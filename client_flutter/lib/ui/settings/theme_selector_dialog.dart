import 'dart:math';

import 'package:flutter/material.dart';
import 'package:note123/config/theme.dart';
import 'package:note123/config/language_manager.dart';

class ThemeSelectorDialog extends StatefulWidget {
  const ThemeSelectorDialog({super.key});

  @override
  State<ThemeSelectorDialog> createState() => _ThemeSelectorDialogState();
}

class _ThemeSelectorDialogState extends State<ThemeSelectorDialog> {
  AppTheme? _selectedTheme;

  @override
  void initState() {
    super.initState();
    _selectedTheme = gAppTheme;
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    // Define spacing variables
    const double crossAxisSpacing = 8.0; // Column spacing
    const double mainAxisSpacing = 8.0; // Row spacing
    const double childAspectRatio = 1.2; // Grid item aspect ratio

    // Calculate dialog dimensions, set min and max limits
    final dialogWidth = min(screenWidth * 0.85, screenHeight * 0.85);

    // Adjust themes per row based on screen width
    final crossAxisCount = dialogWidth > 600 ? 4 : (dialogWidth > 450 ? 3 : 2);

    // Calculate number of rows needed based on theme count and columns
    final rowCount = (appThemes.length / crossAxisCount).ceil();

    // Calculate ideal grid height
    final gridItemWidth = (dialogWidth - (crossAxisCount - 1) * crossAxisSpacing) / crossAxisCount;
    final gridItemHeight = gridItemWidth / childAspectRatio;
    final idealGridHeight = rowCount * gridItemHeight + (rowCount - 1) * mainAxisSpacing;

    // Limit max height, prevent dialog from being too tall
    final dialogHeight = min(idealGridHeight, screenHeight * 0.9);

    return AlertDialog(
      insetPadding: EdgeInsets.zero,
      titlePadding: const EdgeInsets.fromLTRB(16, 8, 0, 0), // Reduce top title padding
      title: Row(
        children: [
          Expanded(child: Text(l10n.selectTheme)),
          IconButton(
            icon: Icon(Icons.close, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: l10n.close,
          ),
        ],
      ),
      contentPadding: const EdgeInsets.all(16),
      content: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount, // Adjust columns based on screen width
            crossAxisSpacing: crossAxisSpacing,
            mainAxisSpacing: mainAxisSpacing,
            childAspectRatio: childAspectRatio, // Adjust grid aspect ratio
          ),
          itemCount: appThemes.length,
          itemBuilder: (context, index) {
            final theme = appThemes[index];
            final isSelected = _selectedTheme?.key == theme.key;

            return _buildThemePreview(theme, isSelected);
          },
        ),
      ),
    );
  }

  Widget _buildThemePreview(AppTheme theme, bool isSelected) {
    final themeData = theme.data;
    final colorScheme = themeData.colorScheme;
    final appBarTheme = themeData.appBarTheme;
    final circular = 2.0;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTheme = theme;
        });
        // Switch theme directly
        switchAppTheme(theme);
        Navigator.of(context).pop(); // Close dialog after selection
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: isSelected ? colorScheme.primary : Colors.grey.shade300, width: isSelected ? 3 : 1),
          borderRadius: BorderRadius.circular(circular),
        ),
        child: Column(
          children: [
            // Title bar preview
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: appBarTheme.backgroundColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(circular),
                  topRight: Radius.circular(circular),
                ),
              ),
              child: Center(
                child: Text(
                  theme.getName(l10n),
                  style: TextStyle(color: appBarTheme.foregroundColor, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
            // Content area preview
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(circular),
                    bottomRight: Radius.circular(circular),
                  ),
                ),
                child: Center(
                  child: Text("text", style: TextStyle(color: colorScheme.onSurface, fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Convenience method to show theme selector dialog
Future<void> showThemeSelector(BuildContext context) async {
  await showDialog(context: context, builder: (context) => const ThemeSelectorDialog());
}
