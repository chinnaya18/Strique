import 'package:flutter/material.dart';
import '../services/cross_device_sync_service.dart';
import '../models/notification_model.dart';

class NotificationProvider extends ChangeNotifier {
  final _syncService = CrossDeviceSyncService();
  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;

  /// Initialize notifications stream for a user
  void initNotifications(String userId) {
    _syncService.getUserNotifications(userId).listen((notifications) {
      _notifications = notifications;
      _unreadCount = notifications.where((n) => !n.isRead).length;
      notifyListeners();
    });
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    await _syncService.markNotificationAsRead(notificationId);
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    await _syncService.deleteNotification(notificationId);
  }
}
