import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_colors.dart';
import '../config/routes.dart';

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

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _linkCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  bool _resetDone = false;

  // oobCode が確認済みかどうか
  String? _oobCode;
  String? _email;

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
      appBar: AppBar(title: const Text('パスワード再設定')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _resetDone
            ? _buildDoneView()
            : _oobCode != null
                ? _buildNewPasswordView()
                : _buildLinkInputView(),
      ),
    );
  }

  /// Step 1: リンクを貼り付ける画面
  Widget _buildLinkInputView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.link, size: 80, color: AppColors.primary),
        const SizedBox(height: 24),
        const Text(
          'メールのリンクを貼り付け',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
          decoration: const InputDecoration(
            labelText: 'リンクを貼り付け',
            hintText: 'https://...',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.content_paste),
          ),
          maxLines: 2,
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 24),
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ElevatedButton(
                onPressed: _submitLink,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.primary,
                  foregroundColor: const Color(0xFF1A1000),
                  textStyle: const TextStyle(fontSize: 16),
                ),
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
        const Icon(Icons.lock_open, size: 80, color: AppColors.primary),
        const SizedBox(height: 24),
        const Text(
          '新しいパスワードを設定',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
          decoration: const InputDecoration(
            labelText: '新しいパスワード',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.lock_outline),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmCtrl,
          decoration: const InputDecoration(
            labelText: 'パスワードを確認',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.lock_outline),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 24),
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ElevatedButton(
                onPressed: _resetPassword,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.primary,
                  foregroundColor: const Color(0xFF1A1000),
                  textStyle: const TextStyle(fontSize: 16),
                ),
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
        const Icon(Icons.check_circle, size: 80, color: AppColors.success),
        const SizedBox(height: 24),
        const Text(
          'パスワードを再設定しました',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          '新しいパスワードでログインしてください。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.login,
              (route) => false,
            );
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: AppColors.primary,
            foregroundColor: const Color(0xFF1A1000),
            textStyle: const TextStyle(fontSize: 16),
          ),
          child: const Text('ログイン画面へ'),
        ),
      ],
    );
  }
}
