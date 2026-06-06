import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:v_effect/l10n/app_localizations.dart';
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
        title: Text(AppLocalizations.of(context)!.securityChangePasswordDialogTitle, style: const TextStyle(color: AppColors.textPrimary)),
        content: Text(AppLocalizations.of(context)!.securityChangePasswordDialogDesc(email), style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context)!.securityChangePasswordCancel, style: const TextStyle(color: AppColors.grey50)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context)!.securityChangePasswordSend, style: const TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _auth.sendPasswordResetEmail(email: email);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.securityPasswordResetSent)),
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
        title: Text(AppLocalizations.of(context)!.securityChangeEmailDialogTitle, style: const TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.securityChangeEmailDialogDesc,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.securityNewEmailLabel,
                hintText: 'example@mail.com',
                hintStyle: const TextStyle(color: AppColors.textMuted),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context)!.securityChangePasswordCancel, style: const TextStyle(color: AppColors.grey50)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context)!.securityChangeEmailSend, style: const TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );

    if (confirmed == true && emailController.text.isNotEmpty) {
      try {
        await _auth.currentUser?.verifyBeforeUpdateEmail(emailController.text.trim());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.securityEmailVerificationSent)),
          );
        }
      } catch (e) {
        _handleError(e);
      }
    }
  }

  void _handleError(dynamic e) {
    final l10n = AppLocalizations.of(context)!;
    String message = l10n.securityErrorGeneric;
    if (e is FirebaseAuthException) {
      if (e.code == 'requires-recent-login') {
        message = l10n.securityErrorRecentLogin;
      } else if (e.code == 'invalid-email') {
        message = l10n.securityErrorInvalidEmail;
      } else if (e.code == 'email-already-in-use') {
        message = l10n.securityErrorEmailInUse;
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
        title: Text(AppLocalizations.of(context)!.securityLogoutConfirmTitle, style: const TextStyle(color: AppColors.textPrimary)),
        content: Text(AppLocalizations.of(context)!.securityLogoutConfirmMessage, style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.securityLogoutConfirmCancel, style: const TextStyle(color: AppColors.grey50)),
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
            child: Text(
              AppLocalizations.of(context)!.securityLogoutConfirmButton,
              style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
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
        title: Text(AppLocalizations.of(context)!.securityDeleteConfirmTitle, style: const TextStyle(color: AppColors.textPrimary)),
        content: Text(
          AppLocalizations.of(context)!.securityDeleteConfirmDesc,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context)!.securityDeleteConfirmCancel, style: const TextStyle(color: AppColors.grey50)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context)!.securityDeleteConfirmButton, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final finalConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: Text(
          AppLocalizations.of(context)!.securityDeleteFinalTitle,
          style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
        ),
        content: Text(
          AppLocalizations.of(context)!.securityDeleteFinalDesc,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context)!.securityDeleteFinalCancel, style: const TextStyle(color: AppColors.grey50)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context)!.securityDeleteFinalButton, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
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
          SnackBar(
            content: Text(AppLocalizations.of(context)!.securityDeleteFailed),
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
        title: Text(AppLocalizations.of(context)!.securitySettingsTitle, style: const TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
      ),
      body: ListView(
        children: [
          _buildSectionHeader(AppLocalizations.of(context)!.securityLoginRecoveryTitle, AppLocalizations.of(context)!.securityLoginRecoveryDesc),
          if (_isEmailProvider) ...[
            _buildListTile(AppLocalizations.of(context)!.securityChangePassword, Icons.lock_outline, onTap: _changePassword),
            _buildListTile(AppLocalizations.of(context)!.securityChangeEmail, Icons.email_outlined, onTap: _changeEmail),
            if (!_isEmailVerified)
              _buildListTile(
                AppLocalizations.of(context)!.securityVerifyEmail,
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

          _buildSectionHeader(AppLocalizations.of(context)!.securityAccountManagementTitle, AppLocalizations.of(context)!.securityAccountManagementDesc),
          _buildListTile(AppLocalizations.of(context)!.securityLogout, Icons.logout, isDestructive: true, onTap: _confirmLogout),
          _buildListTile(AppLocalizations.of(context)!.securityDeleteAccount, Icons.delete_forever_outlined, isDestructive: true, onTap: _deleteAccount),
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
            Text(
              AppLocalizations.of(context)!.securityLinkedAccounts,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            if (_linkedProviders.isEmpty)
              Text(AppLocalizations.of(context)!.securityNoLinkedAccounts, style: const TextStyle(color: AppColors.textMuted, fontSize: 13))
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
      case 'password': return AppLocalizations.of(context)!.securityProviderEmail;
      default: return providerId;
    }
  }
}
