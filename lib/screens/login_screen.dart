import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/routes.dart';
import '../services/auth_service.dart';

/// 【rennさんへ】
/// ここはユーザーがログインや新規登録をする画面です。
/// StatefulWidget は「入力された文字」や「ロード中の状態」など、変化するデータを持つ画面で使います。
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // テキスト入力欄（メールアドレスとパスワード）の中身を管理するためのコントローラーです。
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _authService = AuthService();

  // ログイン処理中かどうかを判定する変数です。
  // これが true の時は、画面にくるくる回るアイコン（ローディング）を表示します。
  bool _isLoading = false;

  /// ログインボタンが押された時の処理です
  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      // Firebaseにメールアドレスとパスワードを送ってログインを試みます。
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(), // trim()は前後の余分な空白を消す処理です
        password: _passCtrl.text.trim(),
      );
      // ログイン成功時、ホーム画面へ移動します（今の画面は消してホームに置き換えます）。
      if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.home);
    } on FirebaseAuthException catch (e) {
      // 想定されるエラーごとに、わかりやすい日本語のメッセージを作ります。
      String msg = 'ログインに失敗しました。';
      if (e.code == 'user-not-found') {
        msg = 'ユーザーが見つかりません。登録してください。';
      } else if (e.code == 'wrong-password') {
        msg = 'パスワードが間違っています。';
      }
      _showError(msg);
    } finally {
      // 成功しても失敗しても、最後に必ずローディング状態を解除します。
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final credential = await _authService.signInWithGoogle();
      if (credential != null && mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    } catch (e) {
      _showError('Googleでのログインに失敗しました。');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _isLoading = true);
    try {
      final credential = await _authService.signInWithApple();
      if (credential != null && mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    } catch (e) {
      _showError('Appleでのログインに失敗しました。');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 新規登録ボタンが押されたとき、新規登録画面へ移動します
  void _goToRegister() {
    Navigator.pushNamed(context, AppRoutes.register);
  }

  /// エラーメッセージを画面の下からピョコッと表示する（SnackBar）ための機能です。
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('V-Effect ログイン')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bolt, size: 80, color: Colors.amber),
            const SizedBox(height: 24),
            // メールアドレス入力欄
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'メールアドレス',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            // パスワード入力欄（文字が黒丸で隠れます）
            TextField(
              controller: _passCtrl,
              decoration: const InputDecoration(
                labelText: 'パスワード',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            // ロード中ならくるくるアイコン、そうでないならボタンを表示します
            if (_isLoading)
              const CircularProgressIndicator()
            else
              Column(
                children: [
                  ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('ログイン'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: const [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('または'),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _signInWithGoogle,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    icon: Image.network(
                      'https://developers.google.com/identity/images/g-logo.png',
                      height: 24,
                      errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 24),
                    ),
                    label: const Text('Googleでログイン'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _signInWithApple,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.black,
                    ),
                    icon: const Icon(Icons.apple, size: 24),
                    label: const Text('Appleでログイン'),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: _goToRegister,
                    child: const Text('新規登録はこちら'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
