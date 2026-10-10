import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:note123/filesync/record_tree.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/model/reminder_entry.dart';
import 'package:note123/ui/desktop/desktop_record_detail_page.dart';
import 'package:note123/utils/utils.dart';

/// Calendar + list page for all reminder tasks across every note.
///
/// - [showAppBar]: when false, renders without a Scaffold/AppBar so it can be
///   embedded inside a desktop detail tab.
/// - [onOpenRecord]: called when the user taps a reminder's note. On desktop
///   this opens a record tab; on mobile it defaults to Navigator.pop + push.
class CalendarPage extends StatefulWidget {
  final bool showAppBar;
  final ValueChanged<TreeContentFile>? onOpenRecord;

  const CalendarPage({super.key, this.showAppBar = true, this.onOpenRecord});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> implements DetailTabPageState {
  List<ReminderEntry> _entries = [];
  bool _loading = true;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  int _viewMode = 0; // 0 = calendar, 1 = list

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _load();
  }

  @override
  void setInForeground(bool value) {
    // No editor lifecycle to manage; refresh on focus so new reminders appear.
    if (value) _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final entries = await collectAllReminders();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  List<ReminderEntry> _entriesForDay(DateTime day) {
    return _entries.where((e) {
      final ts = e.task.remindAt ?? e.task.dueAt;
      if (ts == null) return false;
      final d = DateTime.fromMillisecondsSinceEpoch(ts);
      return isSameDay(d, day);
    }).toList();
  }

  void _openRecord(String uuid) {
    final record = Repository.get().recordTree.findFile(uuid);
    if (record == null) return;
    widget.onOpenRecord?.call(record);
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody(context);
    if (!widget.showAppBar) return body;
    return Scaffold(
      appBar: AppBar(
        title: const Text('日历任务'),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(40), child: _buildToggleBar(context)),
      ),
      body: body,
    );
  }

  Widget _buildToggleBar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 40,
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          Expanded(
            child: _ToggleButton(
              label: '日历',
              icon: Icons.calendar_month,
              selected: _viewMode == 0,
              onTap: () => setState(() => _viewMode = 0),
            ),
          ),
          Expanded(
            child: _ToggleButton(
              label: '列表',
              icon: Icons.list,
              selected: _viewMode == 1,
              onTap: () => setState(() => _viewMode = 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_viewMode == 0) return _buildCalendarView(context);
    return _buildListView(context);
  }

  Widget _buildCalendarView(BuildContext context) {
    final theme = Theme.of(context);
    final selectedEntries = _selectedDay != null ? _entriesForDay(_selectedDay!) : <ReminderEntry>[];

    return Column(
      children: [
        if (!widget.showAppBar) _buildToggleBar(context),
        TableCalendar<ReminderEntry>(
          firstDay: DateTime(2000),
          lastDay: DateTime(2100),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selected, focused) {
            setState(() {
              _selectedDay = selected;
              _focusedDay = focused;
            });
          },
          onFormatChanged: (format) {
            if (_calendarFormat != format) setState(() => _calendarFormat = format);
          },
          onPageChanged: (focused) => _focusedDay = focused,
          eventLoader: (day) => _entriesForDay(day),
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(color: theme.colorScheme.primary.withAlpha(80), shape: BoxShape.circle),
            selectedDecoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
            markerDecoration: BoxDecoration(color: theme.colorScheme.secondary, shape: BoxShape.circle),
          ),
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, day, events) {
              if (events.isEmpty) return null;
              return Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: theme.colorScheme.secondary, shape: BoxShape.circle),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: selectedEntries.isEmpty
              ? Center(
                  child: Text('当天无提醒', style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(120))),
                )
              : ListView.builder(
                  itemCount: selectedEntries.length,
                  itemBuilder: (context, i) => _buildEntryTile(context, selectedEntries[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildListView(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        if (!widget.showAppBar) _buildToggleBar(context),
        Expanded(
          child: _entries.isEmpty
              ? Center(
                  child: Text('暂无提醒任务', style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(120))),
                )
              : ListView.builder(
                  itemCount: _entries.length,
                  itemBuilder: (context, i) => _buildEntryTile(context, _entries[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildEntryTile(BuildContext context, ReminderEntry entry) {
    final theme = Theme.of(context);
    final task = entry.task;
    final ts = task.remindAt ?? task.dueAt;
    final timeStr = ts != null ? Utils.formatTime(ts) : '无时间';
    final overdue = ts != null && ts < DateTime.now().millisecondsSinceEpoch && !task.done;
    return ListTile(
      dense: true,
      leading: Icon(
        task.done ? Icons.check_circle : Icons.notifications_active,
        color: task.done ? Colors.green : (overdue ? Colors.red : theme.colorScheme.primary),
        size: 20,
      ),
      title: Text(
        task.name.isEmpty ? '(无名称)' : task.name,
        style: TextStyle(decoration: task.done ? TextDecoration.lineThrough : null),
      ),
      subtitle: Text(
        '${entry.recordPath}${entry.recordName}  ·  $timeStr',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => _openRecord(entry.recordUuid),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleButton({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withAlpha(140),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withAlpha(140),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
