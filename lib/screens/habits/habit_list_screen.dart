import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/habit_provider.dart';
import '../../models/habit_model.dart';
import '../../models/work_model.dart';

class HabitListScreen extends StatelessWidget {
  const HabitListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final habitProvider = Provider.of<HabitProvider>(context);
    final userId = authProvider.userId;

    if (userId == null) return const SizedBox.shrink();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'Completed'),
            ],
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.pushNamed(context, AppRoutes.createHabit);
          },
          icon: const Icon(Icons.add),
          label: const Text('New Habit'),
        ),
        body: TabBarView(
          children: [
            // Active Habits
            _buildHabitList(
              context,
              habitProvider.habits
                  .where((h) => h.status == HabitStatus.active)
                  .toList(),
              'No active habits',
              '🎯',
            ),
            // Completed Habits
            _buildHabitList(
              context,
              habitProvider.habits
                  .where((h) => h.status == HabitStatus.completed)
                  .toList(),
              'No completed habits yet',
              '🏆',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitList(
    BuildContext context,
    List<HabitModel> habits,
    String emptyMessage,
    String emptyEmoji,
  ) {
    if (habits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emptyEmoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      );
    }

    final habitProvider = Provider.of<HabitProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.userId ?? '';

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: habits.length,
      itemBuilder: (context, index) {
        final habit = habits[index];
        return _HabitCardWithTasks(
          habit: habit,
          userId: userId,
          habitProvider: habitProvider,
        );
      },
    );
  }
}

class _HabitCardWithTasks extends StatefulWidget {
  final HabitModel habit;
  final String userId;
  final HabitProvider habitProvider;

  const _HabitCardWithTasks({
    required this.habit,
    required this.userId,
    required this.habitProvider,
  });

  @override
  State<_HabitCardWithTasks> createState() => _HabitCardWithTasksState();
}

class _HabitCardWithTasksState extends State<_HabitCardWithTasks> {
  bool _isExpanded = false;
  final TextEditingController _taskController = TextEditingController();

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  Future<void> _addTask() async {
    final taskName = _taskController.text.trim();
    if (taskName.isEmpty) return;
    await widget.habitProvider.addWork(
      habitId: widget.habit.id,
      userId: widget.userId,
      workName: taskName,
    );
    _taskController.clear();
  }

  Future<void> _toggleTask(WorkModel work, List<WorkModel> allWorks) async {
    final newStatus = !work.isCompleted;
    await widget.habitProvider.updateWorkCompletion(
      habitId: widget.habit.id,
      workId: work.id,
      isCompleted: newStatus,
    );
    // Auto-complete habit when all tasks done
    if (newStatus && widget.habit.status == HabitStatus.active) {
      final isHabitDoneToday = widget.habitProvider.isHabitCompletedToday(
        widget.habit.id,
      );
      if (!isHabitDoneToday) {
        final allDone = allWorks
            .where((w) => w.id != work.id && !w.isCompleted)
            .isEmpty;
        if (allDone) {
          await widget.habitProvider.completeHabit(
            userId: widget.userId,
            habitId: widget.habit.id,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('All tasks done! Habit completed for today! 🎉'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final habit = widget.habit;
    final isCompleted = habit.status == HabitStatus.completed;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Habit header row
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? AppColors.success.withOpacity(0.1)
                          : AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        habit.icon ?? '🎯',
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.habitName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${habit.completedDays}/${habit.durationDays} days • ${habit.remainingDays} days left',
                          style: const TextStyle(
                            color: AppColors.textSecondaryLight,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: habit.progressPercentage,
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isCompleted
                                  ? AppColors.success
                                  : AppColors.primary,
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: isCompleted
                          ? AppColors.streakGold
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),

              // Task summary (always visible if tasks exist)
              StreamBuilder<List<WorkModel>>(
                stream: widget.habitProvider.getWorksForHabit(habit.id),
                builder: (context, snapshot) {
                  final works = snapshot.data ?? [];
                  final completedCount = works
                      .where((w) => w.isCompleted)
                      .length;
                  final totalCount = works.length;

                  return Column(
                    children: [
                      if (totalCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 10, left: 60),
                          child: Row(
                            children: [
                              Icon(
                                Icons.task_alt,
                                size: 16,
                                color: completedCount == totalCount
                                    ? AppColors.success
                                    : AppColors.textSecondaryLight,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$completedCount/$totalCount tasks',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: completedCount == totalCount
                                      ? AppColors.success
                                      : AppColors.textSecondaryLight,
                                  fontWeight: completedCount == totalCount
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: totalCount > 0
                                        ? completedCount / totalCount
                                        : 0,
                                    backgroundColor: AppColors.success
                                        .withOpacity(0.1),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          AppColors.success,
                                        ),
                                    minHeight: 4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Expanded task list
                      AnimatedCrossFade(
                        firstChild: const SizedBox.shrink(),
                        secondChild: _buildTaskList(works),
                        crossFadeState: _isExpanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 250),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskList(List<WorkModel> works) {
    final isActive = widget.habit.status == HabitStatus.active;
    return Padding(
      padding: const EdgeInsets.only(top: 12, left: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 8),
          if (works.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No tasks yet.${isActive ? ' Add tasks below.' : ''}',
                style: const TextStyle(
                  color: AppColors.textSecondaryLight,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ...works.map(
            (work) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: Checkbox(
                      value: work.isCompleted,
                      onChanged: isActive
                          ? (value) => _toggleTask(work, works)
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      activeColor: AppColors.success,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      work.workName,
                      style: TextStyle(
                        fontSize: 14,
                        decoration: work.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: work.isCompleted
                            ? AppColors.textSecondaryLight
                            : null,
                      ),
                    ),
                  ),
                  if (isActive)
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: IconButton(
                        onPressed: () {
                          widget.habitProvider.deleteWork(
                            habitId: widget.habit.id,
                            workId: work.id,
                          );
                        },
                        icon: const Icon(Icons.close, size: 16),
                        color: AppColors.textSecondaryLight,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (isActive) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    decoration: InputDecoration(
                      hintText: 'Add a task...',
                      hintStyle: const TextStyle(fontSize: 13),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: AppColors.primary.withOpacity(0.2),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: AppColors.primary.withOpacity(0.2),
                        ),
                      ),
                    ),
                    style: const TextStyle(fontSize: 13),
                    onSubmitted: (_) => _addTask(),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 36,
                  width: 36,
                  child: IconButton(
                    onPressed: _addTask,
                    icon: const Icon(Icons.add_circle, size: 24),
                    color: AppColors.primary,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
