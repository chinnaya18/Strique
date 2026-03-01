import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/achievement_model.dart';
import '../config/constants.dart';

class AchievementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check and award achievements based on current streak
  Future<AchievementModel?> checkStreakAchievements({
    required String userId,
    required int currentStreak,
  }) async {
    String? badgeType;

    if (currentStreak == 7) {
      badgeType = AppConstants.badge7Day;
    } else if (currentStreak == 30) {
      badgeType = AppConstants.badge30Day;
    } else if (currentStreak == 100) {
      badgeType = AppConstants.badge100Day;
    }

    if (badgeType == null) return null;

    // Check if already earned
    final existing = await _firestore
        .collection(AppConstants.achievementsCollection)
        .where('userId', isEqualTo: userId)
        .where('badgeType', isEqualTo: badgeType)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) return null; // Already earned

    return _awardBadge(userId: userId, badgeType: badgeType);
  }

  /// Award a badge
  Future<AchievementModel> _awardBadge({
    required String userId,
    required String badgeType,
  }) async {
    final achievement = AchievementModel.createBadge(
      userId: userId,
      badgeType: badgeType,
    );

    final docRef = await _firestore
        .collection(AppConstants.achievementsCollection)
        .add(achievement.toMap());

    return AchievementModel(
      id: docRef.id,
      userId: achievement.userId,
      badgeType: achievement.badgeType,
      title: achievement.title,
      description: achievement.description,
      icon: achievement.icon,
      dateEarned: achievement.dateEarned,
    );
  }

  /// Award habit completion badge
  Future<AchievementModel?> awardHabitCompletionBadge(String userId) async {
    final existing = await _firestore
        .collection(AppConstants.achievementsCollection)
        .where('userId', isEqualTo: userId)
        .where('badgeType', isEqualTo: AppConstants.badgeHabitComplete)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) return null;

    return _awardBadge(
        userId: userId, badgeType: AppConstants.badgeHabitComplete);
  }

  /// Award first friend badge
  Future<AchievementModel?> awardFirstFriendBadge(String userId) async {
    final existing = await _firestore
        .collection(AppConstants.achievementsCollection)
        .where('userId', isEqualTo: userId)
        .where('badgeType', isEqualTo: AppConstants.badgeFirstFriend)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) return null;

    return _awardBadge(
        userId: userId, badgeType: AppConstants.badgeFirstFriend);
  }

  /// Award 7-day friendship streak badge
  Future<AchievementModel?> awardFriendshipStreakBadge(String userId) async {
    final existing = await _firestore
        .collection(AppConstants.achievementsCollection)
        .where('userId', isEqualTo: userId)
        .where('badgeType', isEqualTo: AppConstants.badge7DayFriendship)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) return null;

    return _awardBadge(
        userId: userId, badgeType: AppConstants.badge7DayFriendship);
  }

  /// Get all achievements for a user
  Stream<List<AchievementModel>> getUserAchievements(String userId) {
    return _firestore
        .collection(AppConstants.achievementsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('dateEarned', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AchievementModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Get all possible badges and their earned status
  Future<List<Map<String, dynamic>>> getAllBadgesWithStatus(
      String userId) async {
    final earned = await _firestore
        .collection(AppConstants.achievementsCollection)
        .where('userId', isEqualTo: userId)
        .get();

    final earnedTypes = earned.docs.map((d) => d.data()['badgeType']).toSet();

    return AchievementModel.badgeDefinitions.entries.map((entry) {
      return {
        'badgeType': entry.key,
        'title': entry.value['title'],
        'description': entry.value['description'],
        'icon': entry.value['icon'],
        'earned': earnedTypes.contains(entry.key),
      };
    }).toList();
  }
}
