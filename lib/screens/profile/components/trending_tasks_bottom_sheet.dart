import 'package:flutter/material.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import '../../../config/app_colors.dart';

// ---────────────────────────────────────────────
// ---トレンドタスク一覧のボトムシート
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
};

/// トレンドタスクのボトムシートを表示する関数
void showTrendingTasksBottomSheet(
  BuildContext context, {
  required List<Map<String, dynamic>> trendingTasks,
  required void Function({String? initialTitle}) onAddTask,
}) {
  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent, // DraggableScrollableSheet用に透明化
    isScrollControlled: true,
    builder: (ctx) {
      final int totalCount = trendingTasks.fold(0, (acc, t) => acc + ((t['count'] as num?)?.toInt() ?? 0));

      return DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---ドラッグハンドル
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: AppColors.grey50,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // ---タイトル
                  Text(
                    AppLocalizations.of(context)!.profileScreenTrendTitle,
                    style: TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ---トレンドリスト
                  if (trendingTasks.isEmpty)
                    Text(AppLocalizations.of(context)!.profileScreenTrendEmpty, style: TextStyle(color: AppColors.grey70))
                  else
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        itemCount: trendingTasks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final trend = trendingTasks[index];
                          final rawName = trend['name'] as String? ?? '';
                          if (rawName.isEmpty) return const SizedBox.shrink();

                          final isEnglish = Localizations.localeOf(context).languageCode == 'en';
                          final name = isEnglish ? (_taskNameTranslationMap[rawName] ?? rawName) : rawName;

                          final count = (trend['count'] as num?)?.toInt() ?? 0;
                          final percentage = totalCount > 0 ? (count / totalCount * 100).toStringAsFixed(1) : '0.0';

                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              onAddTask(initialTitle: name);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.bgSurface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
                              ),
                              child: Row(
                                children: [
                                  // ---ランキング番号
                                  SizedBox(
                                    width: 28,
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: index < 3 ? AppColors.accentGold : AppColors.textMuted,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  // ---タスク名
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            name,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: AppColors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        if (trend['isTrending'] == true) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: Colors.redAccent.withValues(alpha: 0.5),
                                                width: 0.5,
                                              ),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.whatshot, color: Colors.redAccent, size: 10),
                                                SizedBox(width: 2),
                                                Text(
                                                  'HOT',
                                                  style: TextStyle(
                                                    color: Colors.redAccent,
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  // ---割合（パーセンテージ）
                                  Text(
                                    '$percentage%',
                                    style: TextStyle(
                                      color: AppColors.accentGold,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // ---追加アイコン
                                  Icon(Icons.add_circle_outline_rounded, color: AppColors.white.withValues(alpha: 0.5), size: 20),
                                ],
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
