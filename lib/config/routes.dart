import 'package:flutter/material.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/otp_verification_screen.dart';
import '../screens/auth/new_password_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/habits/habit_list_screen.dart';
import '../screens/habits/create_habit_screen.dart';
import '../screens/streak/streak_screen.dart';
import '../screens/analytics/analytics_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/friends/friends_screen.dart';
import '../screens/friends/add_friend_screen.dart';
import '../screens/achievements/achievements_screen.dart';
import '../screens/notifications/notification_settings_screen.dart';
import '../screens/home/home_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String otpVerification = '/otp-verification';
  static const String newPassword = '/new-password';
  static const String home = '/home';
  static const String dashboard = '/dashboard';
  static const String habitList = '/habits';
  static const String createHabit = '/habits/create';
  static const String streak = '/streak';
  static const String analytics = '/analytics';
  static const String profile = '/profile';
  static const String friends = '/friends';
  static const String addFriend = '/friends/add';
  static const String achievements = '/achievements';
  static const String notifications = '/notifications';

  static Map<String, WidgetBuilder> routes = {
    splash: (context) => const SplashScreen(),
    login: (context) => const LoginScreen(),
    register: (context) => const RegisterScreen(),
    forgotPassword: (context) => const ForgotPasswordScreen(),
    otpVerification: (context) {
      final email = ModalRoute.of(context)?.settings.arguments as String? ?? '';
      return OTPVerificationScreen(email: email);
    },
    newPassword: (context) {
      final email = ModalRoute.of(context)?.settings.arguments as String? ?? '';
      return NewPasswordScreen(email: email);
    },
    home: (context) => const HomeScreen(),
    dashboard: (context) => const DashboardScreen(),
    habitList: (context) => const HabitListScreen(),
    createHabit: (context) => const CreateHabitScreen(),
    streak: (context) => const StreakScreen(),
    analytics: (context) => const AnalyticsScreen(),
    profile: (context) => const ProfileScreen(),
    friends: (context) => const FriendsScreen(),
    addFriend: (context) => const AddFriendScreen(),
    achievements: (context) => const AchievementsScreen(),
    notifications: (context) => const NotificationSettingsScreen(),
  };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    return null;
  }
}
