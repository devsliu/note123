import 'package:flutter/material.dart';
import 'package:note123/config/language_manager.dart';
import 'package:note123/filesync/record_ext.dart';
import 'package:note123/filesync/repository.dart';

/// Dialog for editing the tags of a single record. Tags are stored in the
/// pipe-separated format `|a|b|`.
class TagEditor extends StatefulWidget {
  final String uuid;

  const TagEditor({super.key, required this.uuid});

  @override
  State<TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends State<TagEditor> {
  final TextEditingController _controller = TextEditingController();
  List<String> _tags = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadTags() async {
    final record = await Repository.get().db?.getRecord(widget.uuid);
    if (record == null || !mounted) return;
    setState(() {
      _tags = List<String>.from(record.tags);
      _loaded = true;
    });
  }

  Future<void> _save() async {
    final serialized = TagFormat.serialize(_tags);
    await Repository.get().editRecord(widget.uuid, false, DateTime.now().millisecondsSinceEpoch, tags: serialized);
  }

  void _addTag() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (_tags.contains(text)) {
      _controller.clear();
      return;
    }
    setState(() {
      _tags.add(text);
      _controller.clear();
    });
    _save();
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.editTags, style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              if (!_loaded)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _tags.map((tag) {
                    return Chip(
                      label: Text(tag, style: const TextStyle(fontSize: 13)),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => _removeTag(tag),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: l10n.tagName,
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _addTag(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(icon: const Icon(Icons.add), onPressed: _addTag, tooltip: l10n.addTag),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.done)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Show the tag editor dialog for the record with [uuid].
Future<void> showTagEditor(BuildContext context, {required String uuid}) {
  return showDialog(
    context: context,
    builder: (context) => TagEditor(uuid: uuid),
  );
}
