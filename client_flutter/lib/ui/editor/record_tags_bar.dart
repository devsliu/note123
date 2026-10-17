import 'dart:async';

import 'package:flutter/material.dart';
import 'package:note123/config/language_manager.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/filesync/tag_tree.dart';
import 'package:note123/ui/editor/record_tags_editor.dart';

/// Show the tag editor dialog with a title bar (same pattern as [showReminderDialog]).
void showTagDialog(BuildContext context, String uuid) {
  final record = Repository.get().recordTree.findRecord(uuid);
  showDialog(
    context: context,
    builder: (_) => TagEditor(uuid: uuid, subtitle: record?.local.path),
  );
}

/// Compact one-line tag summary bar — same style as [ReminderBar].
/// Shows a `#` icon followed by comma-separated tag names.
/// Tapping opens the tag editor dialog.
class TagBar extends StatefulWidget {
  final String uuid;
  const TagBar({super.key, required this.uuid});

  @override
  State<TagBar> createState() => _TagBarState();
}

class _TagBarState extends State<TagBar> {
  StreamSubscription<TagTreeEvent>? _tagSub;

  @override
  void initState() {
    super.initState();
    _tagSub = Repository.get().tagTree.onEvent.listen((event) {
      if (event.type == TagTreeEvent.typeRebuild || event.uuid == widget.uuid) {
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tagSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final record = Repository.get().recordTree.findRecord(widget.uuid);
    final theme = Theme.of(context);
    final tags = record?.tags ?? const <String>[];
    final hasTags = tags.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => showTagDialog(context, widget.uuid),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: Row(
            children: [
              Icon(Icons.tag_outlined, size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  hasTags ? tags.join(' · ') : l10n.addTag,
                  style: TextStyle(
                    fontSize: 14,
                    color: hasTags ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withAlpha(120),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
