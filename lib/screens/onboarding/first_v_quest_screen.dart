import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import '../../config/app_colors.dart';
import '../../config/routes.dart';
import '../../services/user_service.dart';
import '../../widgets/gradient_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../profile/components/trending_tasks_bottom_sheet.dart';

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
  int _selectedTimeframeIndex = 0; // 0: 朝, 1: 昼, 2: 夜
  List<Map<String, dynamic>> _trendingTasks = [];

  // 入力フォームのフェードインアニメーション
  late final AnimationController _ctrlB;
  late final Animation<double> _formAnim;

  List<String> _getSuggestedTriggers(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    switch (_selectedTimeframeIndex) {
      case 0:
        return [l.morningTrigger1, l.morningTrigger2, l.morningTrigger3];
      case 1:
        return [l.afternoonTrigger1, l.afternoonTrigger2, l.afternoonTrigger3];
      case 2:
        return [l.nightTrigger1, l.nightTrigger2, l.nightTrigger3];
      default:
        return [];
    }
  }

  List<String> _getSuggestedTasks(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    switch (_selectedTimeframeIndex) {
      case 0:
        return [l.morningTask1, l.morningTask2, l.morningTask3];
      case 1:
        return [l.afternoonTask1, l.afternoonTask2, l.afternoonTask3];
      case 2:
        return [l.nightTask1, l.nightTask2, l.nightTask3];
      default:
        return [];
    }
  }

  @override
  void initState() {
    super.initState();

    _ctrlB = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _formAnim = CurvedAnimation(parent: _ctrlB, curve: Curves.easeOut);
    _ctrlB.forward();

    _questCtrl.addListener(() => setState(() {}));
    _triggerCtrl.addListener(() => setState(() {}));

    _loadTrendingTasks();
  }

  Future<void> _loadTrendingTasks() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('global_stats')
          .doc('trends')
          .get();
      debugPrint('Firestore trends document exists: ${snap.exists}');
      if (snap.exists && mounted) {
        final data = snap.data();
        debugPrint('Firestore trends data: $data');
        final rawList = data?['trends'] as List<dynamic>? ?? [];
        final list = rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        setState(() {
          _trendingTasks = list;
        });
      }
    } catch (e, stack) {
      debugPrint('Error loading trends: $e');
      debugPrint('Stacktrace: $stack');
    }
  }

  @override
  void dispose() {
    _questCtrl.dispose();
    _triggerCtrl.dispose();
    _ctrlB.dispose();
    super.dispose();
  }

  Future<void> _complete({bool skip = false}) async {
    setState(() => _isSaving = true);
    try {
      await _userService.saveFirstVQuest(
        questTitle: skip ? null : _questCtrl.text.trim(),
        questTrigger: skip ? null : _triggerCtrl.text.trim(),
        questReward: null,
      );
      if (mounted) {
        Navigator.pushNamed(
          context,
          AppRoutes.onboardingProfile,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.onboardingFirstQuestSaveFailed(e))));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _unfocus() {
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _unfocus,
      child: Scaffold(
        backgroundColor: AppColors.black,
        body: SafeArea(
          child: Column(
            children: [
              // タイムラインエリア (旧キーワードエリア)
              if (isKeyboardOpen)
                const SizedBox.shrink()
              else
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 32.0, right: 32.0, top: 24.0, bottom: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.onboardingFirstQuestTimeframeHeader,
                          style: GoogleFonts.notoSansJp(
                            fontSize: 14,
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Center(
                            child: _buildTimeframeSelector(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // 入力エリア
              Expanded(
                flex: isKeyboardOpen ? 1 : 8,
                child: FadeTransition(
                  opacity: _formAnim,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                // オンボーディング画面の見出しテキストを表示します（例：「習慣化したい(やりたい)ことを決めましょう」）。
                                // ローカライズキー firstQuestTitle を使用し、文言全体を共通化しています。
                                Text(
                                  AppLocalizations.of(context)!.firstQuestTitle,
                                  style: GoogleFonts.notoSansJp(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.white,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildHabitHints(),
                                const SizedBox(height: 16),
                                _buildInputField(),
                                _buildHabitPreview(),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
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
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // トリガーラベル（右側にトレンドボタンを配置）
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l.onboardingFirstQuestTriggerLabel,
              style: GoogleFonts.notoSansJp(
                fontSize: 12,
                color: AppColors.grey50,
              ),
            ),
            TextButton(
              onPressed: () {
                showTrendingTasksBottomSheet(
                  context,
                  trendingTasks: _trendingTasks,
                  onAddTask: ({String? initialTitle}) {
                    if (initialTitle != null) {
                      setState(() {
                        _questCtrl.text = initialTitle;
                        _questCtrl.selection = TextSelection.fromPosition(
                          TextPosition(offset: initialTitle.length),
                        );
                      });
                    }
                  },
                );
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                l.profileScreenWeeklyTrend,
                style: GoogleFonts.notoSansJp(
                  color: AppColors.accentGold,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // トリガー提案チップス
        _buildSuggestedTriggers(),
        const SizedBox(height: 8),
        TextField(
          controller: _triggerCtrl,
          style: GoogleFonts.notoSansJp(
            color: AppColors.textPrimary,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: l.onboardingFirstQuestTriggerHintText,
            hintStyle: GoogleFonts.notoSansJp(
              color: AppColors.grey30,
              fontSize: 15,
            ),
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
        const SizedBox(height: 16),
        // タスク名ラベル
        Text(
          l.onboardingFirstQuestTaskLabel,
          style: GoogleFonts.notoSansJp(
            fontSize: 12,
            color: AppColors.grey50,
          ),
        ),
        const SizedBox(height: 8),
        // タスク提案チップス
        _buildSuggestedTasks(),
        const SizedBox(height: 8),
        TextField(
          controller: _questCtrl,
          style: GoogleFonts.notoSansJp(
            color: AppColors.textPrimary,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: l.onboardingFirstQuestTaskHintText,
            hintStyle: GoogleFonts.notoSansJp(
              color: AppColors.grey30,
              fontSize: 15,
            ),
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
        const SizedBox(height: 12),
        Text(
          l.onboardingFirstQuestPrivacyNote,
          style: GoogleFonts.notoSansJp(
            fontSize: 11,
            color: AppColors.grey50,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestedTriggers() {
    final triggers = _getSuggestedTriggers(context);
    final currentText = _triggerCtrl.text;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: triggers.map((trigger) {
          final isSelected = currentText == trigger;
          return GestureDetector(
            onTap: () {
              setState(() {
                _triggerCtrl.text = trigger;
                _triggerCtrl.selection = TextSelection.fromPosition(
                  TextPosition(offset: trigger.length),
                );
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.accentGold.withValues(alpha: 0.15) : AppColors.grey10,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppColors.accentGold
                      : AppColors.grey15,
                  width: 1,
                ),
              ),
              child: Text(
                trigger,
                style: GoogleFonts.notoSansJp(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? AppColors.accentGold
                      : AppColors.textPrimary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSuggestedTasks() {
    final tasks = _getSuggestedTasks(context);
    final currentText = _questCtrl.text;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tasks.map((task) {
          final isSelected = currentText == task;
          return GestureDetector(
            onTap: () {
              setState(() {
                _questCtrl.text = task;
                _questCtrl.selection = TextSelection.fromPosition(
                  TextPosition(offset: task.length),
                );
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.grey10,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.grey15,
                  width: 1,
                ),
              ),
              child: Text(
                task,
                style: GoogleFonts.notoSansJp(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textPrimary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimeframeSelector() {
    final l = AppLocalizations.of(context)!;
    final items = [
      {
        'label': l.timeframeMorning,
        'colors': [Colors.orangeAccent, Colors.redAccent],
      },
      {
        'label': l.timeframeAfternoon,
        'colors': [Colors.amber, Colors.orange],
      },
      {
        'label': l.timeframeNight,
        'colors': [Colors.indigo, Colors.purple],
      },
    ];

    return Row(
      children: List.generate(items.length, (index) {
        final isSelected = _selectedTimeframeIndex == index;
        final item = items[index];
        final colors = item['colors'] as List<Color>;

        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedTimeframeIndex = index;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              margin: EdgeInsets.only(
                left: index == 0 ? 0 : 8,
                right: index == items.length - 1 ? 0 : 8,
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: isSelected
                    ? LinearGradient(
                        colors: colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected ? null : AppColors.grey10,
                border: Border.all(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.5)
                      : AppColors.grey15,
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: colors[0].withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item['label'] as String,
                    style: GoogleFonts.notoSansJp(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? AppColors.white : AppColors.grey50,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildHabitPreview() {
    final hasTrigger = _triggerCtrl.text.isNotEmpty;
    final hasQuest = _questCtrl.text.isNotEmpty;

    if (!hasTrigger && !hasQuest) {
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
            AppLocalizations.of(context)!.habitStackingHint,
            style: GoogleFonts.notoSansJp(
              fontSize: 11,
              color: AppColors.grey50,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context)!.temptationBundlingHint,
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
}
