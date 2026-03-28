import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // REQUIRED
import '../config/app_colors.dart';
import '../config/routes.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../services/push_notification_service.dart';
import '../services/user_service.dart'; // REQUIRED

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = true;
  bool _pushNotifications = true;
  bool _isPrivateAccount = false;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAppVersion();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load local settings
    bool localDarkMode = prefs.getBool('isDarkMode') ?? true;
    
    // Load remote settings from Firestore
    bool remotePush = true;
    bool remotePrivate = false;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            if (data.containsKey('pushNotifications')) remotePush = data['pushNotifications'];
            if (data.containsKey('isPrivateAccount')) remotePrivate = data['isPrivateAccount'];
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading remote settings: $e');
    }

    if (mounted) {
      setState(() {
        _isDarkMode = localDarkMode;
        _pushNotifications = remotePush;
        _isPrivateAccount = remotePrivate;
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

  Future<void> _toggleTheme(bool value) async {
    setState(() => _isDarkMode = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
    VEffectApp.themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> _togglePushNotifications(bool value) async {
    setState(() => _pushNotifications = value);
    try {
      await UserService.instance.updateSettings(pushNotifications: value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('設定の保存に失敗しました')),
        );
        setState(() => _pushNotifications = !value); // revert
      }
    }
  }

  Future<void> _togglePrivateAccount(bool value) async {
    setState(() => _isPrivateAccount = value);
    try {
      await UserService.instance.updateSettings(isPrivateAccount: value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('設定の保存に失敗しました')),
        );
        setState(() => _isPrivateAccount = !value); // revert
      }
    }
  }

  Future<void> _launchURL(String urlString) async {
    final url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('リンクを開けませんでした')),
        );
      }
    }
  }
  
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: const Text('ログアウト', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('本当にログアウトしますか？', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル', style: TextStyle(color: AppColors.grey50)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await PushNotificationService().removeFcmToken();
              await FirebaseAuth.instance.signOut();
              if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.login);
            },
            child: const Text('ログアウト', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    // 1回目の確認ダイアログ
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: const Text(
          'アカウントを削除しますか？',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'アカウントを削除すると、プロフィール・投稿・フォロー関係などすべてのデータが完全に削除されます。この操作は取り消せません。',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル', style: TextStyle(color: AppColors.grey50)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除する', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // 2回目の確認ダイアログ
    final finalConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: const Text(
          '本当に削除しますか？',
          style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'この操作は元に戻せません。アカウントを完全に削除してよろしいですか？',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル', style: TextStyle(color: AppColors.grey50)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('完全に削除する', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (finalConfirmed != true || !mounted) return;

    // ローディング表示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await PushNotificationService().removeFcmToken();
      await AuthService().deleteAccount();
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // ローディングを閉じる
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('アカウントの削除に失敗しました。時間をおいて再度お試しください。'),
            backgroundColor: AppColors.error,
          ),
        );
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
        padding: const EdgeInsets.only(bottom: 60),
        children: [
          _buildSectionHeader('外観'),
          SwitchListTile(
            title: const Text('ダークモード', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: const Text('（※完全なライトモード対応は今後のアップデートで提供されます）', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            value: _isDarkMode,
            onChanged: _toggleTheme,
            activeThumbColor: AppColors.white,
            activeTrackColor: AppColors.grey50,
          ),
          
          _buildSectionHeader('通知'),
          SwitchListTile(
            title: const Text('プッシュ通知', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: const Text('フォローや投稿に関する通知', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            value: _pushNotifications,
            onChanged: _togglePushNotifications,
            activeThumbColor: AppColors.white,
            activeTrackColor: AppColors.grey50,
          ),

          _buildSectionHeader('プライバシー'),
          SwitchListTile(
            title: const Text('非公開アカウント', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: const Text('承認した人だけが投稿を見られるようになります', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            value: _isPrivateAccount,
            onChanged: _togglePrivateAccount,
            activeThumbColor: AppColors.white,
            activeTrackColor: AppColors.grey50,
          ),

          _buildSectionHeader('サポート・法的情報'),
          ListTile(
            title: const Text('お問い合わせ / バグ報告', style: TextStyle(color: AppColors.textPrimary)),
            trailing: const Icon(Icons.open_in_new, color: AppColors.textMuted, size: 16),
            onTap: () => _launchURL('https://forms.gle/Zj29yQmSSKCZ4Kar8'),
          ),
          ListTile(
            title: const Text('利用規約', style: TextStyle(color: AppColors.textPrimary)),
            trailing: const Icon(Icons.open_in_new, color: AppColors.textMuted, size: 16),
            onTap: () => _launchURL('https://v-effect.web.app/terms/'),
          ),
          ListTile(
            title: const Text('プライバシーポリシー', style: TextStyle(color: AppColors.textPrimary)),
            trailing: const Icon(Icons.open_in_new, color: AppColors.textMuted, size: 16),
            onTap: () => _launchURL('https://v-effect.web.app/privacy/'),
          ),
          ListTile(
            title: const Text('バージョン情報', style: TextStyle(color: AppColors.textPrimary)),
            trailing: Text(_appVersion, style: const TextStyle(color: AppColors.textMuted)),
          ),

          _buildSectionHeader('アカウント'),
          ListTile(
            title: const Text('ログアウト', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
            onTap: _confirmLogout,
          ),
          ListTile(
            title: const Text('アカウントを削除する', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
            onTap: _deleteAccount,
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
