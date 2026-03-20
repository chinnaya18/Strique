import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/friendship_model.dart';
import '../models/user_model.dart';
import '../config/constants.dart';
import 'cross_device_sync_service.dart';

class FriendshipService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _syncService = CrossDeviceSyncService();

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

    // Send friend request notification
    await _syncService.sendFriendRequestNotification(
      fromUserId: currentUserId,
      fromUserName: currentUser.name,
      toUserId: friendUserId,
    );

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

    // Determine who accepted and who to notify
    final acceptorId = userId;
    final recipientId =
        userId == friendship.user1Id ? friendship.user2Id : friendship.user1Id;
    final acceptorName =
        userId == friendship.user1Id ? friendship.user1Name : friendship.user2Name;

    await docRef.update({
      'status': 'accepted',
    });

    // Send acceptance notification to the other user
    await _syncService.sendFriendRequestAcceptedNotification(
      fromUserId: acceptorId,
      fromUserName: acceptorName,
      toUserId: recipientId,
    );
  }

  /// Reject a friend request
  Future<void> rejectFriendRequest({
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

    // Only the receiver (user2Id) can reject
    if (friendship.user2Id != userId && friendship.user1Id != userId) {
      throw Exception('Unauthorized');
    }

    // Delete the friendship request
    await docRef.delete();
  }

  /// Get all friendships for a user (all statuses)
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

  /// Get only accepted friendships
  Stream<List<FriendshipModel>> getAcceptedFriendships(String userId) {
    return _firestore
        .collection(AppConstants.friendshipsCollection)
        .where(Filter.or(
          Filter('user1Id', isEqualTo: userId),
          Filter('user2Id', isEqualTo: userId),
        ))
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FriendshipModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Get pending friend requests (where user is receiver)
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
        'lastBothCompletedDate': Timestamp.fromDate(DateTime.now()),
      });
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
        .where('status', isEqualTo: 'accepted')
        .get();

    final friendships = snapshot.docs
        .map((doc) => FriendshipModel.fromMap(doc.data(), doc.id))
        .toList();
    friendships.sort((a, b) => b.friendshipStreak.compareTo(a.friendshipStreak));
    return friendships;
  }
}
