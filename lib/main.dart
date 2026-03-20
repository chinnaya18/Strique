import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'config/constants.dart';
import 'providers/auth_provider.dart';
import 'providers/habit_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/friendship_provider.dart';
import 'services/notification_service.dart';
import 'services/cross_device_sync_service.dart';
import 'services/completion_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with options for web
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyBJ0Ry2z29T94g9GoBrEPi-6uzDha1nfzM",
        authDomain: "streakforge-c709f.firebaseapp.com",
        projectId: "streakforge-c709f",
        storageBucket: "streakforge-c709f.firebasestorage.app",
        messagingSenderId: "395796914101",
        appId: '1:395796914101:web:45067f9805b22a85e643fc',
        databaseURL: "https://streakforge-c709f.firebaseio.com",
      ),
    );
    debugPrint('✅ Firebase initialized successfully.');
  } catch (e) {
    debugPrint('⚠️ Firebase initialization warning: $e');
  }

  // Initialize Notifications
  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('⚠️ Notification initialization failed: $e');
  }

  // Initialize Cross-Device Sync Service
  try {
    await CrossDeviceSyncService().initialize();
  } catch (e) {
    debugPrint('⚠️ CrossDeviceSyncService initialization failed: $e');
  }

  // Initialize background tasks for streak management
  _initializeStreakManagement();

  // Set preferred orientations
  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } catch (e) {
    debugPrint('⚠️ Orientation settings not supported on this platform.');
  }

  runApp(const StreakForgeApp());
}

/// Initialize background streak management tasks
void _initializeStreakManagement() {
  // Check and reset streaks every day at midnight
  _scheduleStreakCheck();
  // Send incomplete reminders daily at 8 PM
  _scheduleIncompleteReminders();
}

void _scheduleStreakCheck() {
  // This would normally use a scheduling library like workmanager
  // For now, we'll implement it as a periodic check when app is open
  Future.delayed(const Duration(seconds: 5), () async {
    while (true) {
      try {
        await CompletionSyncService().checkAndResetStreaksIfNeeded();
        // Check every hour
        await Future.delayed(const Duration(hours: 1));
      } catch (e) {
        debugPrint('Error in streak check loop: $e');
        await Future.delayed(const Duration(minutes: 5));
      }
    }
  });
}

void _scheduleIncompleteReminders() {
  // Send reminders at 8 PM daily
  Future.delayed(const Duration(seconds: 10), () async {
    while (true) {
      try {
        final now = DateTime.now();
        // Send at 8 PM
        if (now.hour == 20) {
          await CompletionSyncService().sendIncompleteReminders();
          // Wait until next day
          await Future.delayed(const Duration(hours: 1));
        } else {
          await Future.delayed(const Duration(minutes: 5));
        }
      } catch (e) {
        debugPrint('Error in incomplete reminders loop: $e');
        await Future.delayed(const Duration(minutes: 5));
      }
    }
  });
}

class StreakForgeApp extends StatelessWidget {
  const StreakForgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => HabitProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => FriendshipProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,

            // Theme
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,

            // Routes
            initialRoute: AppRoutes.splash,
            routes: AppRoutes.routes,
            onGenerateRoute: AppRoutes.onGenerateRoute,
          );
        },
      ),
    );
  }
}
