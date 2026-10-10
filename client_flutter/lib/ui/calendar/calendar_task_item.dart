import 'package:flutter/material.dart';
import 'package:note123/model/reminder_entry.dart';
import 'package:note123/model/reminder_task.dart';

/// A clickable row shown at the top of record list pages, opening the calendar page.
/// Shows the count of reminder tasks due/reminding today.
class CalendarTaskItem extends StatefulWidget {
  final VoidCallback onTap;
  const CalendarTaskItem({super.key, required this.onTap});

  @override
  State<CalendarTaskItem> createState() => _CalendarTaskItemState();
}

class _CalendarTaskItemState extends State<CalendarTaskItem> {
  int _todayCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    final entries = await collectAllReminders();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final todayEnd = todayStart + 24 * 3600 * 1000;
    final count = entries.where((e) {
      if (e.task.done) return false;
      final ts = e.task.remindAt ?? e.task.dueAt;
      if (ts == null) return false;
      return ts >= todayStart && ts < todayEnd;
    }).length;
    if (mounted) setState(() => _todayCount = count);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.colorScheme.outline.withAlpha(50))),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text('日历任务', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const Spacer(),
            if (_todayCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$_todayCount', style: TextStyle(fontSize: 11, color: theme.colorScheme.onPrimary)),
              ),
            Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.onSurface.withAlpha(120)),
          ],
        ),
      ),
    );
  }
}
