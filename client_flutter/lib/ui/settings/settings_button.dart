import 'package:flutter/material.dart';
import 'package:note123/ui/settings/settings_page.dart';
import 'package:note123/config/language_manager.dart';

class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.settings_outlined),
      tooltip: l10n.settings,
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsPage()));
      },
    );
  }
}
