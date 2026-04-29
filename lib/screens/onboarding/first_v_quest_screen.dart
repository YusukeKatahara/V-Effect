import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../config/routes.dart';
import '../../services/user_service.dart';
import '../../widgets/gradient_button.dart';

class FirstVQuestScreen extends StatefulWidget {
  const FirstVQuestScreen({super.key});

  @override
  State<FirstVQuestScreen> createState() => _FirstVQuestScreenState();
}

class _FirstVQuestScreenState extends State<FirstVQuestScreen>
    with TickerProviderStateMixin {
  final _questCtrl = TextEditingController();
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
  int _placeholderIndex = 0;
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
      duration: const Duration(milliseconds: 10000),
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
  }

  void _startPlaceholderTimer() {
    _placeholderTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        setState(() {
          _placeholderIndex = (_placeholderIndex + 1) % _placeholders.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _questCtrl.dispose();
    _ctrlA.dispose();
    _ctrlB.dispose();
    _placeholderTimer?.cancel();
    super.dispose();
  }

  Future<void> _complete({bool skip = false}) async {
    setState(() => _isSaving = true);
    try {
      await _userService.saveFirstVQuest(
        questTitle: skip ? null : _questCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.home,
          (r) => false,
          arguments: 1, // HeroTasks タブ
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Column(
          children: [
            // キーワードエリア
            Expanded(
              flex: 5,
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
                                'これらのキーワードから連想される\nあなたの姿はどんなですか',
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
              flex: 5,
              child: FadeTransition(
                opacity: _formAnim,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        '最初の V Quest を決めましょう',
                        style: GoogleFonts.notoSansJp(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
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
    );
  }

  Widget _buildInputField() {
    final showPlaceholder = _questCtrl.text.isEmpty;
    return Stack(
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
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.grey50),
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
                  key: ValueKey(_placeholderIndex),
                  style: GoogleFonts.notoSansJp(
                    color: AppColors.grey30,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
      ],
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
