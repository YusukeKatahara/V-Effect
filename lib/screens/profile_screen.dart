import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import '../config/app_colors.dart';
import '../models/app_user.dart';
import '../models/app_task.dart';
import '../models/post.dart';
import '../services/user_service.dart';
import '../services/post_service.dart';
import '../widgets/v_effect_header.dart';
import '../widgets/season_hint_modal.dart';
import '../models/season.dart';
import '../widgets/v_badge_widget.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/push_notification_service.dart';
import 'qr_display_screen.dart';
import 'qr_scanner_screen.dart';
import '../widgets/responsive_container.dart';
import '../widgets/full_screen_image_viewer.dart';
import 'past_comparison_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserService _userService = UserService.instance;
  final PostService _postService = PostService.instance;
  final _db = FirebaseFirestore.instance;
  late final String _uid;
  bool _loading = true;
  AppUser? _user;
  List<Post> _todayPosts = [];
  Map<String, dynamic> _privateData = {};
  Map<String, Season> _seasonsMap = {};
  Map<String, int> _seasonPostsCountMap = {};
  Stream<DocumentSnapshot>? _userStream;
  List<Map<String, dynamic>> _trendingTasks = [];

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser!.uid;
    _userStream = _db.collection('users').doc(_uid).snapshots();
    _loadPrivateData();
    _loadTrendingTasks();
  }

  Future<void> _loadTrendingTasks() async {
    try {
      final doc = await _db.collection('global_stats').doc('trends').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data.containsKey('trends') && data['trends'] is List) {
          if (mounted) {
            setState(() {
              _trendingTasks = (data['trends'] as List)
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList();
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading trending tasks: $e');
    }
  }

  Future<void> _loadPrivateData() async {
    final privateSnap =
        await _db
            .collection('users')
            .doc(_uid)
            .collection('private')
            .doc('data')
            .get();
    if (!mounted) return;
    setState(() {
      _privateData =
          privateSnap.exists ? privateSnap.data() as Map<String, dynamic> : {};
      _loading = false;
    });
  }

  Future<void> _loadProfile() async {
    final uid = _userService.currentUid;
    if (uid == null) return;
    try {
      // 非公開情報の再ロード
      await _loadPrivateData();

      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        final user = AppUser.fromFirestore(doc);
        // ワンタイムタスクの期限切れチェックと削除
        await _checkAndCleanupOneTimeTasks(user);

        // シーズン情報の取得
        final seasonIds = user.tasks.where((t) => t.isSeason && t.seasonId != null).map((t) => t.seasonId!).toSet().toList();
        final Map<String, Season> newSeasonsMap = {};
        final Map<String, int> newSeasonPostsCountMap = {};
        if (seasonIds.isNotEmpty) {
          final seasonsSnap = await FirebaseFirestore.instance.collection('seasons').where(FieldPath.documentId, whereIn: seasonIds).get();
          for (var doc in seasonsSnap.docs) {
            final season = Season.fromFirestore(doc);
            newSeasonsMap[doc.id] = season;
            
            // シーズンタスクごとの投稿数をカウント（該当タスク名の全投稿を取得して期間内を集計）
            try {
              final postsSnap = await FirebaseFirestore.instance
                  .collection('posts')
                  .where('userId', isEqualTo: uid)
                  .where('taskName', isEqualTo: season.taskName)
                  .get();
              
              int count = 0;
              final Map<String, int> dailyPostCounts = {};
              for (var postDoc in postsSnap.docs) {
                final createdAt = (postDoc.data()['createdAt'] as Timestamp?)?.toDate();
                if (createdAt != null &&
                    createdAt.isAfter(season.startDate) &&
                    createdAt.isBefore(season.endDate)) {
                  final dateKey = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
                  final currentDailyCount = dailyPostCounts[dateKey] ?? 0;
                  if (currentDailyCount < 1) {
                    count++;
                    dailyPostCounts[dateKey] = currentDailyCount + 1;
                  }
                }
              }
              newSeasonPostsCountMap[doc.id] = count;
            } catch (e) {
              debugPrint('Error counting season posts: $e');
              newSeasonPostsCountMap[doc.id] = 0;
            }
          }
        }

        // 今日の投稿を取得
        final todayPosts = await _postService.getFriendPostsList(uid);

        // 再ロード（削除された可能性があるため）
        final freshDoc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (mounted) {
          setState(() {
            _user = AppUser.fromFirestore(freshDoc);
            _todayPosts = todayPosts;
            _seasonsMap = newSeasonsMap;
            _seasonPostsCountMap = newSeasonPostsCountMap;
            _loading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 完了日が昨日以前のワンタイムタスクを自動削除する
  Future<void> _checkAndCleanupOneTimeTasks(AppUser user) async {
    await _userService.cleanupExpiredTasks(user);
  }

  // ---── 時刻設定の変更 ──
  Future<void> _selectTime(BuildContext context) async {
    final initialTimeStr = _privateData['taskTime'] ?? '08:00';
    final parts = initialTimeStr.split(':');
    final now = DateTime.now();
    DateTime tempDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );

    await showCupertinoModalPopup(
      context: context,
      builder:
          (modalContext) => Container(
            height: 300,
            padding: const EdgeInsets.only(top: 6.0),
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            color: AppColors.bgElevated,
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  // ---ツールバー（完了ボタン）
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.white.withValues(alpha: 0.1),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CupertinoButton(
                          child: Text(
                            AppLocalizations.of(context)!.profileSetupPickerCancel,
                            style: const TextStyle(color: AppColors.grey50),
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        CupertinoButton(
                          child: Text(
                            AppLocalizations.of(context)!.profileSetupPickerDone,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () async {
                            final timeStr =
                                '${tempDateTime.hour.toString().padLeft(2, '0')}:${tempDateTime.minute.toString().padLeft(2, '0')}';

                            // 先にモーダルを閉じて blackout を防ぐ
                            Navigator.pop(context);

                            try {
                              await _userService.updateProfile(
                                taskTime: timeStr,
                              );

                              // taskTime が変更された場合、V Alert を即座に再スケジュール
                              PushNotificationService()
                                  .scheduleVAlert(timeStr)
                                  .catchError(
                                    (e) => debugPrint(
                                      'V Alert schedule error: $e',
                                    ),
                                  );

                              if (mounted) {
                                _loadProfile();
                              }
                            } catch (e) {
                              debugPrint('Error updating taskTime: $e');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(AppLocalizations.of(context)!.profileScreenTimeUpdateFailed)),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  // ---ピッカー本体
                  Expanded(
                    child: CupertinoTheme(
                      data: const CupertinoThemeData(
                        brightness: Brightness.dark,
                        textTheme: CupertinoTextThemeData(
                          dateTimePickerTextStyle: TextStyle(
                            color: AppColors.white,
                            fontSize: 22,
                          ),
                        ),
                      ),
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.time,
                        use24hFormat: true,
                        initialDateTime: tempDateTime,
                        onDateTimeChanged: (DateTime newDate) {
                          tempDateTime = newDate;
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showTrendingTasksBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // DraggableScrollableSheet用に透明化
      isScrollControlled: true,
      builder: (ctx) {
        final int totalCount = _trendingTasks.fold(0, (acc, t) => acc + ((t['count'] as num?)?.toInt() ?? 0));

        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    Text(
                      AppLocalizations.of(context)!.profileScreenTrendTitle,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_trendingTasks.isEmpty)
                      Text(AppLocalizations.of(context)!.profileScreenTrendEmpty, style: const TextStyle(color: AppColors.grey70))
                    else
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          itemCount: _trendingTasks.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final trend = _trendingTasks[index];
                            final name = trend['name'] as String? ?? '';
                            final count = (trend['count'] as num?)?.toInt() ?? 0;
                            if (name.isEmpty) return const SizedBox.shrink();

                            final percentage = totalCount > 0 ? (count / totalCount * 100).toStringAsFixed(1) : '0.0';

                            return InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                Navigator.of(ctx).pop();
                                _addTask(initialTitle: name);
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
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          color: AppColors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '$percentage%',
                                      style: const TextStyle(
                                        color: AppColors.accentGold,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
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

  // ---── ヒーロータスクの追加 ──
  Future<void> _addTask({String? initialTitle}) async {
    final controller = TextEditingController(text: initialTitle);
    final triggerController = TextEditingController();
    final rewardController = TextEditingController();
    bool isOneTime = false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (context, setModalState) => AlertDialog(
                  backgroundColor: AppColors.bgElevated,
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.profileScreenAddTask,
                        style: const TextStyle(color: AppColors.white),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.lightbulb_outline,
                          color: AppColors.accentGold,
                          size: 20,
                        ),
                        onPressed: () => _showHabitTipsDialog(context),
                      ),
                    ],
                  ),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: triggerController,
                          style: const TextStyle(color: AppColors.white),
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.profileScreenTaskTriggerHint,
                            hintStyle: const TextStyle(color: AppColors.grey30),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: controller,
                          autofocus: true,
                          style: const TextStyle(color: AppColors.white),
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.profileScreenTaskNameHint,
                            hintStyle: const TextStyle(color: AppColors.grey30),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: rewardController,
                          style: const TextStyle(color: AppColors.white),
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.profileScreenTaskRewardHint,
                            hintStyle: const TextStyle(color: AppColors.grey30),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildHabitPreviewForDialog(triggerController, controller, rewardController),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text(
                            'One-Time Task',
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            AppLocalizations.of(context)!.profileScreenOneTimeTaskTitle,
                            style: TextStyle(
                              color: AppColors.grey50,
                              fontSize: 11,
                            ),
                          ),
                          value: isOneTime,
                          activeColor: AppColors.accentGold,
                          onChanged: (val) {
                            setModalState(() => isOneTime = val);
                          },
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        AppLocalizations.of(context)!.editProfileCancel,
                        style: const TextStyle(color: AppColors.grey50),
                      ),
                    ),
                    TextButton(
                      onPressed:
                          () => Navigator.pop(ctx, {
                            'title': controller.text,
                            'trigger': triggerController.text,
                            'reward': rewardController.text,
                            'isOneTime': isOneTime,
                          }),
                      child: Text(
                        AppLocalizations.of(context)!.profileScreenAddTask,
                        style: const TextStyle(color: AppColors.white),
                      ),
                    ),
                  ],
                ),
          ),
    );

    if (result != null && result['title'].toString().trim().isNotEmpty) {
      final updatedTasks = List<AppTask>.from(_user!.tasks)..add(
        AppTask(
          title: result['title'].toString().trim(),
          trigger: result['trigger']?.toString().trim().isEmpty == true ? null : result['trigger']?.toString().trim(),
          reward: result['reward']?.toString().trim().isEmpty == true ? null : result['reward']?.toString().trim(),
          isOneTime: result['isOneTime'] as bool,
        ),
      );
      await _userService.updateProfile(tasks: updatedTasks);
      _loadProfile();
    }
  }

  // ---── ヒーロータスクの編集 ──
  Future<void> _editTask(int index) async {
    final task = _user!.tasks[index];
    final controller = TextEditingController(text: task.title);
    final triggerController = TextEditingController(text: task.trigger);
    final rewardController = TextEditingController(text: task.reward);
    bool isOneTime = task.isOneTime;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (context, setModalState) => AlertDialog(
                  backgroundColor: AppColors.bgElevated,
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.profileScreenEditTask,
                        style: const TextStyle(color: AppColors.white),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.lightbulb_outline,
                          color: AppColors.accentGold,
                          size: 20,
                        ),
                        onPressed: () => _showHabitTipsDialog(context),
                      ),
                    ],
                  ),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: triggerController,
                            style: const TextStyle(color: AppColors.white),
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(context)!.profileScreenTaskTriggerHint,
                              hintStyle: const TextStyle(color: AppColors.grey30),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: controller,
                            autofocus: true,
                            style: const TextStyle(color: AppColors.white),
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(context)!.profileScreenTaskNameHint,
                              hintStyle: const TextStyle(color: AppColors.grey30),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: rewardController,
                            style: const TextStyle(color: AppColors.white),
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(context)!.profileScreenTaskRewardHint,
                              hintStyle: const TextStyle(color: AppColors.grey30),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildHabitPreviewForDialog(triggerController, controller, rewardController),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            title: const Text(
                              'One-Time Task',
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              AppLocalizations.of(context)!.profileScreenOneTimeTaskTitle,
                              style: TextStyle(
                                color: AppColors.grey50,
                                fontSize: 11,
                              ),
                            ),
                            value: isOneTime,
                            activeColor: AppColors.accentGold,
                            onChanged: (val) {
                              setModalState(() => isOneTime = val);
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        AppLocalizations.of(context)!.editProfileCancel,
                        style: const TextStyle(color: AppColors.grey50),
                      ),
                    ),
                    TextButton(
                      onPressed:
                          () => Navigator.pop(ctx, {
                            'title': controller.text,
                            'trigger': triggerController.text,
                            'reward': rewardController.text,
                            'isOneTime': isOneTime,
                          }),
                      child: Text(
                        AppLocalizations.of(context)!.profileScreenSaveTask,
                        style: const TextStyle(color: AppColors.white),
                      ),
                    ),
                  ],
                ),
          ),
    );

    if (result != null && result['title'].toString().trim().isNotEmpty) {
      final oldTitle = task.title;
      final newTitle = result['title'].toString().trim();
      
      final updatedTasks = List<AppTask>.from(_user!.tasks);
      final newTrigger = result['trigger']?.toString().trim().isEmpty == true ? null : result['trigger']?.toString().trim();
      final newReward = result['reward']?.toString().trim().isEmpty == true ? null : result['reward']?.toString().trim();
      updatedTasks[index] = task.copyWith(
        title: newTitle,
        trigger: newTrigger,
        clearTrigger: newTrigger == null,
        reward: newReward,
        clearReward: newReward == null,
        isOneTime: result['isOneTime'] as bool,
      );
      await _userService.updateProfile(tasks: updatedTasks);
      
      if (oldTitle != newTitle) {
        await _postService.updateTaskNameForPosts(oldTitle, newTitle);
      }
      
      _loadProfile();
    }
  }

  // ---── 習慣化のコツをポップアップ表示 ──
  void _showHabitTipsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppColors.bgElevated,
            title: Row(
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  color: AppColors.accentGold,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.profileScreenHabitTipsTitle,
                  style: GoogleFonts.notoSansJp(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentGold,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.habitStackingHint,
                  style: GoogleFonts.notoSansJp(
                    fontSize: 13,
                    color: AppColors.grey50,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context)!.temptationBundlingHint,
                  style: GoogleFonts.notoSansJp(
                    fontSize: 13,
                    color: AppColors.grey50,
                    height: 1.5,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  AppLocalizations.of(context)!.profileScreenHabitTipsClose,
                  style: const TextStyle(color: AppColors.white),
                ),
              ),
            ],
          ),
    );
  }

  // ---── ヒーロータスクの削除 ──
  Future<void> _deleteTask(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppColors.bgElevated,
            title: Text(
              AppLocalizations.of(context)!.profileScreenDeleteTaskTitle,
              style: const TextStyle(color: AppColors.white),
            ),
            content: Text(AppLocalizations.of(context)!.profileScreenDeleteTaskMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  AppLocalizations.of(context)!.profileScreenDeleteTaskCancel,
                  style: const TextStyle(color: AppColors.grey50),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  AppLocalizations.of(context)!.profileScreenDeleteTaskButton,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      final updatedTasks = List<AppTask>.from(_user!.tasks)..removeAt(index);
      if (updatedTasks.length != _user!.tasks.length) {
        await _userService.updateProfile(tasks: updatedTasks);
        _loadProfile();
      }
    }
  }

  Widget _buildHabitPreviewForDialog(
    TextEditingController triggerCtrl,
    TextEditingController taskCtrl,
    TextEditingController rewardCtrl,
  ) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: taskCtrl,
      builder: (context, taskVal, _) {
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: triggerCtrl,
          builder: (context, triggerVal, _) {
            return ValueListenableBuilder<TextEditingValue>(
              valueListenable: rewardCtrl,
              builder: (context, rewardVal, _) {
                final hasTrigger = triggerVal.text.trim().isNotEmpty;
                final hasQuest = taskVal.text.trim().isNotEmpty;
                final hasReward = rewardVal.text.trim().isNotEmpty;

                if (!hasTrigger && !hasQuest && !hasReward) {
                  return const SizedBox.shrink();
                }

                return Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.grey10,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (hasTrigger) ...[
                        Text(
                          triggerVal.text.trim(),
                          style: GoogleFonts.notoSansJp(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accentGold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        const Icon(
                          Icons.arrow_downward_rounded,
                          size: 14,
                          color: AppColors.grey50,
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        hasQuest ? taskVal.text.trim() : AppLocalizations.of(context)!.profileNoTaskPlaceholder,
                        style: GoogleFonts.notoSerifJp(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: hasQuest ? AppColors.white : AppColors.grey50,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (hasReward) ...[
                        const SizedBox(height: 6),
                        const Icon(
                          Icons.arrow_downward_rounded,
                          size: 14,
                          color: AppColors.grey50,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          rewardVal.text.trim(),
                          style: GoogleFonts.notoSansJp(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accentGold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                child: StreamBuilder<DocumentSnapshot>(
                  stream: _userStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.exists) {
                      _user = AppUser.fromFirestore(snapshot.data!);
                    }
                    if (_user == null) return _buildEmptyState();
                    return _buildContent();
                  },
                ),
              ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        AppLocalizations.of(context)!.profileScreenProfileNotFound,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        _buildTitleBar(),
        Expanded(
          child: ResponsiveContainer(
            maxWidth: 600, // Profile can be slightly wider
            child: RefreshIndicator(
              onRefresh: _loadProfile,
              color: AppColors.primary,
              backgroundColor: AppColors.bgSurface,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildProfileHeader()),
  
                  // ---── スケジュール設定 ─────────────────────────────
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverToBoxAdapter(child: _buildScheduleSection()),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
  
                  // ---── 過去の軌跡を振り返るボタン ──────────────────────────
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverToBoxAdapter(
                      child: GestureDetector(
                        onTap: () {
                          if (_user == null) return;
                          final taskNames = _user!.tasks.map((t) => t.title).toList();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PastComparisonScreen(userTaskNames: taskNames),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: AppColors.bgElevated,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.accentGold.withOpacity(0.3), width: 1),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // より柔らかい表現にするため、ひらがな表記の「積み重ねを振りかえる」にしました
                              Text(
                                AppLocalizations.of(context)!.profileScreenReviewButton,
                                style: GoogleFonts.notoSansJp(
                                  color: AppColors.accentGold,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),

                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverToBoxAdapter(child: _buildTaskSection()),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTitleBar() {
    return VEffectHeader(
      leading: IconButton(
        icon: const Icon(Icons.edit_outlined, color: AppColors.white, size: 22),
        onPressed: () async {
          if (_user == null) return;
          final didUpdate = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => EditProfileScreen(
                user: _user!,
                privateData: _privateData,
              ),
            ),
          );
          if (didUpdate == true) {
            _loadProfile();
          }
        },
      ),
      trailing: IconButton(
        icon: const Icon(Icons.settings_outlined, color: AppColors.white, size: 22),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          );
        },
      ),
    );
  }

  void _showQrActionDialog() {
    if (_user == null) return;
    showDialog(
      context: context,
      builder:
          (ctx) => SimpleDialog(
            backgroundColor: AppColors.bgSurface,
            title: Text(
              AppLocalizations.of(context)!.profileScreenQrTitle,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            children: [
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QrDisplayScreen(user: _user!),
                    ),
                  );
                },
                child: Text(
                  AppLocalizations.of(context)!.profileScreenQrDisplay,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                ),
              ),
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QrScannerScreen()),
                  );
                },
                child: Text(
                  AppLocalizations.of(context)!.profileScreenQrScan,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                ),
              ),
            ],
          ),
    );
  }


  // ---プロフィールヘッダー
  // ---
  Widget _buildProfileHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient:
                      _user!.photoUrl == null
                          ? AppColors.primaryGradient
                          : null,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.white.withValues(alpha: 0.1),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child:
                    _user!.photoUrl != null
                        ? GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  opaque: false,
                                  barrierColor: Colors.black.withValues(alpha: 0.9),
                                  pageBuilder: (context, _, __) => FullScreenImageViewer(
                                    imageUrl: _user!.photoUrl!,
                                    heroTag: 'profile_image_${_user!.uid}',
                                  ),
                                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                    return FadeTransition(opacity: animation, child: child);
                                  },
                                ),
                              );
                            },
                            child: Hero(
                              tag: 'profile_image_${_user!.uid}',
                              child: CircleAvatar(
                                radius: 40,
                                backgroundImage: ResizeImage(
                                  CachedNetworkImageProvider(_user!.photoUrl!),
                                  width: 240,
                                ),
                              ),
                            ),
                          )
                        : const CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.transparent,
                          child: Icon(
                            Icons.person_rounded,
                            size: 40,
                            color: AppColors.black,
                          ),
                        ),

              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _user!.username ?? '',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_user!.equippedBadgeUrl != null && _user!.equippedBadgeUrl!.isNotEmpty) ...[
                          VBadgeWidget(
                            imageUrl: _user!.equippedBadgeUrl,
                            animationType: _user!.equippedBadgeAnimation ?? 'none',
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (_user!.instagramId != null && _user!.instagramId!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () async {
                              final instagramId = _user!.instagramId!;
                              final appUri = Uri.parse('instagram://user?username=$instagramId');
                              final webUri = Uri.parse('https://instagram.com/$instagramId');
                              try {
                                if (await canLaunchUrl(appUri)) {
                                  await launchUrl(appUri);
                                } else {
                                  await launchUrl(webUri, mode: LaunchMode.externalApplication);
                                }
                              } catch (e) {
                                debugPrint('Could not launch instagram: $e');
                              }
                            },
                            child: const FaIcon(
                              FontAwesomeIcons.instagram,
                              color: AppColors.white,
                              size: 22,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${_user!.userId ?? ''}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.grey15.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.white.withValues(alpha: 0.08),
                    width: 0.5,
                  ),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.qr_code,
                    color: AppColors.textPrimary,
                    size: 26,
                  ),
                  tooltip: AppLocalizations.of(context)!.profileScreenQrTooltip,
                  onPressed: _showQrActionDialog,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 18,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.grey15.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.white.withValues(alpha: 0.08),
                      width: 0.5,
                    ),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildFollowStat(
                            AppLocalizations.of(context)!.profileScreenFollowing,
                            _user!.following.length,
                            onTap:
                                () => Navigator.pushNamed(
                                  context,
                                  '/follow-list',
                                  arguments: {
                                    'uid': _uid,
                                    'isFollowing': true,
                                    'title': AppLocalizations.of(context)!.profileScreenFollowingTitle,
                                  },
                                ),
                          ),
                        ),
                        VerticalDivider(
                          color: AppColors.white.withValues(alpha: 0.1),
                          thickness: 1,
                          width: 1,
                        ),
                        Expanded(
                          child: _buildFollowStat(
                            AppLocalizations.of(context)!.profileScreenFollowers,
                            _user!.followers.length,
                            onTap:
                                () => Navigator.pushNamed(
                                  context,
                                  '/follow-list',
                                  arguments: {
                                    'uid': _uid,
                                    'isFollowing': false,
                                    'title': AppLocalizations.of(context)!.profileScreenFollowersTitle,
                                  },
                                ),
                          ),
                        ),
                        VerticalDivider(
                          color: AppColors.white.withValues(alpha: 0.1),
                          thickness: 1,
                          width: 1,
                        ),
                        Expanded(
                          child: _buildFollowStat(
                            AppLocalizations.of(context)!.profileScreenStreak,
                            _user!.streak,
                            icon: Icons.local_fire_department_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFollowStat(
    String label,
    int count, {
    IconData? icon,
    VoidCallback? onTap,
  }) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: AppColors.accentGold),
              const SizedBox(width: 4),
            ],
            Text(
              '$count',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color:
                    icon != null ? AppColors.accentGold : AppColors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.notoSansJp(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: content,
        ),
      );
    }
    return content;
  }

  // ---
  // ---スケジュール設定（直接変更可能）
  // ---
  Widget _buildScheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _EditableInfoRow(
                icon: Icons.schedule_rounded,
                label: 'V Alert',
                value: _privateData['taskTime'] ?? '08:00',
                onTap: () => _selectTime(context),
                isFirst: true,
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---
  // ---ヒーロータスクセクション（追加・削除可能）
  // ---
  Widget _buildTaskSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SectionTitle(title: AppLocalizations.of(context)!.profileScreenHeroTasks),
            TextButton(
              onPressed: _showTrendingTasksBottomSheet,
              child: Text(
                AppLocalizations.of(context)!.profileScreenWeeklyTrend,
                style: const TextStyle(color: AppColors.accentGold, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_user!.tasks.isEmpty)
          _buildEmptyTaskCard()
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
                onReorder: (int oldIndex, int newIndex) async {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  final updatedTasks = List<AppTask>.from(_user!.tasks);
                  final task = updatedTasks.removeAt(oldIndex);
                  updatedTasks.insert(newIndex, task);
                  
                  setState(() {
                    _user!.tasks.clear();
                    _user!.tasks.addAll(updatedTasks);
                  });
                  
                  await _userService.updateProfile(tasks: updatedTasks);
                  _loadProfile();
                },
                itemCount: _user!.tasks.length,
                itemBuilder: (context, index) {
                  return _buildQuestCard(index, key: ObjectKey(_user!.tasks[index]));
                },
              ),
              _buildAddTaskSlot(),
            ],
          ),
      ],
    );
  }

  Widget _buildEmptyTaskCard() {
    return InkWell(
      onTap: _addTask,
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

  Widget _buildAddTaskSlot() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: InkWell(
        onTap: _addTask,
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

  Widget _buildQuestCard(int index, {Key? key}) {
    final task = _user!.tasks[index];
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 8), // よりコンパクトに
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16), // 少し収まりの良い角丸に
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.grey15, AppColors.grey10],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.4), // 少し影を深めて奥行きを
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: AppColors.white.withValues(alpha: 0.08), // 高級感のある細い境界線
            width: 0.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (task.isSeason) {
                final season = _seasonsMap[task.seasonId];
                if (season != null) {
                  SeasonHintModal.show(context, task, season, (newTrigger) async {
                    final updatedTasks = List<AppTask>.from(_user!.tasks);
                    updatedTasks[index] = task.copyWith(
                      trigger: newTrigger.isEmpty ? null : newTrigger,
                      clearTrigger: newTrigger.isEmpty,
                    );
                    await _userService.updateProfile(tasks: updatedTasks);
                    _loadProfile();
                  });
                }
              } else {
                _editTask(index);
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ), // コンパクトなパディング
              child: Row(
                children: [
                  Container(
                    width: 26, // サイズ縮小
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.white.withValues(alpha: 0.05), // 主張を抑える
                      border: Border.all(
                        color: AppColors.white.withValues(alpha: 0.08),
                        width: 0.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontSize: 12, // 文字サイズ調整
                          fontWeight: FontWeight.w700, // ボールド感は維持
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          task.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (task.isSeason) ...[
                          const SizedBox(height: 2),
                          (() {
                            final season = _seasonsMap[task.seasonId];
                            final count = _seasonPostsCountMap[task.seasonId] ?? 0;
                            final requiredCount = season?.requiredPostsCount ?? 12;
                            return Text(
                              'Season ($count/$requiredCount)',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.grey50, // メタリックシルバー風
                                letterSpacing: 0.5,
                              ),
                            );
                          })(),
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
                  if (!task.isSeason)
                    IconButton(
                      onPressed: () => _deleteTask(index),
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
}

// ---────────────────────────────────────────────
// ---直接編集可能な情報行
// ---────────────────────────────────────────────
class _EditableInfoRow extends StatelessWidget {
  const _EditableInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.isFirst = false,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(16) : Radius.zero,
        bottom: isLast ? const Radius.circular(16) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textMuted),
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 18,
                color: AppColors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---────────────────────────────────────────────
// ---セクションタイトル
// ---────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.accentGold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
