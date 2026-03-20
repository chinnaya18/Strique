import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import '../models/notification_model.dart';
import '../config/constants.dart';

class CrossDeviceSyncService {
  static final CrossDeviceSyncService _instance =
      CrossDeviceSyncService._internal();
  factory CrossDeviceSyncService() => _instance;
  CrossDeviceSyncService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Request notification permissions
      await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        provisional: false,
        sound: true,
      );

      // Initialize timezone
      tzdata.initializeTimeZones();

      // Setup local notifications
      if (!kIsWeb) {
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
      }

      // Handle incoming messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      _initialized = true;
      debugPrint('✅ CrossDeviceSyncService initialized');
    } catch (e) {
      debugPrint('⚠️ CrossDeviceSyncService initialization failed: $e');
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    // Handle notification tap
    debugPrint('🔔 Notification tapped: ${response.payload}');
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📨 Foreground message: ${message.notification?.title}');
    _showLocalNotification(
      title: message.notification?.title ?? 'Strique',
      body: message.notification?.body ?? '',
      payload: message.data.toString(),
    );
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('🎯 Message opened app: ${message.notification?.title}');
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized || kIsWeb) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        AppConstants.friendAlertChannel,
        'Strique Notifications',
        channelDescription: 'Important notifications from Strique',
        importance: Importance.max,
        priority: Priority.high,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        id: title.hashCode,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('❌ Failed to show notification: $e');
    }
  }

  /// Create and store notification
  Future<void> createNotification({
    required String userId,
    required NotificationType type,
    required String title,
    required String body,
    String? senderId,
    String? senderName,
    String? data,
  }) async {
    try {
      final notification = NotificationModel(
        id: '',
        userId: userId,
        senderId: senderId,
        senderName: senderName,
        type: type,
        title: title,
        body: body,
        data: data,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection(AppConstants.notificationsCollection)
          .add(notification.toMap());

      // Show local notification
      await _showLocalNotification(
        title: title,
        body: body,
        payload: data,
      );
    } catch (e) {
      debugPrint('❌ Failed to create notification: $e');
    }
  }

  /// Get notifications for user
  Stream<List<NotificationModel>> getUserNotifications(String userId) {
    return _firestore
        .collection(AppConstants.notificationsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Get unread notifications count
  Stream<int> getUnreadNotificationCount(String userId) {
    return _firestore
        .collection(AppConstants.notificationsCollection)
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    await _firestore
        .collection(AppConstants.notificationsCollection)
        .doc(notificationId)
        .update({
          'isRead': true,
          'readAt': Timestamp.fromDate(DateTime.now()),
        });
  }

  /// Mark all notifications as read
  Future<void> markAllNotificationsAsRead(String userId) async {
    final snapshot = await _firestore
        .collection(AppConstants.notificationsCollection)
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    final now = Timestamp.fromDate(DateTime.now());

    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {
        'isRead': true,
        'readAt': now,
      });
    }

    await batch.commit();
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    await _firestore
        .collection(AppConstants.notificationsCollection)
        .doc(notificationId)
        .delete();
  }

  /// Delete old notifications (older than 30 days)
  Future<void> cleanupOldNotifications(String userId) async {
    final thirtyDaysAgo =
        DateTime.now().subtract(const Duration(days: 30));

    final snapshot = await _firestore
        .collection(AppConstants.notificationsCollection)
        .where('userId', isEqualTo: userId)
        .where('createdAt', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
        .get();

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  /// Send friend request notification
  Future<void> sendFriendRequestNotification({
    required String fromUserId,
    required String fromUserName,
    required String toUserId,
  }) async {
    await createNotification(
      userId: toUserId,
      type: NotificationType.friendRequest,
      title: '👥 Friend Request',
      body: '$fromUserName sent you a friend request!',
      senderId: fromUserId,
      senderName: fromUserName,
    );
  }

  /// Send friend request accepted notification
  Future<void> sendFriendRequestAcceptedNotification({
    required String fromUserId,
    required String fromUserName,
    required String toUserId,
  }) async {
    await createNotification(
      userId: toUserId,
      type: NotificationType.friendRequestAccepted,
      title: '✅ Request Accepted',
      body: '$fromUserName accepted your friend request!',
      senderId: fromUserId,
      senderName: fromUserName,
    );
  }

  /// Send streak reminder
  Future<void> sendStreakReminder({
    required String userId,
    required String userName,
  }) async {
    await createNotification(
      userId: userId,
      type: NotificationType.streakReminder,
      title: '🔥 Complete Your Tasks!',
      body: 'Complete your habit now to keep your streak alive!',
    );
  }

  /// Send friend completion notification
  Future<void> sendFriendCompletedNotification({
    required String toUserId,
    required String friendName,
  }) async {
    await createNotification(
      userId: toUserId,
      type: NotificationType.friendCompletedTask,
      title: '🎉 Friend Completed!',
      body: '$friendName completed their task today!',
    );
  }

  /// Send friend streak warning
  Future<void> sendFriendStreakWarning({
    required String toUserId,
    required String friendName,
    required int hoursRemaining,
  }) async {
    await createNotification(
      userId: toUserId,
      type: NotificationType.friendStreakWarning,
      title: '⚠️ Help Your Friend!',
      body:
          'Remind $friendName to complete their task in the next $hoursRemaining hours before their streak resets!',
    );
  }

  /// Send friendship streak increment notification
  Future<void> sendFriendshipStreakNotification({
    required String userId,
    required String friendName,
    required int streakCount,
  }) async {
    await createNotification(
      userId: userId,
      type: NotificationType.friendshipStreakIncrement,
      title: '🔥 Friendship Streak Fire!',
      body:
          'You and $friendName are on a $streakCount day streak together! 💪',
    );
  }

  /// Send streak reset warning (6 hours before reset)
  Future<void> sendStreakResetWarning({
    required String userId,
  }) async {
    await createNotification(
      userId: userId,
      type: NotificationType.streakResetWarning,
      title: '⏰ Time is Running Out!',
      body:
          'You have 6 hours left to complete your habit! Don\'t lose your streak! 🔥',
    );
  }

  /// Schedule 6-hour reminder before streak reset (at 6 PM for 24-hour cycle ending at midnight)
  Future<void> scheduleStreakResetWarnings(String userId) async {
    try {
      if (!_initialized || kIsWeb) return;

      // Schedule warning at 6 PM (6 hours before midnight reset)
      await _notifications.zonedSchedule(
        id: userId.hashCode % 100000,
        title: '⏰ Time is Running Out!',
        body: 'You have 6 hours left to complete your habit!',
        scheduledDate: _nextInstanceOfTime(18, 0),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            AppConstants.streakAlertChannel,
            'Streak Alerts',
            channelDescription: 'Warnings before streaks reset',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Failed to schedule streak warning: $e');
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }
}
