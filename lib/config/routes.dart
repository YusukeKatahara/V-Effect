import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import '../screens/main_shell.dart';
import '../screens/camera_screen.dart';
import '../screens/register_screen.dart';
import '../screens/profile_setup_screen.dart';
import '../screens/task_setup_screen.dart';
import '../screens/profile_screen.dart';

/// アプリ全体のルート（画面の住所）定義
class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String camera = '/camera';
  static const String profileSetup = '/profile-setup';
  static const String taskSetup = '/task-setup';
  static const String friends = '/friends';
  static const String profile = '/profile';

  static Map<String, WidgetBuilder> get routes => {
        login: (context) => const LoginScreen(),
        register: (context) => const RegisterScreen(),
        home: (context) => const MainShell(),
        camera: (context) => const CameraScreen(),
        profileSetup: (context) => const ProfileSetupScreen(),
        taskSetup: (context) => const TaskSetupScreen(),
        profile: (context) => const ProfileScreen(),
      };
}
