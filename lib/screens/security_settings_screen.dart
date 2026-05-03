import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_colors.dart';
import '../config/routes.dart';
import '../services/auth_service.dart';
import '../services/push_notification_service.dart';
import 'email_verification_screen.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final _auth = FirebaseAuth.instance;
  bool _isEmailVerified = false;
  bool _isEmailProvider = false;
  List<String> _linkedProviders = [];

  @override
  void initState() {
    super.initState();
    _loadAuthStatus();
  }

  Future<void> _loadAuthStatus() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload();
      if (mounted) {
        setState(() {
          _isEmailVerified = _auth.currentUser?.emailVerified ?? false;
          _isEmailProvider = _auth.currentUser?.providerData.any((p) => p.providerId == 'password') ?? false;
          _linkedProviders = _auth.currentUser?.providerData.map((p) => p.providerId).toList() ?? [];
        });
      }
    }
  }

  Future<void> _changePassword() async {
    final email = _auth.currentUser?.email;
    if (email == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: const Text('パスワードを変更', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('$email 宛にパスワード再設定用のメールを送信しますか？', style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル', style: TextStyle(color: AppColors.grey50)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('送信', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _auth.sendPasswordResetEmail(email: email);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('再設定メールを送信しました。メールをご確認ください。')),
          );
        }
      } catch (e) {
        _handleError(e);
      }
    }
  }

  Future<void> _changeEmail() async {
    final emailController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: const Text('メールアドレスを変更', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '新しいメールアドレスを入力してください。確認メールを送信します。',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: '新しいメールアドレス',
                hintText: 'example@mail.com',
                hintStyle: TextStyle(color: AppColors.textMuted),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル', style: TextStyle(color: AppColors.grey50)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('確認メールを送信', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );

    if (confirmed == true && emailController.text.isNotEmpty) {
      try {
        await _auth.currentUser?.verifyBeforeUpdateEmail(emailController.text.trim());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('新しいアドレスに確認メールを送信しました。リンクをタップして変更を完了してください。')),
          );
        }
      } catch (e) {
        _handleError(e);
      }
    }
  }

  void _handleError(dynamic e) {
    String message = 'エラーが発生しました。';
    if (e is FirebaseAuthException) {
      if (e.code == 'requires-recent-login') {
        message = 'セキュリティのため、一度ログアウトして再度ログインしてからやり直してください。';
      } else if (e.code == 'invalid-email') {
        message = '無効なメールアドレスです。';
      } else if (e.code == 'email-already-in-use') {
        message = 'このメールアドレスは既に登録されています。';
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
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
              await _auth.signOut();
              if (mounted) {
                Navigator.pushReplacementNamed(context, AppRoutes.login);
              }
            },
            child: const Text(
              'ログアウト',
              style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: const Text('アカウントを削除しますか？', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'プロフィール・投稿などすべてのデータが完全に削除されます。この操作は取り消せません。',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル', style: TextStyle(color: AppColors.grey50)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

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
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
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
            content: Text('アカウントの削除に失敗しました。再ログインして再度お試しください。'),
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
        title: const Text('パスワードとセキュリティ', style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
      ),
      body: ListView(
        children: [
          _buildSectionHeader('ログインとリカバリー', 'パスワード、ログイン設定、リカバリー方法を管理できます。'),
          if (_isEmailProvider) ...[
            _buildListTile('パスワードを変更', Icons.lock_outline, onTap: _changePassword),
            _buildListTile('メールアドレスを変更', Icons.email_outlined, onTap: _changeEmail),
            if (!_isEmailVerified)
              _buildListTile(
                'メールアドレスを認証する',
                Icons.mark_email_unread_outlined,
                onTap: () async {
                  final verified = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => const EmailVerificationScreen(),
                    ),
                  );
                  if (verified == true) _loadAuthStatus();
                },
              ),
          ],
          _buildLinkedAccounts(),

          _buildSectionHeader('アカウント管理', 'アプリへのアクセスやアカウントのデータに関する設定を行います。'),
          _buildListTile('ログアウト', Icons.logout, isDestructive: true, onTap: _confirmLogout),
          _buildListTile('アカウントを削除', Icons.delete_forever_outlined, isDestructive: true, onTap: _deleteAccount),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String description) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(String title, IconData icon, {VoidCallback? onTap, bool isDestructive = false}) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? AppColors.error : AppColors.textPrimary,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? AppColors.error : AppColors.textPrimary,
          fontWeight: isDestructive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
      onTap: onTap,
    );
  }

  Widget _buildLinkedAccounts() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '連携済みのアカウント',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            if (_linkedProviders.isEmpty)
              const Text('なし', style: TextStyle(color: AppColors.textMuted, fontSize: 13))
            else
              ..._linkedProviders.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(_getProviderIcon(p), size: 16, color: AppColors.textMuted),
                    const SizedBox(width: 12),
                    Text(
                      _getProviderName(p),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                    const Spacer(),
                    const Icon(Icons.check_circle, size: 16, color: AppColors.success),
                  ],
                ),
              )),
          ],
        ),
      ),
    );
  }

  IconData _getProviderIcon(String providerId) {
    switch (providerId) {
      case 'google.com': return Icons.g_mobiledata;
      case 'apple.com': return Icons.apple;
      case 'password': return Icons.email;
      default: return Icons.link;
    }
  }

  String _getProviderName(String providerId) {
    switch (providerId) {
      case 'google.com': return 'Google';
      case 'apple.com': return 'Apple';
      case 'password': return 'メールアドレス';
      default: return providerId;
    }
  }
}
