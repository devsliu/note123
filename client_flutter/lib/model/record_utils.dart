import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:intl/intl.dart';
import 'package:note123/config/language_manager.dart';

class RecordUtils {
  static String generateRecordName() {
    final dt = DateTime.now();
    final time = DateFormat('yyyy-MM-dd HH:mm').format(dt);
    return "${l10n.record} $time";
  }

  static String getTitleFromDelta(Document doc) {
    // Traverse child nodes (Blocks) of the document root
    for (final node in doc.root.children) {
      // Check whether the node contains text content
      // In AppFlowy, text node data is typically stored in delta
      final delta = node.delta;
      if (delta != null && delta.isNotEmpty) {
        // Convert delta to plain text
        final text = delta.toPlainText().trim();

        if (text.isNotEmpty) {
          // Use the first line as the title
          final title = text.split('\n').first.trim();
          if (title.isNotEmpty) {
            return title;
          }
        }
      }
    }
    return "";
  }

  static String? getTitleFromText(String text, String? defaultValue) {
    if (text.isNotEmpty) {
      // Only take the first line; if it contains newlines, truncate to before the first newline
      String title = text.split('\n').first.trim();
      if (title.length > 20) {
        title = title.substring(0, 20);
      }
      if (title.isNotEmpty) {
        return title;
      }
    }
    return defaultValue;
  }
}
