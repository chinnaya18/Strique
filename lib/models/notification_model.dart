import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  friendRequest,
  friendRequestAccepted,
  friendRequestRejected,
  streakReminder,
  friendStreakWarning,
  friendCompletedTask,
  friendshipStreakIncrement,
  streakResetWarning,
}

class NotificationModel {
  final String id;
  final String userId; // Recipient user ID
  final String? senderId; // Sender user ID (for friend-related notifications)
  final String? senderName;
  final NotificationType type;
  final String title;
  final String body;
  final String? data; // Additional data (friendship ID, habit ID, etc.)
  final DateTime createdAt;
  final bool isRead;
  final DateTime? readAt;

  NotificationModel({
    required this.id,
    required this.userId,
    this.senderId,
    this.senderName,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    required this.createdAt,
    this.isRead = false,
    this.readAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      id: id,
      userId: map['userId'] ?? '',
      senderId: map['senderId'],
      senderName: map['senderName'],
      type: NotificationType.values.firstWhere(
        (e) => e.name == (map['type'] ?? 'streakReminder'),
        orElse: () => NotificationType.streakReminder,
      ),
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      data: map['data'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      isRead: map['isRead'] ?? false,
      readAt: map['readAt'] != null
          ? (map['readAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'senderId': senderId,
      'senderName': senderName,
      'type': type.name,
      'title': title,
      'body': body,
      'data': data,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
    };
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? senderId,
    String? senderName,
    NotificationType? type,
    String? title,
    String? body,
    String? data,
    DateTime? createdAt,
    bool? isRead,
    DateTime? readAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
    );
  }
}
