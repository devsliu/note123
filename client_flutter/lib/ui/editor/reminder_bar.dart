import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:note123/config/language_manager.dart';
import 'package:note123/filesync/reminder_tree.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/filesync/record_tree.dart';
import 'package:note123/ui/calendar/reminder_panel.dart';
import 'package:note123/utils/utils.dart';

/// Show a dialog with the full [ReminderPanel] for a record, including
/// a title bar with filename + path.
void showReminderDialog(BuildContext context, String uuid) {
  final file = Repository.get().recordTree.findFile(uuid);
  final screenWidth = MediaQuery.of(context).size.width;
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: math.min(400, screenWidth * 0.85),
        child: ReminderPanel(uuid: uuid, subtitle: file?.path, maxLines: 5),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.done))],
    ),
  );
}

/// Compact one-line reminder summary bar. Shows task count + first task's
/// name and time. Tapping opens the full [ReminderPanel] in a dialog.
class ReminderBar extends StatefulWidget {
  final String uuid;
  const ReminderBar({super.key, required this.uuid});

  @override
  State<ReminderBar> createState() => _ReminderBarState();
}

class _ReminderBarState extends State<ReminderBar> {
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
    if (event.type != RecordEvent.typeRebuild && event.value2 != null && event.value2 != widget.uuid) return;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final record = Repository.get().recordTree.findFile(widget.uuid)?.record;
    final tasks = record == null ? const <ReminderTask>[] : ReminderTask.fromJsonString(record.local.reminder);
    if (tasks.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final first = tasks.first;
    final timeStr = Utils.reminderTimeStr(first);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => showReminderDialog(context, widget.uuid),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: Row(
            children: [
              Icon(Icons.notifications_active_outlined, size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${first.name.isEmpty ? l10n.unnamedTask : first.name} · $timeStr',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
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
