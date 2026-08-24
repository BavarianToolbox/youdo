import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../features/tasks/domain/task.dart';
import '../core/utils/currency_formatter.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background message handling — Firebase handles display automatically
  debugPrint('Background FCM message: ${message.messageId}');
}

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

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification != null) {
        _showForegroundNotification(notification);
      }
    });
  }

  static Future<bool> requestPermissions() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final iosGranted = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        (iosGranted ?? false);
  }

  static Future<String?> getFcmToken() async {
    return FirebaseMessaging.instance.getToken();
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

  static void _showForegroundNotification(RemoteNotification notification) {
    _plugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      _notificationDetails(),
    );
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
