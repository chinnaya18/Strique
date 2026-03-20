import 'package:flutter/material.dart';
import '../services/friendship_service.dart';
import '../models/friendship_model.dart';

class FriendshipProvider extends ChangeNotifier {
  final FriendshipService _friendshipService = FriendshipService();

  List<FriendshipModel> _friends = [];
  List<FriendshipModel> _pendingRequests = [];
  List<FriendshipModel> _leaderboard = [];

  List<FriendshipModel> get friends => _friends;
  List<FriendshipModel> get pendingRequests => _pendingRequests;
  List<FriendshipModel> get leaderboard => _leaderboard;

  /// Initialize friendships stream
  void initFriendships(String userId) {
    _friendshipService.getAcceptedFriendships(userId).listen((friends) {
      _friends = friends;
      _leaderboard = List.from(friends)
        ..sort((a, b) => b.friendshipStreak.compareTo(a.friendshipStreak));
      notifyListeners();
    });

    _friendshipService.getPendingFriendRequests(userId).listen((requests) {
      _pendingRequests = requests;
      notifyListeners();
    });
  }

  /// Add a new friend
  Future<void> addFriend(String currentUserId, String friendCode) async {
    try {
      await _friendshipService.addFriend(
        currentUserId: currentUserId,
        friendCode: friendCode,
      );
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Accept friend request
  Future<void> acceptFriendRequest(String friendshipId, String userId) async {
    try {
      await _friendshipService.acceptFriendRequest(
        friendshipId: friendshipId,
        userId: userId,
      );
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Reject friend request
  Future<void> rejectFriendRequest(String friendshipId, String userId) async {
    try {
      await _friendshipService.rejectFriendRequest(
        friendshipId: friendshipId,
        userId: userId,
      );
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Remove friend
  Future<void> removeFriend(String friendshipId) async {
    try {
      await _friendshipService.removeFriend(friendshipId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Get leaderboard
  Future<void> loadLeaderboard(String userId) async {
    try {
      _leaderboard = await _friendshipService.getLeaderboard(userId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
}
