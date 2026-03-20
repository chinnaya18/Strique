import 'package:flutter/foundation.dart' show debugPrint;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/friendship_model.dart';
import '../models/notification_model.dart';
import '../config/constants.dart';
import 'cross_device_sync_service.dart';

class CompletionSyncService {
  static final CompletionSyncService _instance =
      CompletionSyncService._internal();
  factory CompletionSyncService() => _instance;
  CompletionSyncService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _syncService = CrossDeviceSyncService();

  /// Listen to friend's daily completion and sync friendship streak
  Stream<void> listenToFriendCompletions({
    required String userId,
    required String friendId,
    required String friendshipId,
  }) {
    return _firestore
        .collection(AppConstants.completionsCollection)
        .where('userId', isEqualTo: friendId)
        .where('status', isEqualTo: 'completed')
        .orderBy('date', descending: true)
        .limit(1)
        .snapshots()
        .asyncMap((snapshot) async {
          if (snapshot.docs.isEmpty) return;

          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);

          // Check if friend completed today
          final friendCompletedToday = snapshot.docs.any((doc) {
            final date = (doc['date'] as Timestamp).toDate();
            final completionDate =
                DateTime(date.year, date.month, date.day);
            return completionDate == today;
          });

          // Check if current user completed today
          final userCompletedToday = await _didUserCompleteToday(userId);

          // Update friendship streak if both completed
          if (friendCompletedToday && userCompletedToday) {
            await _updateFriendshipStreakIfBothCompleted(
              friendshipId: friendshipId,
              userId: userId,
              friendId: friendId,
            );
          }
        });
  }

  /// Check if user completed all habits today
  Future<bool> _didUserCompleteToday(String userId) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Get active habits
    final habitsSnapshot = await _firestore
        .collection(AppConstants.habitsCollection)
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .get();

    if (habitsSnapshot.docs.isEmpty) return false;

    // Get today's completions
    final completionsSnapshot = await _firestore
        .collection(AppConstants.completionsCollection)
        .where('userId', isEqualTo: userId)
        .where('date', isEqualTo: Timestamp.fromDate(today))
        .where('status', isEqualTo: 'completed')
        .get();

    final completedHabitIds =
        completionsSnapshot.docs.map((doc) => doc.data()['habitId']).toSet();

    // Check if every active habit is completed
    return habitsSnapshot.docs.every(
      (habitDoc) => completedHabitIds.contains(habitDoc.id),
    );
  }

  /// Update friendship streak when both users complete tasks
  Future<void> _updateFriendshipStreakIfBothCompleted({
    required String friendshipId,
    required String userId,
    required String friendId,
  }) async {
    final docRef = _firestore
        .collection(AppConstants.friendshipsCollection)
        .doc(friendshipId);

    final doc = await docRef.get();
    if (!doc.exists) return;

    final friendship = FriendshipModel.fromMap(doc.data()!, friendshipId);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Check if we already incremented today
    if (friendship.lastBothCompletedDate != null) {
      final lastDate = DateTime(
        friendship.lastBothCompletedDate!.year,
        friendship.lastBothCompletedDate!.month,
        friendship.lastBothCompletedDate!.day,
      );

      if (lastDate == today) {
        return; // Already incremented today
      }
    }

    // Increment streak
    final newStreak = friendship.friendshipStreak + 1;
    final newMax = newStreak > friendship.maxFriendshipStreak
        ? newStreak
        : friendship.maxFriendshipStreak;

    await docRef.update({
      'friendshipStreak': newStreak,
      'maxFriendshipStreak': newMax,
      'lastBothCompletedDate': Timestamp.fromDate(now),
    });

    // Get user names for notification
    final userDoc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .get();
    final friendDoc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(friendId)
        .get();

    final userName = userDoc.data()?['name'] ?? 'Friend';
    final friendName = friendDoc.data()?['name'] ?? 'Friend';

    // Send notifications to both users
    await _syncService.sendFriendshipStreakNotification(
      userId: userId,
      friendName: friendName,
      streakCount: newStreak,
    );

    await _syncService.sendFriendshipStreakNotification(
      userId: friendId,
      friendName: userName,
      streakCount: newStreak,
    );

    debugPrint('✅ Friendship streak updated to $newStreak');
  }

  /// Check and reset friendship streaks if 24 hours have passed without both completing
  Future<void> checkAndResetStreaksIfNeeded() async {
    try {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      // Get all friendships with active streaks
      final snapshot = await _firestore
          .collection(AppConstants.friendshipsCollection)
          .where('friendshipStreak', isGreaterThan: 0)
          .where('status', isEqualTo: 'accepted')
          .get();

      for (var doc in snapshot.docs) {
        final friendship = FriendshipModel.fromMap(doc.data(), doc.id);

        // If lastBothCompletedDate is before yesterday, reset streak
        if (friendship.lastBothCompletedDate == null ||
            friendship.lastBothCompletedDate!.isBefore(yesterday)) {
          await doc.reference.update({
            'friendshipStreak': 0,
          });

          debugPrint(
              '🚨 Reset friendship streak for ${friendship.id}');

          // Notify both users
          await _syncService.createNotification(
            userId: friendship.user1Id,
            type: NotificationType.streakResetWarning,
            title: '😢 Streak Reset',
            body:
                'You and your friend didn\'t complete your tasks within 24 hours. Your friendship streak has been reset!',
          );

          await _syncService.createNotification(
            userId: friendship.user2Id,
            type: NotificationType.streakResetWarning,
            title: '😢 Streak Reset',
            body:
                'You and your friend didn\'t complete your tasks within 24 hours. Your friendship streak has been reset!',
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking and resetting streaks: $e');
    }
  }

  /// Send reminder notifications for friends who haven't completed
  Future<void> sendIncompleteReminders() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Get all accepted friendships
      final friendships = await _firestore
          .collection(AppConstants.friendshipsCollection)
          .where('status', isEqualTo: 'accepted')
          .get();

      for (var friendshipDoc in friendships.docs) {
        final friendship =
            FriendshipModel.fromMap(friendshipDoc.data(), friendshipDoc.id);

        // Check both users' completion status
        final user1Completed = await _isUserCompletedForDate(
          friendship.user1Id,
          today,
        );
        final user2Completed = await _isUserCompletedForDate(
          friendship.user2Id,
          today,
        );

        // If one completed but other didn't, notify the incomplete user
        if (user1Completed && !user2Completed) {
          await _syncService.sendFriendStreakWarning(
            toUserId: friendship.user2Id,
            friendName: friendship.user1Name,
            hoursRemaining: 24 - now.hour,
          );
        } else if (user2Completed && !user1Completed) {
          await _syncService.sendFriendStreakWarning(
            toUserId: friendship.user1Id,
            friendName: friendship.user2Name,
            hoursRemaining: 24 - now.hour,
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error sending incomplete reminders: $e');
    }
  }

  /// Check if user completed all habits for a specific date
  Future<bool> _isUserCompletedForDate(String userId, DateTime date) async {
    // Get active habits
    final habitsSnapshot = await _firestore
        .collection(AppConstants.habitsCollection)
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .get();

    if (habitsSnapshot.docs.isEmpty) return false;

    // Get completions for that date
    final completionsSnapshot = await _firestore
        .collection(AppConstants.completionsCollection)
        .where('userId', isEqualTo: userId)
        .where('date', isEqualTo: Timestamp.fromDate(date))
        .where('status', isEqualTo: 'completed')
        .get();

    final completedHabitIds =
        completionsSnapshot.docs.map((doc) => doc.data()['habitId']).toSet();

    // Check if all active habits are completed
    return habitsSnapshot.docs.every(
      (habitDoc) => completedHabitIds.contains(habitDoc.id),
    );
  }

  /// Get real-time sync status of a friendship
  Stream<Map<String, dynamic>> getFriendshipSyncStatus({
    required String friendshipId,
    required String userId,
    required String friendId,
  }) {
    return _firestore
        .collection(AppConstants.friendshipsCollection)
        .doc(friendshipId)
        .snapshots()
        .asyncMap((snapshot) async {
          if (!snapshot.exists) {
            return {'status': 'error', 'message': 'Friendship not found'};
          }

          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);

          final userCompleted = await _isUserCompletedForDate(userId, today);
          final friendCompleted =
              await _isUserCompletedForDate(friendId, today);

          return {
            'userCompleted': userCompleted,
            'friendCompleted': friendCompleted,
            'bothCompleted': userCompleted && friendCompleted,
            'streak': snapshot.data()?['friendshipStreak'] ?? 0,
            'maxStreak': snapshot.data()?['maxFriendshipStreak'] ?? 0,
            'lastBothCompletedDate':
                snapshot.data()?['lastBothCompletedDate'],
          };
        });
  }
}
