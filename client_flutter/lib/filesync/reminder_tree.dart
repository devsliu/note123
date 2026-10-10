import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:note123/filesync/database.dart';
import 'package:note123/filesync/table_record.dart';

/// A single reminder task embedded in a record.
/// Stored as a JSON array string in the record's `reminder` field.
///
/// Date/time is encoded with two integers:
/// - [time]: `HHmm` (4 digits), e.g. `1203` = 12:03, `0059` = 00:59.
/// - [date]: depends on [repeat]:
///   * once: `YYYYMMDD` (e.g. `20380903` = 2038-09-03).
///   * yearly: `MMDD` (e.g. `0903` = Sep 3).
///   * monthly: day of month, 1-31.
///   * weekly: concatenation of selected weekday digits 1(Mon)..7(Sun),
///     sorted ascending, e.g. `12567` = Mon/Tue/Fri/Sat/Sun.
class ReminderTask {
  /// Repeat mode constants.
  static const int repeatOnce = 0;
  static const int repeatWeekly = 1;
  static const int repeatMonthly = 2;
  static const int repeatYearly = 3;

  String id;
  String name;

  /// Date part, encoded per [repeat]. 0 = unset.
  int date;

  /// Time part, encoded as `HHmm`. 0 = unset.
  int time;

  /// Repeat mode: one of [repeatOnce], [repeatWeekly], [repeatMonthly], [repeatYearly].
  int repeat;

  /// Whether the task is completed.
  bool done;

  ReminderTask({
    required this.id,
    required this.name,
    this.date = 0,
    this.time = 0,
    this.repeat = repeatOnce,
    this.done = false,
  });

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'date': date, 'time': time, 'repeat': repeat, 'done': done};

  factory ReminderTask.fromJson(Map<String, dynamic> json) {
    final repeat = json['repeat'] as int? ?? repeatOnce;
    int date = json['date'] as int? ?? 0;
    int time = json['time'] as int? ?? 0;

    // Backward-compat: migrate from legacy `remindAt` / `weekdays` fields.
    if (date == 0 && time == 0) {
      final remindAt = json['remindAt'] as int? ?? 0;
      if (remindAt > 0) {
        final dt = DateTime.fromMillisecondsSinceEpoch(remindAt);
        time = dt.hour * 100 + dt.minute;
        switch (repeat) {
          case repeatOnce:
            date = dt.year * 10000 + dt.month * 100 + dt.day;
            break;
          case repeatYearly:
            date = dt.month * 100 + dt.day;
            break;
          case repeatMonthly:
            date = dt.day;
            break;
          case repeatWeekly:
            final wd = (json['weekdays'] as List?)?.map((e) => e as int).toList() ?? <int>[];
            wd.sort();
            date = int.tryParse(wd.join()) ?? 0;
            break;
        }
      }
    }

    return ReminderTask(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      date: date,
      time: time,
      repeat: repeat,
      done: json['done'] as bool? ?? false,
    );
  }

  /// Parse a JSON array string into a list of tasks. Empty/invalid input → [].
  static List<ReminderTask> fromJsonString(String jsonStr) {
    if (jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List;
      return list.map((e) => ReminderTask.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Serialize a list of tasks to a JSON array string.
  static String toJsonString(List<ReminderTask> tasks) {
    return jsonEncode(tasks.map((e) => e.toJson()).toList());
  }

  /// Hour parsed from [time] (0-23), clamped into range.
  int get hour => (time ~/ 100).clamp(0, 23);

  /// Minute parsed from [time] (0-59), clamped into range.
  int get minute => (time % 100).clamp(0, 59);

  /// Weekday set (1=Mon..7=Sun) parsed from [date] in weekly mode.
  Set<int> get weekdaySet {
    if (repeat != repeatWeekly) return {};
    return _digitsOf(date);
  }

  /// For once-mode: (year, month, day) parsed from [date] (`YYYYMMDD`).
  (int, int, int) get onceDate {
    final d = _parseDateInt(date);
    return (d.year, d.month, d.day);
  }

  /// For yearly-mode: (month, day) parsed from [date] (`MMDD`).
  (int, int) get yearlyMonthDay => _parseMonthDay(date);

  /// For monthly-mode: day of month, clamped to 1-31.
  int get monthlyDay => date.clamp(1, 31);

  /// Encode (year, month, day) as an 8-digit `YYYYMMDD` int.
  static int encodeOnceDate(int year, int month, int day) => year * 10000 + month * 100 + day;

  /// Encode (month, day) as a 4-digit `MMDD` int.
  static int encodeYearlyDate(int month, int day) => month * 100 + day;

  /// Encode a weekday list (1-7) into the sorted digit-concatenation int.
  static int encodeWeeklyDate(List<int> weekdays) {
    final sorted = [...weekdays]..sort();
    var result = 0;
    for (final d in sorted) {
      result = result * 10 + d;
    }
    return result;
  }

  /// Encode (hour, minute) as a 4-digit `HHmm` int.
  static int encodeTime(int hour, int minute) => hour * 100 + minute;
}

// ---------------------------------------------------------------------------
// Occurrence helpers
// ---------------------------------------------------------------------------

/// Parse an 8-digit `YYYYMMDD` int into a [DateTime] (date only).
/// Out-of-range month/day are clamped into valid ranges.
DateTime _parseDateInt(int date) {
  final y = (date ~/ 10000).clamp(0, 9999);
  final m = ((date ~/ 100) % 100).clamp(1, 12);
  final d = (date % 100).clamp(1, 31);
  return DateTime(y, m, d);
}

/// Parse a 4-digit `MMDD` int into (month, day).
/// Out-of-range values are clamped into valid ranges.
(int, int) _parseMonthDay(int date) {
  final m = ((date ~/ 100) % 100).clamp(1, 12);
  final d = (date % 100).clamp(1, 31);
  return (m, d);
}

/// Extract the decimal digits of [n] as a set of ints (1-7 filtered).
Set<int> _digitsOf(int n) {
  final set = <int>{};
  var v = n.abs();
  while (v > 0) {
    final d = v % 10;
    if (d >= 1 && d <= 7) set.add(d);
    v ~/= 10;
  }
  return set;
}

/// Returns the next occurrence of [task] strictly after [from], or null.
DateTime? nextReminderOccurrence(ReminderTask task, DateTime from) {
  final hour = task.hour;
  final minute = task.minute;

  switch (task.repeat) {
    case ReminderTask.repeatOnce:
      {
        final d = _parseDateInt(task.date);
        final full = DateTime(d.year, d.month, d.day, hour, minute);
        return full.isAfter(from) ? full : null;
      }
    case ReminderTask.repeatWeekly:
      {
        final days = task.weekdaySet;
        if (days.isEmpty) return null;
        var cursor = DateTime(from.year, from.month, from.day, hour, minute);
        if (!cursor.isAfter(from)) cursor = cursor.add(const Duration(days: 1));
        for (var i = 0; i < 8; i++) {
          if (days.contains(cursor.weekday)) return cursor;
          cursor = cursor.add(const Duration(days: 1));
        }
        return null;
      }
    case ReminderTask.repeatMonthly:
      {
        final day = task.monthlyDay;
        var y = from.year;
        var m = from.month;
        for (var i = 0; i < 13; i++) {
          final dim = DateTime(y, m + 1, 0).day;
          final d = day.clamp(1, dim);
          final dt = DateTime(y, m, d, hour, minute);
          if (dt.isAfter(from)) return dt;
          m++;
          if (m > 12) {
            m = 1;
            y++;
          }
        }
        return null;
      }
    case ReminderTask.repeatYearly:
      {
        final md = _parseMonthDay(task.date);
        final m = md.$1;
        final day = md.$2;
        var y = from.year;
        for (var i = 0; i < 10; i++) {
          final dim = DateTime(y, m + 1, 0).day;
          final dd = day.clamp(1, dim);
          final dt = DateTime(y, m, dd, hour, minute);
          if (dt.isAfter(from)) return dt;
          y++;
        }
        return null;
      }
  }
  return null;
}

/// Whether [task] has any occurrence during the given calendar [day].
bool reminderOccursOnDay(ReminderTask task, DateTime day) {
  final from = DateTime(day.year, day.month, day.day).subtract(const Duration(milliseconds: 1));
  final next = nextReminderOccurrence(task, from);
  if (next == null) return false;
  return next.year == day.year && next.month == day.month && next.day == day.day;
}

/// A reminder task together with its owning record's metadata.
class ReminderEntry {
  final String recordUuid;
  final String recordName;
  final String recordPath;
  final ReminderTask task;

  ReminderEntry({required this.recordUuid, required this.recordName, required this.recordPath, required this.task});

  /// Effective sort timestamp: next upcoming occurrence, or 0 if none.
  int get sortAt => nextReminderOccurrence(task, DateTime.now())?.millisecondsSinceEpoch ?? 0;
}

/// Holds all reminder entries extracted from records, kept in sync with the
/// owning [RecordTree]. Callers read reminders from here instead of scanning
/// the database directly.
class ReminderTree {
  final List<ReminderEntry> _entries = [];
  final Map<String, List<ReminderEntry>> _byRecord = {};

  /// Bumped whenever the reminder set changes. Listeners can re-read [entries]
  /// to get the latest snapshot.
  final ValueNotifier<int> refreshNotifier = ValueNotifier<int>(0);

  /// All reminder entries, sorted ascending by [ReminderEntry.sortAt].
  List<ReminderEntry> get entries => List.unmodifiable(_entries);

  /// Rebuild from a full record list (used on initial load).
  void rebuild(List<LocalRecord> records) {
    _entries.clear();
    _byRecord.clear();
    for (final record in records) {
      _addRecord(record);
    }
    _sort();
    _notify();
  }

  /// Insert or update a single record's reminders.
  void upsertRecord(LocalRecord record) {
    final old = _byRecord.remove(record.uuid);
    if (old != null) old.forEach(_entries.remove);

    final added = _addRecord(record);

    // Only sort and notify when something actually changed.
    if (old != null || added) {
      _sort();
      _notify();
    }
  }

  /// Remove all reminders belonging to [uuid].
  void deleteRecord(String uuid) {
    final removed = _byRecord.remove(uuid);
    if (removed == null) return;
    removed.forEach(_entries.remove);
    _notify();
  }

  /// Reminder tasks belonging to [uuid], or empty list if none.
  List<ReminderTask> tasksForRecord(String uuid) {
    return _byRecord[uuid]?.map((e) => e.task).toList() ?? const [];
  }

  /// Entries that occur on the given calendar [day].
  List<ReminderEntry> entriesForDay(DateTime day) {
    return _entries.where((e) => reminderOccursOnDay(e.task, day)).toList();
  }

  void _notify() {
    refreshNotifier.value++;
  }

  /// Adds a record's reminders. Returns true if any entries were added.
  bool _addRecord(LocalRecord record) {
    if (record.localEditType == LocalEditType.delete) return false;
    final json = record.localReminder.isNotEmpty ? record.localReminder : record.remoteReminder;
    if (json.isEmpty) return false;
    final tasks = ReminderTask.fromJsonString(json);
    if (tasks.isEmpty) return false;
    final list = <ReminderEntry>[];
    for (final task in tasks) {
      list.add(
        ReminderEntry(
          recordUuid: record.uuid,
          recordName: record.localName.isNotEmpty ? record.localName : record.remoteName,
          recordPath: record.localPath.isNotEmpty ? record.localPath : record.remotePath,
          task: task,
        ),
      );
    }
    _byRecord[record.uuid] = list;
    _entries.addAll(list);
    return true;
  }

  void _sort() {
    _entries.sort((a, b) => a.sortAt.compareTo(b.sortAt));
  }
}
