import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_colors.dart';
import '../config/routes.dart';
import '../services/analytics_service.dart';
import '../services/user_service.dart';
import '../widgets/premium_background.dart';

/// プロフィール設定後に表示されるヒーロータスクテンプレート選択画面
///
/// ユーザーが V Effect の標準フローを即座に体験できるよう、
/// フロー: テンプレート選択 → Main (Home) へ遷移
class TaskTemplateScreen extends StatefulWidget {
  const TaskTemplateScreen({super.key});

  @override
  State<TaskTemplateScreen> createState() => _TaskTemplateScreenState();
}

class _TaskTemplateScreenState extends State<TaskTemplateScreen>
    with TickerProviderStateMixin {
  final UserService _userService = UserService.instance;

  // テンプレート定義
  static const List<_TaskTemplate> _templates = [
    _TaskTemplate(
      icon: Icons.menu_book_rounded,
      title: '本を開く',
      subtitle: '好きな本を開いて写真を撮ろう',
    ),
    _TaskTemplate(
      icon: Icons.air_rounded,
      title: '外で深呼吸する',
      subtitle: '外に出て深呼吸している瞬間を撮ろう',
    ),
    _TaskTemplate(
      icon: Icons.water_drop_rounded,
      title: '水を飲む',
      subtitle: 'コップ一杯の水を飲む瞬間を撮ろう',
    ),
    _TaskTemplate(
      icon: Icons.edit_rounded,
      title: '自分で決める',
      subtitle: '好きなヒーロータスクを自由に設定しよう',
    ),
  ];

  int? _selectedIndex;
  bool _isProcessing = false;

  // カスタムヒーロータスク入力用（「自分で決める」選択時）
  final TextEditingController _customTaskCtrl = TextEditingController();
  bool _showCustomInput = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  late final AnimationController _staggerCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _staggerCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _staggerCtrl.dispose();
    _customTaskCtrl.dispose();
    super.dispose();
  }

  /// 選択されたテンプレートのヒーロータスク名を返す
  String? get _selectedTaskName {
    if (_selectedIndex == null) return null;
    // 「自分で決める」の場合はカスタム入力値
    if (_selectedIndex == _templates.length - 1) {
      final custom = _customTaskCtrl.text.trim();
      return custom.isNotEmpty ? custom : null;
    }
    return _templates[_selectedIndex!].title;
  }

  /// テンプレート選択 → カメラ起動 → 投稿完了でヒーロータスク設定へ遷移
  Future<void> _onStartTask() async {
    final taskName = _selectedTaskName;
    if (taskName == null) return;

    HapticFeedback.lightImpact();
    setState(() => _isProcessing = true);

    try {
      // Analytics: テンプレート選択を記録
      AnalyticsService.instance.logTemplateSelected(
        templateName: taskName,
        isCustom: _selectedIndex == _templates.length - 1,
      );

      // テンプレートのヒーロータスクを一時的に保存（初回投稿用）
      await _userService.saveTemplateTask(taskName: taskName);

      if (!mounted) return;
      
      // チュートリアル用のフラグをローカル等に立てる代わりに、Home画面遷移時に渡すこともできますが、
      // 簡単のため、初回のHome表示時にフラグを監視・チェックする方法もあります。Analyticsで初投稿か判定します。
      
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.home, (r) => false);
    } catch (e) {
      debugPrint('TaskTemplate error: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('エラーが発生しました。もう一度お試しください。')),
        );
      }
    }
  }

  /// スキップ → 直接ヒーロータスク設定画面へ
  void _onSkip() {
    AnalyticsService.instance.logTemplateSelected(
      templateName: 'skipped',
      isCustom: false,
    );
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.taskSetup, (r) => false);
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
              opacity: _fadeAnim,
              child: Column(
                children: [
                  // ── Header ──
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        const SizedBox(width: 48), // balance
                        const Spacer(),
                        Text(
                          'Step 2 / 2',
                          style: GoogleFonts.notoSansJp(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        // スキップボタン
                        TextButton(
                          onPressed: _isProcessing ? null : _onSkip,
                          child: Text(
                            'スキップ',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Content ──
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 16),

                          // ── Intro text ──
                          _buildIntroSection(),

                          const SizedBox(height: 28),

                          // ── Template cards ──
                          ...List.generate(_templates.length, (index) {
                            return _buildTemplateCard(index);
                          }),

                          // ── Custom input ──
                          if (_showCustomInput) ...[
                            const SizedBox(height: 4),
                            _buildCustomInput(),
                          ],

                          const SizedBox(height: 32),

                          // ── Start button ──
                          _buildStartButton(),

                          const SizedBox(height: 24),
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

  Widget _buildIntroSection() {
    return Column(
      children: [
        // アイコン
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.white.withValues(alpha: 0.12),
                AppColors.white.withValues(alpha: 0.04),
              ],
            ),
            border: Border.all(
              color: AppColors.white.withValues(alpha: 0.1),
            ),
          ),
          child: const Icon(
            Icons.rocket_launch_rounded,
            size: 32,
            color: AppColors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'まずは一つ、やってみよう！',
          textAlign: TextAlign.center,
          style: GoogleFonts.notoSansJp(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'かんたんなヒーロータスクを選んで\nアプリをはじめましょう',
          textAlign: TextAlign.center,
          style: GoogleFonts.notoSansJp(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateCard(int index) {
    final template = _templates[index];
    final isSelected = _selectedIndex == index;

    // Staggered animation
    final delay = index / _templates.length;
    final end = (delay + 0.5) > 1.0 ? 1.0 : (delay + 0.5);
    final animation = CurvedAnimation(
      parent: _staggerCtrl,
      curve: Interval(delay, end, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - animation.value)),
          child: Opacity(
            opacity: animation.value,
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GestureDetector(
          onTap: _isProcessing
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedIndex = index;
                    // 「自分で決める」の場合はカスタム入力を表示
                    _showCustomInput = index == _templates.length - 1;
                  });
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.white.withValues(alpha: 0.08)
                  : AppColors.bgSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? AppColors.white.withValues(alpha: 0.3)
                    : AppColors.border.withValues(alpha: 0.5),
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.white.withValues(alpha: 0.05),
                        blurRadius: 20,
                        spreadRadius: 0,
                      ),
                    ]
                  : [],
            ),
            child: Row(
              children: [
                // アイコン
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? AppColors.white.withValues(alpha: 0.12)
                        : AppColors.grey15,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.white.withValues(alpha: 0.2)
                          : AppColors.grey20,
                    ),
                  ),
                  child: Icon(
                    template.icon,
                    size: 22,
                    color: isSelected ? AppColors.white : AppColors.grey50,
                  ),
                ),
                const SizedBox(width: 14),
                // テキスト
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.title,
                        style: GoogleFonts.notoSansJp(
                          fontSize: 16,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? AppColors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        template.subtitle,
                        style: GoogleFonts.notoSansJp(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // チェック
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        isSelected ? AppColors.white : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.white
                          : AppColors.grey30,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded,
                          size: 16, color: AppColors.black)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextField(
        controller: _customTaskCtrl,
        autofocus: true,
        style: GoogleFonts.notoSansJp(
          color: AppColors.textPrimary,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          labelText: 'ヒーロータスク名を入力',
          hintText: '例: ランニング3km',
          labelStyle: TextStyle(color: AppColors.textSecondary),
          hintStyle: TextStyle(color: AppColors.textMuted),
          prefixIcon:
              const Icon(Icons.edit_note_rounded, color: AppColors.grey50),
          filled: true,
          fillColor: AppColors.bgSurface,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: AppColors.border.withValues(alpha: 0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.white, width: 1),
          ),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildStartButton() {
    final canStart = _selectedTaskName != null;

    return Column(
      children: [
        // メインボタン
        GestureDetector(
          onTap: canStart && !_isProcessing ? _onStartTask : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: canStart && !_isProcessing
                  ? AppColors.primaryGradient
                  : null,
              color: canStart && !_isProcessing
                  ? null
                  : AppColors.bgElevated,
              borderRadius: BorderRadius.circular(14),
              boxShadow: canStart && !_isProcessing
                  ? [
                      BoxShadow(
                        color: AppColors.white.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : [],
            ),
            child: Center(
              child: _isProcessing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'アプリをはじめる',
                          style: GoogleFonts.notoSansJp(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: canStart
                                ? AppColors.black
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// テンプレートデータクラス
class _TaskTemplate {
  final IconData icon;
  final String title;
  final String subtitle;

  const _TaskTemplate({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
