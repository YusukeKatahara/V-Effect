import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../config/app_colors.dart';
import '../config/routes.dart';
import '../widgets/premium_background.dart';
import '../widgets/gradient_button.dart';
import '../widgets/premium_icon_header.dart';

/// パスワードリセット画面
///
/// ユーザーID とメールアドレスの両方を入力し、
/// Firestore 上で一致した場合のみリセットメールを送信します。
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _userIdCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _isSending = false;
  bool _sent = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _userIdCtrl.dispose();
    _emailCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    final userId = _userIdCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    if (userId.isEmpty || email.isEmpty) {
      _showMessage('ユーザーIDとメールアドレスの両方を入力してください。');
      return;
    }

    setState(() => _isSending = true);
    try {
      // Step 1: Cloud Functions でユーザーID + メールアドレスの一致を検証
      final callable =
          FirebaseFunctions.instance.httpsCallable('sendPasswordReset');
      await callable.call({'userId': userId, 'email': email});

      // Step 2: 検証通過後、Firebase Auth でリセットメールを送信
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) setState(() => _sent = true);
    } on FirebaseFunctionsException catch (e) {
      _showMessage(e.message ?? 'メールの送信に失敗しました。');
    } catch (e) {
      _showMessage('エラーが発生しました。もう一度お試しください。');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Stack(
        children: [
          const PremiumBackground(),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  // ── カスタムAppBar ──
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: AppColors.textPrimary),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Text('パスワードをリセット',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            )),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: _sent ? _buildSentView() : _buildFormView(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PremiumIconHeader(
            icon: Icons.lock_reset, size: 72, iconSize: 40),
        const SizedBox(height: 24),
        const Text(
          'パスワードをお忘れですか？',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        const Text(
          'ユーザーIDと登録したメールアドレスを入力してください。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _userIdCtrl,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'ユーザーID',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _emailCtrl,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'メールアドレス',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 24),
        GradientButton(
          onPressed: _sendResetEmail,
          isLoading: _isSending,
          child: const Text('リセットメールを送信'),
        ),
      ],
    );
  }

  Widget _buildSentView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.success,
            boxShadow: [
              BoxShadow(
                color: AppColors.success.withValues(alpha: 0.4),
                blurRadius: 32,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(Icons.mark_email_read,
              size: 40, color: AppColors.black),
        ),
        const SizedBox(height: 24),
        const Text(
          'メールを送信しました',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        Text(
          '${_emailCtrl.text.trim()} 宛に\nパスワードリセット用のメールを送信しました。',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 32),
        GradientButton(
          onPressed: () {
            Navigator.pushNamed(context, AppRoutes.resetPassword);
          },
          child: const Text('メールのリンクで再設定する'),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text('ログイン画面に戻る'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => _sent = false),
          child: const Text(
            'メールが届かない場合はもう一度送信',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }
}
