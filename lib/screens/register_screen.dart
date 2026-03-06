import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/routes.dart';

/// 新規登録画面 — メールアドレスとパスワードでアカウントを作成します
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passConfirmCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _passConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.profileSetup);
      }
    } on FirebaseAuthException catch (e) {
      String msg = '登録に失敗しました。';
      if (e.code == 'email-already-in-use') {
        msg = 'このメールアドレスは既に使われています。';
      } else if (e.code == 'weak-password') {
        msg = 'パスワードは6文字以上にしてください。';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('登録に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新規登録')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.bolt, size: 80, color: Colors.amber),
              const SizedBox(height: 24),

              // メールアドレス
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'メールアドレス',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'メールアドレスを入力してください' : null,
              ),
              const SizedBox(height: 16),

              // パスワード
              TextFormField(
                controller: _passCtrl,
                decoration: const InputDecoration(
                  labelText: 'パスワード',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'パスワードを入力してください';
                  }
                  if (v.trim().length < 6) {
                    return '6文字以上で入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // パスワード確認
              TextFormField(
                controller: _passConfirmCtrl,
                decoration: const InputDecoration(
                  labelText: 'パスワード（確認）',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'パスワードを再入力してください';
                  }
                  if (v.trim() != _passCtrl.text.trim()) {
                    return 'パスワードが一致しません';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _register,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 17),
                      ),
                      child: const Text('アカウントを作成'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
