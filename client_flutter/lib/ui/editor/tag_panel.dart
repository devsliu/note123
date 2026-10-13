import 'package:flutter/material.dart';
import 'package:note123/filesync/record_tree.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/ui/editor/tag_editor.dart';

/// Shows the current record's tags as a row of small buttons at the bottom of
/// the editor. Only renders when the record has tags.
class TagPanel extends StatefulWidget {
  final String uuid;

  const TagPanel({super.key, required this.uuid});

  @override
  State<TagPanel> createState() => _TagPanelState();
}

class _TagPanelState extends State<TagPanel> {
  late final ValueNotifier<List<RecordEvent>> _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = Repository.get().recordTree.refreshNotifier;
    _notifier.addListener(_onEvents);
  }

  @override
  void dispose() {
    _notifier.removeListener(_onEvents);
    super.dispose();
  }

  void _onEvents() {
    final events = _notifier.value;
    if (events.isNotEmpty && !events.any((e) => e.value2 == widget.uuid)) {
      return;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final file = Repository.get().recordTree.findFile(widget.uuid);
    if (file == null) return const SizedBox.shrink();
    final tags = file.record.tags;
    if (tags.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final tag in tags)
            InkWell(
              onTap: () => _openTag(tag),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: theme.colorScheme.primary.withAlpha(60)),
                ),
                child: Text(tag, style: TextStyle(fontSize: 12, color: theme.colorScheme.primary)),
              ),
            ),
        ],
      ),
    );
  }

  void _openTag(String tag) {
    // TODO: navigate to the tags list filtered by this tag.
    // For now, just open the tag editor.
    showTagEditor(context, uuid: widget.uuid);
  }
}
