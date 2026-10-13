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

/// ヒーロータスク一覧の表示フィルター
enum TaskListFilter {
  all,
  today,
  weekly,
  monthly,
}

/// タスク一覧のカテゴリー切り替えピル（ALL / TODAY / WEEKLY / MONTHLY）
class SliverTaskFilterPills extends StatelessWidget {
  const SliverTaskFilterPills({
    super.key,
    required this.selectedFilter,
    required this.onSelectFilter,
    required this.counts,
  });

  final TaskListFilter selectedFilter;
  final ValueChanged<TaskListFilter> onSelectFilter;
  final Map<TaskListFilter, int> counts;

  String _labelFor(TaskListFilter filter) {
    switch (filter) {
      case TaskListFilter.all:
        return 'ALL';
      case TaskListFilter.today:
        return 'TODAY';
      case TaskListFilter.weekly:
        return 'WEEKLY';
      case TaskListFilter.monthly:
        return 'MONTHLY';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: TaskListFilter.values.map((filter) {
              final isSelected = selectedFilter == filter;
              final count = counts[filter] ?? 0;
              final label = _labelFor(filter);

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onSelectFilter(filter),
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutExpo,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accentGold
                            : AppColors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.accentGold
                              : AppColors.white.withValues(alpha: 0.08),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              color: isSelected ? AppColors.black : AppColors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$count',
                            style: TextStyle(
                              color: isSelected
                                  ? AppColors.black.withValues(alpha: 0.7)
                                  : AppColors.grey50,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

/// フィルター適用時に該当タスクが無い場合のカード
class SliverFilteredEmptyCard extends StatelessWidget {
  const SliverFilteredEmptyCard({
    super.key,
    required this.filter,
    required this.onAddTask,
  });

  final TaskListFilter filter;
  final VoidCallback onAddTask;

  @override
  Widget build(BuildContext context) {
    String title;
    switch (filter) {
      case TaskListFilter.today:
        title = '今日のタスクはありません';
        break;
      case TaskListFilter.weekly:
        title = '週の目標タスクはありません';
        break;
      case TaskListFilter.monthly:
        title = '月の目標タスクはありません';
        break;
      case TaskListFilter.all:
        title = 'タスクがありません';
        break;
    }

    return SliverToBoxAdapter(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.white.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                color: AppColors.grey50,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onAddTask,
              icon: Icon(Icons.add, size: 16, color: AppColors.accentGold),
              label: Text(
                'このカテゴリーに追加',
                style: TextStyle(
                  color: AppColors.accentGold,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
