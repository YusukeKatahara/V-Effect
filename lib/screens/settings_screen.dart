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
  bool _isEmailVerified = false;
  bool _isEmailProvider = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAppVersion();
    _loadEmailVerificationStatus();
  }

  Future<void> _loadEmailVerificationStatus() async {
    try {
      await FirebaseAuth.instance.currentUser?.reload();
    } catch (_) {}
    final user = FirebaseAuth.instance.currentUser;
    if (mounted) {
      setState(() {
        _isEmailProvider =
            user?.providerData.any((p) => p.providerId == 'password') == true;
        _isEmailVerified = user?.emailVerified == true;
      });
    }
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

  void _confirmLogout() {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppColors.bgElevated,
            title: const Text(
              'ログアウト',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            content: const Text(
              '本当にログアウトしますか？',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'キャンセル',
                  style: TextStyle(color: AppColors.grey50),
                ),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await PushNotificationService().removeFcmToken();
                  await FirebaseAuth.instance.signOut();
                  if (mounted) {
                    Navigator.pushReplacementNamed(context, AppRoutes.login);
                  }
                },
                child: const Text(
                  'ログアウト',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _setPassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    final passwordController = TextEditingController();
    final confirmController = TextEditingController();

    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          String? errorMessage;
          return AlertDialog(
            backgroundColor: AppColors.bgElevated,
            title: const Text('パスワードを設定', style: TextStyle(color: AppColors.textPrimary)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.email!, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  autofocus: true,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'パスワード（6文字以上）',
                    hintStyle: TextStyle(color: AppColors.textMuted),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textMuted)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textPrimary)),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'パスワード（確認）',
                    hintStyle: TextStyle(color: AppColors.textMuted),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textMuted)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textPrimary)),
                  ),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(errorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('キャンセル', style: TextStyle(color: AppColors.grey50)),
              ),
              TextButton(
                onPressed: () {
                  final pw = passwordController.text;
                  final confirm = confirmController.text;
                  if (pw.length < 6) {
                    setDialogState(() => errorMessage = 'パスワードは6文字以上にしてください');
                    return;
                  }
                  if (pw != confirm) {
                    setDialogState(() => errorMessage = 'パスワードが一致しません');
                    return;
                  }
                  Navigator.pop(ctx, pw);
                },
                child: const Text('設定', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );

    if (password == null || !mounted) return;

    try {
      final credential = EmailAuthProvider.credential(email: user.email!, password: password);
      await user.linkWithCredential(credential);
      setState(() => _isEmailProvider = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('パスワードを設定しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('パスワードの設定に失敗しました'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$email にパスワード再設定メールを送信しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('メールの送信に失敗しました'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _changeEmail() async {
    final controller = TextEditingController();
    final newEmail = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: const Text('メールアドレスの変更', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: '新しいメールアドレス',
            hintStyle: TextStyle(color: AppColors.textMuted),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textMuted)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textPrimary)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル', style: TextStyle(color: AppColors.grey50)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('変更', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (newEmail == null || newEmail.isEmpty || !mounted) return;
    try {
      await FirebaseAuth.instance.currentUser?.verifyBeforeUpdateEmail(newEmail);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$newEmail に確認メールを送信しました。確認後に変更が反映されます。')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('メールアドレスの変更に失敗しました'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _deleteAccount() async {
    // 1回目の確認ダイアログ
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppColors.bgElevated,
            title: const Text(
              'アカウントを削除しますか？',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            content: const Text(
              'アカウントを削除すると、プロフィール・投稿・フォロー関係などすべてのデータが完全に削除されます。この操作は取り消せません。',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'キャンセル',
                  style: TextStyle(color: AppColors.grey50),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  '削除',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;

    // 2回目の確認ダイアログ
    final finalConfirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppColors.bgElevated,
            title: const Text(
              '本当に削除しますか？',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              'この操作は元に戻せません。アカウントを完全に削除してよろしいですか？',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'キャンセル',
                  style: TextStyle(color: AppColors.grey50),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  '完全に削除する',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
          _buildSectionHeader('通知'),
          SwitchListTile(
            title: const Text(
              'プッシュ通知',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            subtitle: const Text(
              'フォローや投稿に関する通知',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            value: _pushNotifications,
            onChanged: _togglePushNotifications,
            activeColor: AppColors.white,
            activeTrackColor: AppColors.grey50,
          ),
          SwitchListTile(
            title: const Text(
              'V Alert 通知',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            subtitle: const Text(
              '自分で決めた頑張り時のリマインダー',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            value: _focusTimeNotifications,
            onChanged: _toggleFocusTimeNotifications,
            activeColor: AppColors.white,
            activeTrackColor: AppColors.grey50,
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

          _buildSectionHeader('アカウント'),
          if (!_isEmailVerified)
            ListTile(
              title: const Text(
                'メールアドレスを認証する',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              leading: const Icon(
                Icons.mark_email_unread_outlined,
                color: AppColors.textPrimary,
              ),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
              onTap: () async {
                final verified = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => const EmailVerificationScreen(),
                  ),
                );
                if (verified == true) _loadEmailVerificationStatus();
              },
            ),
          ListTile(
            title: Text(
              _isEmailProvider ? 'パスワードの再設定' : 'パスワード',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            subtitle: _isEmailProvider
                ? null
                : const Text('未設定', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            leading: const Icon(Icons.lock_reset, color: AppColors.textPrimary),
            trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
            onTap: _isEmailProvider ? _resetPassword : _setPassword,
          ),
          ListTile(
            title: const Text(
              'メールアドレスの変更',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            leading: const Icon(Icons.email_outlined, color: AppColors.textPrimary),
            trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
            onTap: _changeEmail,
          ),
          ListTile(
            title: const Text(
              'ログアウト',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: _confirmLogout,
          ),
          ListTile(
            title: const Text(
              'アカウントを削除',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
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
