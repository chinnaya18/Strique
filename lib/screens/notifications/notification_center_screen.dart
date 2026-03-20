import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/cross_device_sync_service.dart';
import '../../models/notification_model.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final _syncService = CrossDeviceSyncService();

  @override
  void initState() {
    super.initState();
    // Mark all as read when opening notification center
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.userId != null) {
        _syncService.markAllNotificationsAsRead(authProvider.userId!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userId = authProvider.userId;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () async {
              await _syncService.markAllNotificationsAsRead(userId);
            },
            child: const Text('Mark All Read'),
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _syncService.getUserNotifications(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '🔕 No Notifications',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'re all caught up!',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data!;

          return ListView.builder(
            itemCount: notifications.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _buildNotificationTile(context, notification);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationTile(
    BuildContext context,
    NotificationModel notification,
  ) {
    final icon = _getNotificationIcon(notification.type);
    final color = _getNotificationColor(notification.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(icon, style: const TextStyle(fontSize: 24)),
          ),
        ),
        title: Text(
          notification.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(notification.body),
            const SizedBox(height: 6),
            Text(
              _formatTime(notification.createdAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        trailing: notification.isRead
            ? null
            : Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
        onLongPress: () {
          _showDeleteDialog(context, notification);
        },
      ),
    );
  }

  String _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.friendRequest:
        return '👥';
      case NotificationType.friendRequestAccepted:
        return '✅';
      case NotificationType.friendRequestRejected:
        return '❌';
      case NotificationType.streakReminder:
        return '🔥';
      case NotificationType.friendStreakWarning:
        return '⚠️';
      case NotificationType.friendCompletedTask:
        return '🎉';
      case NotificationType.friendshipStreakIncrement:
        return '🔥';
      case NotificationType.streakResetWarning:
        return '⏰';
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.friendRequest:
      case NotificationType.friendRequestAccepted:
        return Colors.blue;
      case NotificationType.streakReminder:
      case NotificationType.friendshipStreakIncrement:
        return Colors.orange;
      case NotificationType.friendStreakWarning:
      case NotificationType.streakResetWarning:
        return Colors.red;
      case NotificationType.friendCompletedTask:
        return Colors.green;
      case NotificationType.friendRequestRejected:
        return Colors.grey;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minutes ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hours ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${dateTime.month}/${dateTime.day}';
    }
  }

  void _showDeleteDialog(
    BuildContext context,
    NotificationModel notification,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notification?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _syncService.deleteNotification(notification.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
