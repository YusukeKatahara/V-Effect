import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/routes.dart';
import '../services/user_service.dart';

/// 新規登録後のプロフィール設定画面（Step 1/2）
/// ユーザー名、ユーザーID、メールアドレスを入力します
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _userIdCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passConfirmCtrl = TextEditingController();
  final _userService = UserService();
  bool _isSaving = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _userIdCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _passConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAndNext() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      // ユーザーIDの重複チェック
      final available = await _userService.isUserIdAvailable(
        _userIdCtrl.text.trim(),
      );
      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('このユーザーIDは既に使われています')),
          );
        }
        return;
      }

      // Firebase Auth でアカウントを作成
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      // Firestore にプロフィール情報を保存
      await _userService.saveProfile(
        username: _usernameCtrl.text.trim(),
        userId: _userIdCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
      );

      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.taskSetup);
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
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('プロフィール設定')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.person_outline, size: 80, color: Colors.amber),
              const SizedBox(height: 8),
              const Text(
                'Step 1 / 2',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              const Text(
                'あなたのプロフィールを設定しましょう',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),

              // ユーザー名
              TextFormField(
                controller: _usernameCtrl,
                decoration: const InputDecoration(
                  labelText: 'ユーザー名',
                  hintText: '例: れん',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'ユーザー名を入力してください' : null,
              ),
              const SizedBox(height: 16),

              // ユーザーID
              TextFormField(
                controller: _userIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'ユーザーID',
                  hintText: '例: renn_123',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.alternate_email),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'ユーザーIDを入力してください';
                  }
                  if (v.trim().length < 3) {
                    return '3文字以上で入力してください';
                  }
                  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v.trim())) {
                    return '英数字とアンダースコアのみ使えます';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

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

              // 次へボタン
              _isSaving
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _saveAndNext,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 17),
                      ),
                      child: const Text('次へ'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
