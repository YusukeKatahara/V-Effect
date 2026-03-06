import 'package:flutter/material.dart';
import '../config/routes.dart';
import '../services/user_service.dart';

/// 新規登録後のプロフィール設定画面（Step 1/2）
/// ユーザー名、ユーザーID、生年月日、性別を入力します
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _userIdCtrl = TextEditingController();
  final _userService = UserService();
  bool _isSaving = false;

  // 生年月日
  int? _birthYear;
  int? _birthMonth;
  int? _birthDay;

  // 性別
  String? _gender;
  static const _genderOptions = ['男性', '女性', 'その他'];

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _userIdCtrl.dispose();
    super.dispose();
  }

  /// 選択中の年月に応じた日数を返す
  int _daysInMonth(int year, int month) {
    return DateUtils.getDaysInMonth(year, month);
  }

  Future<void> _saveAndNext() async {
    if (!_formKey.currentState!.validate()) return;

    // 生年月日のバリデーション
    if (_birthYear == null || _birthMonth == null || _birthDay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('生年月日を選択してください')),
      );
      return;
    }

    // 性別のバリデーション
    if (_gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('性別を選択してください')),
      );
      return;
    }

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

      // Firestore にプロフィール情報を保存
      final birthDate =
          '${_birthYear!}-${_birthMonth!.toString().padLeft(2, '0')}-${_birthDay!.toString().padLeft(2, '0')}';
      await _userService.saveProfile(
        username: _usernameCtrl.text.trim(),
        userId: _userIdCtrl.text.trim(),
        birthDate: birthDate,
        gender: _gender!,
      );

      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.taskSetup);
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
    final currentYear = DateTime.now().year;

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
              const SizedBox(height: 24),

              // 生年月日
              const Text(
                '生年月日',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // 年
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<int>(
                      initialValue: _birthYear,
                      decoration: const InputDecoration(
                        labelText: '年',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(
                        100,
                        (i) => currentYear - i,
                      )
                          .map((y) => DropdownMenuItem(
                                value: y,
                                child: Text('$y'),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() {
                        _birthYear = v;
                        // 日の上限を再計算
                        if (_birthMonth != null && _birthDay != null) {
                          final maxDay = _daysInMonth(_birthYear!, _birthMonth!);
                          if (_birthDay! > maxDay) _birthDay = maxDay;
                        }
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 月
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<int>(
                      initialValue: _birthMonth,
                      decoration: const InputDecoration(
                        labelText: '月',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(12, (i) => i + 1)
                          .map((m) => DropdownMenuItem(
                                value: m,
                                child: Text('$m'),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() {
                        _birthMonth = v;
                        // 日の上限を再計算
                        if (_birthYear != null && _birthDay != null) {
                          final maxDay = _daysInMonth(_birthYear!, _birthMonth!);
                          if (_birthDay! > maxDay) _birthDay = maxDay;
                        }
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 日
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<int>(
                      initialValue: _birthDay,
                      decoration: const InputDecoration(
                        labelText: '日',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(
                        (_birthYear != null && _birthMonth != null)
                            ? _daysInMonth(_birthYear!, _birthMonth!)
                            : 31,
                        (i) => i + 1,
                      )
                          .map((d) => DropdownMenuItem(
                                value: d,
                                child: Text('$d'),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _birthDay = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 性別
              const Text(
                '性別',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: _gender ?? '',
                onChanged: (v) => setState(() => _gender = v),
                child: Column(
                  children: _genderOptions.map((option) {
                    return RadioListTile<String>(
                      title: Text(option),
                      value: option,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: EdgeInsets.zero,
                    );
                  }).toList(),
                ),
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
