import 'package:note123/filesync/repository.dart';
import 'package:note123/model/reminder_task.dart';

/// A reminder task together with its owning record's metadata.
class ReminderEntry {
  final String recordUuid;
  final String recordName;
  final String recordPath;
  final ReminderTask task;

  ReminderEntry({required this.recordUuid, required this.recordName, required this.recordPath, required this.task});

  /// Effective sort timestamp: remindAt if set, else dueAt, else far future.
  int get sortAt => task.remindAt ?? task.dueAt ?? 0;
}

/// Collect every reminder task from every local record (localReminder takes
/// priority over remoteReminder). Sorted ascending by [ReminderEntry.sortAt].
Future<List<ReminderEntry>> collectAllReminders() async {
  final db = Repository.get().db;
  if (db == null) return [];
  final records = await db.getAllLocalRecords();
  final entries = <ReminderEntry>[];
  for (final record in records) {
    final json = record.localReminder.isNotEmpty ? record.localReminder : record.remoteReminder;
    if (json.isEmpty) continue;
    final tasks = ReminderTask.fromJsonString(json);
    for (final task in tasks) {
      entries.add(
        ReminderEntry(
          recordUuid: record.uuid,
          recordName: record.localName.isNotEmpty ? record.localName : record.remoteName,
          recordPath: record.localPath.isNotEmpty ? record.localPath : record.remotePath,
          task: task,
        ),
      );
    }
  }
  entries.sort((a, b) => a.sortAt.compareTo(b.sortAt));
  return entries;
}
