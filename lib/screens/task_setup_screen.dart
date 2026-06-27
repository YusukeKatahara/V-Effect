import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:v_effect/l10n/app_localizations.dart';

import '../config/app_colors.dart';
import '../config/routes.dart';
import '../models/app_task.dart';
import '../services/analytics_service.dart';
import '../services/user_service.dart';
import '../widgets/premium_background.dart';
import '../widgets/gradient_button.dart';
import '../widgets/premium_icon_header.dart';
import '../widgets/section_title.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/service_providers.dart';

/// 新規登録後のヒーロータスク設定画面
/// プロフィール写真、ヒーロータスク、ヒーロータスク実行時間、起床時間を入力します
/// テンプレート選択で既にヒーロータスクが1つ保存されている場合、それをプリフィルします
class TaskSetupScreen extends ConsumerStatefulWidget {
  const TaskSetupScreen({super.key});

  @override
  ConsumerState<TaskSetupScreen> createState() => _TaskSetupScreenState();
}

class _TaskSetupScreenState extends ConsumerState<TaskSetupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // フェードアニメーション
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  // プロフィール写真
  File? _profileImage;
  final _picker = ImagePicker();

  // ヒーロータスク入力欄（最初は1つ）
  final List<TextEditingController> _taskCtrls = [TextEditingController()];

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
      final uid = ref.read(userServiceProvider).currentUid;
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



  /// 時間を「午前 7:00」「午後 9:00」のような日本語形式で画面に表示します


  /// プロフィール画像を Firebase Storage にアップロードして URL を返す
  Future<String?> _uploadProfileImage() async {
    if (_profileImage == null) return null;
    return await ref.read(userServiceProvider).uploadProfileImage(_profileImage!);
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
      ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.taskSetupAtLeastOne)));
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

      await ref.read(userServiceProvider).saveTaskSettings(
        tasks: tasks,
        photoUrl: photoUrl,
      );

      debugPrint('ヒーロータスク保存成功！');

      final analytics = ref.read(analyticsServiceProvider);
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
            content: Text(AppLocalizations.of(context)!.taskSetupSaveFailed),
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
                            icon: Icon(
                              Icons.arrow_back,
                              color: AppColors.textPrimary,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        Text(
                          AppLocalizations.of(context)!.taskSetupTitle,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate([
                                const SizedBox(height: 8),
                                const PremiumIconHeader(
                                  icon: Icons.task_alt,
                                  size: 72,
                                  iconSize: 40,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Step 2 / 2',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  AppLocalizations.of(context)!.taskSetupSubtitle,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 32),

                                // ── プロフィール写真 ──
                                SectionTitle(title: AppLocalizations.of(context)!.taskSetupProfilePhoto),
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
                                                ? Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.camera_alt,
                                                      size: 32,
                                                      color: AppColors.textMuted,
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      AppLocalizations.of(context)!.taskSetupSelectPhoto,
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
                                SectionTitle(title: AppLocalizations.of(context)!.taskSetupHeroTasks),
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
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: AppColors.primaryGradient,
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${index + 1}',
                                              style: TextStyle(
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
                                            style: TextStyle(
                                              color: AppColors.textPrimary,
                                            ),
                                            decoration: InputDecoration(
                                              labelText: AppLocalizations.of(context)!.taskSetupHeroTaskLabel(index + 1),
                                              hintText: AppLocalizations.of(context)!.hintTaskExample,
                                            ),
                                          ),
                                        ),
                                        if (_taskCtrls.length > 1)
                                          IconButton(
                                            icon: Icon(
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
                                    label: Text(AppLocalizations.of(context)!.taskSetupAddTask),
                                    onPressed: _addTaskField,
                                  ),
                                ),
                                const SizedBox(height: 24),

                              ]),
                            ),
                          ),
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 28, right: 28, bottom: 24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  GradientButton(
                                    onPressed: _saveAndFinish,
                                    isLoading: _isSaving,
                                    child: Text(AppLocalizations.of(context)!.taskSetupCompleteButton),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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
