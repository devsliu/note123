import 'package:flutter/widgets.dart';
import 'package:note123/filesync/record_ext.dart';

/// Helpers for the pipe-separated tag storage format, e.g. `|work|todo|`.

/// A single tag: its name, expanded state in the tree, and the records that
/// carry it.
class Tag {
  final String name;
  bool expanded = true;
  final List<RecordEntry> records = [];

  Tag(this.name);
}

/// One-level tag index with two synchronized maps:
///   - [_recordTags]: uuid → list of [Tag] for that record
///   - [_tagsMap]:    tag name → [Tag] (name + records carrying it)
class TagTree {
  final Map<String /*uuid*/, List<Tag>> _recordTags = {};
  final Map<String /*tagname*/, Tag> _tagsMap = {};

  final ValueNotifier<int> tagCountNotifier = ValueNotifier<int>(0);
  bool _sortedDirty = true;
  List<Tag> _sortedTags = const [];

  /// Look up expanded state for a tag by name. Defaults to true if the tag
  /// exists but has never been toggled. Returns false if the tag is unknown.
  bool isExpanded(String name) => _tagsMap[name]?.expanded ?? false;

  /// Toggle or set the expanded state of a tag. No-op if the tag doesn't exist.
  void setExpanded(String name, bool value) {
    _tagsMap[name]?.expanded = value;
  }

  /// Full rebuild from scratch (used on initial load or after DB clear).
  void rebuild(List<RecordEntry> records) {
    _recordTags.clear();
    _tagsMap.clear();
    for (final record in records) {
      _upsertInternal(record);
    }
    _recomputeSorted();
  }

  /// Incremental upsert: apply tags from [record].
  void upsert(RecordEntry record) {
    _upsertInternal(record);
    _recomputeSorted();
  }

  /// Incremental remove: drop all tags for record with [uuid].
  void remove(String uuid) {
    final oldTags = _recordTags.remove(uuid);
    if (oldTags == null) return;
    for (final tag in oldTags) {
      tag.records.removeWhere((r) => r.uuid == uuid);
      if (tag.records.isEmpty) _tagsMap.remove(tag.name);
    }
    _sortedDirty = true;
    _recomputeSorted();
  }

  void _upsertInternal(RecordEntry record) {
    final uuid = record.uuid;
    final newNames = record.tags;
    final oldTags = _recordTags.remove(uuid) ?? const [];
    final oldMap = <String, Tag>{for (final t in oldTags) t.name: t};

    final newTags = <Tag>[];
    for (final name in newNames) {
      final existing = oldMap[name] ?? _tagsMap[name];
      if (existing != null) {
        existing.records
          ..removeWhere((r) => r.uuid == uuid)
          ..add(record);
      } else {
        _tagsMap[name] = Tag(name)..records.add(record);
      }
      newTags.add(_tagsMap[name]!);
    }

    // Remove records from tags that are no longer on this record
    for (final t in oldTags) {
      if (newNames.contains(t.name)) continue;
      t.records.removeWhere((r) => r.uuid == uuid);
      if (t.records.isEmpty) _tagsMap.remove(t.name);
    }

    if (newTags.isNotEmpty) {
      _recordTags[uuid] = newTags;
    }
    _sortedDirty = true;
  }

  void _recomputeSorted() {
    if (!_sortedDirty) return;
    _sortedTags = _tagsMap.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    _sortedDirty = false;
    tagCountNotifier.value = _tagsMap.length;
  }

  /// Sorted tag entries.
  List<Tag> get tags => _sortedTags;

  /// Number of distinct tags.
  int get tagCount => _tagsMap.length;
}
