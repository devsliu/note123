import 'dart:convert';

/// A single reminder task embedded in a record.
/// Stored as a JSON array string in the record's `reminder` field.
class ReminderTask {
  String id;
  String name;

  /// Due time in milliseconds since epoch. null = no due date.
  int? dueAt;

  /// Reminder time in milliseconds since epoch. null = no reminder.
  int? remindAt;

  /// Whether the task is completed.
  bool done;

  ReminderTask({required this.id, required this.name, this.dueAt, this.remindAt, this.done = false});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'dueAt': dueAt, 'remindAt': remindAt, 'done': done};

  factory ReminderTask.fromJson(Map<String, dynamic> json) => ReminderTask(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    dueAt: json['dueAt'] as int?,
    remindAt: json['remindAt'] as int?,
    done: json['done'] as bool? ?? false,
  );

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
}
