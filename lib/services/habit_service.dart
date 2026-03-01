import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/habit_model.dart';
import '../models/completion_model.dart';
import '../models/work_model.dart';
import '../config/constants.dart';
import 'achievement_service.dart';

class HabitService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new habit
  Future<HabitModel> createHabit({
    required String userId,
    required String habitName,
    String? description,
    String? icon,
    required int durationDays,
  }) async {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day);
    final endDate = startDate.add(Duration(days: durationDays));

    final docRef = _firestore.collection(AppConstants.habitsCollection).doc();

    final habit = HabitModel(
      id: docRef.id,
      userId: userId,
      habitName: habitName,
      description: description,
      icon: icon,
      startDate: startDate,
      durationDays: durationDays,
      endDate: endDate,
    );

    await docRef.set(habit.toMap());

    // Increment user's total habits
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .update({'totalHabits': FieldValue.increment(1)});

    return habit;
  }

  // Get all habits for a user
  Stream<List<HabitModel>> getUserHabits(String userId) {
    return _firestore
        .collection(AppConstants.habitsCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final habits = snapshot.docs
              .map((doc) => HabitModel.fromMap(doc.data(), doc.id))
              .toList();
          habits.sort((a, b) => b.startDate.compareTo(a.startDate));
          return habits;
        });
  }

  // Get active habits
  Stream<List<HabitModel>> getActiveHabits(String userId) {
    return _firestore
        .collection(AppConstants.habitsCollection)
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => HabitModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get a single habit
  Future<HabitModel?> getHabit(String habitId) async {
    final doc = await _firestore
        .collection(AppConstants.habitsCollection)
        .doc(habitId)
        .get();

    if (!doc.exists) return null;
    return HabitModel.fromMap(doc.data()!, doc.id);
  }

  // Mark habit as completed for today
  Future<void> completeHabitForToday({
    required String userId,
    required String habitId,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Check if already completed today
    final existing = await _firestore
        .collection(AppConstants.completionsCollection)
        .where('userId', isEqualTo: userId)
        .where('habitId', isEqualTo: habitId)
        .where('date', isEqualTo: Timestamp.fromDate(today))
        .get();

    if (existing.docs.isNotEmpty) return; // Already completed

    // Create completion record
    final completion = CompletionModel(
      id: '',
      userId: userId,
      habitId: habitId,
      date: today,
      status: CompletionStatus.completed,
      completedAt: now,
    );

    await _firestore
        .collection(AppConstants.completionsCollection)
        .add(completion.toMap());

    // Update habit completed days and last completed date
    await _firestore
        .collection(AppConstants.habitsCollection)
        .doc(habitId)
        .update({
      'completedDays': FieldValue.increment(1),
      'lastCompletedDate': Timestamp.fromDate(now),
    });

    // Check if habit duration is complete
    final habit = await getHabit(habitId);
    if (habit != null && habit.completedDays >= habit.durationDays) {
      await _firestore
          .collection(AppConstants.habitsCollection)
          .doc(habitId)
          .update({'status': 'completed'});

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update({'completedHabits': FieldValue.increment(1)});

      // Award habit completion badge
      final achievementService = AchievementService();
      await achievementService.awardHabitCompletionBadge(userId);
    }
  }

  // Get today's completions for a user
  Future<List<CompletionModel>> getTodayCompletions(String userId) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final snapshot = await _firestore
        .collection(AppConstants.completionsCollection)
        .where('userId', isEqualTo: userId)
        .where('date', isEqualTo: Timestamp.fromDate(today))
        .get();

    return snapshot.docs
        .map((doc) => CompletionModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  // Get completions for a date range (for analytics)
  Future<List<CompletionModel>> getCompletionsInRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final snapshot = await _firestore
        .collection(AppConstants.completionsCollection)
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    return snapshot.docs
        .map((doc) => CompletionModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  // Delete a habit
  Future<void> deleteHabit(String habitId, String userId) async {
    await _firestore
        .collection(AppConstants.habitsCollection)
        .doc(habitId)
        .delete();

    // Delete associated completions
    final completions = await _firestore
        .collection(AppConstants.completionsCollection)
        .where('habitId', isEqualTo: habitId)
        .get();

    final batch = _firestore.batch();
    for (var doc in completions.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .update({'totalHabits': FieldValue.increment(-1)});
  }

  // Renew a completed habit
  Future<HabitModel> renewHabit({
    required String habitId,
    required int durationDays,
  }) async {
    final habit = await getHabit(habitId);
    if (habit == null) throw Exception('Habit not found');

    return createHabit(
      userId: habit.userId,
      habitName: habit.habitName,
      description: habit.description,
      icon: habit.icon,
      durationDays: durationDays,
    );
  }

  // Work-related methods
  // Create a new work/task for a habit
  Future<WorkModel> createWork({
    required String habitId,
    required String userId,
    required String workName,
  }) async {
    final now = DateTime.now();
    final workRef = _firestore
        .collection(AppConstants.habitsCollection)
        .doc(habitId)
        .collection('works')
        .doc();

    final work = WorkModel(
      id: workRef.id,
      habitId: habitId,
      userId: userId,
      workName: workName,
      createdAt: now,
      order: 0,
    );

    await workRef.set(work.toMap());
    return work;
  }

  // Get all works for a habit
  Stream<List<WorkModel>> getWorksForHabit(String habitId) {
    return _firestore
        .collection(AppConstants.habitsCollection)
        .doc(habitId)
        .collection('works')
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WorkModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Update work completion status
  Future<void> updateWorkCompletion({
    required String habitId,
    required String workId,
    required bool isCompleted,
  }) async {
    await _firestore
        .collection(AppConstants.habitsCollection)
        .doc(habitId)
        .collection('works')
        .doc(workId)
        .update({
      'isCompleted': isCompleted,
      'completedAt': isCompleted ? Timestamp.now() : null,
    });
  }

  // Delete a work
  Future<void> deleteWork({
    required String habitId,
    required String workId,
  }) async {
    await _firestore
        .collection(AppConstants.habitsCollection)
        .doc(habitId)
        .collection('works')
        .doc(workId)
        .delete();
  }

  // Check if all works are completed for a habit
  Future<bool> areAllWorksCompleted(String habitId) async {
    final snapshot = await _firestore
        .collection(AppConstants.habitsCollection)
        .doc(habitId)
        .collection('works')
        .where('isCompleted', isEqualTo: false)
        .get();

    return snapshot.docs.isEmpty;
  }

  // Get completion count for a habit
  Future<Map<String, int>> getWorkCompletionStats(String habitId) async {
    final snapshot = await _firestore
        .collection(AppConstants.habitsCollection)
        .doc(habitId)
        .collection('works')
        .get();

    final total = snapshot.docs.length;
    final completed =
        snapshot.docs.where((doc) => doc['isCompleted'] == true).length;

    return {'total': total, 'completed': completed};
  }
}
