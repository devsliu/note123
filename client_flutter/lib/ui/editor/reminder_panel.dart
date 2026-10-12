import 'dart:async';

import 'package:flutter/material.dart';
import 'package:note123/config/language_manager.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/filesync/reminder_tree.dart';
import 'package:note123/utils/utils.dart';
import 'package:note123/ui/calendar/reminder_task_editor.dart';

class ReminderPanel extends StatefulWidget {
  final String uuid;

  /// Maximum number of task rows to show before scrolling.
  final int maxLines;

  /// Whether tasks can be edited/added/deleted.
  final bool editable;

  const ReminderPanel({super.key, required this.uuid, this.maxLines = 10, this.editable = true});

  @override
  State<ReminderPanel> createState() => ReminderPanelState();
}

class ReminderPanelState extends State<ReminderPanel> {
  List<ReminderTask> _tasks = [];
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    final record = await Repository.get().db?.getRecord(widget.uuid);
    if (record == null) return;
    setState(() {
      _tasks = ReminderTask.fromJsonString(
        record.localReminder.isNotEmpty ? record.localReminder : record.remoteReminder,
      );
    });
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), _saveTasks);
  }

  Future<void> _saveTasks() async {
    final repo = Repository.get();
    final json = ReminderTask.toJsonString(_tasks);
    await repo.editRecord(widget.uuid, false, DateTime.now().millisecondsSinceEpoch, reminder: json);
  }

  /// Show the task editor dialog for adding a new task.
  void showAddDialog() {
    if (!widget.editable) return;
    final task = ReminderTask(id: DateTime.now().millisecondsSinceEpoch.toString(), name: '');
    _showEditor(task, isNew: true);
  }

  void _showEditor(ReminderTask task, {required bool isNew}) {
    showDialog<void>(
      context: context,
      builder: (ctx) => ReminderTaskEditor(
        task: task,
        onSaved: (updated) {
          final idx = _tasks.indexWhere((t) => t.id == updated.id);
          setState(() {
            if (idx >= 0) {
              _tasks[idx] = updated;
            } else {
              _tasks.add(updated);
            }
          });
          _scheduleSave();
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  void _removeTask(String id) {
    setState(() => _tasks.removeWhere((t) => t.id == id));
    _scheduleSave();
  }

  void _toggleDone(ReminderTask task) {
    final idx = _tasks.indexWhere((t) => t.id == task.id);
    if (idx < 0) return;
    setState(() {
      _tasks[idx] = task.copyWith(done: !task.done);
    });
    _scheduleSave();
  }

  @override
  Widget build(BuildContext context) {
    if (_tasks.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final itemHeight = 32.0;
    final maxHeight = widget.maxLines * itemHeight + 4 + 32; // +32: header row scrolls with the items

    final rows = <Widget>[];
    for (var i = 0; i < _tasks.length; i++) {
      if (i > 0) rows.add(Divider(height: 1, color: theme.colorScheme.outline.withAlpha(30)));
      rows.add(
        _TaskRow(
          task: _tasks[i],
          editable: widget.editable,
          onToggle: () => _toggleDone(_tasks[i]),
          onEdit: () => _showEditor(_tasks[i], isNew: false),
          onRemove: () => _removeTask(_tasks[i].id),
        ),
      );
    }
    final header = Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(Icons.notifications_active_outlined, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            l10n.reminderTasks,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
          ),
          const Spacer(),
          if (widget.editable)
            IconButton(
              icon: Icon(Icons.add, size: 16, color: theme.colorScheme.primary),
              onPressed: showAddDialog,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              tooltip: l10n.addReminder,
            ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outline.withAlpha(100))),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [header, ...rows],
          ),
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final ReminderTask task;
  final bool editable;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _TaskRow({
    required this.task,
    required this.editable,
    required this.onToggle,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeStr = Utils.reminderTimeStr(task);
    final nameColor = task.done ? theme.colorScheme.onSurface.withAlpha(120) : theme.colorScheme.onSurface;
    return SizedBox(
      height: 34,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 28,
            child: Checkbox(
              value: task.done,
              onChanged: editable ? (_) => onToggle() : null,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
            ),
          ),
          Expanded(
            child: Text(
              task.name.isEmpty ? l10n.unnamedTask : task.name,
              style: TextStyle(
                fontSize: 12,
                decoration: task.done ? TextDecoration.lineThrough : null,
                color: nameColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            task.repeat != ReminderTask.repeatOnce ? Icons.repeat : Icons.schedule,
            size: 11,
            color: theme.colorScheme.onSurface.withAlpha(100),
          ),
          const SizedBox(width: 2),
          Text(timeStr, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withAlpha(100))),
          if (editable) ...[
            IconButton(
              icon: Icon(Icons.edit_outlined, size: 16, color: theme.colorScheme.primary),
              onPressed: onEdit,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, size: 16, color: theme.colorScheme.error),
              onPressed: onRemove,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
          ],
        ],
      ),
    );
  }
}
