import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../features/tasks/domain/task.dart';
import '../core/utils/currency_formatter.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _channelId = 'task_reminders';
  static const _channelName = 'Task Reminders';

  static Future<void> init() async {
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
  }

  static Future<bool> requestPermissions() async {
    final iosGranted = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    final androidGranted = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    return (iosGranted ?? false) || (androidGranted ?? false);
  }

  static Future<void> scheduleTaskReminder(Task task) async {
    final reminderTime = task.dueDate.subtract(const Duration(hours: 1));
    if (reminderTime.isBefore(DateTime.now())) return;

    final tzReminderTime = tz.TZDateTime.from(reminderTime, tz.local);

    String body;
    if (task.hasReward) {
      body =
          'Earn ${CurrencyFormatter.formatCompact(task.rewardAmount)} by completing on time!';
    } else if (task.hasPenalty) {
      body =
          '${CurrencyFormatter.formatCompact(task.penaltyAmount)} penalty if missed!';
    } else {
      body = "Don't miss your deadline!";
    }

    await _plugin.zonedSchedule(
      task.id.hashCode,
      '⏰ Due soon: ${task.title}',
      body,
      tzReminderTime,
      _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: task.id,
    );
  }

  static Future<void> cancelTaskReminder(String taskId) async {
    await _plugin.cancel(taskId.hashCode);
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  static NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Reminders for upcoming task deadlines',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
  }
}
