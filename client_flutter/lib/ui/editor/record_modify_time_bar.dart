import 'dart:async';

import 'package:flutter/material.dart';
import 'package:note123/config/language_manager.dart';
import 'package:note123/filesync/record_ext.dart';
import 'package:note123/filesync/record_tree.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/utils/utils.dart';

/// A compact footer bar showing the last-modify time, version, and optional
/// conflict label for the record identified by [uuid]. Automatically
/// rebuilds on record tree events that touch this uuid.
class RecordModifyTimeBar extends StatefulWidget {
  final String uuid;
  const RecordModifyTimeBar({super.key, required this.uuid});

  @override
  State<RecordModifyTimeBar> createState() => _RecordModifyTimeBarState();
}

class _RecordModifyTimeBarState extends State<RecordModifyTimeBar> {
  StreamSubscription<RecordEvent>? _treeSub;

  @override
  void initState() {
    super.initState();
    _treeSub = Repository.get().recordTree.onEvent.listen(_onEvent);
  }

  @override
  void dispose() {
    _treeSub?.cancel();
    super.dispose();
  }

  void _onEvent(RecordEvent event) {
    if (event.type != RecordEvent.typeRebuild && event.value2 != null && event.value2 != widget.uuid) {
      return;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileNode = Repository.get().recordTree.findFile(widget.uuid);
    if (fileNode == null) return const SizedBox.shrink();
    final record = fileNode.record.local;
    final hasConflict = record.syncConflict;
    final color = hasConflict ? theme.colorScheme.error : theme.colorScheme.onSurface.withAlpha(150);
    final conflictLabel = hasConflict ? "  [${l10n.hasConflict}]" : "";
    final version = record.version != record.remoteVersion
        ? 'v${record.version}->v${record.remoteVersion}'
        : 'v${record.version}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        " $version $conflictLabel ${l10n.lastModify}: ${Utils.formatTime(record.editAt)}",
        style: TextStyle(fontSize: 12, color: color),
      ),
    );
  }
}
