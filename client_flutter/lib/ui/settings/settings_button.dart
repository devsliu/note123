import 'package:flutter/material.dart';
import 'package:notee/ui/base_app.dart';
import 'package:notee/config/language_manager.dart';

class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.settings_outlined),
      tooltip: l10n.settings,
      onPressed: () {
        AppNavigator.of(context).navigate(AppNavigator.uriSettings);
      },
    );
  }
}
