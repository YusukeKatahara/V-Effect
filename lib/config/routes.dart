import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import '../screens/main_shell.dart';
import '../screens/camera_screen.dart';
import '../screens/register_screen.dart';
import '../screens/profile_setup_screen.dart';
import '../screens/task_setup_screen.dart';
import '../screens/task_template_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/search_screen.dart';
import '../screens/follow_list_screen.dart';
import '../screens/pending_requests_screen.dart';
import '../screens/user_profile_screen.dart';
import '../screens/v_practice_screen.dart';
import '../screens/v_timeline_screen.dart';

import '../screens/initial_friend_screen.dart';
import '../screens/onboarding/v_effect_screen.dart';
import '../screens/onboarding/profile_settings_screen.dart';
import '../screens/onboarding/first_v_quest_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/reset_password_screen.dart';
import '../screens/email_verification_screen.dart';
import '../screens/auth_wrapper.dart';
import '../screens/terms_screen.dart';
import '../screens/privacy_policy_screen.dart';
import '../screens/notification_settings_screen.dart';
import '../screens/security_settings_screen.dart';
import '../screens/blog_post_detail_screen.dart';
import '../screens/blog_post_editor_screen.dart';
import '../screens/display_settings_screen.dart';
import '../screens/chat/direct_chat_list_screen.dart';
import '../screens/chat/direct_chat_screen.dart';



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
  static const String notificationSettings = '/notification-settings';
  static const String securitySettings = '/security-settings';
  static const String vPractice = '/v-practice';
  static const String blogPostDetail = '/blog-post-detail';
  static const String blogPostEditor = '/blog-post-editor';
  static const String onboardingVEffect     = '/onboarding/v-effect';
  static const String onboardingProfile     = '/onboarding/profile';
  static const String onboardingFirstQuest  = '/onboarding/first-quest';
  static const String displaySettings       = '/display-settings';
  static const String vTimeline             = '/v-timeline';
  static const String directChatList        = '/direct-chats';
  static const String directChat            = '/direct-chat';


  static Map<String, WidgetBuilder> get routes => {
        wrapper: (context) => const AuthWrapper(),
        displaySettings: (context) => const DisplaySettingsScreen(),
        directChatList: (context) => const DirectChatListScreen(),
        directChat: (context) {
          final args = ModalRoute.of(context)?.settings.arguments as DirectChatScreenArgs;
          return DirectChatScreen(args: args);
        },
        login: (context) => const LoginScreen(),
        register: (context) => const RegisterScreen(),
        home: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is int) {
            MainShell.activeTabIndex.value = args;
          }
          return MainShell(initialIndex: MainShell.activeTabIndex.value);
        },
        camera: (context) {
          final args = ModalRoute.of(context)?.settings.arguments as String?;
          return CameraScreen(heroTaskName: args);
        },
        profileSetup: (context) => const ProfileSetupScreen(),
        taskSetup: (context) => const TaskSetupScreen(),
        taskTemplate: (context) => const TaskTemplateScreen(),
        profile: (context) => const ProfileScreen(),
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
        notificationSettings: (context) => const NotificationSettingsScreen(),
        securitySettings: (context) => const SecuritySettingsScreen(),
        vPractice: (context) => const VPracticeScreen(),
        blogPostDetail: (context) => const BlogPostDetailScreen(),
        blogPostEditor: (context) => const BlogPostEditorScreen(),
        onboardingVEffect: (context) => const VEffectScreen(),
        onboardingProfile: (context) => const OnboardingProfileSettingsScreen(),
        onboardingFirstQuest: (context) => const FirstVQuestScreen(),
        vTimeline: (context) => const VTimelineScreen(),
      };
}
