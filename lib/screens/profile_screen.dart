import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui' as ui;
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
import 'qr_display_screen.dart';
import 'qr_scanner_screen.dart';
import '../widgets/responsive_container.dart';
import 'past_comparison_screen.dart';
import '../widgets/shimmer_container.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/weekly_review_provider.dart';
import 'weekly_review_screen.dart';


// ---── コンポーネントのインポート ──
import 'profile/components/profile_header_section.dart';
import 'profile/components/task_section.dart';
import 'profile/components/trending_tasks_bottom_sheet.dart';
import 'profile/components/quest_card.dart';


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
  StreamSubscription<void>? _postUpdateSubscription;
  StreamSubscription<void>? _userUpdateSubscription;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser!.uid;
    _userStream = _db.collection('users').doc(_uid).snapshots();
    _loadPrivateData();
    _loadTrendingTasks();
    _loadProfile();

    // データの更新通知を監視
    _postUpdateSubscription = _postService.updateStream.listen((_) {
      if (mounted) _loadProfile();
    });
    // ヒーロータスク変更の通知を監視
    _userUpdateSubscription = _userService.updateStream.listen((_) {
      if (mounted) _loadProfile();
    });
  }

  @override
  void dispose() {
    _postUpdateSubscription?.cancel();
    _userUpdateSubscription?.cancel();
    super.dispose();
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

      // 過去の投稿数のマイグレーションチェック（非同期）
      final userDoc = await _db.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final rawUser = AppUser.fromFirestore(userDoc);
        if (!rawUser.totalPostsMigrated || rawUser.totalPosts == -1) {
          _userService.migrateTotalPosts(uid);
        }
      }

      // 🚀 現在開催中のシーズンタスクを Firestore から取得
      final now = DateTime.now();
      var seasonsSnap = await _db.collection('seasons')
          .where('startDate', isLessThanOrEqualTo: now)
          .get();

      var activeSeasons = seasonsSnap.docs
          .map((doc) => Season.fromFirestore(doc))
          .where((s) => now.isBefore(s.endDate))
          .toList();

      // 💡 検証・デバッグ環境での日付超過対策: アクティブなシーズンが0件の場合、メモリ上でテスト用のシーズンを作成して追加します
      if (activeSeasons.isEmpty) {
        final dummySeasonId = 'debug_season_test';
        final dummySeason = Season(
          id: dummySeasonId,
          taskName: '感謝を伝える', // 重複を避ける一般的なシーズンタスク名
          requiredPostsCount: 12,
          startDate: now.subtract(const Duration(days: 7)),
          endDate: now.add(const Duration(days: 365)), // 1年後まで有効
          hintTitle: '感謝を伝えるヒント💡',
          hintBody: '毎日1回、周囲の人や出来事に感謝して、言葉や記録に残してみましょう！',
        );
        activeSeasons.add(dummySeason);
      }

      final seasonTasks = activeSeasons.map((s) => AppTask(
        title: s.taskName,
        isOneTime: false,
        isSeason: true,
        seasonId: s.id,
      )).toList();

      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        final rawUser = AppUser.fromFirestore(doc);
        // ワンタイムタスクの期限切れチェックと削除
        await _checkAndCleanupOneTimeTasks(rawUser);

        // シーズン情報とカウントの取得
        final progressData = await _postService.getSeasonProgressMap(uid, seasonTasks);
        final Map<String, Season> newSeasonsMap = Map<String, Season>.from(progressData['seasonsMap'] ?? {});
        final Map<String, int> newSeasonPostsCountMap = Map<String, int>.from(progressData['seasonPostsCountMap'] ?? {});

        // 今日の投稿を取得
        final todayPosts = await _postService.getFriendPostsList(uid);

        // 再ロード（削除された可能性があるため）
        final freshDoc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        
        final freshRawUser = AppUser.fromFirestore(freshDoc);
        final mergedTasks = List<AppTask>.from(freshRawUser.tasks);
        final newSeasonTasks = <AppTask>[];
        for (final sTask in seasonTasks) {
          final exists = mergedTasks.any(
            (uTask) => uTask.title == sTask.title && uTask.isSeason,
          );
          if (!exists) {
            newSeasonTasks.add(sTask);
          }
        }
        
        bool didAdd = false;
        if (newSeasonTasks.isNotEmpty) {
          // 新規のシーズンタスクはリストの先頭に自動挿入する
          mergedTasks.insertAll(0, newSeasonTasks);
          didAdd = true;
        }

        // 新規追加が発生した場合は、Firestore に保存して同期
        if (didAdd) {
          await _userService.updateProfile(tasks: mergedTasks);
        }

        if (mounted) {
          setState(() {
            _user = freshRawUser.copyWith(tasks: mergedTasks);
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



  // ---── ヒーロータスクの追加 ──
  Future<void> _addTask({String? initialTitle}) async {
    final controller = TextEditingController(text: initialTitle);
    final triggerController = TextEditingController();

    bool isOneTime = false;

    // AlertDialogからshowModalBottomSheetに変更し、キーボードの真上にせり上がるように設定
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true, // コンテンツサイズに応じて高さを調整可能にする
      backgroundColor: Colors.transparent, // 角丸のコンテナを綺麗に表現するため背景は透明に設定
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (context, setModalState) => Container(
                  decoration: BoxDecoration(
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
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
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
                          style: TextStyle(color: AppColors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.profileScreenTaskTriggerHint,
                            hintStyle: TextStyle(color: AppColors.grey30, fontSize: 14),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // --- タスク名入力欄 ---
                        TextField(
                          controller: controller,
                          autofocus: true,
                          style: TextStyle(color: AppColors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.profileScreenTaskNameHint,
                            hintStyle: TextStyle(color: AppColors.grey30, fontSize: 14),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildHabitPreviewForDialog(triggerController, controller),
                        const SizedBox(height: 8),
                        // --- 単発タスク切り替えスイッチ ---
                        SwitchListTile(
                          visualDensity: VisualDensity.compact,
                          title: Text(
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
                                style: TextStyle(color: AppColors.grey50),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, {
                                'title': controller.text,
                                'trigger': triggerController.text,
                                'isOneTime': isOneTime,
                              }),
                              child: Text(
                                AppLocalizations.of(context)!.profileScreenAddTask,
                                style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
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

    bool isOneTime = task.isOneTime;

    // AlertDialogからshowModalBottomSheetに変更し、キーボードの真上にせり上がるように設定
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true, // コンテンツサイズに応じて高さを調整可能にする
      backgroundColor: Colors.transparent, // 角丸のコンテナを綺麗に表現するため背景は透明に設定
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (context, setModalState) => Container(
                  decoration: BoxDecoration(
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
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
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
                          style: TextStyle(color: AppColors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.profileScreenTaskTriggerHint,
                            hintStyle: TextStyle(color: AppColors.grey30, fontSize: 14),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // --- タスク名入力欄 ---
                        TextField(
                          controller: controller,
                          autofocus: true,
                          style: TextStyle(color: AppColors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.profileScreenTaskNameHint,
                            hintStyle: TextStyle(color: AppColors.grey30, fontSize: 14),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildHabitPreviewForDialog(triggerController, controller),
                        const SizedBox(height: 8),
                        // --- 単発タスク切り替えスイッチ ---
                        SwitchListTile(
                          visualDensity: VisualDensity.compact,
                          title: Text(
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
                                style: TextStyle(color: AppColors.grey50),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, {
                                'title': controller.text,
                                'trigger': triggerController.text,
                                'isOneTime': isOneTime,
                              }),
                              child: Text(
                                AppLocalizations.of(context)!.profileScreenSaveTask,
                                style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
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

      updatedTasks[index] = task.copyWith(
        title: newTitle,
        trigger: newTrigger,
        clearTrigger: newTrigger == null,
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
                Icon(
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
                  style: TextStyle(color: AppColors.white),
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
              style: TextStyle(color: AppColors.white),
            ),
            content: Text(AppLocalizations.of(context)!.profileScreenDeleteTaskMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  AppLocalizations.of(context)!.profileScreenDeleteTaskCancel,
                  style: TextStyle(color: AppColors.grey50),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  AppLocalizations.of(context)!.profileScreenDeleteTaskButton,
                  style: TextStyle(color: AppColors.error),
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
  ) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: taskCtrl,
      builder: (context, taskVal, _) {
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: triggerCtrl,
          builder: (context, triggerVal, _) {
            final hasTrigger = triggerVal.text.trim().isNotEmpty;
            final hasQuest = taskVal.text.trim().isNotEmpty;

            if (!hasTrigger && !hasQuest) {
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
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Icon(
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
                          color: hasQuest ? AppColors.accentGold : AppColors.grey50,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
          },
        );
      },
    );
  }

  Widget _buildSkeleton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー部分のシマー
            Row(
              children: [
                const ShimmerContainer.circular(size: 80),
                const SizedBox(width: 20),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerContainer(width: 140, height: 24, borderRadius: 4),
                    SizedBox(height: 8),
                    ShimmerContainer(width: 90, height: 14, borderRadius: 4),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 40),
            // スタッツ部分のシマー
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                3,
                (i) => const Column(
                  children: [
                    ShimmerContainer(width: 40, height: 20, borderRadius: 4),
                    SizedBox(height: 8),
                    ShimmerContainer(width: 60, height: 12, borderRadius: 4),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            // 進捗（ストリークプログレス）セクションを模した大きなシマー
            const ShimmerContainer(
              width: double.infinity,
              height: 120,
              borderRadius: 16,
            ),
            const SizedBox(height: 40),
            // タスク一覧用の骨組みシマー
            const ShimmerContainer(width: 120, height: 18, borderRadius: 4),
            const SizedBox(height: 16),
            ...List.generate(
              2,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    const ShimmerContainer.circular(size: 24),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerContainer(width: 180, height: 14, borderRadius: 4),
                        SizedBox(height: 6),
                        ShimmerContainer(width: 120, height: 10, borderRadius: 4),
                      ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body:
          _user == null && _loading
              ? _buildSkeleton()
              : SafeArea(
                child: StreamBuilder<DocumentSnapshot>(
                  stream: _userStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final rawUser = AppUser.fromFirestore(snapshot.data!);
                      _user = rawUser;
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
        style: TextStyle(color: AppColors.textSecondary),
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
  
                  // ---── ストリークプログレス（進捗状況） ──
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverToBoxAdapter(child: _buildStreakProgressCard()),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
  
                  // ---── 過去の軌跡を振り返るボタン ──────────────────────────
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverToBoxAdapter(
                      child: GestureDetector(
                        onTap: () {
                          if (_user == null) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PastComparisonScreen(userTasks: _user!.tasks),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: AppColors.bgElevated,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.accentGold, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.isDark
                                    ? Colors.transparent
                                    : AppColors.accentGold.withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // より柔らかい表現にするため、ひらがな表記の「積み重ねを振りかえる」にしました
                              Text(
                                AppLocalizations.of(context)!.profileScreenReviewButton,
                                style: GoogleFonts.notoSansJp(
                                  color: AppColors.white,
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
                  
                  // ---── 既読時の今週の振り返りバナー（週末のみ表示） ──
                  Consumer(
                    builder: (context, ref, child) {
                      final isWeeklyReviewReadAsync = ref.watch(isWeeklyReviewReadProvider);
                      final isWeeklyReviewRead = isWeeklyReviewReadAsync.value ?? false;
                      final isWeekend = DateTime.now().weekday == DateTime.saturday || DateTime.now().weekday == DateTime.sunday;

                      if (isWeekend && isWeeklyReviewRead) {
                        return SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          sliver: SliverToBoxAdapter(
                            child: _buildProfileWeeklyReviewBanner(context, ref),
                          ),
                        );
                      }
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    },
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),


                  // ---── ヒーロータスクセクション ──
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverTaskSectionHeader(
                      onShowTrendingTasks: () {
                        showTrendingTasksBottomSheet(
                          context,
                          trendingTasks: _trendingTasks,
                          onAddTask: _addTask,
                        );
                      },
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),

                  if (_user!.tasks.isEmpty)
                    SliverPadding(
                      key: const ValueKey('profile_empty_task_card_padding'),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverEmptyTaskCard(
                        onAddTask: _addTask,
                      ),
                    )
                  else ...[
                    SliverPadding(
                      key: const ValueKey('profile_reorderable_list_padding'),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverReorderableList(
                        itemCount: _user!.tasks.length,
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
                        itemBuilder: (context, index) {
                          final task = _user!.tasks[index];
                          return ReorderableDelayedDragStartListener(
                            key: ValueKey(task.id.isNotEmpty ? task.id : 'task_${task.title}_$index'),
                            index: index,
                            child: QuestCard(
                              index: index,
                              task: task,
                              seasonsMap: _seasonsMap,
                              seasonPostsCountMap: _seasonPostsCountMap,
                              todayPosts: _todayPosts,
                              onTap: () {
                                if (task.isSeason) {
                                  final season = _seasonsMap[task.seasonId] ??
                                      _seasonsMap['debug_season'] ??
                                      _seasonsMap['debug_season_test'] ??
                                      Season.createFallback(
                                        task.title,
                                        seasonId: task.seasonId,
                                      );
                                  
                                  SeasonHintModal.show(context, task, season, (newTrigger) async {
                                    final updatedTasks = List<AppTask>.from(_user!.tasks);
                                    updatedTasks[index] = task.copyWith(
                                      trigger: newTrigger.isEmpty ? null : newTrigger,
                                      clearTrigger: newTrigger.isEmpty,
                                    );
                                    await _userService.updateProfile(tasks: updatedTasks);
                                    _loadProfile();
                                  });
                                } else {
                                  _editTask(index);
                                }
                              },
                              onDelete: () => _deleteTask(index),
                            ),
                          );
                        },
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 8)),
                    SliverPadding(
                      key: const ValueKey('profile_add_task_slot_padding'),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverAddTaskSlot(
                        onAddTask: _addTask,
                      ),
                    ),
                  ],
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
        icon: Icon(Icons.edit_outlined, color: AppColors.white, size: 22),
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
        icon: Icon(Icons.settings_outlined, color: AppColors.white, size: 22),
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
              style: TextStyle(color: AppColors.textPrimary),
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
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
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
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
                ),
              ),
            ],
          ),
    );
  }

  // ---
  // ---スケジュール設定（直接変更可能）
  // ---
  Widget _buildStreakProgressCard() {
    if (_user == null) return const SizedBox.shrink();

    final streak = _user!.streak;
    final l10n = AppLocalizations.of(context)!;
    
    // 閾値、ティア名、カラーの定義
    final thresholds = [0, 3, 7, 14, 30, 66, 100, 180, 270, 365];
    final names = [
      l10n.tierIron,
      l10n.tierBronze,
      l10n.tierSilver,
      l10n.tierGold,
      l10n.tierPlatinum,
      l10n.tierEmerald,
      l10n.tierDiamond,
      l10n.tierMaster,
      l10n.tierGrandmaster,
      l10n.tierChallenger,
    ];
    final colors = [
      const Color(0xFF5E4B43),
      const Color(0xFF8F5338),
      const Color(0xFF8091A0),
      const Color(0xFFC89C3C),
      const Color(0xFF327A8A),
      const Color(0xFF10825B),
      const Color(0xFF4A60AB),
      const Color(0xFF8D2D9E),
      const Color(0xFFB53030),
      const Color(0xFFE0A33B),
    ];

    String currentTier = l10n.tierIron;
    String nextTier = l10n.tierChallenger;
    int currentThreshold = 0;
    int nextThreshold = 365;
    double percent = 1.0;
    Color currentTierColor = colors.first;
    Color nextTierColor = colors.last;

    if (streak < 365) {
      int index = 0;
      for (int i = 0; i < thresholds.length - 1; i++) {
        if (streak >= thresholds[i] && streak < thresholds[i + 1]) {
          index = i;
          break;
        }
      }
      currentTier = names[index];
      nextTier = names[index + 1];
      currentThreshold = thresholds[index];
      nextThreshold = thresholds[index + 1];
    } else {
      currentTier = l10n.tierChallenger;
      nextTier = l10n.tierChallenger;
      currentThreshold = 365;
      nextThreshold = 365;
    }

    // セグメント数と進捗パーセントの動的計算 (1日 = 1メモリ、Challengerは60固定)
    int segmentCount;
    if (streak < 365) {
      segmentCount = nextThreshold >= 12 ? nextThreshold : 12;
      percent = (streak / nextThreshold).clamp(0.0, 1.0);
      currentTierColor = colors[thresholds.indexOf(currentThreshold)];
      nextTierColor = colors[thresholds.indexOf(nextThreshold)];
    } else {
      segmentCount = 60;
      percent = 1.0;
      currentTierColor = colors.last;
      nextTierColor = colors.last;
    }

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // 左側: セグメント分割型円形メーター
            SizedBox(
              width: 90,
              height: 90,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(90, 90),
                    painter: SegmentedCircularProgressPainter(
                      percent: percent,
                      activeColor: currentTierColor,
                      inactiveColor: Colors.white.withValues(alpha: 0.08),
                      segmentCount: segmentCount,
                      strokeWidth: 12, // 太くして存在感を出す
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$streak',
                        style: GoogleFonts.outfit(
                          color: currentTierColor,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        l10n.profileScreenStreak,
                        style: TextStyle(
                          color: currentTierColor,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            // 右側: 詳細テキスト項目
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailRow(l10n.profileScreenCurrentRank, currentTier, valueColor: currentTierColor),
                  const SizedBox(height: 6),
                  _buildDetailRow(l10n.profileScreenStreak, l10n.profileScreenStreakDays(streak)),
                  const SizedBox(height: 6),
                  _buildDetailRow(
                    l10n.profileScreenStreakProgress,
                    l10n.profileScreenStreakProgressValue(streak, nextThreshold),
                  ),
                  const SizedBox(height: 6),
                  _buildDetailRow(
                    l10n.profileScreenNextRank,
                    streak < 365 ? nextTier : l10n.profileScreenStreakMax,
                    valueColor: streak < 365 ? nextTierColor : const Color(0xFFE0A33B),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor, String suffix = ''}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: RichText(
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: TextStyle(
                color: valueColor ?? AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              children: [
                TextSpan(text: value),
                if (suffix.isNotEmpty)
                  TextSpan(
                    text: suffix,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileWeeklyReviewBanner(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        try {
          final posts = await _postService.getWeeklyReviewPosts();
          final streak = await _postService.getStreak();
          if (!context.mounted) return;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WeeklyReviewScreen(posts: posts, currentStreak: streak),
            ),
          );
        } catch (e) {
          debugPrint('WeeklyReview Load Error (Profile): $e');
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.accentGold,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.isDark
                  ? Colors.transparent
                  : AppColors.accentGold.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WEEKLY REVIEW',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accentGold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.of(context)!.weeklyReviewReplay,
                    style: GoogleFonts.notoSansJp(
                      fontSize: 14,
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.white.withValues(alpha: 0.3),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}


class SegmentedCircularProgressPainter extends CustomPainter {
  final double percent;
  final Color activeColor;
  final Color inactiveColor;
  final int segmentCount;
  final double strokeWidth;

  SegmentedCircularProgressPainter({
    required this.percent,
    required this.activeColor,
    required this.inactiveColor,
    required this.segmentCount,
    this.strokeWidth = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    
    final activeSegmentCount = (percent * segmentCount).round();
    final segmentAngle = 360.0 / segmentCount;
    
    // 総セグメント数に応じてスリット（隙間）の角度を動的に計算 (合計で72度程度が隙間になるように)
    final gapDegree = 72.0 / segmentCount;
    final gapAngleRad = gapDegree * (3.141592653589793 / 180.0);
    final drawAngleRad = (segmentAngle - gapDegree) * (3.141592653589793 / 180.0);

    double startAngleRad = -3.141592653589793 / 2; // 12時の位置から開始

    for (int i = 0; i < segmentCount; i++) {
      final isActive = i < activeSegmentCount;
      
      final paint = Paint()
        ..color = isActive ? activeColor : inactiveColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      if (isActive) {
        // 単色ネオン感を引き立てる発光シャドウ
        paint.imageFilter = ui.ImageFilter.blur(sigmaX: 0.25, sigmaY: 0.25);
      }

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngleRad + (gapAngleRad / 2),
        drawAngleRad,
        false,
        paint,
      );

      startAngleRad += segmentAngle * (3.141592653589793 / 180.0);
    }
  }

  @override
  bool shouldRepaint(covariant SegmentedCircularProgressPainter oldDelegate) {
    return oldDelegate.percent != percent ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor ||
        oldDelegate.segmentCount != segmentCount;
  }
}
