import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../config/constants.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    try {
      tzdata.initializeTimeZones();

      if (kIsWeb) {
        // flutter_local_notifications does not support web natively.
        // On web we skip plugin init - notifications won't fire but app won't crash.
        _initialized = false;
        return;
      }

      // Mobile / desktop platforms
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );
      _initialized = true;
    } catch (e) {
      print('Notification initialization error: $e');
      _initialized = false;
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    // Handle notification tap
  }

  /// Schedule daily reminder
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    try {
      // Save preference regardless of platform
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.prefReminderTime, '$hour:$minute');

      if (!_initialized) return;

      await _notifications.zonedSchedule(
        id: 0,
        title: '\ud83d\udd25 ${AppConstants.appName}',
        body: 'Time to complete your habits! Keep your streak alive!',
        scheduledDate: _nextInstanceOfTime(hour, minute),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            AppConstants.dailyReminderChannel,
            'Daily Reminders',
            channelDescription: 'Daily habit completion reminders',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      print('Error scheduling daily reminder: $e');
    }
  }

  /// Send streak risk notification
  Future<void> sendStreakRiskAlert() async {
    try {
      if (!_initialized) return;

      await _notifications.show(
        id: 1,
        title: '\u26a0\ufe0f Streak at Risk!',
        body:
            'You haven\'t completed all your habits today. Don\'t break your streak!',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            AppConstants.streakAlertChannel,
            'Streak Alerts',
            channelDescription: 'Alerts when your streak is at risk',
            importance: Importance.max,
            priority: Priority.max,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    } catch (e) {
      print('Error sending streak alert: $e');
    }
  }

  /// Send friend activity notification
  Future<void> sendFriendAlert(String friendName) async {
    try {
      if (!_initialized) return;

      await _notifications.show(
        id: 2,
        title: '\ud83d\udc4b Friend Activity',
        body: '$friendName completed their habits! Can you keep up?',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            AppConstants.friendAlertChannel,
            'Friend Alerts',
            channelDescription: 'Friend activity notifications',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    } catch (e) {
      print('Error sending friend alert: $e');
    }
  }

  /// Send "Push your friend!" notification when a friend hasn't completed tasks by 9 PM
  Future<void> sendPushFriendAlert(String friendName) async {
    try {
      if (!_initialized) return;

      await _notifications.show(
        id: 10 + friendName.hashCode.abs() % 1000,
        title: '\ud83d\udca5 Push Your Friend!',
        body: '$friendName hasn\'t completed their habits yet today! Send them a nudge to keep the friendship streak alive! \ud83d\udd25',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            AppConstants.friendAlertChannel,
            'Friend Alerts',
            channelDescription: 'Friend accountability notifications',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    } catch (e) {
      print('Error sending push friend alert: $e');
    }
  }

  /// Send "Save your friend!" notification when the user hasn't completed tasks
  Future<void> sendSaveFriendAlert(String userName) async {
    try {
      if (!_initialized) return;

      await _notifications.show(
        id: 20 + userName.hashCode.abs() % 1000,
        title: '\ud83d\udea8 Save Your Friend!',
        body: 'Your friend $userName\'s streak is at risk because you haven\'t completed your habits! Complete them now to save the friendship streak! \ud83d\udcaa',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            AppConstants.friendAlertChannel,
            'Friend Alerts',
            channelDescription: 'Friend accountability notifications',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    } catch (e) {
      print('Error sending save friend alert: $e');
    }
  }

  /// Schedule 9 PM friend accountability check
  Future<void> scheduleFriendAccountabilityCheck() async {
    try {
      if (!_initialized) return;

      await _notifications.zonedSchedule(
        id: 9,
        title: '\ud83d\udc65 Friend Accountability Check',
        body: 'Check if your friends have completed their habits today!',
        scheduledDate: _nextInstanceOfTime(21, 0),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            AppConstants.friendAlertChannel,
            'Friend Alerts',
            channelDescription: 'Friend accountability check at 9 PM',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      print('Error scheduling friend accountability check: $e');
    }
  }

  /// Send birthday notification
  Future<void> sendBirthdayNotification() async {
    try {
      if (!_initialized) return;

      await _notifications.show(
        id: 3,
        title: '\ud83c\udf82 Happy Birthday!',
        body: AppConstants.birthdayMessage,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            AppConstants.dailyReminderChannel,
            'Daily Reminders',
            channelDescription: 'Daily reminders',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    } catch (e) {
      print('Error sending birthday notification: $e');
    }
  }

  /// Send friend request notification
  Future<void> showFriendRequestNotification({
    required String friendName,
    required String requestId,
  }) async {
    try {
      if (!_initialized) return;

      await _notifications.show(
        id: requestId.hashCode,
        title: '👥 Friend Request',
        body: '$friendName wants to connect!',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            AppConstants.dailyReminderChannel,
            'Friend Requests',
            channelDescription: 'Notifications for friend requests',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    } catch (e) {
      print('Error sending friend request notification: $e');
    }
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    try {
      if (!_initialized) return;
      await _notifications.cancelAll();
    } catch (e) {
      print('Error canceling notifications: $e');
    }
  }

  /// Send notification for incomplete habits
  Future<void> sendIncompleteHabitsAlert({
    required int pendingHabits,
    required int pendingTasks,
  }) async {
    try {
      if (!_initialized) return;

      String body;
      if (pendingHabits > 0 && pendingTasks > 0) {
        body =
            'You have $pendingHabits habit${pendingHabits > 1 ? 's' : ''} and '
            '$pendingTasks task${pendingTasks > 1 ? 's' : ''} left to complete today. '
            'Don\'t break your streak!';
      } else if (pendingHabits > 0) {
        body =
            'You have $pendingHabits habit${pendingHabits > 1 ? 's' : ''} left to complete today. '
            'Keep going!';
      } else {
        body =
            'You have $pendingTasks task${pendingTasks > 1 ? 's' : ''} left to finish today. '
            'Complete them to stay on track!';
      }

      await _notifications.show(
        id: 4,
        title: '\u23f0 Incomplete Tasks & Habits',
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            AppConstants.streakAlertChannel,
            'Streak Alerts',
            channelDescription: 'Alerts for incomplete habits and tasks',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    } catch (e) {
      print('Error sending incomplete habits alert: $e');
    }
  }

  /// Schedule evening reminder for incomplete habits/tasks
  Future<void> scheduleEveningReminder({int hour = 20, int minute = 0}) async {
    try {
      if (!_initialized) return;

      await _notifications.zonedSchedule(
        id: 5,
        title: '\ud83c\udf19 Evening Check-in',
        body:
            'Have you completed all your habits and tasks today? '
            'Open the app to check your progress!',
        scheduledDate: _nextInstanceOfTime(hour, minute),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            AppConstants.dailyReminderChannel,
            'Daily Reminders',
            channelDescription: 'Evening reminder for incomplete habits',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      print('Error scheduling evening reminder: $e');
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
