import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // REQUIRED
import '../config/app_colors.dart';
import '../config/routes.dart';
import '../screens/email_verification_screen.dart';
import '../services/auth_service.dart';
import '../services/push_notification_service.dart';
import '../services/user_service.dart'; // REQUIRED

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;
  bool _focusTimeNotifications = true;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAppVersion();
  }


  Future<void> _loadSettings() async {
    // Load remote settings from Firestore
    bool remotePush = true;
    bool remoteFocusTime = true;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            if (data.containsKey('pushNotifications')) {
              remotePush = data['pushNotifications'];
            }
            if (data.containsKey('focusTimeNotifications')) {
              remoteFocusTime = data['focusTimeNotifications'];
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading remote settings: $e');
    }

    if (mounted) {
      setState(() {
        _pushNotifications = remotePush;
        _focusTimeNotifications = remoteFocusTime;
      });
    }
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = '${info.version} (${info.buildNumber})';
        });
      }
    } catch (e) {
      debugPrint('Failed to load version: $e');
    }
  }

  Future<void> _togglePushNotifications(bool value) async {
    setState(() => _pushNotifications = value);
    try {
      await UserService.instance.updateSettings(pushNotifications: value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('設定の保存に失敗しました')));
        setState(() => _pushNotifications = !value); // revert
      }
    }
  }

  Future<void> _toggleFocusTimeNotifications(bool value) async {
    setState(() => _focusTimeNotifications = value);
    try {
      await UserService.instance.updateSettings(focusTimeNotifications: value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('設定の保存に失敗しました')));
        setState(() => _focusTimeNotifications = !value); // revert
      }
    }
  }

  Future<void> _launchURL(String urlString) async {
    final url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.inAppBrowserView)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('リンクを開けませんでした')));
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: AppColors.bgBase,
        title: const Text('設定', style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 60, top: 8),
        children: [
          ListTile(
            title: const Text(
              '通知',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            trailing: const Icon(
              Icons.chevron_right,
              color: AppColors.textMuted,
            ),
            onTap: () => Navigator.pushNamed(context, AppRoutes.notificationSettings),
          ),
          ListTile(
            title: const Text(
              'パスワードとセキュリティ',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            trailing: const Icon(
              Icons.chevron_right,
              color: AppColors.textMuted,
            ),
            onTap: () => Navigator.pushNamed(context, AppRoutes.securitySettings),
          ),
          
          _buildSectionHeader('サポート・法的情報'),
          ListTile(
            title: const Text(
              'お問い合わせ / バグ報告',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            trailing: const Icon(
              Icons.open_in_new,
              color: AppColors.textMuted,
              size: 16,
            ),
            onTap: () => _launchURL('https://forms.gle/Zj29yQmSSKCZ4Kar8'),
          ),
          ListTile(
            title: const Text(
              '利用規約',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            trailing: const Icon(
              Icons.chevron_right,
              color: AppColors.textMuted,
            ),
            onTap: () => Navigator.pushNamed(context, AppRoutes.terms),
          ),
          ListTile(
            title: const Text(
              'プライバシーポリシー',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            trailing: const Icon(
              Icons.chevron_right,
              color: AppColors.textMuted,
            ),
            onTap: () => Navigator.pushNamed(context, AppRoutes.privacyPolicy),
          ),
          ListTile(
            title: const Text(
              'バージョン情報',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            trailing: Text(
              _appVersion,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
