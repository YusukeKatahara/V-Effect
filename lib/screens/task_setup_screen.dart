import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_colors.dart';
import '../config/routes.dart';
import '../models/app_task.dart';
import '../services/analytics_service.dart';
import '../services/user_service.dart';
import '../widgets/premium_background.dart';
import '../widgets/gradient_button.dart';
import '../widgets/premium_icon_header.dart';
import '../widgets/section_title.dart';

/// 新規登録後のヒーロータスク設定画面
/// プロフィール写真、ヒーロータスク、ヒーロータスク実行時間、起床時間を入力します
/// テンプレート選択で既にヒーロータスクが1つ保存されている場合、それをプリフィルします
class TaskSetupScreen extends StatefulWidget {
  const TaskSetupScreen({super.key});

  @override
  State<TaskSetupScreen> createState() => _TaskSetupScreenState();
}

class _TaskSetupScreenState extends State<TaskSetupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _userService = UserService.instance;
  bool _isSaving = false;

  // フェードアニメーション
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  // プロフィール写真
  File? _profileImage;
  final _picker = ImagePicker();

  // ヒーロータスク入力欄（最初は1つ）
  final List<TextEditingController> _taskCtrls = [TextEditingController()];

  // ヒーロータスク実行時間と起床時間
  TimeOfDay _taskTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _wakeUpTime = const TimeOfDay(hour: 7, minute: 0);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    _loadTemplateTask();
  }

  /// テンプレートで選択済みのヒーロータスクがあればプリフィル
  Future<void> _loadTemplateTask() async {
    try {
      final uid = _userService.currentUid;
      if (uid == null) return;
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final tasks = List<String>.from(snap.data()?['tasks'] ?? []);
      if (tasks.isNotEmpty && mounted) {
        setState(() {
          _taskCtrls[0].text = tasks[0];
        });
      }
    } catch (_) {
      // テンプレートヒーロータスクの読み込みに失敗しても続行
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    for (final ctrl in _taskCtrls) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _profileImage = File(picked.path));
    }
  }

  void _addTaskField() {
    setState(() => _taskCtrls.add(TextEditingController()));
  }

  void _removeTaskField(int index) {
    if (_taskCtrls.length <= 1) return;
    setState(() {
      _taskCtrls[index].dispose();
      _taskCtrls.removeAt(index);
    });
  }

  /// 【rennさんへ】
  /// iPhoneの設定画面みたいに、スクロールで時間を選べるピッカーを表示します。
  /// 画面の下からスルッと出てきて、上下にクルクル回して選ぶやつです。
  Future<void> _pickTime({required bool isWakeUp}) async {
    final initial = isWakeUp ? _wakeUpTime : _taskTime;
    // 一時的に選択中の時・分を保持する変数
    int selectedHour = initial.hour;
    int selectedMinute = initial.minute;

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SizedBox(
              height: 320,
              child: Column(
                children: [
                  // ── ヘッダー部分：タイトルと「完了」ボタン ──
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (Navigator.of(context).canPop())
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                            ),
                            child: const Text('キャンセル'),
                          ),
                        Expanded(
                          child: Center(
                            child: Text(
                              isWakeUp ? '起きる時間' : 'ヒーロータスクの時間',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // 「完了」を押したら、選んだ時間を確定して閉じる
                            setState(() {
                              final newTime = TimeOfDay(
                                hour: selectedHour,
                                minute: selectedMinute,
                              );
                              if (isWakeUp) {
                                _wakeUpTime = newTime;
                              } else {
                                _taskTime = newTime;
                              }
                            });
                            Navigator.pop(context);
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                          ),
                          child: const Text(
                            '完了',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  // ── スクロールホイール部分 ──
                  Expanded(
                    child: Row(
                      children: [
                        // 「時」のホイール（0〜23時）
                        Expanded(
                          child: ListWheelScrollView.useDelegate(
                            itemExtent: 48,
                            diameterRatio: 1.5,
                            physics: const FixedExtentScrollPhysics(),
                            controller: FixedExtentScrollController(
                              initialItem: selectedHour,
                            ),
                            onSelectedItemChanged: (index) {
                              setModalState(() => selectedHour = index);
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: 24,
                              builder: (context, index) {
                                final isSelected = index == selectedHour;
                                return Center(
                                  child: Text(
                                    '$index時',
                                    style: TextStyle(
                                      fontSize: isSelected ? 22 : 16,
                                      fontWeight:
                                          isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                      color:
                                          isSelected
                                              ? AppColors.primary
                                              : AppColors.textMuted,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        // 「分」のホイール（0〜59分、5分刻み）
                        Expanded(
                          child: ListWheelScrollView.useDelegate(
                            itemExtent: 48,
                            diameterRatio: 1.5,
                            physics: const FixedExtentScrollPhysics(),
                            controller: FixedExtentScrollController(
                              initialItem: selectedMinute ~/ 5,
                            ),
                            onSelectedItemChanged: (index) {
                              setModalState(() => selectedMinute = index * 5);
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: 12, // 0, 5, 10, ... 55
                              builder: (context, index) {
                                final minute = index * 5;
                                final isSelected = minute == selectedMinute;
                                return Center(
                                  child: Text(
                                    '${minute.toString().padLeft(2, '0')}分',
                                    style: TextStyle(
                                      fontSize: isSelected ? 22 : 16,
                                      fontWeight:
                                          isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                      color:
                                          isSelected
                                              ? AppColors.primary
                                              : AppColors.textMuted,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 時間を「午前 7:00」「午後 9:00」のような日本語形式で画面に表示します
  String _formatTime(TimeOfDay time) {
    final period = time.hour < 12 ? '午前' : '午後';
    final h = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final m = time.minute.toString().padLeft(2, '0');
    return '$period $h:$m';
  }

  /// Firestoreに保存する用の24時間形式（例: "07:00"）
  String _formatTimeForSave(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// プロフィール画像を Firebase Storage にアップロードして URL を返す
  Future<String?> _uploadProfileImage() async {
    if (_profileImage == null) return null;
    return await _userService.uploadProfileImage(_profileImage!);
  }

  Future<void> _saveAndFinish() async {
    if (!_formKey.currentState!.validate()) return;

    final tasks =
        _taskCtrls
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .map((t) => AppTask(title: t))
            .toList();

    if (tasks.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ヒーロータスクを1つ以上入力してください')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      // プロフィール画像のアップロード
      String? photoUrl;
      if (!kIsWeb && _profileImage != null) {
        photoUrl = await _uploadProfileImage();
      }

      debugPrint('ヒーロータスク保存開始: tasks=$tasks');
      debugPrint('wakeUpTime=${_formatTimeForSave(_wakeUpTime)}');
      debugPrint('taskTime=${_formatTimeForSave(_taskTime)}');

      await _userService.saveTaskSettings(
        tasks: tasks,
        wakeUpTime: _formatTimeForSave(_wakeUpTime),
        taskTime: _formatTimeForSave(_taskTime),
        photoUrl: photoUrl,
      );

      debugPrint('ヒーロータスク保存成功！');

      final analytics = AnalyticsService.instance;
      await analytics.logTaskSetupComplete(taskCount: tasks.length);
      await analytics.logOnboardingComplete();
      await analytics.setTaskCount(tasks.length);

      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.initialFriend);
      }
    } catch (e, stackTrace) {
      debugPrint('ヒーロータスク保存エラー: $e');
      debugPrint('スタックトレース: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存に失敗しました。もう一度お試しください。'),
            duration: const Duration(seconds: 10),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  // ── Custom header ──
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
                              Icons.arrow_back,
                              color: AppColors.textPrimary,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        const Text(
                          'ヒーロータスク設定',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ── Content ──
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
                              icon: Icons.task_alt,
                              size: 72,
                              iconSize: 40,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Step 2 / 2',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'ヒーロータスクとスケジュールをカスタマイズしましょう',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 32),

                            // ── プロフィール写真 ──
                            const SectionTitle(title: 'プロフィール写真'),
                            const SizedBox(height: 12),
                            Center(
                              child: GestureDetector(
                                onTap: _pickProfileImage,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.6),
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.2),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 56,
                                    backgroundColor: AppColors.bgElevated,
                                    backgroundImage:
                                        _profileImage != null
                                            ? FileImage(_profileImage!)
                                            : null,
                                    child:
                                        _profileImage == null
                                            ? const Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.camera_alt,
                                                  size: 32,
                                                  color: AppColors.textMuted,
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  '写真を選択',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors.textMuted,
                                                  ),
                                                ),
                                              ],
                                            )
                                            : null,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // ── ヒーロータスク入力欄 ──
                            const SectionTitle(title: 'やりたいヒーロータスク'),
                            const SizedBox(height: 8),
                            ...List.generate(_taskCtrls.length, (index) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: AppColors.primaryGradient,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.black,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _taskCtrls[index],
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                        ),
                                        decoration: InputDecoration(
                                          labelText: 'ヒーロータスク ${index + 1}',
                                          hintText: '例: ランニング3km',
                                        ),
                                      ),
                                    ),
                                    if (_taskCtrls.length > 1)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                          color: AppColors.error,
                                        ),
                                        onPressed: () =>
                                            _removeTaskField(index),
                                      ),
                                  ],
                                ),
                              );
                            }),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  icon: const Icon(Icons.add),
                                  label: const Text('ヒーロータスクを追加'),
                                  onPressed: _addTaskField,
                                ),
                              ),
                            const SizedBox(height: 24),

                            // ── 起床時間（先に聞く：朝のスケジュール順） ──
                            const SectionTitle(title: 'いつも何時に起きますか？'),
                            const SizedBox(height: 4),
                            const Text(
                              'この時間に起床の通知をお届けします',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => _pickTime(isWakeUp: true),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.alarm),
                                ),
                                child: Text(
                                  _formatTime(_wakeUpTime),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // ── ヒーロータスク実行時間 ──
                            const SectionTitle(title: 'ヒーロータスクをいつやりたいですか？'),
                            const SizedBox(height: 4),
                            const Text(
                              'この時間に通知を送ってヒーロータスクをリマインドします',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => _pickTime(isWakeUp: false),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.schedule),
                                ),
                                child: Text(
                                  _formatTime(_taskTime),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),

                            // ── 完了ボタン ──
                            GradientButton(
                              onPressed: _saveAndFinish,
                              isLoading: _isSaving,
                              child: const Text('設定を完了してはじめる'),
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
