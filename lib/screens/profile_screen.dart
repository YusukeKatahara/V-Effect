import 'package:flutter/material.dart';
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
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/push_notification_service.dart';
import 'qr_display_screen.dart';
import 'qr_scanner_screen.dart';
import '../widgets/responsive_container.dart';
import 'past_comparison_screen.dart';

// ---── コンポーネントのインポート ──
import 'profile/components/editable_info_row.dart';
import 'profile/components/profile_header_section.dart';
import 'profile/components/task_section.dart';
import 'profile/components/trending_tasks_bottom_sheet.dart';


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
    _loadProfile();
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

        // シーズン情報とカウントの取得
        final seasonTasks = user.tasks.where((t) => t.isSeason).toList();
        final progressData = await _postService.getSeasonProgressMap(uid, seasonTasks);
        final Map<String, Season> newSeasonsMap = Map<String, Season>.from(progressData['seasonsMap'] ?? {});
        final Map<String, int> newSeasonPostsCountMap = Map<String, int>.from(progressData['seasonPostsCountMap'] ?? {});

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

  // ---── ヒーロータスクの追加 ──
  Future<void> _addTask({String? initialTitle}) async {
    final controller = TextEditingController(text: initialTitle);
    final triggerController = TextEditingController();
    final rewardController = TextEditingController();
    bool isOneTime = false;

    // AlertDialogからshowModalBottomSheetに変更し、キーボードの真上にせり上がるように設定
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true, // コンテンツサイズに応じて高さを調整可能にする
      backgroundColor: Colors.transparent, // 角丸のコンテナを綺麗に表現するため背景は透明に設定
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (context, setModalState) => Container(
                  decoration: const BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)), // 上部の角丸デザイン
                  ),
                  padding: EdgeInsets.only(
                    top: 16,
                    left: 16,
                    right: 16,
                    // MediaQueryを使用してキーボードの高さ分（viewInsets.bottom）だけ下部に余白を追加し、上に押し上げる
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- タイトルとヒントボタン ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.profileScreenAddTask,
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.lightbulb_outline,
                                color: AppColors.accentGold,
                                size: 18,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _showHabitTipsDialog(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // --- トリガー入力欄（習慣化のきっかけとなる行動、例：ワークアウト後） ---
                        TextField(
                          controller: triggerController,
                          style: const TextStyle(color: AppColors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.profileScreenTaskTriggerHint,
                            hintStyle: const TextStyle(color: AppColors.grey30, fontSize: 14),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // --- タスク名入力欄 ---
                        TextField(
                          controller: controller,
                          autofocus: true,
                          style: const TextStyle(color: AppColors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.profileScreenTaskNameHint,
                            hintStyle: const TextStyle(color: AppColors.grey30, fontSize: 14),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // --- ご褒美入力欄（任意） ---
                        TextField(
                          controller: rewardController,
                          style: const TextStyle(color: AppColors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.profileScreenTaskRewardHint,
                            hintStyle: const TextStyle(color: AppColors.grey30, fontSize: 14),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // --- リアルタイム組み立てプレビュー ---
                        _buildHabitPreviewForDialog(triggerController, controller, rewardController),
                        const SizedBox(height: 8),
                        // --- 単発タスク切り替えスイッチ ---
                        SwitchListTile(
                          visualDensity: VisualDensity.compact,
                          title: const Text(
                            'One-Time Task',
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            AppLocalizations.of(context)!.profileScreenOneTimeTaskTitle,
                            style: TextStyle(
                              color: AppColors.grey50,
                              fontSize: 10,
                            ),
                          ),
                          value: isOneTime,
                          activeColor: AppColors.accentGold,
                          onChanged: (val) {
                            setModalState(() => isOneTime = val);
                          },
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 12),
                        // --- 操作ボタン（キャンセル・追加） ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(
                                AppLocalizations.of(context)!.editProfileCancel,
                                style: const TextStyle(color: AppColors.grey50),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, {
                                'title': controller.text,
                                'trigger': triggerController.text,
                                'reward': rewardController.text,
                                'isOneTime': isOneTime,
                              }),
                              child: Text(
                                AppLocalizations.of(context)!.profileScreenAddTask,
                                style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );

    if (result != null && result['title'].toString().trim().isNotEmpty) {
      final rawTitle = result['title'].toString().trim();
      // デバッグ・テスト用：タイトルが [SEASON] で始まる場合はシーズンタスクとして登録する
      final isDebugSeason = rawTitle.toUpperCase().startsWith('[SEASON]');
      final title = isDebugSeason ? rawTitle.substring('[SEASON]'.length).trim() : rawTitle;

      final newTask = AppTask(
        title: title.isEmpty ? 'Test Season Task' : title,
        trigger: result['trigger']?.toString().trim().isEmpty == true ? null : result['trigger']?.toString().trim(),
        reward: result['reward']?.toString().trim().isEmpty == true ? null : result['reward']?.toString().trim(),
        isOneTime: result['isOneTime'] as bool,
        isSeason: isDebugSeason,
        seasonId: isDebugSeason ? 'debug_season_test' : null,
      );

      final updatedTasks = List<AppTask>.from(_user!.tasks);
      if (isDebugSeason) {
        updatedTasks.insert(0, newTask);
      } else {
        updatedTasks.add(newTask);
      }
      
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

    // AlertDialogからshowModalBottomSheetに変更し、キーボードの真上にせり上がるように設定
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true, // コンテンツサイズに応じて高さを調整可能にする
      backgroundColor: Colors.transparent, // 角丸のコンテナを綺麗に表現するため背景は透明に設定
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (context, setModalState) => Container(
                  decoration: const BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)), // 上部の角丸デザイン
                  ),
                  padding: EdgeInsets.only(
                    top: 16,
                    left: 16,
                    right: 16,
                    // MediaQueryを使用してキーボードの高さ分（viewInsets.bottom）だけ下部に余白を追加し、上に押し上げる
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- タイトルとヒントボタン ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.profileScreenEditTask,
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.lightbulb_outline,
                                color: AppColors.accentGold,
                                size: 18,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _showHabitTipsDialog(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // --- トリガー入力欄（習慣化のきっかけとなる行動、例：ワークアウト後） ---
                        TextField(
                          controller: triggerController,
                          style: const TextStyle(color: AppColors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.profileScreenTaskTriggerHint,
                            hintStyle: const TextStyle(color: AppColors.grey30, fontSize: 14),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // --- タスク名入力欄 ---
                        TextField(
                          controller: controller,
                          autofocus: true,
                          style: const TextStyle(color: AppColors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.profileScreenTaskNameHint,
                            hintStyle: const TextStyle(color: AppColors.grey30, fontSize: 14),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // --- ご褒美入力欄（任意） ---
                        TextField(
                          controller: rewardController,
                          style: const TextStyle(color: AppColors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.profileScreenTaskRewardHint,
                            hintStyle: const TextStyle(color: AppColors.grey30, fontSize: 14),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // --- リアルタイム組み立てプレビュー ---
                        _buildHabitPreviewForDialog(triggerController, controller, rewardController),
                        const SizedBox(height: 8),
                        // --- 単発タスク切り替えスイッチ ---
                        SwitchListTile(
                          visualDensity: VisualDensity.compact,
                          title: const Text(
                            'One-Time Task',
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            AppLocalizations.of(context)!.profileScreenOneTimeTaskTitle,
                            style: TextStyle(
                              color: AppColors.grey50,
                              fontSize: 10,
                            ),
                          ),
                          value: isOneTime,
                          activeColor: AppColors.accentGold,
                          onChanged: (val) {
                            setModalState(() => isOneTime = val);
                          },
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 12),
                        // --- 操作ボタン（キャンセル・保存） ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(
                                AppLocalizations.of(context)!.editProfileCancel,
                                style: const TextStyle(color: AppColors.grey50),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, {
                                'title': controller.text,
                                'trigger': triggerController.text,
                                'reward': rewardController.text,
                                'isOneTime': isOneTime,
                              }),
                              child: Text(
                                AppLocalizations.of(context)!.profileScreenSaveTask,
                                style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
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

                // 余白やフォントサイズを極限まで縮小し、スクロールを減らすようにレイアウトを最適化
                return Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accentGold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        const Icon(
                          Icons.arrow_downward_rounded,
                          size: 10,
                          color: AppColors.grey50,
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        hasQuest ? taskVal.text.trim() : AppLocalizations.of(context)!.profileNoTaskPlaceholder,
                        style: GoogleFonts.notoSerifJp(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: hasQuest ? AppColors.white : AppColors.grey50,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (hasReward) ...[
                        const SizedBox(height: 2),
                        const Icon(
                          Icons.arrow_downward_rounded,
                          size: 10,
                          color: AppColors.grey50,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          rewardVal.text.trim(),
                          style: GoogleFonts.notoSansJp(
                            fontSize: 11,
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
                  // ---── プロフィールヘッダー ──
                  SliverToBoxAdapter(
                    child: ProfileHeaderSection(
                      user: _user!,
                      uid: _uid,
                      onQrPressed: _showQrActionDialog,
                    ),
                  ),
  
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

                  // ---── ヒーロータスクセクション ──
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverToBoxAdapter(
                      child: TaskSection(
                        user: _user!,
                        seasonsMap: _seasonsMap,
                        seasonPostsCountMap: _seasonPostsCountMap,
                        onAddTask: _addTask,
                        onEditTask: _editTask,
                        onDeleteTask: _deleteTask,
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
                        onShowTrendingTasks: () {
                          showTrendingTasksBottomSheet(
                            context,
                            trendingTasks: _trendingTasks,
                            onAddTask: _addTask,
                          );
                        },
                        onSeasonTaskTap: (int index) {
                          final task = _user!.tasks[index];
                          final season = _seasonsMap[task.seasonId] ?? _seasonsMap['debug_season'] ?? _seasonsMap['debug_season_test'] ?? Season.createFallback(
                            task.title,
                            seasonId: task.seasonId,
                          );
                          
                          SeasonHintModal.show(context, task, season, (newTrigger, newReward) async {
                            final updatedTasks = List<AppTask>.from(_user!.tasks);
                            updatedTasks[index] = task.copyWith(
                              trigger: newTrigger.isEmpty ? null : newTrigger,
                              clearTrigger: newTrigger.isEmpty,
                              reward: newReward.isEmpty ? null : newReward,
                              clearReward: newReward.isEmpty,
                            );
                            await _userService.updateProfile(tasks: updatedTasks);
                            _loadProfile();
                          });
                        },
                      ),
                    ),
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
              EditableInfoRow(
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
}
