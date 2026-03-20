import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../config/constants.dart';

class StreakService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Evaluate the daily streak.
  /// Call this after checking if all today's tasks are completed.
  /// Returns true if streak was incremented, false if reset.
  Future<bool> evaluateDailyStreak({
    required String userId,
    required bool allTasksCompleted,
  }) async {
    final userDoc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .get();

    if (!userDoc.exists) return false;

    final user = UserModel.fromMap(userDoc.data()!, userId);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (allTasksCompleted) {
      // Prevent double-incrementing if already evaluated today
      if (user.lastStreakDate != null) {
        final lastDate = DateTime(
          user.lastStreakDate!.year,
          user.lastStreakDate!.month,
          user.lastStreakDate!.day,
        );
        if (!lastDate.isBefore(today)) {
          return true; // Already evaluated today
        }
      }

      // Increment streak
      final newStreak = user.currentStreak + 1;
      final newMax =
          newStreak > user.maxStreak ? newStreak : user.maxStreak;

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update({
        'currentStreak': newStreak,
        'maxStreak': newMax,
        'totalCompletedDays': FieldValue.increment(1),
        'lastStreakDate': Timestamp.fromDate(today),
      });

      return true;
    } else {
      // Check if user has streak freeze
      if (user.streakFreezeCount > 0) {
        // Use a freeze instead of resetting
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(userId)
            .update({
          'streakFreezeCount': FieldValue.increment(-1),
          'lastStreakDate': Timestamp.fromDate(today),
        });
        return true; // Streak preserved
      }

      // Reset streak
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update({
        'currentStreak': 0,
        'lastStreakDate': Timestamp.fromDate(today),
      });

      return false;
    }
  }

  /// Check on app open whether the user missed any previous day(s).
  /// If they did, reset the streak to 0 (or consume a streak freeze).
  /// This handles the case where the user simply never opens the app or
  /// doesn't complete all habits, so evaluateDailyStreak is never called.
  Future<void> checkAndResetStreakIfNeeded(String userId) async {
    final userDoc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .get();

    if (!userDoc.exists) return;

    final user = UserModel.fromMap(userDoc.data()!, userId);

    // If streak is already 0, nothing to reset
    if (user.currentStreak == 0) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // If no lastStreakDate recorded, compare against join date
    final lastDate = user.lastStreakDate ?? user.joinDate;
    final lastDay = DateTime(lastDate.year, lastDate.month, lastDate.day);

    // If lastStreakDate is today or yesterday, no missed day yet
    final differenceInDays = today.difference(lastDay).inDays;
    if (differenceInDays <= 1) return;

    // The user missed at least one full day — check if yesterday was completed
    final yesterday = today.subtract(const Duration(days: 1));
    final yesterdayCompleted = await _wereAllHabitsCompletedOn(userId, yesterday);

    if (yesterdayCompleted) {
      // Yesterday was fine; the gap might be from the day before.
      // Evaluate each missed day between lastStreakDate+1 and day-before-yesterday.
      // For simplicity, iterate missed days and consume freezes or reset.
      for (int i = 1; i < differenceInDays - 1; i++) {
        final missedDay = lastDay.add(Duration(days: i));
        final completed = await _wereAllHabitsCompletedOn(userId, missedDay);
        if (!completed) {
          await evaluateDailyStreak(userId: userId, allTasksCompleted: false);
          return;
        }
      }
      // All intermediate days were completed — evaluate yesterday
      await evaluateDailyStreak(userId: userId, allTasksCompleted: true);
    } else {
      // Yesterday was NOT completed — reset streak
      await evaluateDailyStreak(userId: userId, allTasksCompleted: false);
    }
  }

  /// Check if all active habits were completed on a specific date.
  Future<bool> _wereAllHabitsCompletedOn(String userId, DateTime date) async {
    final day = DateTime(date.year, date.month, date.day);

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
        .where('date', isEqualTo: Timestamp.fromDate(day))
        .where('status', isEqualTo: 'completed')
        .get();

    final completedHabitIds =
        completionsSnapshot.docs.map((doc) => doc.data()['habitId']).toSet();

    for (final habitDoc in habitsSnapshot.docs) {
      if (!completedHabitIds.contains(habitDoc.id)) {
        return false;
      }
    }
    return true;
  }

  /// Check if all active habits are completed for today
  Future<bool> areAllHabitsCompletedToday(String userId) async {
    // Get active habits
    final habitsSnapshot = await _firestore
        .collection(AppConstants.habitsCollection)
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .get();

    if (habitsSnapshot.docs.isEmpty) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

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
    for (final habitDoc in habitsSnapshot.docs) {
      if (!completedHabitIds.contains(habitDoc.id)) {
        return false;
      }
    }

    return true;
  }

  /// Add streak freeze to user
  Future<void> addStreakFreeze(String userId, {int count = 1}) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .update({
      'streakFreezeCount': FieldValue.increment(count),
    });
  }

  /// Get streak statistics
  Future<Map<String, dynamic>> getStreakStats(String userId) async {
    final userDoc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .get();

    if (!userDoc.exists) {
      return {
        'currentStreak': 0,
        'maxStreak': 0,
        'totalCompletedDays': 0,
        'streakFreezeCount': 0,
      };
    }

    final data = userDoc.data()!;
    return {
      'currentStreak': data['currentStreak'] ?? 0,
      'maxStreak': data['maxStreak'] ?? 0,
      'totalCompletedDays': data['totalCompletedDays'] ?? 0,
      'streakFreezeCount': data['streakFreezeCount'] ?? 0,
    };
  }
}
