import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  static const _placeholders = ['ジム', '英語学習', '部屋の掃除', 'ランニング', '栄養管理'];
  static const _triggerPlaceholders = ['朝起きたら', '帰宅したら', 'お風呂から上がったら', '机に座ったら'];
  int _placeholderIndex = 0;
  int _triggerPlaceholderIndex = 0;
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
  }

  void _startPlaceholderTimer() {
    _placeholderTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        setState(() {
          _placeholderIndex = (_placeholderIndex + 1) % _placeholders.length;
          _triggerPlaceholderIndex = (_triggerPlaceholderIndex + 1) % _triggerPlaceholders.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _questCtrl.dispose();
    _triggerCtrl.dispose();
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
        ).showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
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
                                  'あなたが理想とする姿はどんなだろう？\nあなたの習慣化したい習慣は何だろう？',
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
                              const TextSpan(text: '最初の '),
                              TextSpan(
                                text: 'V Quest',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.white,
                                ),
                              ),
                              TextSpan(
                                text: ' (ヒーロータスク)',
                                style: GoogleFonts.notoSansJp(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.grey50,
                                ),
                              ),
                              const TextSpan(text: ' を決めましょう'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildHabitHints(),
                        const SizedBox(height: 16),
                        _buildTriggerChips(),
                        const SizedBox(height: 12),
                        _buildInputField(),
                        const Spacer(),
                        GradientButton(
                          onPressed:
                              _isSaving ? null : () => _complete(skip: false),
                          isLoading: _isSaving,
                          child: Text(
                            '完了',
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
                              'スキップ',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'トリガー (任意)',
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
                      '例: ${_triggerPlaceholders[_triggerPlaceholderIndex]}',
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
          'タスク名',
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
                      '例: ${_placeholders[_placeholderIndex]}',
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
      ],
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
              const Icon(Icons.lightbulb_outline, color: AppColors.accentGold, size: 14),
              const SizedBox(width: 6),
              Text(
                '習慣化のコツ',
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
            '• 2分間ルール\nまずは「本を1ページ読む」「スクワットを10回する」など極小の行動から始めましょう。',
            style: GoogleFonts.notoSansJp(
              fontSize: 11,
              color: AppColors.grey50,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '• ハビット・スタッキング\nすでに毎日やっている行動の後に新しい習慣をくっつけると効果的です。',
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

  Widget _buildTriggerChips() {
    final triggers = ['朝起きたら', '帰宅したら', 'お風呂から上がったら', '机に座ったら'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: triggers.map((trigger) {
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ActionChip(
              backgroundColor: AppColors.grey10,
              side: const BorderSide(color: AppColors.border),
              label: Text(
                trigger,
                style: GoogleFonts.notoSansJp(
                  fontSize: 12,
                  color: AppColors.white,
                ),
              ),
              onPressed: () {
                _triggerCtrl.text = trigger;
                _triggerCtrl.selection = TextSelection.fromPosition(
                  TextPosition(offset: _triggerCtrl.text.length),
                );
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  List<Widget> _buildKeywords(BoxConstraints constraints) {
    const keywords = ['勝利', '努力', '達成感', '目標', '習慣化', '継続'];
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
