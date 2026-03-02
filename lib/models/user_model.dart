import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final DateTime? dateOfBirth;
  final DateTime joinDate;
  final int currentStreak;
  final int maxStreak;
  final int totalHabits;
  final int completedHabits;
  final int totalCompletedDays;
  final String role;
  final int streakFreezeCount;
  final String? friendId;
  final String? profileImageUrl;
  final DateTime? lastStreakDate;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.dateOfBirth,
    required this.joinDate,
    this.currentStreak = 0,
    this.maxStreak = 0,
    this.totalHabits = 0,
    this.completedHabits = 0,
    this.totalCompletedDays = 0,
    this.role = 'user',
    this.streakFreezeCount = 0,
    this.friendId,
    this.profileImageUrl,
    this.lastStreakDate,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      dateOfBirth: map['dateOfBirth'] != null
          ? (map['dateOfBirth'] as Timestamp).toDate()
          : null,
      joinDate: map['joinDate'] != null
          ? (map['joinDate'] as Timestamp).toDate()
          : DateTime.now(),
      currentStreak: map['currentStreak'] ?? 0,
      maxStreak: map['maxStreak'] ?? 0,
      totalHabits: map['totalHabits'] ?? 0,
      completedHabits: map['completedHabits'] ?? 0,
      totalCompletedDays: map['totalCompletedDays'] ?? 0,
      role: map['role'] ?? 'user',
      streakFreezeCount: map['streakFreezeCount'] ?? 0,
      friendId: map['friendId'],
      profileImageUrl: map['profileImageUrl'],
      lastStreakDate: map['lastStreakDate'] != null
          ? (map['lastStreakDate'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'dateOfBirth': dateOfBirth != null
          ? Timestamp.fromDate(dateOfBirth!)
          : null,
      'joinDate': Timestamp.fromDate(joinDate),
      'currentStreak': currentStreak,
      'maxStreak': maxStreak,
      'totalHabits': totalHabits,
      'completedHabits': completedHabits,
      'totalCompletedDays': totalCompletedDays,
      'role': role,
      'streakFreezeCount': streakFreezeCount,
      'friendId': friendId,
      'profileImageUrl': profileImageUrl,
      'lastStreakDate': lastStreakDate != null
          ? Timestamp.fromDate(lastStreakDate!)
          : null,
    };
  }

  UserModel copyWith({
    String? name,
    String? email,
    DateTime? dateOfBirth,
    int? currentStreak,
    int? maxStreak,
    int? totalHabits,
    int? completedHabits,
    int? totalCompletedDays,
    String? role,
    int? streakFreezeCount,
    String? friendId,
    String? profileImageUrl,
    DateTime? lastStreakDate,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      joinDate: joinDate,
      currentStreak: currentStreak ?? this.currentStreak,
      maxStreak: maxStreak ?? this.maxStreak,
      totalHabits: totalHabits ?? this.totalHabits,
      completedHabits: completedHabits ?? this.completedHabits,
      totalCompletedDays: totalCompletedDays ?? this.totalCompletedDays,
      role: role ?? this.role,
      streakFreezeCount: streakFreezeCount ?? this.streakFreezeCount,
      friendId: friendId ?? this.friendId,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      lastStreakDate: lastStreakDate ?? this.lastStreakDate,
    );
  }

  bool get isBirthdayToday {
    if (dateOfBirth == null) return false;
    final now = DateTime.now();
    return dateOfBirth!.month == now.month && dateOfBirth!.day == now.day;
  }
}
