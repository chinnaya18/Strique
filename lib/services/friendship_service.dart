import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/friendship_model.dart';
import '../models/user_model.dart';
import '../config/constants.dart';
import 'streak_service.dart';
import 'achievement_service.dart';
import 'notification_service.dart';

class FriendshipService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Add a friend using friend ID
  Future<FriendshipModel?> addFriend({
    required String currentUserId,
    required String friendCode,
  }) async {
    // Find user by friend ID
    final querySnapshot = await _firestore
        .collection(AppConstants.usersCollection)
        .where('friendId', isEqualTo: friendCode.toUpperCase())
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception('No user found with this Friend ID.');
    }

    final friendDoc = querySnapshot.docs.first;
    final friendUserId = friendDoc.id;

    if (friendUserId == currentUserId) {
      throw Exception('You cannot add yourself as a friend.');
    }

    // Check if friendship already exists
    final existingFriendship = await _firestore
        .collection(AppConstants.friendshipsCollection)
        .where('user1Id', whereIn: [currentUserId, friendUserId])
        .get();

    for (var doc in existingFriendship.docs) {
      final data = doc.data();
      if ((data['user1Id'] == currentUserId &&
              data['user2Id'] == friendUserId) ||
          (data['user1Id'] == friendUserId &&
              data['user2Id'] == currentUserId)) {
        throw Exception('You are already friends!');
      }
    }

    // Get current user data
    final currentUserDoc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(currentUserId)
        .get();
    final currentUser =
        UserModel.fromMap(currentUserDoc.data()!, currentUserId);
    final friendUser =
        UserModel.fromMap(friendDoc.data(), friendUserId);

    // Create friendship
    final docRef =
        _firestore.collection(AppConstants.friendshipsCollection).doc();

    final friendship = FriendshipModel(
      id: docRef.id,
      user1Id: currentUserId,
      user2Id: friendUserId,
      user1Name: currentUser.name,
      user2Name: friendUser.name,
      createdAt: DateTime.now(),
      status: FriendshipStatus.pending,
    );

    await docRef.set(friendship.toMap());
    return friendship;
  }

  /// Accept a friend request
  Future<void> acceptFriendRequest({
    required String friendshipId,
    required String userId,
  }) async {
    final docRef =
        _firestore.collection(AppConstants.friendshipsCollection).doc(friendshipId);
    
    final doc = await docRef.get();
    if (!doc.exists) {
      throw Exception('Friendship request not found');
    }

    final friendship = FriendshipModel.fromMap(doc.data()!, friendshipId);
    
    // Only the receiver (user2Id) can accept
    if (friendship.user2Id != userId && friendship.user1Id != userId) {
      throw Exception('Unauthorized');
    }

    await docRef.update({
      'status': 'accepted',
    });
  }

  /// Get all friendships for a user
  Stream<List<FriendshipModel>> getUserFriendships(String userId) {
    return _firestore
        .collection(AppConstants.friendshipsCollection)
        .where(Filter.or(
          Filter('user1Id', isEqualTo: userId),
          Filter('user2Id', isEqualTo: userId),
        ))
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FriendshipModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Update friendship streak
  /// Called when both users in a friendship complete their tasks
  Future<void> updateFriendshipStreak({
    required String friendshipId,
    required bool bothCompleted,
  }) async {
    final doc = await _firestore
        .collection(AppConstants.friendshipsCollection)
        .doc(friendshipId)
        .get();

    if (!doc.exists) return;

    final friendship = FriendshipModel.fromMap(doc.data()!, doc.id);

    // Prevent double-counting: only increment once per day
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (friendship.lastBothCompletedDate != null) {
      final lastDate = friendship.lastBothCompletedDate!;
      final lastDay = DateTime(lastDate.year, lastDate.month, lastDate.day);
      if (lastDay.isAtSameMomentAs(today) && bothCompleted) {
        return; // Already counted today
      }
    }

    if (bothCompleted) {
      final newStreak = friendship.friendshipStreak + 1;
      final newMax = newStreak > friendship.maxFriendshipStreak
          ? newStreak
          : friendship.maxFriendshipStreak;

      await _firestore
          .collection(AppConstants.friendshipsCollection)
          .doc(friendshipId)
          .update({
        'friendshipStreak': newStreak,
        'maxFriendshipStreak': newMax,
        'lastBothCompletedDate': Timestamp.fromDate(now),
      });

      // Award 7-day friendship badge if applicable
      if (newStreak == 7) {
        final achievementService = AchievementService();
        await achievementService.awardFriendshipStreakBadge(friendship.user1Id);
        await achievementService.awardFriendshipStreakBadge(friendship.user2Id);
      }
    } else {
      // Reset friendship streak
      await _firestore
          .collection(AppConstants.friendshipsCollection)
          .doc(friendshipId)
          .update({
        'friendshipStreak': 0,
      });
    }
  }

  /// Check and update all friendship streaks for a user who just completed all habits
  Future<void> checkAndUpdateFriendshipStreaks(String userId) async {
    final streakService = StreakService();

    // Get all accepted friendships for this user
    final snapshot = await _firestore
        .collection(AppConstants.friendshipsCollection)
        .where(Filter.or(
          Filter('user1Id', isEqualTo: userId),
          Filter('user2Id', isEqualTo: userId),
        ))
        .get();

    for (final doc in snapshot.docs) {
      final friendship = FriendshipModel.fromMap(doc.data(), doc.id);
      if (friendship.status != FriendshipStatus.accepted) continue;

      // Get the friend's ID
      final friendId = friendship.getFriendId(userId);

      // Check if the friend has also completed all habits today
      final friendCompleted = await streakService.areAllHabitsCompletedToday(friendId);

      if (friendCompleted) {
        // Both completed! Update the friendship streak
        await updateFriendshipStreak(
          friendshipId: friendship.id,
          bothCompleted: true,
        );
      }
    }
  }

  /// Schedule 9 PM check for incomplete friends and send push/save notifications
  Future<void> checkFriendCompletionAndNotify(String userId) async {
    final streakService = StreakService();
    final notificationService = NotificationService();

    // Check if current user completed
    final userCompleted = await streakService.areAllHabitsCompletedToday(userId);

    // Get all accepted friendships
    final snapshot = await _firestore
        .collection(AppConstants.friendshipsCollection)
        .where(Filter.or(
          Filter('user1Id', isEqualTo: userId),
          Filter('user2Id', isEqualTo: userId),
        ))
        .get();

    for (final doc in snapshot.docs) {
      final friendship = FriendshipModel.fromMap(doc.data(), doc.id);
      if (friendship.status != FriendshipStatus.accepted) continue;

      final friendId = friendship.getFriendId(userId);
      final friendName = friendship.getFriendName(userId);
      final friendCompleted = await streakService.areAllHabitsCompletedToday(friendId);

      if (!friendCompleted) {
        // Friend hasn't completed — notify user to push their friend
        await notificationService.sendPushFriendAlert(friendName);
      }

      if (!userCompleted) {
        // User hasn't completed — store a Firestore notification for the friend
        // so the friend's device picks it up as "Save your friend!"
        await _firestore.collection(AppConstants.notificationsCollection).add({
          'targetUserId': friendId,
          'type': 'save_friend',
          'title': '🛟 Save Your Friend!',
          'body': '${ _getUserName(userId, friendship) } hasn\'t completed their habits yet! Encourage them!',
          'createdAt': Timestamp.now(),
          'read': false,
        });
      }
    }
  }

  String _getUserName(String userId, FriendshipModel friendship) {
    return userId == friendship.user1Id ? friendship.user1Name : friendship.user2Name;
  }

  /// Remove friendship
  Future<void> removeFriend(String friendshipId) async {
    await _firestore
        .collection(AppConstants.friendshipsCollection)
        .doc(friendshipId)
        .delete();
  }

  /// Get leaderboard (friends sorted by streak)
  Future<List<FriendshipModel>> getLeaderboard(String userId) async {
    final snapshot = await _firestore
        .collection(AppConstants.friendshipsCollection)
        .where(Filter.or(
          Filter('user1Id', isEqualTo: userId),
          Filter('user2Id', isEqualTo: userId),
        ))
        .get();

    final friendships = snapshot.docs
        .map((doc) => FriendshipModel.fromMap(doc.data(), doc.id))
        .toList();
    friendships.sort((a, b) => b.friendshipStreak.compareTo(a.friendshipStreak));
    return friendships;
  }
}
