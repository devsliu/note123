import 'dart:async';

import 'package:flutter/material.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/model/reminder_task.dart';
import 'package:note123/utils/utils.dart';
import 'package:uuid/uuid.dart';

/// Panel for managing reminder tasks of a record.
/// Reads/writes the `localReminder` JSON field directly to DB.
class ReminderPanel extends StatefulWidget {
  final String uuid;
  const ReminderPanel({super.key, required this.uuid});

  @override
  State<ReminderPanel> createState() => _ReminderPanelState();
}

class _ReminderPanelState extends State<ReminderPanel> {
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

  /// Debounced save: writes the JSON string to localReminder and triggers sync.
  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), () {
      _saveTasks();
    });
  }

  Future<void> _saveTasks() async {
    final repo = Repository.get();
    final json = ReminderTask.toJsonString(_tasks);
    await repo.editRecord(widget.uuid, false, DateTime.now().millisecondsSinceEpoch, reminder: json);
  }

  void _addTask() {
    setState(() {
      _tasks.add(ReminderTask(id: const Uuid().v4(), name: ''));
    });
    _scheduleSave();
  }

  void _removeTask(String id) {
    setState(() {
      _tasks.removeWhere((t) => t.id == id);
    });
    _scheduleSave();
  }

  void _updateTask(ReminderTask task) {
    final idx = _tasks.indexWhere((t) => t.id == task.id);
    if (idx < 0) return;
    setState(() {
      _tasks[idx] = task;
    });
    _scheduleSave();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outline.withAlpha(40))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active_outlined, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                '提醒任务',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _addTask,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('添加', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
              ),
            ],
          ),
          if (_tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 22, top: 2, bottom: 4),
              child: Text('暂无提醒任务', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(100))),
            )
          else
            ..._tasks.map((task) => _TaskRow(task: task, onChanged: _updateTask, onRemove: () => _removeTask(task.id))),
        ],
      ),
    );
  }
}

class _TaskRow extends StatefulWidget {
  final ReminderTask task;
  final ValueChanged<ReminderTask> onChanged;
  final VoidCallback onRemove;
  const _TaskRow({required this.task, required this.onChanged, required this.onRemove});

  @override
  State<_TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends State<_TaskRow> {
  late TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.task.name);
  }

  @override
  void didUpdateWidget(covariant _TaskRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.name != widget.task.name && _nameCtrl.text != widget.task.name) {
      _nameCtrl.text = widget.task.name;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isDue}) async {
    final now = DateTime.now();
    final initial = isDue
        ? (widget.task.dueAt != null ? DateTime.fromMillisecondsSinceEpoch(widget.task.dueAt!) : now)
        : (widget.task.remindAt != null ? DateTime.fromMillisecondsSinceEpoch(widget.task.remindAt!) : now);
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null) return;
    if (!mounted) return;
    final pickedTime = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (pickedTime == null) return;
    final dt = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
    final ms = dt.millisecondsSinceEpoch;
    final updated = ReminderTask(
      id: widget.task.id,
      name: widget.task.name,
      dueAt: isDue ? ms : widget.task.dueAt,
      remindAt: isDue ? widget.task.remindAt : ms,
      done: widget.task.done,
    );
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Checkbox(
            value: widget.task.done,
            onChanged: (v) {
              widget.onChanged(
                ReminderTask(
                  id: widget.task.id,
                  name: widget.task.name,
                  dueAt: widget.task.dueAt,
                  remindAt: widget.task.remindAt,
                  done: v ?? false,
                ),
              );
            },
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                border: OutlineInputBorder(),
                hintText: '任务名称',
              ),
              style: TextStyle(
                fontSize: 13,
                decoration: widget.task.done ? TextDecoration.lineThrough : null,
                color: widget.task.done ? theme.colorScheme.onSurface.withAlpha(120) : null,
              ),
              onChanged: (v) {
                widget.onChanged(
                  ReminderTask(
                    id: widget.task.id,
                    name: v,
                    dueAt: widget.task.dueAt,
                    remindAt: widget.task.remindAt,
                    done: widget.task.done,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 4),
          _TimeChip(
            label: widget.task.dueAt != null ? Utils.formatShortTime(widget.task.dueAt!) : '截止',
            hasValue: widget.task.dueAt != null,
            onTap: () => _pickDateTime(isDue: true),
            onClear: widget.task.dueAt != null
                ? () {
                    widget.onChanged(
                      ReminderTask(
                        id: widget.task.id,
                        name: widget.task.name,
                        dueAt: null,
                        remindAt: widget.task.remindAt,
                        done: widget.task.done,
                      ),
                    );
                  }
                : null,
            color: Colors.orange,
          ),
          const SizedBox(width: 4),
          _TimeChip(
            label: widget.task.remindAt != null ? Utils.formatShortTime(widget.task.remindAt!) : '提醒',
            hasValue: widget.task.remindAt != null,
            onTap: () => _pickDateTime(isDue: false),
            onClear: widget.task.remindAt != null
                ? () {
                    widget.onChanged(
                      ReminderTask(
                        id: widget.task.id,
                        name: widget.task.name,
                        dueAt: widget.task.dueAt,
                        remindAt: null,
                        done: widget.task.done,
                      ),
                    );
                  }
                : null,
            color: Colors.blueAccent,
          ),
          IconButton(
            icon: Icon(Icons.close, size: 16, color: theme.colorScheme.onSurface.withAlpha(120)),
            onPressed: widget.onRemove,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String label;
  final bool hasValue;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final Color color;
  const _TimeChip({
    required this.label,
    required this.hasValue,
    required this.onTap,
    this.onClear,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: hasValue ? color : theme.colorScheme.outline.withAlpha(120)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule, size: 12, color: hasValue ? color : theme.colorScheme.onSurface.withAlpha(120)),
            const SizedBox(width: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: hasValue ? color : theme.colorScheme.onSurface.withAlpha(120)),
            ),
            if (onClear != null)
              InkWell(
                onTap: onClear,
                child: Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Icon(Icons.close, size: 11, color: color),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
