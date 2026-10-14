import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../models/app_task.dart';
import '../../../models/season.dart';
import '../../../models/post.dart'; // Post モデルのインポート

// ---────────────────────────────────────────────
// ---クエストカード（各タスクの表示カード）
// ---────────────────────────────────────────────
class QuestCard extends StatelessWidget {
  const QuestCard({
    super.key,
    required this.index,
    required this.task,
    required this.seasonsMap,
    required this.seasonPostsCountMap,
    required this.todayPosts, // 今日の投稿一覧を受け取る
    this.weeklyPostsCountMap = const {},
    this.monthlyPostsCountMap = const {},
    required this.onTap,
    required this.onDelete,
  });

  /// タスクのインデックス
  final int index;
  /// 表示するタスクデータ
  final AppTask task;
  /// シーズン情報のマップ
  final Map<String, Season> seasonsMap;
  /// シーズンごとの投稿数マップ
  final Map<String, int> seasonPostsCountMap;
  /// 今日の投稿一覧
  final List<Post> todayPosts;
  /// 週次タスクの達成回数マップ (taskId or taskName -> count)
  final Map<String, int> weeklyPostsCountMap;
  /// 月次タスクの達成回数マップ (taskId or taskName -> count)
  final Map<String, int> monthlyPostsCountMap;
  /// タスクカードがタップされたときのコールバック
  final VoidCallback onTap;
  /// タスクの削除ボタンが押されたときのコールバック
  final VoidCallback onDelete;

  /// 週次または月次の現在達成回数を取得
  int get _frequencyCount {
    if (task.isWeekly) {
      if (task.id.isNotEmpty && weeklyPostsCountMap.containsKey(task.id)) {
        return weeklyPostsCountMap[task.id] ?? 0;
      }
      return weeklyPostsCountMap[task.title] ?? 0;
    }
    if (task.isMonthly) {
      if (task.id.isNotEmpty && monthlyPostsCountMap.containsKey(task.id)) {
        return monthlyPostsCountMap[task.id] ?? 0;
      }
      return monthlyPostsCountMap[task.title] ?? 0;
    }
    return 0;
  }

  /// 本日そのタスクの投稿が行われたかどうか
  bool get _isPostedToday {
    return todayPosts.any((p) => (p.taskId != null && p.taskId == task.id) || p.taskName == task.title);
  }

  /// タスクが達成（完了）されたかどうかを判定します
  /// 
  /// 1. ワンタイムタスク：`completedAt` が null でないこと
  /// 2. シーズンタスク：現在の投稿数 `count` が目標数 `requiredCount` 以上であること
  /// 3. 週次目標タスク：今週の達成回数が目標回数 `targetCount` 以上であること
  int get _requiredCount {
    final sId = task.seasonId ?? 'debug_season_test';
    final season = seasonsMap[sId];
    if (season != null) return season.requiredPostsCount;
    final cleanName = task.title.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (cleanName.contains('WINTERARC') || (task.seasonId != null && task.seasonId!.toLowerCase().contains('winter_arc'))) {
      return 40;
    }
    return 12;
  }

  /// 4. 月次目標タスク：今月の達成回数が目標回数 `targetCount` 以上であること
  /// 5. 通常タスク（デイリー）：今日の投稿 `todayPosts` の中に該当タスク名の投稿が存在すること
  bool get _isCompleted {
    if (task.isOneTime) {
      return task.completedAt != null;
    }
    if (task.isSeason) {
      final sId = task.seasonId ?? 'debug_season_test';
      final count = seasonPostsCountMap[sId] ?? 0;
      return count >= _requiredCount;
    }
    if (task.isWeekly) {
      return _frequencyCount >= task.targetCount;
    }
    if (task.isMonthly) {
      return _frequencyCount >= task.targetCount;
    }
    // 通常タスクは、今日そのタスク名で投稿が完了しているか
    return _isPostedToday;
  }

  @override
  Widget build(BuildContext context) {
    final bool isSeason = task.isSeason;
    final bool isCompleted = _isCompleted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8), // よりコンパクトに
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16), // 少し収まりの良い角丸に
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.grey15, AppColors.grey10],
          ),
          boxShadow: [
            if (isSeason)
              BoxShadow(
                color: AppColors.accentGold.withValues(alpha: 0.25), // うっすらとしたゴールドの発光
                blurRadius: 12,
                spreadRadius: 1,
              )
            else
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.4), // 少し影を深めて奥行きを
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
          border: Border.all(
            color: isCompleted
                ? AppColors.accentGold // 達成時ははっきりとしたゴールド枠
                : (isSeason
                    ? AppColors.accentGold.withValues(alpha: 0.6) // 未達成のシーズンタスクは少し抑えたゴールド
                    : AppColors.white.withValues(alpha: 0.08)), // 通常の未達成タスクは控えめなグレー
            width: (isCompleted || isSeason) ? 1.5 : 0.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ), // コンパクトなパディング
              child: Row(
                children: [
                  // ---タスク番号またはシーズンアイコン（達成時はゴールドのチェックマーク）
                  Container(
                    width: 26, // サイズ縮小
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted
                          ? AppColors.accentGold.withValues(alpha: 0.2) // 達成時はゴールド背景
                          : (isSeason
                              ? AppColors.accentGold.withValues(alpha: 0.1)
                              : AppColors.white.withValues(alpha: 0.05)), // 主張を抑える
                      border: Border.all(
                        color: isCompleted
                            ? AppColors.accentGold // 達成時はゴールド枠
                            : (isSeason
                                ? AppColors.accentGold.withValues(alpha: 0.3)
                                : AppColors.white.withValues(alpha: 0.08)),
                        width: 0.5,
                      ),
                    ),
                    child: Center(
                      child: isCompleted
                          ? Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: AppColors.accentGold, // 達成時はチェックマーク
                            )
                          : (isSeason
                              ? Icon(
                                  Icons.star_rounded,
                                  size: 16,
                                  color: AppColors.accentGold,
                                )
                              : Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 12, // 文字サイズ調整
                                    fontWeight: FontWeight.w700, // ボールド感は維持
                                    color: AppColors.white,
                                  ),
                                )),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // ---タスク名とサブ情報
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (task.isSeason) ...[
                          const SizedBox(height: 2),
                          _buildSeasonLabel(),
                        ] else if (task.isOneTime) ...[
                          const SizedBox(height: 2),
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'One-Time',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accentGold.withValues(
                                  alpha: 0.7,
                                ),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ] else if (task.isWeekly || task.isMonthly) ...[
                          const SizedBox(height: 4),
                          _buildFrequencyProgressBadge(),
                        ],
                      ],
                    ),
                  ),
                  // --- 削除ボタン
                  IconButton(
                    onPressed: onDelete,
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppColors.white.withValues(alpha: 0.2),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// シーズン進捗ラベルの構築
  Widget _buildSeasonLabel() {
    final sId = task.seasonId ?? 'debug_season_test';
    final count = seasonPostsCountMap[sId] ?? 0;
    return Text(
      'Season ($count/$_requiredCount)',
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.grey50, // メタリックシルバー風
        letterSpacing: 0.5,
      ),
    );
  }

  /// 週次・月次タスクの達成進捗バッジ（例: 週 2/3 回、月 1/2 回）
  Widget _buildFrequencyProgressBadge() {
    final count = _frequencyCount;
    final target = task.targetCount;
    final isDone = count >= target;
    final prefix = task.isWeekly ? '週' : '月';
    final progress = (target > 0) ? (count / target).clamp(0.0, 1.0) : 0.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 頻度バッジ（ピル形状）
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isDone
                ? AppColors.accentGold.withValues(alpha: 0.2)
                : AppColors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDone
                  ? AppColors.accentGold
                  : AppColors.white.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                task.isWeekly ? Icons.calendar_today_rounded : Icons.calendar_month_rounded,
                size: 10,
                color: isDone ? AppColors.accentGold : AppColors.grey50,
              ),
              const SizedBox(width: 4),
              Text(
                '$prefix $count/$target 回',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isDone ? AppColors.accentGold : AppColors.grey50,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // ミニ進捗プログレスバー
        SizedBox(
          width: 42,
          height: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                isDone ? AppColors.accentGold : AppColors.accentGold.withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
        if (_isPostedToday && !isDone) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.accentGold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '本日済',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: AppColors.accentGold,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
