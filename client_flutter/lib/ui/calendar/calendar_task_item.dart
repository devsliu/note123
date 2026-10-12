import 'package:flutter/material.dart';
import 'package:note123/config/language_manager.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/utils/utils.dart';

/// A clickable row shown at the top of record list pages, opening the calendar page.
/// Shows the count of reminder tasks reminding today.
class CalendarTaskItem extends StatelessWidget {
  final ValueCallback<BuildContext> onTap;
  const CalendarTaskItem({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reminderTree = Repository.get().reminderTree;
    return ValueListenableBuilder<int>(
      valueListenable: reminderTree.todayCountNotifier,
      builder: (context, todayCount, _) {
        final totalCount = reminderTree.entries.length;
        return InkWell(
          onTap: () => onTap(context),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline.withAlpha(150)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 4),
                Text(l10n.calendarTasks, style: TextStyle(fontSize: 14)),
                const Spacer(),
                if (todayCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(8)),
                    child: Text('$todayCount', style: TextStyle(fontSize: 12, color: theme.colorScheme.onPrimary)),
                  ),
                if (todayCount == 0) Text('$totalCount', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }
}
