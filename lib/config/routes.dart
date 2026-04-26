import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import '../screens/main_shell.dart';
import '../screens/camera_screen.dart';
import '../screens/register_screen.dart';
import '../screens/profile_setup_screen.dart';
import '../screens/task_setup_screen.dart';
import '../screens/task_template_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/friends_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/search_screen.dart';
import '../screens/follow_list_screen.dart';
import '../screens/pending_requests_screen.dart';
import '../screens/user_profile_screen.dart';
import '../screens/v_practice_screen.dart';

import '../screens/initial_friend_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/reset_password_screen.dart';
import '../screens/email_verification_screen.dart';
import '../screens/auth_wrapper.dart';
import '../screens/terms_screen.dart';
import '../screens/privacy_policy_screen.dart';
import '../screens/terms_agreement_screen.dart';

/// アプリ全体のルート（画面の住所）定義
class AppRoutes {
  static const String wrapper = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String camera = '/camera';
  static const String profileSetup = '/profile-setup';
  static const String taskSetup = '/task-setup';
  static const String taskTemplate = '/task-template';
  static const String friends = '/friends';
  static const String profile = '/profile';
  static const String notifications = '/notifications';
  static const String search = '/search';
  static const String editProfile = '/edit-profile';
  static const String userProfile = '/user-profile';
  static const String followList = '/follow-list';
  static const String pendingRequests = '/pending-requests';
  static const String initialFriend = '/initial-friend';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String emailVerification = '/email-verification';
  static const String terms = '/terms';
  static const String privacyPolicy = '/privacy-policy';
  static const String termsAgreement = '/terms-agreement';
  static const String vPractice = '/v-practice';

  static Map<String, WidgetBuilder> get routes => {
        wrapper: (context) => const AuthWrapper(),
        login: (context) => const LoginScreen(),
        register: (context) => const RegisterScreen(),
        home: (context) => const MainShell(),
        camera: (context) => const CameraScreen(),
        profileSetup: (context) => const ProfileSetupScreen(),
        taskSetup: (context) => const TaskSetupScreen(),
        taskTemplate: (context) => const TaskTemplateScreen(),
        profile: (context) => const ProfileScreen(),
        friends: (context) => const FriendsScreen(),
        notifications: (context) => const NotificationsScreen(),
        search: (context) => const SearchScreen(),
        userProfile: (context) => const UserProfileScreen(),
        followList: (context) => const FollowListScreen(),
        pendingRequests: (context) => const PendingRequestsScreen(),
        initialFriend: (context) => const InitialFriendScreen(),
        forgotPassword: (context) => const ForgotPasswordScreen(),
        resetPassword: (context) => const ResetPasswordScreen(),
        emailVerification: (context) => const EmailVerificationScreen(),
        terms: (context) => const TermsScreen(),
        privacyPolicy: (context) => const PrivacyPolicyScreen(),
        termsAgreement: (context) => const TermsAgreementScreen(),
        vPractice: (context) => const VPracticeScreen(),
      };
}
