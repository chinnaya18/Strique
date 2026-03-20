import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/streak_service.dart';

class StreakScreen extends StatefulWidget {
  const StreakScreen({super.key});

  @override
  State<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends State<StreakScreen> {
  final StreakService _streakService = StreakService();
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final userId =
        Provider.of<AuthProvider>(context, listen: false).userId;
    if (userId != null) {
      final stats = await _streakService.getStreakStats(userId);
      setState(() => _stats = stats);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Main Streak Display
              _buildMainStreakDisplay(user?.currentStreak ?? 0),
              const SizedBox(height: 32),

              // Stats Grid
              if (_stats != null) ...[
                _buildStatsGrid(),
                const SizedBox(height: 24),
              ],

              // Streak Milestones
              _buildMilestones(user?.currentStreak ?? 0),
              const SizedBox(height: 24),

              // Streak Freeze Info
              _buildStreakFreezeCard(
                _stats?['streakFreezeCount'] ?? user?.streakFreezeCount ?? 0,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainStreakDisplay(int streak) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: streak > 0
              ? [AppColors.primary, const Color(0xFFCC4400)]
              : [Colors.grey.shade400, Colors.grey.shade600],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (streak > 0 ? AppColors.primary : Colors.grey)
                .withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            streak > 0 ? '🔥' : '❄️',
            style: const TextStyle(fontSize: 64),
          ),
          const SizedBox(height: 16),
          Text(
            '$streak',
            style: const TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            streak == 1 ? 'Day Streak' : 'Days Streak',
            style: TextStyle(
              fontSize: 20,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          if (streak == 0) ...[
            const SizedBox(height: 12),
            Text(
              'Complete all habits to start your streak!',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        _buildStatTile(
          '👑',
          'Best Streak',
          '${_stats!['maxStreak']} days',
          AppColors.streakGold,
        ),
        const SizedBox(width: 12),
        _buildStatTile(
          '✅',
          'Total Days',
          '${_stats!['totalCompletedDays']}',
          AppColors.success,
        ),
      ],
    );
  }

  Widget _buildStatTile(
      String emoji, String label, String value, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondaryLight,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMilestones(int currentStreak) {
    final milestones = [
      {'days': 7, 'title': 'Week Warrior', 'emoji': '⚡'},
      {'days': 30, 'title': 'Monthly Master', 'emoji': '🔥'},
      {'days': 60, 'title': 'Discipline King', 'emoji': '💎'},
      {'days': 100, 'title': 'Century Legend', 'emoji': '👑'},
      {'days': 365, 'title': 'Year Champion', 'emoji': '🏆'},
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Streak Milestones',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ...milestones.map((m) {
              final days = m['days'] as int;
              final reached = currentStreak >= days;
              final progress =
                  (currentStreak / days).clamp(0.0, 1.0);

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Text(
                      m['emoji'] as String,
                      style: TextStyle(
                        fontSize: 24,
                        color: reached ? null : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                m['title'] as String,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: reached
                                      ? null
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                              Text(
                                '$days days',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: reached
                                      ? AppColors.success
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor:
                                  AppColors.primary.withOpacity(0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                reached
                                    ? AppColors.success
                                    : AppColors.primary,
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (reached)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.check_circle,
                            color: AppColors.success, size: 20),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakFreezeCard(int freezeCount) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text('🧊', style: TextStyle(fontSize: 28)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Streak Freezes',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$freezeCount available',
                    style: const TextStyle(
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Protects your streak if you miss a day',
                    style: TextStyle(
                      color: AppColors.textSecondaryLight,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
