import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import '../../../config/app_colors.dart';
import '../../../services/analytics_service.dart';

// ---────────────────────────────────────────────
// --- トレンドタスク一覧のボトムシート
// （週間トレンドのタスクを表示し、タップで追加できる）
// ---────────────────────────────────────────────

// ---タスク名の日本語から英語への翻訳辞書
const Map<String, String> _taskNameTranslationMap = {
  '筋トレ': 'Workout',
  '感謝': 'Gratitude',
  '早起き': 'Early Rising',
  'プログラミング': 'Coding',
  '研究': 'Research',
  '開発': 'Development',
  'ポケモン': 'Pokémon',
  'ゲーム': 'Gaming',
  'ランク戦': 'Ranked Match',
  '計画': 'Planning',
  'セルフケア': 'Self-care',
  '読書': 'Reading',
  '勉強': 'Studying',
  '英語': 'English Study',
  '瞑想': 'Meditation',
  'ランニング': 'Running',
  '散歩': 'Walking',
  'ストレッチ': 'Stretching',
  'ヨガ': 'Yoga',
  '日記': 'Journaling',
  '片付け': 'Cleaning',
  '掃除': 'Cleaning',
  '自炊': 'Cooking',
  '水分補給': 'Hydration',
  '休養': 'Rest',
  '睡眠': 'Sleep',
  'ウォーキング': 'Walking',
  '創作': 'Creative Work',
  '仕事': 'Work',
  '就職活動': 'Job Hunting',
};

/// タスクの内容から適切なカテゴリーアイコンを取得するヘルパー
IconData _getCategoryIcon(String taskName) {
  final cat = AnalyticsService.classifyTask(taskName);
  switch (cat) {
    case 'exercise':
      return Icons.fitness_center_rounded;
    case 'study':
      return Icons.menu_book_rounded;
    case 'lifestyle':
      final lower = taskName.toLowerCase();
      if (lower.contains('寝') ||
          lower.contains('睡眠') ||
          lower.contains('sleep') ||
          lower.contains('休養')) {
        return Icons.bedtime_rounded;
      }
      if (lower.contains('感謝') ||
          lower.contains('セルフケア') ||
          lower.contains('瞑想')) {
        return Icons.favorite_rounded;
      }
      return Icons.wb_sunny_rounded;
    case 'creative':
      return Icons.palette_rounded;
    case 'work':
      return Icons.laptop_mac_rounded;
    default:
      return Icons.auto_awesome_rounded;
  }
}

/// トレンドタスクのボトムシートを表示する関数
void showTrendingTasksBottomSheet(
  BuildContext context, {
  required List<Map<String, dynamic>> trendingTasks,
  required void Function({String? initialTitle}) onAddTask,
  List<String> existingTaskTitles = const [],
}) {
  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent, // DraggableScrollableSheet用に透明化
    isScrollControlled: true,
    builder: (ctx) {
      // 件数(count)の降順、同数の場合はスコア(score)の降順でソート
      final sortedTasks = List<Map<String, dynamic>>.from(trendingTasks)
        ..sort((a, b) {
          final countA = (a['count'] as num?)?.toInt() ?? 0;
          final countB = (b['count'] as num?)?.toInt() ?? 0;
          if (countB != countA) {
            return countB.compareTo(countA);
          }
          final scoreA = (a['score'] as num?)?.toDouble() ?? 0.0;
          final scoreB = (b['score'] as num?)?.toDouble() ?? 0.0;
          return scoreB.compareTo(scoreA);
        });

      final int totalCount = sortedTasks.fold(
        0,
        (acc, t) => acc + ((t['count'] as num?)?.toInt() ?? 0),
      );

      // 1位の件数（相対プログレスバー計算用の基準値）
      final int maxCount = sortedTasks.isNotEmpty
          ? ((sortedTasks.first['count'] as num?)?.toInt() ?? 0)
          : 0;

      final l10n = AppLocalizations.of(context)!;
      final isEnglish = Localizations.localeOf(context).languageCode == 'en';

      return DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                top: BorderSide(
                  color: AppColors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---ドラッグハンドル
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // ---ヘッダーエリア（タイトル ＆ サブタイトル）
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        l10n.profileScreenTrendTitle,
                        style: TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.white.withValues(alpha: 0.08),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          isEnglish ? 'Weekly' : '今週の集計',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.profileScreenTrendSubtitle,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ---トレンドリスト
                  if (sortedTasks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          l10n.profileScreenTrendEmpty,
                          style: TextStyle(color: AppColors.grey70, fontSize: 14),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        physics: const BouncingScrollPhysics(),
                        itemCount: sortedTasks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final trend = sortedTasks[index];
                          final rawName = trend['name'] as String? ?? '';
                          if (rawName.isEmpty) return const SizedBox.shrink();

                          final name = isEnglish
                              ? (_taskNameTranslationMap[rawName] ?? rawName)
                              : rawName;

                          final count = (trend['count'] as num?)?.toInt() ?? 0;
                          final percentage = totalCount > 0
                              ? (count / totalCount * 100).toStringAsFixed(1)
                              : '0.0';

                          // 相対プログレス（1位の件数を1.0とする）
                          final double relativeProgress = maxCount > 0
                              ? (count / maxCount).clamp(0.08, 1.0)
                              : 0.1;

                          // ユーザーがすでに登録しているか
                          final isAlreadyAdded = existingTaskTitles.any(
                            (title) =>
                                title.trim().toLowerCase() ==
                                rawName.trim().toLowerCase(),
                          );

                          // 順位ごとのスタイリング
                          final isTop1 = index == 0;
                          final isTop2 = index == 1;
                          final isTop3 = index == 2;
                          final isPodium = index < 3;

                          final Color rankColor = isTop1
                              ? AppColors.accentGold
                              : isTop2
                                  ? const Color(0xFFD4D4D4) // Silver
                                  : isTop3
                                      ? const Color(0xFFCD7F32) // Bronze
                                      : AppColors.grey50;

                          final Color cardBorderColor = isTop1
                              ? AppColors.accentGold.withValues(alpha: 0.35)
                              : isTop2
                                  ? Colors.white.withValues(alpha: 0.16)
                                  : isTop3
                                      ? const Color(0xFFCD7F32).withValues(alpha: 0.25)
                                      : Colors.white.withValues(alpha: 0.05);

                          return Container(
                            decoration: BoxDecoration(
                              color: isTop1
                                  ? const Color(0xFF1E1C15) // 1位のみほんのりアンバーな質感
                                  : AppColors.bgSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: cardBorderColor,
                                width: isTop1 ? 1.2 : 0.8,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: isAlreadyAdded
                                    ? null
                                    : () {
                                        HapticFeedback.lightImpact();
                                        Navigator.of(ctx).pop();
                                        onAddTask(initialTitle: name);
                                      },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          // --- 順位バッジ
                                          Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isPodium
                                                  ? rankColor.withValues(alpha: 0.15)
                                                  : Colors.white.withValues(alpha: 0.04),
                                              border: isPodium
                                                  ? Border.all(
                                                      color: rankColor,
                                                      width: 1,
                                                    )
                                                  : null,
                                            ),
                                            child: Center(
                                              child: isTop1
                                                  ? Icon(
                                                      Icons.emoji_events_rounded,
                                                      size: 15,
                                                      color: AppColors.accentGold,
                                                    )
                                                  : Text(
                                                      '${index + 1}',
                                                      style: TextStyle(
                                                        color: rankColor,
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),

                                          // --- カテゴリーアイコン
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.05),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: Colors.white.withValues(alpha: 0.06),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Icon(
                                              _getCategoryIcon(rawName),
                                              size: 16,
                                              color: AppColors.white.withValues(alpha: 0.85),
                                            ),
                                          ),
                                          const SizedBox(width: 12),

                                          // --- タスク名 ＆ 統計情報
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        name,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: TextStyle(
                                                          color: AppColors.white,
                                                          fontSize: 15,
                                                          fontWeight: isPodium
                                                              ? FontWeight.bold
                                                              : FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                    if (isTop1) ...[
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 5,
                                                          vertical: 1.5,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: AppColors.accentGold
                                                              .withValues(alpha: 0.15),
                                                          borderRadius:
                                                              BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          'NO.1',
                                                          style: TextStyle(
                                                            color: AppColors.accentGold,
                                                            fontSize: 8.5,
                                                            fontWeight: FontWeight.w900,
                                                            letterSpacing: 0.5,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                    if (trend['isTrending'] == true) ...[
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.red
                                                              .withValues(alpha: 0.15),
                                                          borderRadius:
                                                              BorderRadius.circular(10),
                                                          border: Border.all(
                                                            color: Colors.redAccent
                                                                .withValues(alpha: 0.4),
                                                            width: 0.5,
                                                          ),
                                                        ),
                                                        child: const Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              Icons.whatshot_rounded,
                                                              color: Colors.redAccent,
                                                              size: 11,
                                                            ),
                                                            SizedBox(width: 2),
                                                            Text(
                                                              'HOT',
                                                              style: TextStyle(
                                                                color: Colors.redAccent,
                                                                fontSize: 8.5,
                                                                fontWeight: FontWeight.bold,
                                                                letterSpacing: 0.5,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    if (count > 0) ...[
                                                      Text(
                                                        l10n.profileScreenPracticingCount(count),
                                                        style: TextStyle(
                                                          color: AppColors.white
                                                              .withValues(alpha: 0.7),
                                                          fontSize: 11.5,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                      Text(
                                                        ' · ',
                                                        style: TextStyle(
                                                          color: AppColors.grey50,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ],
                                                    Text(
                                                      '$percentage%',
                                                      style: TextStyle(
                                                        color: isPodium
                                                            ? rankColor
                                                            : AppColors.grey50,
                                                        fontSize: 11.5,
                                                        fontWeight: isPodium
                                                            ? FontWeight.bold
                                                            : FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),

                                          // --- アクションボタン（登録済み or 追加ボタン）
                                          if (isAlreadyAdded)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.accentGold
                                                    .withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: AppColors.accentGold
                                                      .withValues(alpha: 0.3),
                                                  width: 0.8,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.check_rounded,
                                                    size: 12,
                                                    color: AppColors.accentGold,
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    l10n.profileScreenTaskAlreadyAdded,
                                                    style: TextStyle(
                                                      color: AppColors.accentGold,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          else
                                            Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.08),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.add_rounded,
                                                color: AppColors.white.withValues(alpha: 0.8),
                                                size: 20,
                                              ),
                                            ),
                                        ],
                                      ),

                                      // --- 相対人気度プログレスバー
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(2),
                                        child: LinearProgressIndicator(
                                          value: relativeProgress,
                                          minHeight: 2.5,
                                          backgroundColor:
                                              Colors.white.withValues(alpha: 0.04),
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            rankColor.withValues(
                                              alpha: isPodium ? 0.85 : 0.4,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
