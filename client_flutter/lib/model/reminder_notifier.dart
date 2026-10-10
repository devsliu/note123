import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:note123/filesync/record_tree.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/model/reminder_task.dart';
import 'package:note123/config/app_config.dart';
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
class ReminderNotifier {
  static final ReminderNotifier instance = ReminderNotifier._();
  ReminderNotifier._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Task ids currently scheduled, keyed by record uuid. Used to cancel the
  /// previous notifications of a record when it is updated or deleted.
  final Map<String, List<String>> _recordTaskIds = {};

  static const String _channelId = 'reminder';
  static const String _channelName = '提醒';

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
    const linux = LinuxInitializationSettings(defaultActionName: '提醒');
    const windows = WindowsInitializationSettings(
      appName: AppConfig.appTitle,
      appUserModelId: AppConfig.packageName,
      guid: _windowsGuid,
    );
    const settings = InitializationSettings(android: android, iOS: ios, linux: linux, windows: windows);
    try {
      await _plugin.initialize(settings: settings);
    } catch (e) {
      AppLogger.e("[ReminderNotifier] initialize failed: $e");
      return;
    }

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    Repository.get().recordTree.refreshNotifier.addListener(_onTreeChanged);

    _initialized = true;
    AppLogger.d("[ReminderNotifier] initialized");

    // One full pass at startup.
    unawaited(rescheduleAll());
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
    final taskIds = _recordTaskIds.remove(recordUuid);
    if (taskIds == null) return;
    for (final tid in taskIds) {
      unawaited(_plugin.cancel(id: _notificationId(tid)));
    }
    AppLogger.d("[ReminderNotifier] cancelled record $recordUuid (${taskIds.length} tasks)");
  }

  /// Re-schedule the reminders of a single (updated or newly inserted) record.
  Future<void> _upsertRecord(String? recordUuid) async {
    if (recordUuid == null) return;
    if (!_initialized) await init();

    // Cancel the previous notifications for this record first.
    _cancelRecord(recordUuid);

    final file = Repository.get().recordTree.findFile(recordUuid);
    final record = file?.record;
    if (record == null) return;

    final json = record.localReminder.isNotEmpty ? record.localReminder : record.remoteReminder;
    if (json.isEmpty) return;

    final tasks = ReminderTask.fromJsonString(json);
    final detail = _notificationDetails();
    final now = DateTime.now().millisecondsSinceEpoch;
    final scheduledIds = <String>[];

    for (final task in tasks) {
      if (task.done || task.remindAt == null || task.remindAt! <= now) continue;
      if (await _scheduleTask(task, detail)) {
        scheduledIds.add(task.id);
      }
    }

    if (scheduledIds.isNotEmpty) {
      _recordTaskIds[recordUuid] = scheduledIds;
    }
    AppLogger.d("[ReminderNotifier] upsert record $recordUuid: ${scheduledIds.length} scheduled");
  }

  /// Schedule a single task notification. Returns true on success.
  Future<bool> _scheduleTask(ReminderTask task, NotificationDetails detail) async {
    if (task.remindAt == null) return false;
    final id = _notificationId(task.id);
    final title = task.name.isEmpty ? '提醒' : task.name;
    final body = _buildBody(task);
    try {
      final scheduledTime = tz.TZDateTime.fromMillisecondsSinceEpoch(tz.local, task.remindAt!);
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledTime,
        notificationDetails: detail,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      return true;
    } catch (e) {
      AppLogger.e("[ReminderNotifier] schedule failed for task ${task.id}: $e");
      return false;
    }
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
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: '笔记任务提醒',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(),
      linux: LinuxNotificationDetails(),
      windows: WindowsNotificationDetails(),
    );
  }

  String _buildBody(ReminderTask task) {
    if (task.dueAt == null) return '该提醒已到时间';
    final due = DateTime.fromMillisecondsSinceEpoch(task.dueAt!);
    final mm = due.month.toString().padLeft(2, '0');
    final dd = due.day.toString().padLeft(2, '0');
    final hh = due.hour.toString().padLeft(2, '0');
    final mi = due.minute.toString().padLeft(2, '0');
    return '截止: ${due.year}-$mm-$dd $hh:$mi';
  }

  /// Full rescan: cancel everything and schedule all reminders from the DB.
  /// Called once at startup.
  Future<void> rescheduleAll() async {
    if (!_initialized) await init();
    final db = Repository.get().db;
    if (db == null) return;

    await _plugin.cancelAll();
    _recordTaskIds.clear();

    final records = await db.getRecordsWithReminders();
    final detail = _notificationDetails();
    final now = DateTime.now().millisecondsSinceEpoch;
    int scheduled = 0;

    for (final record in records) {
      final json = record.localReminder.isNotEmpty ? record.localReminder : record.remoteReminder;
      if (json.isEmpty) continue;
      final tasks = ReminderTask.fromJsonString(json);
      final ids = <String>[];
      for (final task in tasks) {
        if (task.done || task.remindAt == null || task.remindAt! <= now) continue;
        if (await _scheduleTask(task, detail)) {
          ids.add(task.id);
          scheduled++;
        }
      }
      if (ids.isNotEmpty) {
        _recordTaskIds[record.uuid] = ids;
      }
    }
    AppLogger.d("[ReminderNotifier] rescheduleAll: $scheduled scheduled across ${records.length} records");
  }

  /// Show a notification immediately. Useful for verifying that the platform
  /// notification channel works (Windows toast / Android channel / iOS).
  Future<void> showTestNotification() async {
    if (!_initialized) await init();
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
