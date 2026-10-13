import 'package:flutter/material.dart';
import 'package:note123/config/language_manager.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/utils/utils.dart';

class CalendarBar extends StatelessWidget {
  final ValueCallback<BuildContext> onTap;
  final bool shrink;

  const CalendarBar({super.key, required this.onTap, this.shrink = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paddingV = shrink ? 4.0 : 10.0;
    return ValueListenableBuilder<int>(
      valueListenable: Repository.get().reminderTree.countNotifier,
      builder: (context, count, _) {
        return InkWell(
          onTap: () => onTap(context),
          hoverColor: theme.colorScheme.primary.withAlpha(50),
          child: Container(
            padding: EdgeInsets.only(left: 12, right: 8, top: paddingV, bottom: paddingV),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 4),
                Text(l10n.calendarTasks, style: TextStyle(fontSize: 14)),
                const Spacer(),
                if (count > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(8)),
                    child: Text('$count', style: TextStyle(fontSize: 12, color: theme.colorScheme.onPrimary)),
                  ),
                Icon(Icons.arrow_forward_ios_outlined, size: 14),
              ],
            ),
          ),
        );
      },
    );
  }
}
