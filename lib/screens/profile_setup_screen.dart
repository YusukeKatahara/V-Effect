import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_colors.dart';
import '../config/routes.dart';
import '../services/analytics_service.dart';
import '../services/user_service.dart';
import '../widgets/premium_background.dart';
import '../widgets/gradient_button.dart';
import '../widgets/premium_icon_header.dart';
import '../widgets/section_title.dart';

/// 新規登録後のプロフィール設定画面（Step 1/2）
/// ユーザー名、ユーザーID、生年月日、性別を入力します
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _userIdCtrl = TextEditingController();
  final _userService = UserService.instance;
  bool _isSaving = false;

  // 生年月日
  int? _birthYear;
  int? _birthMonth;
  int? _birthDay;

  // 性別
  String? _gender;
  static const _genderOptions = ['男性', '女性', 'その他'];

  // 追加項目
  TimeOfDay? _wakeUpTime;
  TimeOfDay? _taskTime;
  
  String? _occupation;
  static const _occupationOptions = [
    '会社員',
    '経営者・役員',
    '公務員',
    '自営業・フリーランス',
    '専門職（医師・弁護士など）',
    '教員・教育関係',
    '学生',
    'パート・アルバイト',
    '専業主婦・主夫',
    '無職',
    'その他',
  ];

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _userIdCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '選択してください';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  void _showTimePickerBottomSheet(
    BuildContext context,
    String title,
    TimeOfDay? initialTime,
    ValueChanged<TimeOfDay> onTimeSelected,
  ) {
    TimeOfDay selectedTime = initialTime ?? const TimeOfDay(hour: 7, minute: 0);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext builder) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      child: const Text('キャンセル', style: TextStyle(color: AppColors.textSecondary)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                    TextButton(
                      child: const Text('完了', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        onTimeSelected(selectedTime);
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 216,
                child: CupertinoTheme(
                  data: const CupertinoThemeData(
                    textTheme: CupertinoTextThemeData(
                      dateTimePickerTextStyle: TextStyle(color: AppColors.textPrimary, fontSize: 22),
                    ),
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    initialDateTime: DateTime(2024, 1, 1, selectedTime.hour, selectedTime.minute),
                    use24hFormat: true,
                    onDateTimeChanged: (DateTime newDateTime) {
                      selectedTime = TimeOfDay.fromDateTime(newDateTime);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showOccupationPickerBottomSheet(BuildContext context) {
    int selectedIndex = _occupationOptions.indexOf(_occupation ?? _occupationOptions[0]);
    if (selectedIndex == -1) selectedIndex = 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext builder) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      child: const Text('キャンセル', style: TextStyle(color: AppColors.textSecondary)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Text('職業を選択', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                    TextButton(
                      child: const Text('完了', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        setState(() {
                          _occupation = _occupationOptions[selectedIndex];
                        });
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 216,
                child: CupertinoTheme(
                  data: const CupertinoThemeData(
                    textTheme: CupertinoTextThemeData(
                      pickerTextStyle: TextStyle(color: AppColors.textPrimary, fontSize: 20),
                    ),
                  ),
                  child: CupertinoPicker(
                    scrollController: FixedExtentScrollController(initialItem: selectedIndex),
                    itemExtent: 40,
                    onSelectedItemChanged: (int index) {
                      selectedIndex = index;
                    },
                    children: _occupationOptions.map((String value) {
                      return Center(
                        child: Text(
                          value,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 20),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 選択中の年月に応じた日数を返す
  int _daysInMonth(int year, int month) {
    return DateUtils.getDaysInMonth(year, month);
  }

  Future<void> _saveAndNext() async {
    if (!_formKey.currentState!.validate()) return;

    // 生年月日のバリデーション
    if (_birthYear == null || _birthMonth == null || _birthDay == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('生年月日を選択してください')));
      return;
    }

    // 性別のバリデーション
    if (_gender == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('性別を選択してください')));
      return;
    }

    // 追加項目のバリデーション
    if (_occupation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('職業を選択してください')),
      );
      return;
    }
    if (_wakeUpTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('起床時間を設定してください')),
      );
      return;
    }
    if (_taskTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ヒーロータスク時間を設定してください')),
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('このユーザーIDは既に使われています')));
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
        wakeUpTime: '${_wakeUpTime!.hour.toString().padLeft(2, '0')}:${_wakeUpTime!.minute.toString().padLeft(2, '0')}',
        taskTime: '${_taskTime!.hour.toString().padLeft(2, '0')}:${_taskTime!.minute.toString().padLeft(2, '0')}',
        occupation: _occupation!,
      );

      await AnalyticsService.instance.logProfileSetupComplete();

      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppRoutes.taskTemplate, (r) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存に失敗しました。もう一度お試しください。')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;

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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        if (Navigator.of(context).canPop())
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: AppColors.textPrimary,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        const Text(
                          'プロフィール設定',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 8),
                            const PremiumIconHeader(
                              icon: Icons.person_outline,
                              size: 72,
                              iconSize: 40,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Step 1 / 2',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'あなたのプロフィールを設定しましょう',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 32),

                            // ユーザー名
                            TextFormField(
                              controller: _usernameCtrl,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'ユーザー名',
                                hintText: '例: V EFFECT',
                                prefixIcon: Icon(Icons.badge),
                              ),
                              validator:
                                  (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'ユーザー名を入力してください'
                                          : null,
                            ),
                            const SizedBox(height: 16),

                            // ユーザーID
                            TextFormField(
                              controller: _userIdCtrl,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'ユーザーID',
                                hintText: '例: v_effect',
                                prefixIcon: Icon(Icons.alternate_email),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'ユーザーIDを入力してください';
                                }
                                final adminEmails = [
                                  'ren0930ren0930@gmail.com',
                                  'y.katahara.academia@gmail.com'
                                ];
                                final isSpecialAdmin = adminEmails.contains(FirebaseAuth.instance.currentUser?.email);
                                if (!isSpecialAdmin) {
                                  if (v.trim().length < 5) {
                                    return '5文字以上で入力してください';
                                  }
                                  if (!RegExp(
                                    r'^[a-zA-Z0-9_]+$',
                                  ).hasMatch(v.trim())) {
                                    return '英数字とアンダースコアのみ使えます';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            // 生年月日
                            const SectionTitle(title: '生年月日'),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                // 年
                                Expanded(
                                  flex: 3,
                                  child: DropdownButtonFormField<int>(
                                    initialValue: _birthYear,
                                    dropdownColor: AppColors.bgElevated,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: '年',
                                    ),
                                    items:
                                        List.generate(
                                              100,
                                              (i) => currentYear - i,
                                            )
                                            .map(
                                              (y) => DropdownMenuItem(
                                                value: y,
                                                child: Text('$y'),
                                              ),
                                            )
                                            .toList(),
                                    onChanged:
                                        (v) => setState(() {
                                          _birthYear = v;
                                          // 日の上限を再計算
                                          if (_birthMonth != null &&
                                              _birthDay != null) {
                                            final maxDay = _daysInMonth(
                                              _birthYear!,
                                              _birthMonth!,
                                            );
                                            if (_birthDay! > maxDay) {
                                              _birthDay = maxDay;
                                            }
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
                                    dropdownColor: AppColors.bgElevated,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: '月',
                                    ),
                                    items:
                                        List.generate(12, (i) => i + 1)
                                            .map(
                                              (m) => DropdownMenuItem(
                                                value: m,
                                                child: Text('$m'),
                                              ),
                                            )
                                            .toList(),
                                    onChanged:
                                        (v) => setState(() {
                                          _birthMonth = v;
                                          // 日の上限を再計算
                                          if (_birthYear != null &&
                                              _birthDay != null) {
                                            final maxDay = _daysInMonth(
                                              _birthYear!,
                                              _birthMonth!,
                                            );
                                            if (_birthDay! > maxDay) {
                                              _birthDay = maxDay;
                                            }
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
                                    dropdownColor: AppColors.bgElevated,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: '日',
                                    ),
                                    items:
                                        List.generate(
                                              (_birthYear != null &&
                                                      _birthMonth != null)
                                                  ? _daysInMonth(
                                                    _birthYear!,
                                                    _birthMonth!,
                                                  )
                                                  : 31,
                                              (i) => i + 1,
                                            )
                                            .map(
                                              (d) => DropdownMenuItem(
                                                value: d,
                                                child: Text('$d'),
                                              ),
                                            )
                                            .toList(),
                                    onChanged:
                                        (v) => setState(() => _birthDay = v),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // 性別
                            const SectionTitle(title: '性別'),
                            const SizedBox(height: 8),
                            RadioGroup<String>(
                              groupValue: _gender ?? '',
                              onChanged:
                                  (v) => setState(() => _gender = v),
                              child: Column(
                                children:
                                    _genderOptions.map((option) {
                                      return RadioListTile<String>(
                                        title: Text(
                                          option,
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        value: option,
                                        activeColor: AppColors.primary,
                                        tileColor: AppColors.bgSurface,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        contentPadding: EdgeInsets.zero,
                                      );
                                    }).toList(),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // 職業
                            const SectionTitle(title: '職業（非公開情報）'),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => _showOccupationPickerBottomSheet(context),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                decoration: BoxDecoration(
                                  color: AppColors.bgElevated,
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _occupation ?? '選択してください',
                                      style: TextStyle(
                                        color: _occupation == null ? AppColors.textSecondary : AppColors.textPrimary,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // 起床時間
                            const SectionTitle(title: '起床時間'),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => _showTimePickerBottomSheet(
                                context,
                                '起床時間を設定',
                                _wakeUpTime,
                                (t) => setState(() => _wakeUpTime = t),
                              ),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                decoration: BoxDecoration(
                                  color: AppColors.bgElevated,
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatTime(_wakeUpTime),
                                      style: TextStyle(
                                        color: _wakeUpTime == null ? AppColors.textSecondary : AppColors.textPrimary,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const Icon(Icons.access_time, color: AppColors.textSecondary),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // ヒーロータスク時間
                            const SectionTitle(title: 'ヒーロータスク実行時間'),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => _showTimePickerBottomSheet(
                                context,
                                'ヒーロータスク実行時間を設定',
                                _taskTime,
                                (t) => setState(() => _taskTime = t),
                              ),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                decoration: BoxDecoration(
                                  color: AppColors.bgElevated,
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatTime(_taskTime),
                                      style: TextStyle(
                                        color: _taskTime == null ? AppColors.textSecondary : AppColors.textPrimary,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const Icon(Icons.access_time, color: AppColors.textSecondary),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),

                            // 次へボタン
                            GradientButton(
                              onPressed: _saveAndNext,
                              isLoading: _isSaving,
                              child: const Text('次へ'),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
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
}
