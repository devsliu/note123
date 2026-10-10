import 'package:flutter/material.dart';
import 'package:note123/config/app_config.dart';
import 'package:note123/config/language_manager.dart';
import 'package:note123/filesync/reminder_entry.dart';

/// A clickable row shown at the top of record list pages, opening the calendar page.
/// Shows the count of reminder tasks reminding today.
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
    final today = DateTime.now();
    final count = entries.where((e) {
      if (e.task.done) return false;
      return reminderOccursOnDay(e.task, today);
    }).length;
    if (mounted) setState(() => _todayCount = count);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppConfig.pageHorizontalPadding, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(l10n.calendarTasks, style: TextStyle(fontSize: 14)),
            const Spacer(),
            if (_todayCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(8)),
                child: Text('$_todayCount', style: TextStyle(fontSize: 11, color: theme.colorScheme.onPrimary)),
              ),
            Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.onSurface.withAlpha(120)),
          ],
        ),
      ),
    );
  }
}
