import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _notificationsEnabled = true;
  bool _dailyReminder = true;
  bool _streakAlerts = true;
  bool _friendAlerts = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);
  bool _loading = true;

  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    final enabled =
        prefs.getBool(AppConstants.prefNotificationsEnabled) ?? true;
    final dailyReminder = prefs.getBool('daily_reminder_enabled') ?? true;
    final streakAlerts = prefs.getBool('streak_alerts_enabled') ?? true;
    final friendAlerts = prefs.getBool('friend_alerts_enabled') ?? true;

    final reminderTimeStr = prefs.getString(AppConstants.prefReminderTime);
    TimeOfDay reminderTime = const TimeOfDay(hour: 9, minute: 0);
    if (reminderTimeStr != null && reminderTimeStr.contains(':')) {
      final parts = reminderTimeStr.split(':');
      reminderTime = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 9,
        minute: int.tryParse(parts[1]) ?? 0,
      );
    }

    if (mounted) {
      setState(() {
        _notificationsEnabled = enabled;
        _dailyReminder = dailyReminder;
        _streakAlerts = streakAlerts;
        _friendAlerts = friendAlerts;
        _reminderTime = reminderTime;
        _loading = false;
      });
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
        AppConstants.prefNotificationsEnabled, _notificationsEnabled);
    await prefs.setBool('daily_reminder_enabled', _dailyReminder);
    await prefs.setBool('streak_alerts_enabled', _streakAlerts);
    await prefs.setBool('friend_alerts_enabled', _friendAlerts);

    // Apply notification changes
    if (_notificationsEnabled && _dailyReminder) {
      await _notificationService.scheduleDailyReminder(
        hour: _reminderTime.hour,
        minute: _reminderTime.minute,
      );
    } else if (!_notificationsEnabled) {
      await _notificationService.cancelAll();
    }
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _reminderTime = picked);
      await _savePreferences();
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Master toggle
                  _buildSectionCard(
                    children: [
                      _buildSwitchTile(
                        icon: Icons.notifications_active,
                        title: 'Enable Notifications',
                        subtitle: 'Turn all notifications on or off',
                        value: _notificationsEnabled,
                        onChanged: (val) async {
                          setState(() => _notificationsEnabled = val);
                          await _savePreferences();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Reminder settings
                  Text(
                    'Reminders',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondaryLight,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _buildSectionCard(
                    children: [
                      _buildSwitchTile(
                        icon: Icons.alarm,
                        title: 'Daily Reminder',
                        subtitle:
                            'Get reminded to complete your habits every day',
                        value: _dailyReminder && _notificationsEnabled,
                        enabled: _notificationsEnabled,
                        onChanged: (val) async {
                          setState(() => _dailyReminder = val);
                          await _savePreferences();
                        },
                      ),
                      if (_dailyReminder && _notificationsEnabled) ...[
                        const Divider(height: 1, indent: 56),
                        ListTile(
                          leading: const Icon(Icons.access_time,
                              color: AppColors.primary),
                          title: const Text('Reminder Time'),
                          subtitle: Text(_formatTime(_reminderTime)),
                          trailing: const Icon(Icons.chevron_right,
                              color: AppColors.textSecondaryLight),
                          onTap: _pickReminderTime,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Alert settings
                  Text(
                    'Alerts',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondaryLight,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _buildSectionCard(
                    children: [
                      _buildSwitchTile(
                        icon: Icons.local_fire_department,
                        title: 'Streak Risk Alerts',
                        subtitle:
                            'Get alerted when your streak is about to break',
                        value: _streakAlerts && _notificationsEnabled,
                        enabled: _notificationsEnabled,
                        onChanged: (val) async {
                          setState(() => _streakAlerts = val);
                          await _savePreferences();
                        },
                      ),
                      const Divider(height: 1, indent: 56),
                      _buildSwitchTile(
                        icon: Icons.people,
                        title: 'Friend Activity',
                        subtitle:
                            'Get notified about friend activities and accountability',
                        value: _friendAlerts && _notificationsEnabled,
                        enabled: _notificationsEnabled,
                        onChanged: (val) async {
                          setState(() => _friendAlerts = val);
                          await _savePreferences();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Info text
                  Center(
                    child: Text(
                      'Notification preferences are stored locally\non this device.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondaryLight,
                          ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionCard({required List<Widget> children}) {
    return Card(
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    return SwitchListTile(
      secondary: Icon(
        icon,
        color: enabled ? AppColors.primary : AppColors.textSecondaryLight,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: enabled ? null : AppColors.textSecondaryLight,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: AppColors.textSecondaryLight,
          fontSize: 12,
        ),
      ),
      value: value,
      activeColor: AppColors.primary,
      onChanged: enabled ? onChanged : null,
    );
  }
}
