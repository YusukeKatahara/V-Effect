import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import '../../config/app_colors.dart';
import '../../config/routes.dart';
import '../../services/user_service.dart';
import '../../widgets/gradient_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/app_user.dart';
import '../../widgets/notification_prompt_sheet.dart';
import '../../widgets/friend_invite_prompt_sheet.dart';
class FirstVQuestScreen extends StatefulWidget {
  const FirstVQuestScreen({super.key});

  @override
  State<FirstVQuestScreen> createState() => _FirstVQuestScreenState();
}

class _FirstVQuestScreenState extends State<FirstVQuestScreen>
    with TickerProviderStateMixin {
  final _questCtrl = TextEditingController();
  final _triggerCtrl = TextEditingController();
  final _rewardCtrl = TextEditingController();
  final _userService = UserService.instance;
  bool _isSaving = false;

  // Phase A: キーワードのフェードイン
  late final AnimationController _ctrlA;
  late final List<Animation<double>> _keywordAnims;
  late final Animation<double> _questionAnim;

  // Phase B: 入力フォームのフェードイン（Phase A 完了後に開始）
  late final AnimationController _ctrlB;
  late final Animation<double> _formAnim;

  // プレースホルダーのループ
  static const _taskPlaceholderCount = 5;
  static const _triggerPlaceholderCount = 4;
  static const _rewardPlaceholderCount = 5;

  List<String> _taskPlaceholders(BuildContext ctx) {
    final l = AppLocalizations.of(ctx)!;
    return [l.firstQuestTaskHint1, l.firstQuestTaskHint2, l.firstQuestTaskHint3, l.firstQuestTaskHint4, l.firstQuestTaskHint5];
  }
  List<String> _triggerPlaceholders(BuildContext ctx) {
    final l = AppLocalizations.of(ctx)!;
    return [l.firstQuestTriggerHint1, l.firstQuestTriggerHint2, l.firstQuestTriggerHint3, l.firstQuestTriggerHint4];
  }
  List<String> _rewardPlaceholders(BuildContext ctx) {
    final l = AppLocalizations.of(ctx)!;
    return [l.firstQuestRewardHint1, l.firstQuestRewardHint2, l.firstQuestRewardHint3, l.firstQuestRewardHint4, l.firstQuestRewardHint5];
  }
  int _placeholderIndex = 0;
  int _triggerPlaceholderIndex = 0;
  int _rewardPlaceholderIndex = 0;
  Timer? _placeholderTimer;

  static const _keywordIntervals = [
    [0.05, 0.10], // 勝利
    [0.09, 0.14], // 努力
    [0.07, 0.12], // 達成感
    [0.11, 0.16], // 目標
    [0.15, 0.20], // 習慣化
    [0.13, 0.18], // 継続
  ];

  @override
  void initState() {
    super.initState();

    _ctrlA = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _keywordAnims =
        _keywordIntervals.map((iv) {
          return CurvedAnimation(
            parent: _ctrlA,
            curve: Interval(iv[0], iv[1], curve: Curves.easeOut),
          );
        }).toList();
    _questionAnim = CurvedAnimation(
      parent: _ctrlA,
      curve: const Interval(0.68, 0.88, curve: Curves.easeOut),
    );

    _ctrlB = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _formAnim = CurvedAnimation(parent: _ctrlB, curve: Curves.easeOut);

    _ctrlA.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _ctrlB.forward();
        _startPlaceholderTimer();
      }
    });

    _ctrlA.forward();

    _questCtrl.addListener(() => setState(() {}));
    _triggerCtrl.addListener(() => setState(() {}));
    _rewardCtrl.addListener(() => setState(() {}));
  }

  void _startPlaceholderTimer() {
    _placeholderTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        setState(() {
          _placeholderIndex = (_placeholderIndex + 1) % _taskPlaceholderCount;
          _triggerPlaceholderIndex = (_triggerPlaceholderIndex + 1) % _triggerPlaceholderCount;
          _rewardPlaceholderIndex = (_rewardPlaceholderIndex + 1) % _rewardPlaceholderCount;
        });
      }
    });
  }

  @override
  void dispose() {
    _questCtrl.dispose();
    _triggerCtrl.dispose();
    _rewardCtrl.dispose();
    _ctrlA.dispose();
    _ctrlB.dispose();
    _placeholderTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkAndShowNotificationPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _userService.currentUid;
    if (uid == null) return;

    // すでに表示済みの場合は何もしません
    final hasShown = prefs.getBool('notification_prompt_shown_$uid') ?? false;
    if (hasShown) return;

    try {
      // すでに通知許可済みの場合はモーダルを表示する必要がないため、フラグだけ立ててスキップします
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        await prefs.setBool('notification_prompt_shown_$uid', true);
        return;
      }

      if (mounted) {
        // ハーフモーダル (プレ・ダイアログ) を表示し、その中で自動でOS通知パーミッション要求をトリガーします
        await NotificationPromptSheet.show(context);
        
        // 次回以降表示されないようにフラグを保存します
        await prefs.setBool('notification_prompt_shown_$uid', true);
      }
    } catch (e) {
      debugPrint('通知プロンプト表示エラー: $e');
    }
  }

  Future<void> _checkAndShowFriendInvitePrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _userService.currentUid;
    if (uid == null) return;

    // すでに表示済みの場合は何もしません
    final hasShown = prefs.getBool('friend_invite_prompt_shown_$uid') ?? false;
    if (hasShown) return;

    try {
      // 最新のユーザー情報をFirestoreから取得します
      final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!snap.exists) return;
      final user = AppUser.fromFirestore(snap);

      if (mounted) {
        // ハーフモーダル (下からせり出るシート) を表示し、結果を受け取ります
        final result = await FriendInvitePromptSheet.show(context, user);

        // 次回以降表示されないようにフラグを保存します
        await prefs.setBool('friend_invite_prompt_shown_$uid', true);

        // 「QRコードで繋がる」が選択された場合、呼び出し元（この画面）のcontextでダイアログを表示
        if (result == FriendInviteResult.qrCode && mounted) {
          FriendInvitePromptSheet.showQrDialog(context, user);
        }
      }
    } catch (e) {
      debugPrint('フレンド招待プロンプト表示エラー: $e');
    }
  }

  Future<void> _complete({bool skip = false}) async {
    setState(() => _isSaving = true);
    try {
      await _userService.saveFirstVQuest(
        questTitle: skip ? null : _questCtrl.text.trim(),
        questTrigger: skip ? null : _triggerCtrl.text.trim(),
        questReward: skip ? null : _rewardCtrl.text.trim(),
      );
      if (mounted) {
        // オンボーディング完了後（ホーム画面へ遷移する前）に通知許可プロンプトを表示
        await _checkAndShowNotificationPrompt();
        
        // 通知許可の後にフレンド招待プロンプトを表示
        if (mounted) {
          await _checkAndShowFriendInvitePrompt();
        }

        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.home,
            (r) => false,
            arguments: 1, // HeroTasks タブ
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.onboardingFirstQuestSaveFailed(e))));
        setState(() => _isSaving = false);
      }
    }
  }

  void _skipAnimation() {
    if (_ctrlA.isAnimating || _ctrlA.status == AnimationStatus.forward) {
      _ctrlA.value = 1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _skipAnimation,
      child: Scaffold(
        backgroundColor: AppColors.black,
        body: SafeArea(
          child: Column(
            children: [
              // キーワードエリア
              if (isKeyboardOpen)
                const SizedBox.shrink()
              else
                Expanded(
                  flex: 3,
                  child: LayoutBuilder(
                  builder: (context, constraints) {
                    return AnimatedBuilder(
                      animation: _ctrlA,
                      builder: (context, _) {
                        return Stack(
                          children: [
                            ..._buildKeywords(constraints),
                            Positioned(
                              bottom: 16,
                              left: 32,
                              right: 32,
                              child: FadeTransition(
                                opacity: _questionAnim,
                                child: Text(
                                  AppLocalizations.of(context)!.onboardingFirstQuestQuestionText,
                                  style: GoogleFonts.notoSansJp(
                                    fontSize: 13,
                                    color: AppColors.grey50,
                                    height: 1.6,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              // 入力エリア
              Expanded(
                flex: isKeyboardOpen ? 1 : 7,
                child: FadeTransition(
                  opacity: _formAnim,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.notoSansJp(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.white,
                            ),
                            children: [
                              TextSpan(text: AppLocalizations.of(context)!.firstQuestTitlePrefix),
                              TextSpan(
                                text: 'V Quest',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.white,
                                ),
                              ),
                              TextSpan(
                                text: AppLocalizations.of(context)!.firstQuestHeroTaskLabel,
                                style: GoogleFonts.notoSansJp(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.grey50,
                                ),
                              ),
                              TextSpan(text: AppLocalizations.of(context)!.firstQuestTitleSuffix),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildHabitHints(),
                        const SizedBox(height: 16),
                        _buildInputField(),
                        _buildHabitPreview(),
                        const Spacer(),
                        GradientButton(
                          onPressed:
                              _isSaving ? null : () => _complete(skip: false),
                          isLoading: _isSaving,
                          child: Text(
                            AppLocalizations.of(context)!.onboardingFirstQuestCompleteButton,
                            style: GoogleFonts.notoSansJp(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed:
                                _isSaving ? null : () => _complete(skip: true),
                            child: Text(
                              AppLocalizations.of(context)!.onboardingFirstQuestSkipButton,
                              style: GoogleFonts.notoSansJp(
                                fontSize: 13,
                                color: AppColors.grey50,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField() {
    final showPlaceholder = _questCtrl.text.isEmpty;
    final showTriggerPlaceholder = _triggerCtrl.text.isEmpty;
    final showRewardPlaceholder = _rewardCtrl.text.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.onboardingFirstQuestTriggerLabel,
          style: GoogleFonts.notoSansJp(
            fontSize: 12,
            color: AppColors.grey50,
          ),
        ),
        const SizedBox(height: 8),
        Stack(
          alignment: Alignment.centerLeft,
          children: [
            TextField(
              controller: _triggerCtrl,
              style: GoogleFonts.notoSansJp(
                color: AppColors.textPrimary,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: '',
                filled: true,
                fillColor: AppColors.grey10,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (showTriggerPlaceholder)
              Positioned(
                left: 16,
                right: 16,
                child: IgnorePointer(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder:
                        (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.4),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                    child: Text(
                      AppLocalizations.of(context)!.hintExampleFormat(_triggerPlaceholders(context)[_triggerPlaceholderIndex]),
                      key: ValueKey<int>(_triggerPlaceholderIndex),
                      style: GoogleFonts.notoSansJp(
                        color: AppColors.grey30,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          AppLocalizations.of(context)!.onboardingFirstQuestTaskLabel,
          style: GoogleFonts.notoSansJp(
            fontSize: 12,
            color: AppColors.grey50,
          ),
        ),
        const SizedBox(height: 8),
        Stack(
          alignment: Alignment.centerLeft,
          children: [
            TextField(
              controller: _questCtrl,
              style: GoogleFonts.notoSansJp(
                color: AppColors.textPrimary,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: '',
                filled: true,
                fillColor: AppColors.grey10,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (showPlaceholder)
              Positioned(
                left: 16,
                right: 16,
                child: IgnorePointer(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder:
                        (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.4),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                    child: Text(
                      AppLocalizations.of(context)!.hintExampleFormat(_taskPlaceholders(context)[_placeholderIndex]),
                      key: ValueKey<int>(_placeholderIndex),
                      style: GoogleFonts.notoSansJp(
                        color: AppColors.grey30,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          AppLocalizations.of(context)!.onboardingFirstQuestRewardLabel,
          style: GoogleFonts.notoSansJp(
            fontSize: 12,
            color: AppColors.grey50,
          ),
        ),
        const SizedBox(height: 8),
        Stack(
          alignment: Alignment.centerLeft,
          children: [
            TextField(
              controller: _rewardCtrl,
              style: GoogleFonts.notoSansJp(
                color: AppColors.textPrimary,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: '',
                filled: true,
                fillColor: AppColors.grey10,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (showRewardPlaceholder)
              Positioned(
                left: 16,
                right: 16,
                child: IgnorePointer(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder:
                        (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.4),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                    child: Text(
                      AppLocalizations.of(context)!.hintExampleFormat(_rewardPlaceholders(context)[_rewardPlaceholderIndex]),
                      key: ValueKey<int>(_rewardPlaceholderIndex),
                      style: GoogleFonts.notoSansJp(
                        color: AppColors.grey30,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          AppLocalizations.of(context)!.onboardingFirstQuestPrivacyNote,
          style: GoogleFonts.notoSansJp(
            fontSize: 11,
            color: AppColors.grey50,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildHabitPreview() {
    final hasTrigger = _triggerCtrl.text.isNotEmpty;
    final hasQuest = _questCtrl.text.isNotEmpty;
    final hasReward = _rewardCtrl.text.isNotEmpty;

    if (!hasTrigger && !hasQuest && !hasReward) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.grey10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (hasTrigger) ...[
            Text(
              _triggerCtrl.text,
              style: GoogleFonts.notoSansJp(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.accentGold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Icon(
              Icons.arrow_downward_rounded,
              size: 16,
              color: AppColors.grey50,
            ),
            const SizedBox(height: 8),
          ],
          Text(
            hasQuest ? _questCtrl.text : AppLocalizations.of(context)!.firstQuestNoTaskPlaceholder,
            style: GoogleFonts.notoSerifJp(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: hasQuest ? AppColors.white : AppColors.grey50,
            ),
            textAlign: TextAlign.center,
          ),
          if (hasReward) ...[
            const SizedBox(height: 8),
            Icon(
              Icons.arrow_downward_rounded,
              size: 16,
              color: AppColors.grey50,
            ),
            const SizedBox(height: 8),
            Text(
              _rewardCtrl.text,
              style: GoogleFonts.notoSansJp(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.accentGold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHabitHints() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.grey15.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: AppColors.accentGold, size: 14),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context)!.onboardingFirstQuestHabitTipsTitle,
                style: GoogleFonts.notoSansJp(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentGold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '• ${AppLocalizations.of(context)!.onboardingFirstQuestHabitStackingTitle}\n${AppLocalizations.of(context)!.onboardingFirstQuestHabitStackingDesc}',
            style: GoogleFonts.notoSansJp(
              fontSize: 11,
              color: AppColors.grey50,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '• ${AppLocalizations.of(context)!.onboardingFirstQuestTemptationBundlingTitle}\n${AppLocalizations.of(context)!.onboardingFirstQuestTemptationBundlingDesc}',
            style: GoogleFonts.notoSansJp(
              fontSize: 11,
              color: AppColors.grey50,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildKeywords(BoxConstraints constraints) {
    final l = AppLocalizations.of(context)!;
    final keywords = [l.firstQuestKeyword1, l.firstQuestKeyword2, l.firstQuestKeyword3, l.firstQuestKeyword4, l.firstQuestKeyword5, l.firstQuestKeyword6];
    // 画面幅に依存しない相対的な配置（左上原点）
    const positions = [
      [0.48, 0.08], // 勝利: 右上寄り
      [0.65, 0.28], // 努力: 右中
      [0.08, 0.10], // 達成感: 左上
      [0.12, 0.42], // 目標: 左中
      [0.42, 0.52], // 習慣化: 中央下
      [0.70, 0.50], // 継続: 右下
    ];
    const sizes = [22.0, 20.0, 18.0, 24.0, 16.0, 20.0];

    return List.generate(keywords.length, (i) {
      return Positioned(
        left: constraints.maxWidth * positions[i][0],
        top: constraints.maxHeight * positions[i][1],
        child: FadeTransition(
          opacity: _keywordAnims[i],
          child: Text(
            keywords[i],
            style: GoogleFonts.notoSansJp(
              fontSize: sizes[i],
              fontWeight: FontWeight.w500,
              color: AppColors.white,
            ),
          ),
        ),
      );
    });
  }
}
