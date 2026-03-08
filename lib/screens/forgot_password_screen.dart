import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../config/routes.dart';

/// パスワードリセット画面
///
/// ユーザーID とメールアドレスの両方を入力し、
/// Firestore 上で一致した場合のみリセットメールを送信します。
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _userIdCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _isSending = false;
  bool _sent = false;

  @override
  void dispose() {
    _userIdCtrl.dispose();
    _emailCtrl.dispose();
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
      appBar: AppBar(title: const Text('パスワードをリセット')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _sent ? _buildSentView() : _buildFormView(),
      ),
    );
  }

  Widget _buildFormView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.lock_reset, size: 80, color: Colors.amber),
        const SizedBox(height: 24),
        const Text(
          'パスワードをお忘れですか？',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          'ユーザーIDと登録したメールアドレスを入力してください。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _userIdCtrl,
          decoration: const InputDecoration(
            labelText: 'ユーザーID',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _emailCtrl,
          decoration: const InputDecoration(
            labelText: 'メールアドレス',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.email_outlined),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 24),
        _isSending
            ? const Center(child: CircularProgressIndicator())
            : ElevatedButton(
                onPressed: _sendResetEmail,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.amber.shade700,
                  textStyle: const TextStyle(fontSize: 16),
                ),
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
        const Icon(Icons.mark_email_read, size: 80, color: Colors.green),
        const SizedBox(height: 24),
        const Text(
          'メールを送信しました',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          '${_emailCtrl.text.trim()} 宛に\nパスワードリセット用のメールを送信しました。',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () {
            Navigator.pushNamed(context, AppRoutes.resetPassword);
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.amber.shade700,
            textStyle: const TextStyle(fontSize: 16),
          ),
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
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }
}
