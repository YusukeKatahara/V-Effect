import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../../../config/app_colors.dart';
import '../../../models/app_task.dart';
import '../../../models/app_user.dart';
import '../../../models/post.dart';
import '../../../providers/service_providers.dart';
import '../../../utils/date_helper.dart';
import '../../../widgets/shimmer_container.dart';

/// 習慣プランナー & 達成記録ボトムシート
///
/// カレンダー上で過去の達成日（写真・タスク）を確認したり、
/// 未来や当日の日付を選択してヒーロータスク（特に週○回などのタスク）の実行予定・習慣コミットメントを予約できます。
class HabitPlannerSheet extends ConsumerStatefulWidget {
  final AppUser user;
  final DateTime? initialDate;
  final VoidCallback? onScheduleUpdated;

  const HabitPlannerSheet({
    super.key,
    required this.user,
    this.initialDate,
    this.onScheduleUpdated,
  });

  /// ボトムシートを表示するヘルパーメソッド
  static Future<void> show(
    BuildContext context, {
    required AppUser user,
    DateTime? initialDate,
    VoidCallback? onScheduleUpdated,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HabitPlannerSheet(
        user: user,
        initialDate: initialDate,
        onScheduleUpdated: onScheduleUpdated,
      ),
    );
  }

  @override
  ConsumerState<HabitPlannerSheet> createState() => _HabitPlannerSheetState();
}

class _HabitPlannerSheetState extends ConsumerState<HabitPlannerSheet> {
  late DateTime _currentMonth;
  late DateTime _selectedDate;
  late Map<String, List<String>> _schedules;
  List<Post> _pastPosts = [];
  bool _isLoadingPosts = true;
  final TextEditingController _quickTaskController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final init = widget.initialDate ?? DateTime.now();
    _currentMonth = DateTime(init.year, init.month, 1);
    _selectedDate = DateTime(init.year, init.month, init.day);
    _schedules = Map<String, List<String>>.from(widget.user.taskSchedules);
    _loadPastPosts();
  }

  @override
  void dispose() {
    _quickTaskController.dispose();
    super.dispose();
  }

  /// 過去の投稿履歴を非同期で取得
  Future<void> _loadPastPosts() async {
    try {
      final posts = await ref.read(postServiceProvider).getAllMyPastPosts();
      if (mounted) {
        setState(() {
          _pastPosts = posts;
          _isLoadingPosts = false;
        });
      }
    } catch (e) {
      debugPrint('HabitPlannerSheet: Error loading past posts: $e');
      if (mounted) {
        setState(() {
          _isLoadingPosts = false;
        });
      }
    }
  }

  /// 選択月を切り替え
  void _changeMonth(int monthDelta) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + monthDelta, 1);
      // 選択日が表示月と異なる場合、その月の1日に合わせる
      if (_selectedDate.year != _currentMonth.year || _selectedDate.month != _currentMonth.month) {
        _selectedDate = DateTime(_currentMonth.year, _currentMonth.month, 1);
      }
    });
  }

  /// 今日に戻る
  void _jumpToToday() {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    setState(() {
      _currentMonth = DateTime(now.year, now.month, 1);
      _selectedDate = DateTime(now.year, now.month, now.day);
    });
  }

  /// 指定した日付に該当する投稿を抽出
  List<Post> _getPostsForDate(DateTime date) {
    final dateStr = DateHelper.toDateString(date);
    return _pastPosts
        .where((p) => DateHelper.toDateString(p.createdAt) == dateStr)
        .toList();
  }

  /// 選択日のコミットメント通知を PushNotificationService に同期
  Future<void> _syncNotificationForDate(String dateStr, List<String> taskIds) async {
    try {
      final titles = taskIds.map((id) => _resolveTaskTitle(id)).toList();
      String? reminderTime;
      for (final id in taskIds) {
        final matched = widget.user.tasks.where((t) => t.id == id || t.title == id);
        if (matched.isNotEmpty && matched.first.reminderTime != null) {
          reminderTime = matched.first.reminderTime;
          break;
        }
      }
      final isJapanese = Localizations.localeOf(context).languageCode == 'ja';
      await ref.read(pushNotificationServiceProvider).syncCommittedDailyReminder(
        dateStr: dateStr,
        taskTitles: titles,
        reminderTime: reminderTime,
        isJapanese: isJapanese,
      );
    } catch (e) {
      debugPrint('Error syncing committed notification: $e');
    }
  }

  /// タスクの予定（習慣コミットメント）をトグル切り替え
  Future<void> _toggleTaskSchedule(AppTask task) async {
    final dateStr = DateHelper.toDateString(_selectedDate);
    final taskId = task.id.isNotEmpty ? task.id : task.title;
    final currentList = List<String>.from(_schedules[dateStr] ?? []);

    final isAlreadyScheduled = currentList.contains(taskId) || currentList.contains(task.title);
    if (isAlreadyScheduled) {
      currentList.removeWhere((id) => id == taskId || id == task.title);
    } else {
      currentList.add(taskId);
    }

    setState(() {
      if (currentList.isEmpty) {
        _schedules.remove(dateStr);
      } else {
        _schedules[dateStr] = currentList;
      }
    });
    HapticFeedback.lightImpact();

    try {
      await ref.read(userServiceProvider).updateTaskSchedule(dateStr, currentList);
      widget.onScheduleUpdated?.call();
      await _syncNotificationForDate(dateStr, currentList);
    } catch (e) {
      debugPrint('Error updating schedule: $e');
      if (mounted) {
        // ロールバック
        setState(() {
          if (isAlreadyScheduled) {
            final rolledBack = List<String>.from(_schedules[dateStr] ?? []);
            rolledBack.add(taskId);
            _schedules[dateStr] = rolledBack;
          } else {
            final rolledBack = List<String>.from(_schedules[dateStr] ?? []);
            rolledBack.removeWhere((id) => id == taskId || id == task.title);
            if (rolledBack.isEmpty) {
              _schedules.remove(dateStr);
            } else {
              _schedules[dateStr] = rolledBack;
            }
          }
        });
        _syncNotificationForDate(dateStr, _schedules[dateStr] ?? []);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('予定の保存に失敗しました')),
        );
      }
    }
  }

  /// クイックタスクを個別追加
  Future<void> _addQuickTask() async {
    final text = _quickTaskController.text.trim();
    if (text.isEmpty) return;

    final dateStr = DateHelper.toDateString(_selectedDate);
    final currentList = List<String>.from(_schedules[dateStr] ?? []);

    if (!currentList.contains(text)) {
      currentList.add(text);
      setState(() {
        _schedules[dateStr] = currentList;
      });
      _quickTaskController.clear();
      HapticFeedback.lightImpact();

      try {
        await ref.read(userServiceProvider).updateTaskSchedule(dateStr, currentList);
        widget.onScheduleUpdated?.call();
        await _syncNotificationForDate(dateStr, currentList);
      } catch (e) {
        debugPrint('Error saving quick task: $e');
        if (mounted) {
          setState(() {
            currentList.remove(text);
            if (currentList.isEmpty) {
              _schedules.remove(dateStr);
            } else {
              _schedules[dateStr] = currentList;
            }
          });
          _syncNotificationForDate(dateStr, _schedules[dateStr] ?? []);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('予定の保存に失敗しました')),
          );
        }
      }
    }
  }

  /// 登録された予定アイテムを削除
  Future<void> _removeScheduledItem(String item) async {
    final dateStr = DateHelper.toDateString(_selectedDate);
    final currentList = List<String>.from(_schedules[dateStr] ?? []);

    currentList.removeWhere((id) => id == item || _resolveTaskTitle(id) == item);
    setState(() {
      if (currentList.isEmpty) {
        _schedules.remove(dateStr);
      } else {
        _schedules[dateStr] = currentList;
      }
    });
    HapticFeedback.lightImpact();

    try {
      await ref.read(userServiceProvider).updateTaskSchedule(dateStr, currentList);
      widget.onScheduleUpdated?.call();
      await _syncNotificationForDate(dateStr, currentList);
    } catch (e) {
      debugPrint('Error removing item: $e');
      if (mounted) {
        setState(() {
          currentList.add(item);
          _schedules[dateStr] = currentList;
        });
        _syncNotificationForDate(dateStr, _schedules[dateStr] ?? []);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('予定の削除に失敗しました')),
        );
      }
    }
  }

  /// タスクの表示名を取得
  String _resolveTaskTitle(String taskIdOrTitle) {
    final matched = widget.user.tasks.where((t) => (t.id == taskIdOrTitle || t.title == taskIdOrTitle));
    if (matched.isNotEmpty) {
      return matched.first.title;
    }
    return taskIdOrTitle;
  }

  /// 選択日の週（月曜〜日曜）における指定タスクのコミット日数を計算
  int _calculateWeeklyCommittedCount(AppTask task) {
    final monday = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    final taskId = task.id.isNotEmpty ? task.id : task.title;
    int count = 0;

    for (int i = 0; i < 7; i++) {
      final day = DateTime(monday.year, monday.month, monday.day + i);
      final dateStr = DateHelper.toDateString(day);
      final list = _schedules[dateStr] ?? [];
      if (list.contains(taskId) || list.contains(task.title)) {
        count++;
      }
    }
    return count;
  }

  /// 選択日の月における指定タスクのコミット日数を計算
  int _calculateMonthlyCommittedCount(AppTask task) {
    final year = _selectedDate.year;
    final month = _selectedDate.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final taskId = task.id.isNotEmpty ? task.id : task.title;
    int count = 0;

    for (int d = 1; d <= daysInMonth; d++) {
      final dateStr = '$year-${month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      final list = _schedules[dateStr] ?? [];
      if (list.contains(taskId) || list.contains(task.title)) {
        count++;
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final isSelectedDatePast = _selectedDate.isBefore(startOfToday);
    final isSelectedDateToday = DateHelper.toDateString(_selectedDate) == DateHelper.toDateString(now);

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141416) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black12,
            width: 0.5,
          ),
        ),
        child: Column(
          children: [
            // 上部ドラッグハンドル
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),

            // ヘッダーバー
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_month_rounded,
                              size: 19,
                              color: AppColors.accentGold,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '習慣プランナー & 達成記録',
                              style: GoogleFonts.notoSansJp(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : AppColors.pureBlack,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '日付を選んで予定をコミット・過去の達成を確認',
                          style: GoogleFonts.notoSansJp(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark ? Colors.white70 : Colors.black54,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, thickness: 0.5),

            // スクロール可能なメインコンテンツ
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 20 + bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── カレンダーコンポーネント ──
                    _buildCalendarSection(isDark, now),

                    const SizedBox(height: 16),

                    // ── 選択日の詳細パネル ──
                    _buildSelectedDatePanel(
                      isDark: isDark,
                      now: now,
                      isPast: isSelectedDatePast,
                      isToday: isSelectedDateToday,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 月間カレンダーグリッドと月送りナビゲーション
  Widget _buildCalendarSection(bool isDark, DateTime now) {
    final year = _currentMonth.year;
    final month = _currentMonth.month;
    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startWeekday = firstDayOfMonth.weekday % 7; // 日=0, 月=1, ..., 土=6
    final totalCells = startWeekday + daysInMonth;
    final startOfToday = DateTime(now.year, now.month, now.day);

    final isJa = Localizations.localeOf(context).languageCode == 'ja';
    final weekdays = isJa
        ? const ['日', '月', '火', '水', '木', '金', '土']
        : const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    final isThisMonth = now.year == year && now.month == month;
    final pastPostDates = _pastPosts.map((p) => DateHelper.toDateString(p.createdAt)).toSet();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1F) : const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
          width: 0.8,
        ),
      ),
      child: Column(
        children: [
          // 月送りヘッダー
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => _changeMonth(-1),
                icon: const Icon(Icons.chevron_left_rounded),
                color: isDark ? Colors.white70 : Colors.black87,
                visualDensity: VisualDensity.compact,
              ),
              Row(
                children: [
                  Text(
                    '$year年 $month月',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppColors.pureBlack,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (!isThisMonth) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _jumpToToday,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentGold.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.accentGold, width: 0.8),
                        ),
                        child: Text(
                          '今日',
                          style: GoogleFonts.notoSansJp(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accentGold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              IconButton(
                onPressed: () => _changeMonth(1),
                icon: const Icon(Icons.chevron_right_rounded),
                color: isDark ? Colors.white70 : Colors.black87,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),

          const SizedBox(height: 6),

          // 曜日ヘッダー
          Row(
            children: List.generate(7, (i) {
              final isSunday = i == 0;
              final isSaturday = i == 6;
              final textColor = isSunday
                  ? const Color(0xFFEF4444)
                  : isSaturday
                      ? const Color(0xFF3B82F6)
                      : (isDark ? Colors.white54 : Colors.black45);

              return Expanded(
                child: Center(
                  child: Text(
                    weekdays[i],
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 6),

          // 日付グリッド
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1.1,
            ),
            itemBuilder: (context, index) {
              if (index < startWeekday) {
                return const SizedBox.shrink();
              }
              final dayNumber = index - startWeekday + 1;
              final date = DateTime(year, month, dayNumber);
              final dateStr = DateHelper.toDateString(date);

              final isSelected = _selectedDate.year == date.year &&
                  _selectedDate.month == date.month &&
                  _selectedDate.day == date.day;
              final isToday = now.year == date.year &&
                  now.month == date.month &&
                  now.day == date.day;
              final isPast = date.isBefore(startOfToday);
              final isAchieved = widget.user.recentPostDates.contains(dateStr) || pastPostDates.contains(dateStr);
              final scheduledList = _schedules[dateStr] ?? [];
              final hasSchedule = scheduledList.isNotEmpty;
              // ドット表示: 未来または今日で、未達成かつ予定がある日
              final showGoldDot = hasSchedule && !isAchieved && !isPast;

              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedDate = date;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.accentGold.withValues(alpha: isDark ? 0.25 : 0.18)
                        : isAchieved
                            ? const Color(0xFF10825B).withValues(alpha: isDark ? 0.35 : 0.2)
                            : isToday
                                ? (isDark ? const Color(0xFF2D2D32) : Colors.black.withValues(alpha: 0.07))
                                : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.accentGold
                          : isToday
                              ? (isDark ? Colors.white38 : Colors.black38)
                              : Colors.transparent,
                      width: isSelected ? 1.8 : 1.0,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 日付番号
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$dayNumber',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: isSelected || isAchieved || isToday
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isSelected
                                  ? AppColors.accentGold
                                  : isAchieved
                                      ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
                                      : isToday
                                          ? (isDark ? Colors.white : AppColors.pureBlack)
                                          : (date.isAfter(startOfToday)
                                              ? (isDark ? Colors.white70 : Colors.black87)
                                              : (isDark ? Colors.white54 : Colors.black54)),
                            ),
                          ),
                          // 達成マーク（チェック）
                          if (isAchieved)
                            Icon(
                              Icons.check_rounded,
                              size: 10,
                              color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                            )
                          else
                            const SizedBox(height: 10),
                        ],
                      ),

                      // 予定（習慣コミットメント）のゴールドドットインジケーター（今日・未来の未達成予定）
                      if (showGoldDot)
                        Positioned(
                          bottom: 2.5,
                          child: Container(
                            width: 4.5,
                            height: 4.5,
                            decoration: BoxDecoration(
                              color: AppColors.accentGold,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accentGold.withValues(alpha: 0.6),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 選択日の詳細パネル（過去の達成記録 ＆ 未来・今日のタスク予定）
  Widget _buildSelectedDatePanel({
    required bool isDark,
    required DateTime now,
    required bool isPast,
    required bool isToday,
  }) {
    final dateStr = DateHelper.toDateString(_selectedDate);
    final datePosts = _getPostsForDate(_selectedDate);
    final isAchieved = widget.user.recentPostDates.contains(dateStr) || datePosts.isNotEmpty;
    final scheduledList = _schedules[dateStr] ?? [];

    final isJa = Localizations.localeOf(context).languageCode == 'ja';
    final weekdays = isJa
        ? const ['月', '火', '水', '木', '金', '土', '日']
        : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekdayName = weekdays[_selectedDate.weekday - 1];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1F) : const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 日付タイトルとステータスバッジ
          Row(
            children: [
              Text(
                '${_selectedDate.month}月${_selectedDate.day}日 ($weekdayName)',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.pureBlack,
                ),
              ),
              const SizedBox(width: 8),
              if (isToday)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accentGold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.accentGold, width: 0.8),
                  ),
                  child: Text(
                    '今日',
                    style: GoogleFonts.notoSansJp(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentGold,
                    ),
                  ),
                ),
              if (isAchieved) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10825B).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF10825B), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 11, color: Color(0xFF34D399)),
                      const SizedBox(width: 3),
                      Text(
                        'ストリーク達成',
                        style: GoogleFonts.notoSansJp(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF34D399),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 14),

          // ── パート1: 過去達成記録（過去日、または今日達成記録がある場合） ──
          if (isPast || (isToday && isAchieved)) ...[
            _buildAchievementHistorySection(
              isDark: isDark,
              isAchieved: isAchieved,
              datePosts: datePosts,
              isPast: isPast,
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, thickness: 0.5),
            const SizedBox(height: 16),
          ],

          // ── パート2: 習慣コミットメント（予定）設定パネル ──
          _buildCommitmentSection(
            isDark: isDark,
            dateStr: dateStr,
            scheduledList: scheduledList,
            isPast: isPast,
            datePosts: datePosts,
            isToday: isToday,
          ),
        ],
      ),
    );
  }

  /// 過去達成記録セクション
  Widget _buildAchievementHistorySection({
    required bool isDark,
    required bool isAchieved,
    required List<Post> datePosts,
    required bool isPast,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history_rounded, size: 16, color: Color(0xFF34D399)),
            const SizedBox(width: 6),
            Text(
              '達成記録',
              style: GoogleFonts.notoSansJp(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.pureBlack,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_isLoadingPosts)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: ShimmerContainer(width: double.infinity, height: 60, borderRadius: 10),
          )
        else if (datePosts.isNotEmpty)
          Column(
            children: datePosts.map((post) {
              final timeStr = DateFormat('HH:mm').format(post.createdAt);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF26262A) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12,
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    // 写真サムネイル
                    if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: post.imageUrl!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const ShimmerContainer(width: 48, height: 48),
                          errorWidget: (_, __, ___) => Container(
                            width: 48,
                            height: 48,
                            color: isDark ? Colors.white12 : Colors.black12,
                            child: const Icon(Icons.broken_image, size: 18),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10825B).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.task_alt_rounded, color: Color(0xFF34D399)),
                      ),
                    const SizedBox(width: 12),
                    // タスク名 & 時間
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.taskName,
                            style: GoogleFonts.notoSansJp(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AppColors.pureBlack,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                timeStr,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: isDark ? Colors.white54 : Colors.black45,
                                ),
                              ),
                              if (post.caption != null && post.caption!.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    post.caption!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.notoSansJp(
                                      fontSize: 11,
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          )
        else if (isAchieved)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF10825B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.military_tech_rounded, color: Color(0xFF34D399), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'この日のストリーク達成記録が保存されています ✨',
                    style: GoogleFonts.notoSansJp(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.pureBlack,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'この日の達成記録はありません。',
              style: GoogleFonts.notoSansJp(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ),
      ],
    );
  }

  /// 習慣コミットメント（予定）セクション
  Widget _buildCommitmentSection({
    required bool isDark,
    required String dateStr,
    required List<String> scheduledList,
    required bool isPast,
    required List<Post> datePosts,
    required bool isToday,
  }) {
    final tasks = widget.user.tasks;

    if (isPast) {
      // 過去日の場合は、当時の予定履歴を閲覧専用で表示
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_note_rounded, size: 16, color: AppColors.accentGold),
              const SizedBox(width: 6),
              Text(
                'この日の予定履歴',
                style: GoogleFonts.notoSansJp(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.pureBlack,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '過去に予定されていたタスクの一覧です',
            style: GoogleFonts.notoSansJp(
              fontSize: 11,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(height: 10),
          if (scheduledList.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: scheduledList.map((item) {
                final title = _resolveTaskTitle(item);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.accentGold.withValues(alpha: isDark ? 0.15 : 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.accentGold, width: 0.8),
                  ),
                  child: Text(
                    title,
                    style: GoogleFonts.notoSansJp(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.pureBlack,
                    ),
                  ),
                );
              }).toList(),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF242428) : Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'この日に登録されていた予定はありません。',
                style: GoogleFonts.notoSansJp(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ),
          ],
        ],
      );
    }

    // 当日または未来日: 習慣コミットメント（予定）設定パネル
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.edit_calendar_rounded, size: 16, color: AppColors.accentGold),
            const SizedBox(width: 6),
            Text(
              '習慣コミットメント（予定）',
              style: GoogleFonts.notoSansJp(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.pureBlack,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'この日に実行するヒーロータスクを選択して予定をコミットしましょう',
          style: GoogleFonts.notoSansJp(
            fontSize: 11,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),

        const SizedBox(height: 12),

        // 週次目標タスクの進捗バッジ（週3回などの目標がある場合）
        ...tasks.where((t) => t.isWeekly).map((weeklyTask) {
          final committedCount = _calculateWeeklyCommittedCount(weeklyTask);
          final isGoalReached = committedCount >= weeklyTask.targetCount;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isGoalReached
                  ? AppColors.accentGold.withValues(alpha: isDark ? 0.2 : 0.12)
                  : (isDark ? const Color(0xFF26262A) : Colors.white),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isGoalReached ? AppColors.accentGold : (isDark ? Colors.white10 : Colors.black12),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isGoalReached ? Icons.workspace_premium_rounded : Icons.flag_rounded,
                  size: 16,
                  color: isGoalReached ? AppColors.accentGold : (isDark ? Colors.white60 : Colors.black54),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${weeklyTask.title}（週${weeklyTask.targetCount}回目標）',
                    style: GoogleFonts.notoSansJp(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.pureBlack,
                    ),
                  ),
                ),
                Text(
                  '今週 $committedCount/${weeklyTask.targetCount}日 予約中',
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: isGoalReached ? AppColors.accentGold : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ],
            ),
          );
        }),

        // 月次目標タスクの進捗バッジ（月10回などの目標がある場合）
        ...tasks.where((t) => t.isMonthly).map((monthlyTask) {
          final committedCount = _calculateMonthlyCommittedCount(monthlyTask);
          final isGoalReached = committedCount >= monthlyTask.targetCount;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isGoalReached
                  ? AppColors.accentGold.withValues(alpha: isDark ? 0.2 : 0.12)
                  : (isDark ? const Color(0xFF26262A) : Colors.white),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isGoalReached ? AppColors.accentGold : (isDark ? Colors.white10 : Colors.black12),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isGoalReached ? Icons.workspace_premium_rounded : Icons.flag_rounded,
                  size: 16,
                  color: isGoalReached ? AppColors.accentGold : (isDark ? Colors.white60 : Colors.black54),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${monthlyTask.title}（月${monthlyTask.targetCount}回目標）',
                    style: GoogleFonts.notoSansJp(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.pureBlack,
                    ),
                  ),
                ),
                Text(
                  '今月 $committedCount/${monthlyTask.targetCount}日 予約中',
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: isGoalReached ? AppColors.accentGold : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ],
            ),
          );
        }),

        // ヒーロータスク選択リスト
        if (tasks.isNotEmpty) ...[
          Text(
            '登録済みヒーロータスク:',
            style: GoogleFonts.notoSansJp(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          ...tasks.map((task) {
            final taskId = task.id.isNotEmpty ? task.id : task.title;
            final isScheduled = scheduledList.contains(taskId) || scheduledList.contains(task.title);
            final isTaskPosted = datePosts.any((p) =>
                (p.taskId != null && (p.taskId == task.id || p.taskId == taskId)) ||
                p.taskName == task.title) ||
                (isToday && task.isCompletedToday);

            // 頻度ラベルの作成
            String freqLabel;
            if (task.isWeekly) {
              freqLabel = '週${task.targetCount}回';
            } else if (task.isMonthly) {
              freqLabel = '月${task.targetCount}回';
            } else if (task.isSeason) {
              freqLabel = 'シーズン';
            } else {
              freqLabel = '毎日';
            }

            return InkWell(
              onTap: () => _toggleTaskSchedule(task),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isScheduled
                      ? AppColors.accentGold.withValues(alpha: isDark ? 0.15 : 0.1)
                      : (isDark ? const Color(0xFF242428) : Colors.white),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isScheduled
                        ? AppColors.accentGold
                        : (isDark ? Colors.white10 : Colors.black12),
                    width: isScheduled ? 1.2 : 0.6,
                  ),
                ),
                child: Row(
                  children: [
                    // チェックボックス
                    Icon(
                      isScheduled ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                      size: 20,
                      color: isScheduled ? AppColors.accentGold : (isDark ? Colors.white38 : Colors.black38),
                    ),
                    const SizedBox(width: 10),
                    // タスク名
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  task.title,
                                  style: GoogleFonts.notoSansJp(
                                    fontSize: 13,
                                    fontWeight: isScheduled ? FontWeight.w700 : FontWeight.w500,
                                    color: isDark ? Colors.white : AppColors.pureBlack,
                                  ),
                                ),
                              ),
                              if (isScheduled && isTaskPosted) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10825B).withValues(alpha: isDark ? 0.3 : 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFF10825B),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    '達成済 ✨',
                                    style: GoogleFonts.notoSansJp(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (task.trigger != null && task.trigger!.isNotEmpty)
                            Text(
                              '⚡️ ${task.trigger!}',
                              style: GoogleFonts.notoSansJp(
                                fontSize: 10,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // 頻度タグ
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        freqLabel,
                        style: GoogleFonts.notoSansJp(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF242428) : Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'ヒーロータスクが未登録です。下の入力欄から予定を追加できます。',
              style: GoogleFonts.notoSansJp(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ),
        ],

        const SizedBox(height: 12),

        // クイック予定追加入力欄
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: _quickTaskController,
                  style: GoogleFonts.notoSansJp(
                    fontSize: 12.5,
                    color: isDark ? Colors.white : AppColors.pureBlack,
                  ),
                  decoration: InputDecoration(
                    hintText: '予定を個別入力 (例: ジム 60分)',
                    hintStyle: GoogleFonts.notoSansJp(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF242428) : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppColors.accentGold),
                    ),
                  ),
                  onSubmitted: (_) => _addQuickTask(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 40,
              child: ElevatedButton.icon(
                onPressed: _addQuickTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGold,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(
                  '追加',
                  style: GoogleFonts.notoSansJp(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),

        // この日に予定されているアイテムのタグ一覧（個別削除可能）
        if (scheduledList.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            '予約中のタスク (${scheduledList.length}件):',
            style: GoogleFonts.notoSansJp(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: scheduledList.map((item) {
              final title = _resolveTaskTitle(item);
              final isItemCompleted = datePosts.any((p) =>
                  (p.taskId != null && p.taskId == item) ||
                  p.taskName == title ||
                  p.taskName == item) ||
                  (isToday && widget.user.tasks.any((t) => (t.id == item || t.title == item) && t.isCompletedToday));
              return Container(
                padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.accentGold, width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.notoSansJp(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.pureBlack,
                      ),
                    ),
                    if (isItemCompleted) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10825B).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '達成済 ✨',
                          style: GoogleFonts.notoSansJp(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _removeScheduledItem(item),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          Icons.cancel_rounded,
                          size: 14,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
