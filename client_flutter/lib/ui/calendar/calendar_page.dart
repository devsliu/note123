import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:note123/config/language_manager.dart';
import 'package:note123/filesync/record_tree.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/filesync/reminder_entry.dart';
import 'package:note123/ui/desktop/desktop_tabs_page.dart';
import 'package:note123/utils/utils.dart';

class CalendarPage extends StatefulWidget {
  final bool showAppBar;
  final ValueChanged<TreeContentFile>? onOpenRecord;

  const CalendarPage({super.key, this.showAppBar = true, this.onOpenRecord});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> implements DesktopTabPageState {
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
    return _entries.where((e) => reminderOccursOnDay(e.task, day)).toList();
  }

  void _openRecord(String uuid) {
    final record = Repository.get().recordTree.findFile(uuid);
    if (record == null) return;
    widget.onOpenRecord?.call(record);
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody(context);
    final segmented = _buildSegmentedControl(context);
    if (!widget.showAppBar) {
      return Stack(
        children: [
          body,
          Positioned(right: 16, bottom: 16, child: segmented),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.calendarTasks),
        actions: [Padding(padding: const EdgeInsets.only(right: 12), child: segmented)],
      ),
      body: body,
    );
  }

  Widget _buildSegmentedControl(BuildContext context) {
    return SegmentedButton<int>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(value: 0, label: Text(l10n.calendarView), icon: const Icon(Icons.calendar_month, size: 18)),
        ButtonSegment(value: 1, label: Text(l10n.listView), icon: const Icon(Icons.list, size: 18)),
      ],
      selected: {_viewMode},
      onSelectionChanged: (set) => setState(() => _viewMode = set.first),
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
        TableCalendar<ReminderEntry>(
          firstDay: DateTime(2000),
          lastDay: DateTime(2100),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          rowHeight: 56,
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
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, day, focused) => _buildDayCell(context, day),
            todayBuilder: (context, day, focused) => _buildDayCell(context, day, isToday: true),
            selectedBuilder: (context, day, focused) => _buildDayCell(context, day, selected: true),
            outsideBuilder: (context, day, focused) => _buildDayCell(context, day, isOutside: true),
            markerBuilder: (context, day, events) => const SizedBox.shrink(),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: selectedEntries.isEmpty
              ? Center(
                  child: Text(
                    l10n.noRemindersToday,
                    style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(120)),
                  ),
                )
              : ListView.separated(
                  itemCount: selectedEntries.length,
                  separatorBuilder: (_, _) => Divider(height: 1, color: theme.colorScheme.outline.withAlpha(40)),
                  itemBuilder: (context, i) => _buildEntryTile(context, selectedEntries[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildDayCell(
    BuildContext context,
    DateTime day, {
    bool selected = false,
    bool isToday = false,
    bool isOutside = false,
  }) {
    final theme = Theme.of(context);
    final entries = _entriesForDay(day);
    final text = entries.isEmpty
        ? ''
        : entries.length == 1
        ? (entries.first.task.name.isEmpty ? l10n.reminder : entries.first.task.name)
        : '${entries.first.task.name.isEmpty ? l10n.reminder : entries.first.task.name} +${entries.length - 1}';

    final dayColor = isOutside
        ? theme.colorScheme.onSurface.withAlpha(80)
        : selected
        ? Colors.white
        : isToday
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      decoration: BoxDecoration(
        color: selected
            ? theme.colorScheme.primary
            : isToday
            ? theme.colorScheme.primary.withAlpha(15)
            : null,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isToday)
                  Text(
                    l10n.today,
                    style: TextStyle(color: dayColor, fontSize: 14, fontWeight: FontWeight.bold),
                  )
                else
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      color: dayColor,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
              ],
            ),
            if (text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 2, right: 2),
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: dayColor, fontSize: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: _entries.isEmpty
              ? Center(
                  child: Text(
                    l10n.noReminderTasks,
                    style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(120)),
                  ),
                )
              : ListView.separated(
                  itemCount: _entries.length,
                  separatorBuilder: (_, _) => Divider(height: 1, color: theme.colorScheme.outline.withAlpha(40)),
                  itemBuilder: (context, i) => _buildEntryTile(context, _entries[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildEntryTile(BuildContext context, ReminderEntry entry) {
    final task = entry.task;
    final timeStr = Utils.reminderTimeStr(task);
    return ListTile(
      dense: true,
      title: Text(
        task.name.isEmpty ? l10n.unnamedTask : task.name,
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
