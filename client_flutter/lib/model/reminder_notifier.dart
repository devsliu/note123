import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:note123/filesync/record_tree.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/filesync/reminder_tree.dart';
import 'package:note123/config/app_config.dart';
import 'package:note123/config/language_manager.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:note123/utils/app_logger.dart';

/// Schedules local notifications for reminder tasks.
///
/// Strategy:
/// - At startup [rescheduleAll] loads every reminder and schedules it.
/// - Afterwards, [RecordTree.refreshNotifier] drives incremental updates:
///   each upsert/delete event only touches the affected record's tasks
///   (cancel old notification ids, then schedule the new ones).
class ReminderNotifier with WidgetsBindingObserver {
  static final ReminderNotifier instance = ReminderNotifier._();
  ReminderNotifier._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Notification ids currently scheduled, keyed by record uuid. Each task may
  /// contribute several ids (one per upcoming occurrence), so we store the
  /// raw notification ids to cancel on record update/delete.
  final Map<String, List<int>> _recordTaskIds = {};

  static const String _channelId = 'reminder';

  /// Stable GUID used for the Windows notification COM server registration.
  static const String _windowsGuid = '1B6FE65B-3B6F-4A2E-8E3A-2C4F5D6E7A8B';

  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));

    const android = AndroidInitializationSettings('@drawable/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    final linux = LinuxInitializationSettings(defaultActionName: l10n.reminderChannel);
    const windows = WindowsInitializationSettings(
      appName: AppConfig.appTitle,
      appUserModelId: AppConfig.packageName,
      guid: _windowsGuid,
    );
    final settings = InitializationSettings(android: android, iOS: ios, linux: linux, windows: windows);
    try {
      await _plugin.initialize(settings: settings);
    } catch (e) {
      AppLogger.e("[ReminderNotifier] initialize failed: $e");
      return;
    }

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    Repository.get().recordTree.refreshNotifier.addListener(_onTreeChanged);
    WidgetsBinding.instance.addObserver(this);

    _initialized = true;
    AppLogger.d("[ReminderNotifier] initialized");

    // One full pass at startup.
    unawaited(rescheduleAll());
  }

  /// Roll recurring reminders forward when the app returns to the foreground.
  /// Without this, pre-scheduled occurrences could run out if the app stayed
  /// backgrounded for a long time.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _initialized) {
      unawaited(rescheduleAll());
    }
  }

  /// React to record tree changes. Folder events are ignored. Each record
  /// upsert/delete is handled incrementally (no full rescan).
  void _onTreeChanged() {
    final events = Repository.get().recordTree.refreshNotifier.value;
    for (final e in events) {
      if (e.type == RecordEvent.typeDeleteRecord) {
        _cancelRecord(e.value2);
      } else if (e.type == RecordEvent.typeUpsertRecord) {
        unawaited(_upsertRecord(e.value2));
      }
    }
  }

  /// Cancel every notification belonging to [recordUuid].
  void _cancelRecord(String? recordUuid) {
    if (recordUuid == null) return;
    final ids = _recordTaskIds.remove(recordUuid);
    if (ids == null || ids.isEmpty) return;
    for (final id in ids) {
      unawaited(_plugin.cancel(id: id));
    }
    AppLogger.d("[ReminderNotifier] cancelled record $recordUuid (${ids.length} notifications)");
  }

  /// Re-schedule the reminders of a single (updated or newly inserted) record.
  Future<void> _upsertRecord(String? recordUuid) async {
    if (recordUuid == null) return;

    // Cancel the previous notifications for this record first.
    _cancelRecord(recordUuid);

    final tasks = Repository.get().reminderTree.tasksForRecord(recordUuid);
    if (tasks.isEmpty) return;

    final detail = _notificationDetails();
    final now = DateTime.now().millisecondsSinceEpoch;
    final scheduledIds = <int>[];

    for (final task in tasks) {
      if (task.done) continue;
      final newIds = await _scheduleTask(task, now, detail);
      scheduledIds.addAll(newIds);
    }

    if (scheduledIds.isNotEmpty) {
      _recordTaskIds[recordUuid] = scheduledIds;
    }
    AppLogger.d("[ReminderNotifier] upsert record $recordUuid: ${scheduledIds.length} notifications scheduled");
  }

  /// Number of upcoming occurrences to pre-schedule per task. Higher values
  /// keep reminders firing even if the app stays closed for a long time, at
  /// the cost of more pending notifications.
  int _aheadCountFor(int repeat) {
    switch (repeat) {
      case ReminderTask.repeatWeekly:
        return 30;
      case ReminderTask.repeatMonthly:
        return 12;
      case ReminderTask.repeatYearly:
        return 10;
      default:
        return 1;
    }
  }

  /// Compute the next [count] occurrence timestamps (ms since epoch) for
  /// [task], strictly after [fromMs]. Returns an empty list for once-tasks
  /// whose time has already passed.
  List<int> _nextOccurrences(ReminderTask task, int fromMs, int count) {
    if (count <= 0) return [];
    final from = DateTime.fromMillisecondsSinceEpoch(fromMs);
    final result = <int>[];
    var cursor = from;
    for (var i = 0; i < count; i++) {
      final next = nextReminderOccurrence(task, cursor);
      if (next == null) break;
      result.add(next.millisecondsSinceEpoch);
      cursor = next;
    }
    return result;
  }

  /// Schedule all upcoming occurrences of [task]. Returns the list of
  /// notification ids that were successfully scheduled.
  Future<List<int>> _scheduleTask(ReminderTask task, int fromMs, NotificationDetails detail) async {
    if (task.time <= 0) return [];
    final count = _aheadCountFor(task.repeat);
    final times = _nextOccurrences(task, fromMs, count);
    if (times.isEmpty) return [];

    final title = task.name.isEmpty ? l10n.reminder : task.name;
    final body = _buildBody(task);
    final ids = <int>[];

    for (var i = 0; i < times.length; i++) {
      final id = _notificationId('${task.id}_$i');
      try {
        final scheduledTime = tz.TZDateTime.fromMillisecondsSinceEpoch(tz.local, times[i]);
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduledTime,
          notificationDetails: detail,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
        ids.add(id);
      } catch (e) {
        AppLogger.e("[ReminderNotifier] schedule failed for task ${task.id} occurrence $i: $e");
      }
    }
    return ids;
  }

  /// Stable positive int32 id from a task id string (FNV-1a).
  int _notificationId(String taskId) {
    var hash = 2166136261;
    for (final c in taskId.codeUnits) {
      hash = ((hash ^ c) * 16777619) & 0xFFFFFFFF;
    }
    return (hash % 0x7FFFFFFF) + 1;
  }

  NotificationDetails _notificationDetails() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        l10n.reminderChannel,
        channelDescription: l10n.reminderChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
      ),
      iOS: const DarwinNotificationDetails(),
      linux: const LinuxNotificationDetails(),
      windows: const WindowsNotificationDetails(),
    );
  }

  String _buildBody(ReminderTask task) {
    return l10n.reminderDueBody;
  }

  /// Full rescan: cancel everything and schedule all reminders from the
  /// reminder tree. Called once at startup. For recurring tasks the next
  /// several occurrences are pre-scheduled so they keep firing even if the app
  /// stays closed.
  Future<void> rescheduleAll() async {
    await _plugin.cancelAll();
    _recordTaskIds.clear();

    final entries = Repository.get().reminderTree.entries;
    if (entries.isEmpty) {
      AppLogger.d("[ReminderNotifier] rescheduleAll: no reminders");
      return;
    }

    // Group tasks by record uuid so each record's notification ids are tracked
    // together for later cancellation on update/delete.
    final byRecord = <String, List<ReminderTask>>{};
    for (final entry in entries) {
      byRecord.putIfAbsent(entry.recordUuid, () => []).add(entry.task);
    }

    final detail = _notificationDetails();
    final now = DateTime.now().millisecondsSinceEpoch;
    int scheduled = 0;

    for (final entry in byRecord.entries) {
      final ids = <int>[];
      for (final task in entry.value) {
        if (task.done) continue;
        final newIds = await _scheduleTask(task, now, detail);
        ids.addAll(newIds);
        scheduled += newIds.length;
      }
      if (ids.isNotEmpty) {
        _recordTaskIds[entry.key] = ids;
      }
    }
    AppLogger.d("[ReminderNotifier] rescheduleAll: $scheduled notifications across ${byRecord.length} records");
  }

  /// Show a notification immediately. Useful for verifying that the platform
  /// notification channel works (Windows toast / Android channel / iOS).
  Future<void> showTestNotification() async {
    try {
      await _plugin.show(
        id: 0,
        title: '通知测试',
        body: '如果你看到这条通知，说明通知通道正常工作',
        notificationDetails: _notificationDetails(),
      );
    } catch (e) {
      AppLogger.e("[ReminderNotifier] test notification failed: $e");
    }
  }
}
