import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_colors.dart';

/// ---------------------------------------------------------------------------
/// StreakHeatmapBar (カレンダー機能付き・超コンパクト・ストリークカード)
///
/// 【デザインコンセプト】
/// - 「コンパクトさ」と「一目でカレンダーと伝わる可読性」を両立。
/// - 7列（日〜土）の曜日ヘッダーと日付グリッドを美しく凝縮。
/// - 連続達成した日は角丸が横に滑らかに繋がる「Streak Flow（カプセル結合）」演出。
/// - 左側に🔥ストリーク数、右上に達成率バッジ。
/// - 高さ約110〜120dp（従来の巨大カレンダーから約60%省スペース化）。
/// ---------------------------------------------------------------------------
class StreakHeatmapBar extends StatelessWidget {
  const StreakHeatmapBar({
    super.key,
    required this.streak,
    required this.recentPostDates,
    this.onTap,
  });

  /// 現在の連続ストリーク数（例: 79）
  final int streak;

  /// 達成した日付の文字列リスト (Format: "YYYY-MM-DD")
  final List<String> recentPostDates;

  /// タップ時のアクション
  final VoidCallback? onTap;

  /// ストリーク数に応じたジュエルランクカラーを取得
  Color _getTierColor(int streakCount) {
    if (streakCount >= 365) return const Color(0xFFE0A33B); // Challenger
    if (streakCount >= 270) return const Color(0xFFB53030); // Grandmaster
    if (streakCount >= 180) return const Color(0xFF8D2D9E); // Master
    if (streakCount >= 100) return const Color(0xFF4A60AB); // Diamond
    if (streakCount >= 66) return const Color(0xFF10825B);  // Emerald
    if (streakCount >= 30) return const Color(0xFF327A8A);  // Platinum
    if (streakCount >= 14) return const Color(0xFFC89C3C);  // Gold
    if (streakCount >= 7) return const Color(0xFF8091A0);   // Silver
    return const Color(0xFF8F5338);                        // Bronze
  }

  @override
  Widget build(BuildContext context) {
    final tierColor = _getTierColor(streak);
    final isDark = AppColors.isDark;
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;

    // 当月の1日と最終日
    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    // 当月1日の曜日 (1:月..7:日 -> 0:日, 1:月...6:土 に変換)
    final startingWeekday = firstDayOfMonth.weekday % 7; 

    // 今月の達成日数
    int achievedDaysThisMonth = 0;
    for (int d = 1; d <= daysInMonth; d++) {
      final dStr = '$year-${month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      if (recentPostDates.contains(dStr)) {
        achievedDaysThisMonth++;
      }
    }

    // 曜日ヘッダー（言語設定に応じた多言語対応）
    final isJa = Localizations.localeOf(context).languageCode == 'ja';
    final weekDays = isJa
        ? const ['日', '月', '火', '水', '木', '金', '土']
        : const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.border : AppColors.grey20,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- 1. ヘッダー行 (🔥ストリーク数 + 月名 + 達成バッジ) ---
              Row(
                children: [
                  // 左: ストリーク数バッジ
                  Row(
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        size: 22,
                        color: tierColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$streak',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.textPrimary : AppColors.pureBlack,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'STREAK',
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: tierColor,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // 右: 月名 & 達成日数ピル
                  Row(
                    children: [
                      Text(
                        '$month月',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.textPrimary : AppColors.pureBlack,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: tierColor.withValues(alpha: isDark ? 0.15 : 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$achievedDaysThisMonth/$daysInMonth日達成',
                          style: GoogleFonts.outfit(
                            color: tierColor,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // --- 2. 曜日ヘッダー行 (日 月 火 水 木 金 土) ---
              Row(
                children: weekDays.map((day) {
                  final isWeekend = day == '日' || day == '土';
                  return Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: GoogleFonts.outfit(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: isWeekend
                              ? (day == '日' ? Colors.redAccent.withValues(alpha: 0.7) : Colors.blueAccent.withValues(alpha: 0.7))
                              : (isDark ? AppColors.grey50 : AppColors.grey70),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 6),

              // --- 3. カレンダーグリッド (7列コンパクト表示) ---
              _buildCalendarGrid(
                year: year,
                month: month,
                daysInMonth: daysInMonth,
                startingWeekday: startingWeekday,
                recentPostDates: recentPostDates,
                tierColor: tierColor,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// コンパクトなカレンダーグリッドの作成
  Widget _buildCalendarGrid({
    required int year,
    required int month,
    required int daysInMonth,
    required int startingWeekday,
    required List<String> recentPostDates,
    required Color tierColor,
    required bool isDark,
  }) {
    final now = DateTime.now();
    final todayDay = (now.year == year && now.month == month) ? now.day : -1;

    // 総セル数（前後のパディング含む）
    final totalCells = startingWeekday + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    return Column(
      children: List.generate(rowCount, (rowIndex) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 3.0),
          child: Row(
            children: List.generate(7, (colIndex) {
              final cellIndex = rowIndex * 7 + colIndex;
              final dayNumber = cellIndex - startingWeekday + 1;

              if (dayNumber < 1 || dayNumber > daysInMonth) {
                // 月外の空白セル
                return const Expanded(child: SizedBox(height: 20));
              }

              final dateStr = '$year-${month.toString().padLeft(2, '0')}-${dayNumber.toString().padLeft(2, '0')}';
              final isDone = recentPostDates.contains(dateStr);
              final isToday = dayNumber == todayDay;

              // 連続達成の連結判定 (前後の日も達成しているか)
              final prevDateStr = '$year-${month.toString().padLeft(2, '0')}-${(dayNumber - 1).toString().padLeft(2, '0')}';
              final nextDateStr = '$year-${month.toString().padLeft(2, '0')}-${(dayNumber + 1).toString().padLeft(2, '0')}';
              final isPrevDone = (dayNumber > 1 && colIndex > 0) && recentPostDates.contains(prevDateStr);
              final isNextDone = (dayNumber < daysInMonth && colIndex < 6) && recentPostDates.contains(nextDateStr);

              return Expanded(
                child: Center(
                  child: Container(
                    height: 20,
                    margin: EdgeInsets.only(
                      left: isPrevDone && isDone ? 0 : 1,
                      right: isNextDone && isDone ? 0 : 1,
                    ),
                    decoration: BoxDecoration(
                      color: isDone
                          ? tierColor
                          : (isToday
                              ? (isDark ? AppColors.grey20 : AppColors.grey10)
                              : Colors.transparent),
                      // 連続達成の場合、左右の角丸をつなげる (Streak Flow)
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(isPrevDone && isDone ? 0 : 6),
                        right: Radius.circular(isNextDone && isDone ? 0 : 6),
                      ),
                      border: isToday && !isDone
                          ? Border.all(color: tierColor, width: 1.2)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$dayNumber',
                      style: GoogleFonts.outfit(
                        fontSize: 9.5,
                        fontWeight: isDone || isToday ? FontWeight.w800 : FontWeight.w500,
                        color: isDone
                            ? Colors.white
                            : (isToday
                                ? tierColor
                                : (isDark ? AppColors.textSecondary : AppColors.grey70)),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}
