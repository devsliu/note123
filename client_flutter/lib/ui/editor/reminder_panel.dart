import 'dart:async';

import 'package:flutter/material.dart';
import 'package:note123/config/language_manager.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/filesync/reminder_entry.dart';
import 'package:note123/utils/utils.dart';
import 'package:uuid/uuid.dart';

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
    final task = ReminderTask(id: const Uuid().v4(), name: '');
    _showEditor(task, isNew: true);
  }

  void _showEditor(ReminderTask task, {required bool isNew}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReminderTaskEditor(
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
      _tasks[idx] = ReminderTask(
        id: task.id,
        name: task.name,
        date: task.date,
        time: task.time,
        repeat: task.repeat,
        done: !task.done,
      );
    });
    _scheduleSave();
  }

  @override
  Widget build(BuildContext context) {
    if (_tasks.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final itemHeight = 36.0;
    final maxHeight = widget.maxLines * itemHeight + 8;

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
    final list = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(child: Column(children: rows)),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  tooltip: l10n.addReminder,
                ),
            ],
          ),
          list,
        ],
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
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, size: 16, color: theme.colorScheme.error),
              onPressed: onRemove,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            ),
          ],
        ],
      ),
    );
  }
}

/// Common interface for the per-mode date/time editor states. The parent
/// editor calls [validateAndGet] on save: on success it returns the encoded
/// `(date, time)` ints; on failure it highlights the invalid fields internally
/// and returns null.
abstract class _DateTimeEditorState<T extends StatefulWidget> extends State<T> {
  (int date, int time)? validateAndGet();
}

// Field keys used for error highlighting inside the editors.
const String _fYear = 'year';
const String _fMonth = 'month';
const String _fDay = 'day';
const String _fHour = 'hour';
const String _fMinute = 'minute';
const String _fWeekdays = 'weekdays';

/// Bottom sheet editor for a single reminder task.
class _ReminderTaskEditor extends StatefulWidget {
  final ReminderTask task;
  final ValueChanged<ReminderTask> onSaved;

  const _ReminderTaskEditor({required this.task, required this.onSaved});

  @override
  State<_ReminderTaskEditor> createState() => _ReminderTaskEditorState();
}

class _ReminderTaskEditorState extends State<_ReminderTaskEditor> {
  late final TextEditingController _nameCtrl;
  late int _repeat;

  // Keys give the parent access to each mode editor's validateAndGet().
  final _onceKey = GlobalKey<_OnceEditorState>();
  final _weeklyKey = GlobalKey<_WeeklyEditorState>();
  final _monthlyKey = GlobalKey<_MonthlyEditorState>();
  final _yearlyKey = GlobalKey<_YearlyEditorState>();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.task.name);
    _repeat = widget.task.repeat;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  /// Ask the currently visible mode editor to validate itself and return the
  /// encoded `(date, time)`. Returns null when validation fails (the editor
  /// shows its own error highlights).
  (int, int)? _currentEditorValues() {
    switch (_repeat) {
      case ReminderTask.repeatOnce:
        return _onceKey.currentState?.validateAndGet();
      case ReminderTask.repeatWeekly:
        return _weeklyKey.currentState?.validateAndGet();
      case ReminderTask.repeatMonthly:
        return _monthlyKey.currentState?.validateAndGet();
      case ReminderTask.repeatYearly:
        return _yearlyKey.currentState?.validateAndGet();
      default:
        return null;
    }
  }

  void _save() {
    final values = _currentEditorValues();
    if (values == null) return; // editor highlighted the invalid fields

    widget.onSaved(
      ReminderTask(
        id: widget.task.id,
        name: _nameCtrl.text.trim(),
        date: values.$1,
        time: values.$2,
        repeat: _repeat,
        done: widget.task.done,
      ),
    );
  }

  /// Builds the date/time editor for the current repeat mode.
  Widget _buildDateTimeEditor() {
    switch (_repeat) {
      case ReminderTask.repeatOnce:
        return _OnceEditor(key: _onceKey, task: widget.task);
      case ReminderTask.repeatWeekly:
        return _WeeklyEditor(key: _weeklyKey, task: widget.task);
      case ReminderTask.repeatMonthly:
        return _MonthlyEditor(key: _monthlyKey, task: widget.task);
      case ReminderTask.repeatYearly:
        return _YearlyEditor(key: _yearlyKey, task: widget.task);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repeatLabels = [l10n.repeatOnce, l10n.repeatWeekly, l10n.repeatMonthly, l10n.repeatYearly];
    final repeatValues = [
      ReminderTask.repeatOnce,
      ReminderTask.repeatWeekly,
      ReminderTask.repeatMonthly,
      ReminderTask.repeatYearly,
    ];
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.editReminder,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
              ),
              const Spacer(),
              TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
              TextButton(onPressed: _save, child: Text(l10n.save)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: const OutlineInputBorder(),
              hintText: l10n.taskName,
            ),
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
          _buildDateTimeEditor(),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(l10n.repeat, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface)),
              const SizedBox(width: 10),
              ...List.generate(repeatValues.length, (i) {
                final val = repeatValues[i];
                final selected = _repeat == val;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(repeatLabels[i], style: const TextStyle(fontSize: 12)),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _repeat = val);
                    },
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Date/time editor widgets (one per repeat mode)
// ---------------------------------------------------------------------------

/// A single numeric date/time input field with optional error highlighting.
class _DateTimeField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final double width;
  final bool error;
  final VoidCallback? onChanged;

  const _DateTimeField({
    required this.controller,
    required this.hint,
    required this.width,
    this.error = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    final primary = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        onChanged: (_) => onChanged?.call(),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: OutlineInputBorder(borderSide: error ? BorderSide(color: errorColor, width: 1.5) : BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderSide: error ? BorderSide(color: errorColor, width: 1.5) : const BorderSide(),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: error ? BorderSide(color: errorColor, width: 1.5) : BorderSide(color: primary, width: 1.5),
          ),
          hintText: hint,
          hintStyle: TextStyle(color: error ? errorColor.withAlpha(150) : null),
        ),
        style: TextStyle(fontSize: 14, color: error ? errorColor : null),
      ),
    );
  }
}

/// The hour + minute input row shared by all repeat modes.
class _TimeFields extends StatelessWidget {
  final TextEditingController hourCtrl;
  final TextEditingController minuteCtrl;
  final bool hourError;
  final bool minuteError;
  final VoidCallback? onChanged;

  const _TimeFields({
    required this.hourCtrl,
    required this.minuteCtrl,
    required this.hourError,
    required this.minuteError,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _DateTimeField(controller: hourCtrl, hint: l10n.unitHour, width: 48, error: hourError, onChanged: onChanged),
        const SizedBox(width: 4),
        const Text(':', style: TextStyle(fontSize: 14)),
        const SizedBox(width: 4),
        _DateTimeField(
          controller: minuteCtrl,
          hint: l10n.unitMinute,
          width: 48,
          error: minuteError,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// once: 年-月-日 + 时:分
class _OnceEditor extends StatefulWidget {
  final ReminderTask task;
  const _OnceEditor({super.key, required this.task});

  @override
  State<_OnceEditor> createState() => _OnceEditorState();
}

class _OnceEditorState extends _DateTimeEditorState<_OnceEditor> {
  late final TextEditingController _yearCtrl;
  late final TextEditingController _monthCtrl;
  late final TextEditingController _dayCtrl;
  late final TextEditingController _hourCtrl;
  late final TextEditingController _minuteCtrl;
  final _invalid = <String>{};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().add(const Duration(minutes: 5));
    final hasDate = widget.task.date > 0;
    final hasTime = widget.task.time > 0;
    final d = widget.task.onceDate;
    _yearCtrl = TextEditingController(text: '${hasDate ? d.$1 : now.year}');
    _monthCtrl = TextEditingController(text: '${hasDate ? d.$2 : now.month}');
    _dayCtrl = TextEditingController(text: '${hasDate ? d.$3 : now.day}');
    _hourCtrl = TextEditingController(text: '${hasTime ? widget.task.hour : now.hour}');
    _minuteCtrl = TextEditingController(text: '${hasTime ? widget.task.minute : now.minute}');
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    _monthCtrl.dispose();
    _dayCtrl.dispose();
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (_invalid.isNotEmpty) setState(() => _invalid.clear());
  }

  @override
  (int, int)? validateAndGet() {
    final invalid = <String>{};
    final year = int.tryParse(_yearCtrl.text.trim());
    if (year == null) invalid.add(_fYear);
    final month = int.tryParse(_monthCtrl.text.trim());
    if (month == null || month < 1 || month > 12) invalid.add(_fMonth);
    final day = int.tryParse(_dayCtrl.text.trim());
    if (day == null || day < 1 || day > 31) {
      invalid.add(_fDay);
    } else if (year != null && month != null) {
      final dim = DateTime(year, month + 1, 0).day;
      if (day > dim) invalid.add(_fDay);
    }
    final hour = int.tryParse(_hourCtrl.text.trim());
    if (hour == null || hour < 0 || hour > 23) invalid.add(_fHour);
    final minute = int.tryParse(_minuteCtrl.text.trim());
    if (minute == null || minute < 0 || minute > 59) invalid.add(_fMinute);

    setState(() {
      _invalid
        ..clear()
        ..addAll(invalid);
    });
    if (invalid.isNotEmpty) return null;
    return (ReminderTask.encodeOnceDate(year!, month!, day!), ReminderTask.encodeTime(hour!, minute!));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _DateTimeField(
          controller: _yearCtrl,
          hint: l10n.unitYear,
          width: 64,
          error: _invalid.contains(_fYear),
          onChanged: _onFieldChanged,
        ),
        const SizedBox(width: 4),
        const Text('-', style: TextStyle(fontSize: 14)),
        const SizedBox(width: 4),
        _DateTimeField(
          controller: _monthCtrl,
          hint: l10n.unitMonth,
          width: 48,
          error: _invalid.contains(_fMonth),
          onChanged: _onFieldChanged,
        ),
        const SizedBox(width: 4),
        const Text('-', style: TextStyle(fontSize: 14)),
        const SizedBox(width: 4),
        _DateTimeField(
          controller: _dayCtrl,
          hint: l10n.unitDay,
          width: 48,
          error: _invalid.contains(_fDay),
          onChanged: _onFieldChanged,
        ),
        const SizedBox(width: 8),
        _TimeFields(
          hourCtrl: _hourCtrl,
          minuteCtrl: _minuteCtrl,
          hourError: _invalid.contains(_fHour),
          minuteError: _invalid.contains(_fMinute),
          onChanged: _onFieldChanged,
        ),
      ],
    );
  }
}

/// weekly: 周一~周日 chips, then 时:分 below
class _WeeklyEditor extends StatefulWidget {
  final ReminderTask task;
  const _WeeklyEditor({super.key, required this.task});

  @override
  State<_WeeklyEditor> createState() => _WeeklyEditorState();
}

class _WeeklyEditorState extends _DateTimeEditorState<_WeeklyEditor> {
  late final TextEditingController _hourCtrl;
  late final TextEditingController _minuteCtrl;
  late final List<int> _weekdays;
  final _invalid = <String>{};
  late final List<String> _labels = l10n.weekdays.split('|');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().add(const Duration(minutes: 5));
    final hasTime = widget.task.time > 0;
    _hourCtrl = TextEditingController(text: '${hasTime ? widget.task.hour : now.hour}');
    _minuteCtrl = TextEditingController(text: '${hasTime ? widget.task.minute : now.minute}');
    _weekdays = [...widget.task.weekdaySet];
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (_invalid.isNotEmpty) setState(() => _invalid.clear());
  }

  void _toggleWeekday(int day) {
    setState(() {
      _invalid.remove(_fWeekdays);
      if (_weekdays.contains(day)) {
        _weekdays.remove(day);
      } else {
        _weekdays.add(day);
      }
    });
  }

  @override
  (int, int)? validateAndGet() {
    final invalid = <String>{};
    if (_weekdays.isEmpty) invalid.add(_fWeekdays);
    final hour = int.tryParse(_hourCtrl.text.trim());
    if (hour == null || hour < 0 || hour > 23) invalid.add(_fHour);
    final minute = int.tryParse(_minuteCtrl.text.trim());
    if (minute == null || minute < 0 || minute > 59) invalid.add(_fMinute);

    setState(() {
      _invalid
        ..clear()
        ..addAll(invalid);
    });
    if (invalid.isNotEmpty) return null;
    return (ReminderTask.encodeWeeklyDate([..._weekdays]), ReminderTask.encodeTime(hour!, minute!));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: List.generate(7, (i) {
            final day = i + 1;
            return ChoiceChip(
              label: Text(_labels[i], style: const TextStyle(fontSize: 12)),
              selected: _weekdays.contains(day),
              onSelected: (_) => _toggleWeekday(day),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );
          }),
        ),
        if (_invalid.contains(_fWeekdays)) ...[
          const SizedBox(height: 4),
          Text(l10n.atLeastOneWeekday, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 10),
        _TimeFields(
          hourCtrl: _hourCtrl,
          minuteCtrl: _minuteCtrl,
          hourError: _invalid.contains(_fHour),
          minuteError: _invalid.contains(_fMinute),
          onChanged: _onFieldChanged,
        ),
      ],
    );
  }
}

/// monthly: 日 + 时:分
class _MonthlyEditor extends StatefulWidget {
  final ReminderTask task;
  const _MonthlyEditor({super.key, required this.task});

  @override
  State<_MonthlyEditor> createState() => _MonthlyEditorState();
}

class _MonthlyEditorState extends _DateTimeEditorState<_MonthlyEditor> {
  late final TextEditingController _dayCtrl;
  late final TextEditingController _hourCtrl;
  late final TextEditingController _minuteCtrl;
  final _invalid = <String>{};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().add(const Duration(minutes: 5));
    final hasDate = widget.task.date > 0;
    final hasTime = widget.task.time > 0;
    _dayCtrl = TextEditingController(text: '${hasDate ? widget.task.monthlyDay : now.day}');
    _hourCtrl = TextEditingController(text: '${hasTime ? widget.task.hour : now.hour}');
    _minuteCtrl = TextEditingController(text: '${hasTime ? widget.task.minute : now.minute}');
  }

  @override
  void dispose() {
    _dayCtrl.dispose();
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (_invalid.isNotEmpty) setState(() => _invalid.clear());
  }

  @override
  (int, int)? validateAndGet() {
    final invalid = <String>{};
    final day = int.tryParse(_dayCtrl.text.trim());
    if (day == null || day < 1 || day > 31) invalid.add(_fDay);
    final hour = int.tryParse(_hourCtrl.text.trim());
    if (hour == null || hour < 0 || hour > 23) invalid.add(_fHour);
    final minute = int.tryParse(_minuteCtrl.text.trim());
    if (minute == null || minute < 0 || minute > 59) invalid.add(_fMinute);

    setState(() {
      _invalid
        ..clear()
        ..addAll(invalid);
    });
    if (invalid.isNotEmpty) return null;
    return (day!, ReminderTask.encodeTime(hour!, minute!));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _DateTimeField(
          controller: _dayCtrl,
          hint: l10n.unitDay,
          width: 56,
          error: _invalid.contains(_fDay),
          onChanged: _onFieldChanged,
        ),
        const SizedBox(width: 4),
        Text(l10n.unitDay, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        _TimeFields(
          hourCtrl: _hourCtrl,
          minuteCtrl: _minuteCtrl,
          hourError: _invalid.contains(_fHour),
          minuteError: _invalid.contains(_fMinute),
          onChanged: _onFieldChanged,
        ),
      ],
    );
  }
}

/// yearly: 月 日 + 时:分
class _YearlyEditor extends StatefulWidget {
  final ReminderTask task;
  const _YearlyEditor({super.key, required this.task});

  @override
  State<_YearlyEditor> createState() => _YearlyEditorState();
}

class _YearlyEditorState extends _DateTimeEditorState<_YearlyEditor> {
  late final TextEditingController _monthCtrl;
  late final TextEditingController _dayCtrl;
  late final TextEditingController _hourCtrl;
  late final TextEditingController _minuteCtrl;
  final _invalid = <String>{};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().add(const Duration(minutes: 5));
    final hasDate = widget.task.date > 0;
    final hasTime = widget.task.time > 0;
    final md = widget.task.yearlyMonthDay;
    _monthCtrl = TextEditingController(text: '${hasDate ? md.$1 : now.month}');
    _dayCtrl = TextEditingController(text: '${hasDate ? md.$2 : now.day}');
    _hourCtrl = TextEditingController(text: '${hasTime ? widget.task.hour : now.hour}');
    _minuteCtrl = TextEditingController(text: '${hasTime ? widget.task.minute : now.minute}');
  }

  @override
  void dispose() {
    _monthCtrl.dispose();
    _dayCtrl.dispose();
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (_invalid.isNotEmpty) setState(() => _invalid.clear());
  }

  @override
  (int, int)? validateAndGet() {
    final invalid = <String>{};
    final month = int.tryParse(_monthCtrl.text.trim());
    if (month == null || month < 1 || month > 12) invalid.add(_fMonth);
    final day = int.tryParse(_dayCtrl.text.trim());
    if (day == null || day < 1 || day > 31) {
      invalid.add(_fDay);
    } else if (month != null) {
      // Use a leap year so Feb 29 is accepted (base year is 2000 on save).
      final dim = DateTime(2000, month + 1, 0).day;
      if (day > dim) invalid.add(_fDay);
    }
    final hour = int.tryParse(_hourCtrl.text.trim());
    if (hour == null || hour < 0 || hour > 23) invalid.add(_fHour);
    final minute = int.tryParse(_minuteCtrl.text.trim());
    if (minute == null || minute < 0 || minute > 59) invalid.add(_fMinute);

    setState(() {
      _invalid
        ..clear()
        ..addAll(invalid);
    });
    if (invalid.isNotEmpty) return null;
    return (ReminderTask.encodeYearlyDate(month!, day!), ReminderTask.encodeTime(hour!, minute!));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _DateTimeField(
          controller: _monthCtrl,
          hint: l10n.unitMonth,
          width: 56,
          error: _invalid.contains(_fMonth),
          onChanged: _onFieldChanged,
        ),
        const SizedBox(width: 4),
        Text(l10n.unitMonth, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        _DateTimeField(
          controller: _dayCtrl,
          hint: l10n.unitDay,
          width: 56,
          error: _invalid.contains(_fDay),
          onChanged: _onFieldChanged,
        ),
        const SizedBox(width: 4),
        Text(l10n.unitDay, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        _TimeFields(
          hourCtrl: _hourCtrl,
          minuteCtrl: _minuteCtrl,
          hourError: _invalid.contains(_fHour),
          minuteError: _invalid.contains(_fMinute),
          onChanged: _onFieldChanged,
        ),
      ],
    );
  }
}
