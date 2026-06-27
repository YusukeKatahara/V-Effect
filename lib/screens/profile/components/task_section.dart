import 'package:flutter/material.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import '../../../config/app_colors.dart';
import 'section_title.dart';

// ---────────────────────────────────────────────
// --- ヒーロータスクセクション用のSliverコンポーネント群
// ---────────────────────────────────────────────

/// タイトルとトレンドボタンを表示する Sliver ヘッダー
class SliverTaskSectionHeader extends StatelessWidget {
  const SliverTaskSectionHeader({
    super.key,
    required this.onShowTrendingTasks,
  });

  final VoidCallback onShowTrendingTasks;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SectionTitle(title: AppLocalizations.of(context)!.profileScreenHeroTasks),
          TextButton(
            onPressed: onShowTrendingTasks,
            child: Text(
              AppLocalizations.of(context)!.profileScreenWeeklyTrend,
              style: TextStyle(color: AppColors.accentGold, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

/// タスクが空のときに表示する Sliver カード
class SliverEmptyTaskCard extends StatelessWidget {
  const SliverEmptyTaskCard({
    super.key,
    required this.onAddTask,
  });

  final VoidCallback onAddTask;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: InkWell(
        onTap: onAddTask,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 40),
          decoration: BoxDecoration(
            color: AppColors.bgSurface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.white.withValues(alpha: 0.05),
                AppColors.white.withValues(alpha: 0.02),
              ],
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.add_circle_outline_rounded,
                size: 32,
                color: AppColors.white.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context)!.profileScreenAddFirstTask,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// タスク追加スロット（＋ボタン）を表示する Sliver
class SliverAddTaskSlot extends StatelessWidget {
  const SliverAddTaskSlot({
    super.key,
    required this.onAddTask,
  });

  final VoidCallback onAddTask;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: InkWell(
        onTap: onAddTask,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.add_rounded,
              size: 24,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
