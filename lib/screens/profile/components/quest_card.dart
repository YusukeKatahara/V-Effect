import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../models/app_task.dart';
import '../../../models/season.dart';

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
  /// タスクカードがタップされたときのコールバック
  final VoidCallback onTap;
  /// タスクの削除ボタンが押されたときのコールバック
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bool isSeason = task.isSeason;

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
            color: isSeason ? AppColors.accentGold.withValues(alpha: 0.8) : AppColors.white.withValues(alpha: 0.08),
            width: isSeason ? 1.5 : 0.5,
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
                  // ---タスク番号またはシーズンアイコン
                  Container(
                    width: 26, // サイズ縮小
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSeason ? AppColors.accentGold.withValues(alpha: 0.1) : AppColors.white.withValues(alpha: 0.05), // 主張を抑える
                      border: Border.all(
                        color: isSeason ? AppColors.accentGold.withValues(alpha: 0.3) : AppColors.white.withValues(alpha: 0.08),
                        width: 0.5,
                      ),
                    ),
                    child: Center(
                      child: isSeason
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
                            ),
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
                        ],
                      ],
                    ),
                  ),
                  // ---削除ボタン（シーズンタスクは削除不可、ただしデバッグ用は除く）
                  if (!task.isSeason || task.seasonId == 'debug_season_test')
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
    final season = seasonsMap[sId];
    final count = seasonPostsCountMap[sId] ?? 0;
    final requiredCount = season?.requiredPostsCount ?? 12;
    return Text(
      'Season ($count/$requiredCount)',
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.grey50, // メタリックシルバー風
        letterSpacing: 0.5,
      ),
    );
  }
}
