import 'package:flutter/material.dart';
import 'package:note123/config/language_manager.dart';

Future<String?> showInputDialog(BuildContext context, String title, String text, bool pass) async {
  final controller = TextEditingController(text: text);
  var result = await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: pass,
          onSubmitted: (String value) {
            return Navigator.pop(context, controller.text.trim());
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: Text(l10n.confirm)),
        ],
      );
    },
  );
  controller.dispose();
  return result;
}
