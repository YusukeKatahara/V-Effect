import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import '../../../config/app_colors.dart';
import '../../../models/app_task.dart';
import '../../../models/app_user.dart';
import '../../../models/season.dart';
import 'section_title.dart';
import 'quest_card.dart';

// ---────────────────────────────────────────────
// ---ヒーロータスクセクション（追加・削除・並べ替え可能）
// ---────────────────────────────────────────────
class TaskSection extends StatelessWidget {
  const TaskSection({
    super.key,
    required this.user,
    required this.seasonsMap,
    required this.seasonPostsCountMap,
    required this.onAddTask,
    required this.onEditTask,
    required this.onDeleteTask,
    required this.onReorder,
    required this.onShowTrendingTasks,
    required this.onSeasonTaskTap,
  });

  /// ユーザー情報
  final AppUser user;
  /// シーズン情報のマップ
  final Map<String, Season> seasonsMap;
  /// シーズンごとの投稿数マップ
  final Map<String, int> seasonPostsCountMap;
  /// タスク追加コールバック
  final VoidCallback onAddTask;
  /// タスク編集コールバック（インデックスを引数に取る）
  final void Function(int index) onEditTask;
  /// タスク削除コールバック（インデックスを引数に取る）
  final void Function(int index) onDeleteTask;
  /// タスク並べ替えコールバック
  final void Function(int oldIndex, int newIndex) onReorder;
  /// トレンドタスク表示コールバック
  final VoidCallback onShowTrendingTasks;
  /// シーズンタスクがタップされたときのコールバック
  final void Function(int index) onSeasonTaskTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SectionTitle(title: AppLocalizations.of(context)!.profileScreenHeroTasks),
            TextButton(
              onPressed: onShowTrendingTasks,
              child: Text(
                AppLocalizations.of(context)!.profileScreenWeeklyTrend,
                style: const TextStyle(color: AppColors.accentGold, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (user.tasks.isEmpty)
          _buildEmptyTaskCard(context)
        else
          Column(
            children: [
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                proxyDecorator: (child, index, animation) {
                  return AnimatedBuilder(
                    animation: animation,
                    builder: (BuildContext context, Widget? child) {
                      final double animValue = Curves.easeInOut.transform(animation.value);
                      final double elevation = lerpDouble(0, 12, animValue)!;
                      return Material(
                        elevation: elevation,
                        color: Colors.transparent,
                        shadowColor: AppColors.black,
                        borderRadius: BorderRadius.circular(16),
                        child: child,
                      );
                    },
                    child: child,
                  );
                },
                onReorder: onReorder,
                itemCount: user.tasks.length,
                itemBuilder: (context, index) {
                  final task = user.tasks[index];
                  return QuestCard(
                    key: ObjectKey(task),
                    index: index,
                    task: task,
                    seasonsMap: seasonsMap,
                    seasonPostsCountMap: seasonPostsCountMap,
                    onTap: () {
                      if (task.isSeason) {
                        onSeasonTaskTap(index);
                      } else {
                        onEditTask(index);
                      }
                    },
                    onDelete: () => onDeleteTask(index),
                  );
                },
              ),
              _buildAddTaskSlot(context),
            ],
          ),
      ],
    );
  }

  /// タスクが空のときに表示するカード
  Widget _buildEmptyTaskCard(BuildContext context) {
    return InkWell(
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
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// タスク追加スロット（＋ボタン）
  Widget _buildAddTaskSlot(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
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
          child: const Center(
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
