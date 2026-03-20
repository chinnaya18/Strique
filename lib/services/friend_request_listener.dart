import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/friendship_model.dart';
import '../config/constants.dart';
import 'notification_service.dart';

class FriendRequestListener {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  StreamSubscription? _friendRequestSub;
  StreamSubscription? _notificationSub;
  
  Stream<List<FriendshipModel>> getPendingFriendRequests(String userId) {
    return _firestore
        .collection(AppConstants.friendshipsCollection)
        .where('user2Id', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FriendshipModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Listen for new friend requests and show notifications
  void listenForFriendRequests(String userId) {
    _friendRequestSub?.cancel();
    _friendRequestSub = getPendingFriendRequests(userId).listen((requests) {
      for (var request in requests) {
        _notificationService.showFriendRequestNotification(
          friendName: request.user1Name,
          requestId: request.id,
        );
      }
    });

    // Also listen for real-time notifications (friend activity, push/save alerts)
    _listenForNotifications(userId);
  }

  /// Listen for Firestore notification documents for cross-device real-time sync
  void _listenForNotifications(String userId) {
    _notificationSub?.cancel();
    _notificationSub = _firestore
        .collection(AppConstants.notificationsCollection)
        .where('targetUserId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;

          final type = data['type'] ?? '';
          final title = data['title'] ?? '';
          final body = data['body'] ?? '';

          switch (type) {
            case 'friend_completed':
              _notificationService.sendFriendAlert(
                body.toString().split(' completed').first,
              );
              break;
            case 'save_friend':
              _notificationService.sendSaveFriendAlert(
                body.toString().split(' hasn').first,
              );
              break;
            case 'push_friend':
              _notificationService.sendPushFriendAlert(
                body.toString().split(' hasn').first,
              );
              break;
          }

          // Mark as read to avoid re-firing
          change.doc.reference.update({'read': true});
        }
      }
    });
  }

  /// Stop all listeners
  void dispose() {
    _friendRequestSub?.cancel();
    _notificationSub?.cancel();
  }
}
