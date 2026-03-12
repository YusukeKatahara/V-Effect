import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_colors.dart';
import '../config/routes.dart';
import '../widgets/premium_background.dart';
import '../widgets/gradient_button.dart';
import '../widgets/premium_icon_header.dart';

/// パスワード再設定画面
///
/// メールのリンクから取得した oobCode を使って新しいパスワードを設定します。
/// - ディープリンク経由: oobCode が自動で渡される
/// - 手動入力: メールのリンクをペーストして oobCode を抽出
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _linkCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  bool _resetDone = false;

  // oobCode が確認済みかどうか
  String? _oobCode;
  String? _email;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ルート引数から oobCode を受け取る（ディープリンク経由）
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, String>?;
    if (args != null && args['oobCode'] != null && _oobCode == null) {
      _verifyCode(args['oobCode']!);
    }
  }

  @override
  void dispose() {
    _linkCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  /// リンクから oobCode を抽出
  String? _extractOobCode(String input) {
    final trimmed = input.trim();
    // URL 形式の場合: oobCode パラメータを抽出
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.queryParameters.containsKey('oobCode')) {
      return uri.queryParameters['oobCode'];
    }
    // 直接コードが入力された場合はそのまま返す
    if (trimmed.length > 10 && !trimmed.contains(' ')) {
      return trimmed;
    }
    return null;
  }

  /// oobCode を検証
  Future<void> _verifyCode(String code) async {
    setState(() => _isLoading = true);
    try {
      final info = await _auth.checkActionCode(code);
      if (mounted) {
        setState(() {
          _oobCode = code;
          _email = info.data['email'] as String?;
        });
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'リンクが無効です。もう一度お試しください。';
      if (e.code == 'expired-action-code') {
        msg = 'リンクの有効期限が切れています。もう一度メールを送信してください。';
      } else if (e.code == 'invalid-action-code') {
        msg = 'リンクが無効です。正しいリンクを貼り付けてください。';
      }
      _showMessage(msg);
    } catch (e) {
      _showMessage('エラーが発生しました。もう一度お試しください。');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// リンクを貼り付けて検証
  Future<void> _submitLink() async {
    final code = _extractOobCode(_linkCtrl.text);
    if (code == null) {
      _showMessage('メールに記載されたリンクを貼り付けてください。');
      return;
    }
    await _verifyCode(code);
  }

  /// 新しいパスワードを設定
  Future<void> _resetPassword() async {
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;

    if (password.length < 6) {
      _showMessage('パスワードは6文字以上にしてください。');
      return;
    }
    if (password != confirm) {
      _showMessage('パスワードが一致しません。');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _auth.confirmPasswordReset(code: _oobCode!, newPassword: password);
      if (mounted) setState(() => _resetDone = true);
    } on FirebaseAuthException catch (e) {
      String msg = 'パスワードの再設定に失敗しました。';
      if (e.code == 'expired-action-code') {
        msg = 'リンクの有効期限が切れています。もう一度メールを送信してください。';
      } else if (e.code == 'weak-password') {
        msg = 'パスワードが弱すぎます。より強いパスワードを設定してください。';
      }
      _showMessage(msg);
    } catch (e) {
      _showMessage('エラーが発生しました。もう一度お試しください。');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                        const Text('パスワード再設定',
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
                      child: _resetDone
                          ? _buildDoneView()
                          : _oobCode != null
                              ? _buildNewPasswordView()
                              : _buildLinkInputView(),
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

  /// Step 1: リンクを貼り付ける画面
  Widget _buildLinkInputView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PremiumIconHeader(icon: Icons.link, size: 72, iconSize: 40),
        const SizedBox(height: 24),
        const Text(
          'メールのリンクを貼り付け',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        const Text(
          'パスワードリセットのメールに記載されている\nリンクをコピーして、下の欄に貼り付けてください。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _linkCtrl,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'リンクを貼り付け',
            hintText: 'https://...',
            prefixIcon: Icon(Icons.content_paste),
          ),
          maxLines: 2,
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 24),
        GradientButton(
          onPressed: _submitLink,
          isLoading: _isLoading,
          child: const Text('次へ'),
        ),
      ],
    );
  }

  /// Step 2: 新しいパスワードを入力する画面
  Widget _buildNewPasswordView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PremiumIconHeader(
            icon: Icons.lock_open, size: 72, iconSize: 40),
        const SizedBox(height: 24),
        const Text(
          '新しいパスワードを設定',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary),
        ),
        if (_email != null) ...[
          const SizedBox(height: 8),
          Text(
            _email!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: 32),
        TextField(
          controller: _passwordCtrl,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            labelText: '新しいパスワード',
            prefixIcon: Icon(Icons.lock_outline),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmCtrl,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'パスワードを確認',
            prefixIcon: Icon(Icons.lock_outline),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 24),
        GradientButton(
          onPressed: _resetPassword,
          isLoading: _isLoading,
          child: const Text('パスワードを再設定'),
        ),
      ],
    );
  }

  /// Step 3: 完了画面
  Widget _buildDoneView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
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
            child: const Icon(Icons.check_circle,
                size: 40, color: Color(0xFF1A1000)),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'パスワードを再設定しました',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        const Text(
          '新しいパスワードでログインしてください。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 32),
        GradientButton(
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.login,
              (route) => false,
            );
          },
          child: const Text('ログイン画面へ'),
        ),
      ],
    );
  }
}
