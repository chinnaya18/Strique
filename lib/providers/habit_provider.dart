import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/habit_model.dart';
import '../models/completion_model.dart';
import '../models/work_model.dart';
import '../models/friendship_model.dart';
import '../config/constants.dart';
import '../services/habit_service.dart';
import '../services/streak_service.dart';
import '../services/achievement_service.dart';
import '../services/notification_service.dart';
import '../services/completion_sync_service.dart';
import '../services/friendship_service.dart';

class HabitProvider extends ChangeNotifier {
  final HabitService _habitService = HabitService();
  final StreakService _streakService = StreakService();
  final AchievementService _achievementService = AchievementService();
  final NotificationService _notificationService = NotificationService();
  final FriendshipService _friendshipService = FriendshipService();

  StreamSubscription? _habitsSubscription;
  StreamSubscription? _activeHabitsSubscription;

  List<HabitModel> _habits = [];
  List<HabitModel> _activeHabits = [];
  List<CompletionModel> _todayCompletions = [];
  bool _isLoading = false;
  String? _error;
  bool _allCompletedToday = false;

  List<HabitModel> get habits => _habits;
  List<HabitModel> get activeHabits => _activeHabits;
  List<CompletionModel> get todayCompletions => _todayCompletions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get allCompletedToday => _allCompletedToday;

  int get totalActiveHabits => _activeHabits.length;
  int get completedTodayCount => _todayCompletions.length;

  /// Initialize habit data for a user
  void initHabits(String userId) {
    // Cancel previous subscriptions to avoid memory leaks
    _habitsSubscription?.cancel();
    _activeHabitsSubscription?.cancel();

    _habitsSubscription = _habitService.getUserHabits(userId).listen((habits) {
      _habits = habits;
      notifyListeners();
    });

    _activeHabitsSubscription = _habitService.getActiveHabits(userId).listen((
      habits,
    ) {
      _activeHabits = habits;
      _checkAllCompleted();
      notifyListeners();
    });

    loadTodayCompletions(userId);

    // Check if the user missed any day and reset streak if needed
    _streakService.checkAndResetStreakIfNeeded(userId);

    // Schedule daily morning reminder & evening reminder for incomplete habits/tasks
    _notificationService.scheduleDailyReminder(hour: 8, minute: 0);
    _notificationService.scheduleEveningReminder(hour: 20, minute: 0);
    _notificationService.scheduleFriendAccountabilityCheck();
  }

  /// Load today's completions
  Future<void> loadTodayCompletions(String userId) async {
    _todayCompletions = await _habitService.getTodayCompletions(userId);
    _checkAllCompleted();
    notifyListeners();
  }

  /// Create a new habit with optional tasks
  Future<bool> createHabitWithTasks({
    required String userId,
    required String habitName,
    String? description,
    String? icon,
    required int durationDays,
    List<String> taskNames = const [],
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final habit = await _habitService.createHabit(
        userId: userId,
        habitName: habitName,
        description: description,
        icon: icon,
        durationDays: durationDays,
      );

      // Create tasks/works for this habit
      for (final taskName in taskNames) {
        await _habitService.createWork(
          habitId: habit.id,
          userId: userId,
          workName: taskName,
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Create a new habit
  Future<bool> createHabit({
    required String userId,
    required String habitName,
    String? description,
    String? icon,
    required int durationDays,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _habitService.createHabit(
        userId: userId,
        habitName: habitName,
        description: description,
        icon: icon,
        durationDays: durationDays,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Complete a habit for today
  Future<bool> completeHabit({
    required String userId,
    required String habitId,
  }) async {
    try {
      await _habitService.completeHabitForToday(
        userId: userId,
        habitId: habitId,
      );

      await loadTodayCompletions(userId);

      // Check if all habits are now completed
      _checkAllCompleted();

      if (_allCompletedToday) {
        // Evaluate streak
        final streakIncremented = await _streakService.evaluateDailyStreak(
          userId: userId,
          allTasksCompleted: true,
        );

        if (streakIncremented) {
          // Check for streak achievements
          final stats = await _streakService.getStreakStats(userId);
          await _achievementService.checkStreakAchievements(
            userId: userId,
            currentStreak: stats['currentStreak'],
          );

          // Notify all friends that this user completed their tasks
          await _notifyFriendsOfCompletion(userId);

          // Trigger sync to check if friends also completed
          await _syncFriendshipStreaks(userId);
        }

        // Check and update friendship streaks (when both friends completed)
        await _friendshipService.checkAndUpdateFriendshipStreaks(userId);

        // Notify friends that this user completed their habits
        await _notifyFriendsOfCompletion(userId);
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Notify all friends that user completed tasks
  Future<void> _notifyFriendsOfCompletion(String userId) async {
    try {
      final friendshipService = FriendshipService();
      await friendshipService.getLeaderboard(userId);
      // Notifications are sent by CompletionSyncService
      // when it detects the completion
    } catch (e) {
      debugPrint('Error notifying friends of completion: $e');
    }
  }

  /// Sync friendship streaks with friends
  Future<void> _syncFriendshipStreaks(String userId) async {
    try {
      final completionSyncService = CompletionSyncService();
      // Trigger the sync check to see if friend also completed
      await completionSyncService.checkAndResetStreaksIfNeeded();
    } catch (e) {
      debugPrint('Error syncing friendship streaks: $e');
    }
  }

  /// Delete a habit
  Future<void> deleteHabit(String habitId, String userId) async {
    await _habitService.deleteHabit(habitId, userId);
    notifyListeners();
  }

  /// Check if a specific habit is completed today
  bool isHabitCompletedToday(String habitId) {
    return _todayCompletions.any((c) => c.habitId == habitId && c.isCompleted);
  }

  void _checkAllCompleted() {
    if (_activeHabits.isEmpty) {
      _allCompletedToday = false;
      return;
    }

    _allCompletedToday = _activeHabits.every(
      (habit) => isHabitCompletedToday(habit.id),
    );
  }

  /// Check for incomplete habits/tasks and send notification if needed
  Future<void> checkAndNotifyIncomplete(String userId) async {
    if (_activeHabits.isEmpty) return;

    final incompleteHabits = _activeHabits
        .where((h) => !isHabitCompletedToday(h.id))
        .toList();

    if (incompleteHabits.isEmpty) return;

    int totalPendingTasks = 0;
    for (final habit in incompleteHabits) {
      final stats = await _habitService.getWorkCompletionStats(habit.id);
      final pending = (stats['total'] ?? 0) - (stats['completed'] ?? 0);
      totalPendingTasks += pending;
    }

    await _notificationService.sendIncompleteHabitsAlert(
      pendingHabits: incompleteHabits.length,
      pendingTasks: totalPendingTasks,
    );

    // Also schedule the evening reminder
    await _notificationService.scheduleEveningReminder();
  }

  /// Get completion data for analytics
  Future<List<CompletionModel>> getCompletionsInRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return _habitService.getCompletionsInRange(
      userId: userId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  // Work-related methods
  Stream<List<WorkModel>> getWorksForHabit(String habitId) {
    return _habitService.getWorksForHabit(habitId);
  }

  Future<void> addWork({
    required String habitId,
    required String userId,
    required String workName,
  }) async {
    try {
      await _habitService.createWork(
        habitId: habitId,
        userId: userId,
        workName: workName,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateWorkCompletion({
    required String habitId,
    required String workId,
    required bool isCompleted,
  }) async {
    try {
      await _habitService.updateWorkCompletion(
        habitId: habitId,
        workId: workId,
        isCompleted: isCompleted,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteWork({
    required String habitId,
    required String workId,
  }) async {
    try {
      await _habitService.deleteWork(habitId: habitId, workId: workId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<bool> areAllWorksCompleted(String habitId) async {
    return _habitService.areAllWorksCompleted(habitId);
  }

  Future<Map<String, int>> getWorkCompletionStats(String habitId) async {
    return _habitService.getWorkCompletionStats(habitId);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Notify all friends that this user completed their habits (real-time via Firestore)
  Future<void> _notifyFriendsOfCompletion(String userId) async {
    try {
      final friendships = await _friendshipService.getLeaderboard(userId);
      for (final friendship in friendships) {
        if (friendship.status != FriendshipStatus.accepted) continue;

        final friendId = friendship.getFriendId(userId);
        final userName = friendship.getFriendName(friendId); // current user's name from friend's perspective

        // Send local notification
        await _notificationService.sendFriendAlert(userName);

        // Also create a Firestore notification document for cross-device sync
        await FirebaseFirestore.instance
            .collection(AppConstants.notificationsCollection)
            .add({
          'targetUserId': friendId,
          'type': 'friend_completed',
          'title': '\ud83d\udc4b Friend Activity',
          'body': '$userName completed all their habits today! Can you keep up?',
          'createdAt': Timestamp.now(),
          'read': false,
        });
      }
    } catch (e) {
      debugPrint('Error notifying friends: $e');
    }
  }

  /// Check friend completion status at 9 PM and send push/save notifications
  Future<void> checkFriendAccountability(String userId) async {
    try {
      await _friendshipService.checkFriendCompletionAndNotify(userId);
    } catch (e) {
      debugPrint('Error checking friend accountability: $e');
    }
  }

  @override
  void dispose() {
    _habitsSubscription?.cancel();
    _activeHabitsSubscription?.cancel();
    super.dispose();
  }
}
