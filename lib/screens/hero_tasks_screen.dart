import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../config/app_colors.dart';
import '../config/routes.dart';
import '../models/post.dart';
import '../models/app_task.dart';
import '../models/app_user.dart';
import '../models/season.dart';
import '../services/analytics_service.dart';
import '../services/post_service.dart';
import '../services/user_service.dart';
import '../widgets/splash_loading.dart';
import '../widgets/streak_flame.dart';
import '../widgets/v_effect_header.dart';
import '../services/sound_service.dart';
import 'camera_screen.dart';
import '../widgets/reaction_avatars.dart';
import '../widgets/entropic_conversion_overlay.dart';
import '../widgets/post_success_dialog.dart';
import '../widgets/season_hint_modal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'main_shell.dart';
import '../providers/dev_blog_provider.dart';
import '../services/app_review_service.dart';

/// 内部管理用のタスクアイテム
class _HeroTaskItem {
  final String name;
  final String? trigger;
  final String? reward; // ご褒美（したい習慣）
  final List<Post> completedPosts;
  final bool isOneTime;
  final bool isSeason;
  final String? seasonId;
  final Season? season;
  final int currentSeasonCount;
  bool get isCompleted => completedPosts.isNotEmpty;

  String get displayName => (trigger != null && trigger!.isNotEmpty) ? '$trigger：$name' : name;

  Post? get latestPost {
    if (completedPosts.isEmpty) return null;
    return completedPosts.reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);
  }

  _HeroTaskItem({
    required this.name,
    this.trigger,
    this.reward,
    this.completedPosts = const [],
    this.isOneTime = false,
    this.isSeason = false,
    this.seasonId,
    this.season,
    this.currentSeasonCount = 0,
  });
}

class HeroTasksScreen extends StatefulWidget {
  final ValueChanged<bool>? onLoadingChanged;

  const HeroTasksScreen({super.key, this.onLoadingChanged});

  @override
  State<HeroTasksScreen> createState() => _HeroTasksScreenState();
}

class _HeroTasksScreenState extends State<HeroTasksScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final PostService _postService = PostService.instance;
  final UserService _userService = UserService.instance;
  final AnalyticsService _analytics = AnalyticsService.instance;
  final SoundService _soundService = SoundService.instance;
  StreamSubscription? _updateSubscription;
  StreamSubscription? _userUpdateSubscription;

  int _streak = 0;
  int _streakProtections = 0;
  bool _loading = true;
  List<_HeroTaskItem> _taskItems = [];

  // ── Card Expansion ──
  int? _expandedIndex; // 長押しで拡大中のカードインデックス
  final Map<String, String?> _userPhotos = {};
  final Map<String, String> _userNames = {};

  // ── Sublimation ──
  late final AnimationController _sublimationController;
  late final Animation<double> _sublimation;
  late final Animation<double> _sublimationFlash;
  late final Animation<double> _sublimationTextOpacity;
  late final Animation<double> _sublimationTextScale;
  late final Animation<double> _sublimationAura;
  late final Animation<double> _sublimationBgDim;
  int? _heroIndex; // 選ばれたHero Taskのインデックス
  bool _isSublimating = false;

  // ── Card Swiping ──
  late final PageController _pageController;
  late final ValueNotifier<double> _scrollPositionNotifier;

  // ── Swipe Guide Tutorial ──
  // 初回スワイプチュートリアルの表示状態を管理するフラグ
  bool _showSwipeGuide = false;
  // チュートリアル矢印の揺れ（バウンスアニメーション）を制御するコントローラー
  late final AnimationController _swipeGuideController;
  // チュートリアル矢印の移動量を表すアニメーション
  late final Animation<double> _swipeGuideTranslation;

  int get _focusedIndex {
    if (_taskItems.isEmpty) return 0;
    final len = _taskItems.length;
    final pos = _scrollPositionNotifier.value.round();
    return (pos % len + len) % len;
  }

  int _lastFocusedIndex = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    MainShell.activeTabIndex.addListener(_onTabChanged);
    final initialPage = 10000;
    _scrollPositionNotifier = ValueNotifier<double>(initialPage.toDouble());
    _pageController = PageController(initialPage: initialPage)
      ..addListener(() {
        if (mounted && _pageController.hasClients) {
          final page = _pageController.page;
          if (page != null && !page.isNaN) {
            // スワイプが始まったら拡大状態を解除
            if (_expandedIndex != null) {
              setState(() => _expandedIndex = null);
              SoundService.instance.stopBgm();
              return;
            }
            _scrollPositionNotifier.value = page;
            // ユーザーがスワイプ（画面移動）を開始したら、ガイドを非表示にする
            if (_showSwipeGuide) {
              _dismissSwipeGuide();
            }
          }
        }
      });
    _loadData();

    _sublimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _sublimation = CurvedAnimation(
      parent: _sublimationController,
      curve: Curves.easeInOutCubic,
    );
    
    _sublimationFlash = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 85),
    ]).animate(CurvedAnimation(
      parent: _sublimationController,
      curve: const Interval(0.2, 0.45, curve: Curves.easeOut),
    ));

    _sublimationTextOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(CurvedAnimation(
      parent: _sublimationController,
      curve: const Interval(0.4, 0.95),
    ));

    _sublimationTextScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 1.1).chain(CurveTween(curve: Curves.easeOutBack)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 70),
    ]).animate(CurvedAnimation(
      parent: _sublimationController,
      curve: const Interval(0.4, 0.7),
    ));

    _sublimationAura = CurvedAnimation(
      parent: _sublimationController,
      curve: const Interval(0.25, 1.0, curve: Curves.easeOut),
    );

    _sublimationBgDim = Tween<double>(begin: 0.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _sublimationController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );

    // ── Swipe Guide Tutorial ──
    // スワイプガイド用のアニメーションコントローラーを初期化
    _swipeGuideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    // 左右に揺れる動き（0.0 から 8.0 の位置への往復）を設定
    _swipeGuideTranslation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 8.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 8.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_swipeGuideController);

    // チュートリアルの表示状態を判定して初期化
    _initSwipeGuide();

    // データの更新通知を監視
    _updateSubscription = _postService.updateStream.listen((_) {
      if (mounted) _loadData();
    });
    // ヒーロータスク変更の通知を監視
    _userUpdateSubscription = _userService.updateStream.listen((_) {
      if (mounted) _loadData();
    });
  }

  @override
  void dispose() {
    MainShell.activeTabIndex.removeListener(_onTabChanged);
    WidgetsBinding.instance.removeObserver(this);
    _soundService.stopBgm();
    _updateSubscription?.cancel();
    _userUpdateSubscription?.cancel();
    _pageController.dispose();
    _sublimationController.dispose();
    _swipeGuideController.dispose();
    super.dispose();
  }

  /// 初回スワイプチュートリアルの表示状態を判定して初期化します。
  /// (SharedPreferences からフラグを読み込み、表示が必要な場合はアニメーションを開始します)
  Future<void> _initSwipeGuide() async {
    final prefs = await SharedPreferences.getInstance();
    // すでにチュートリアルが表示されたかどうかを確認します
    final hasShown = prefs.getBool('v_quest_swipe_tutorial_shown') ?? false;
    if (!hasShown && mounted) {
      setState(() {
        _showSwipeGuide = true;
      });
      // バウンスアニメーションをリピート開始（リバースありで往復させます）
      _swipeGuideController.repeat(reverse: true);
    }
  }

  /// スワイプ操作を検知した際に、ガイドを非表示にし、表示済みフラグを保存します。
  Future<void> _dismissSwipeGuide() async {
    if (!mounted) return;
    setState(() {
      _showSwipeGuide = false;
    });
    _swipeGuideController.stop();
    final prefs = await SharedPreferences.getInstance();
    // 次回以降表示されないようにフラグを保存します
    await prefs.setBool('v_quest_swipe_tutorial_shown', true);
  }

  Future<void> _loadData() async {
    try {
      final homeData = await _postService.getHomeData();
      final friendUids =
          (homeData['friends'] as List<dynamic>?)?.cast<String>() ?? [];

      if (!mounted) return;

      final allTasks = (homeData['tasks'] as List<dynamic>?)?.cast<AppTask>() ?? [];
      
      // ワンタイムタスクのクリーンアップ（期限切れを削除）
      final uid = _userService.currentUid;
      if (uid != null) {
        final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (snap.exists) {
          final user = AppUser.fromFirestore(snap);
          await _userService.cleanupExpiredTasks(user);
          // クリーンアップされた可能性があるため、再ロードが必要な場合はここで再取得するか
          // リマインドとして _loadData を再度呼ぶのもありだが、
          // 24時間経過後に削除されるタイミングなので、ユーザーが画面を開いた瞬間に消えるので
          // 取得済みの allTasks からフィルタリングして即時反映する
          final now = DateTime.now();
          final startOfToday = DateTime(now.year, now.month, now.day);
          allTasks.removeWhere((t) => t.isOneTime && t.completedAt != null && t.completedAt!.isBefore(startOfToday));
        }
      }

      final postedPosts =
          (homeData['postedTasksToday'] as List<dynamic>?)?.cast<Post>() ?? [];

      // Seasonタスクの進行状況を取得
      final seasonTasks = allTasks.where((t) => t.isSeason).toList();
      Map<String, Season> seasonsMap = {};
      Map<String, int> seasonPostsCountMap = {};
      if (uid != null && seasonTasks.isNotEmpty) {
        final progressData = await _postService.getSeasonProgressMap(uid, seasonTasks);
        seasonsMap = Map<String, Season>.from(progressData['seasonsMap'] ?? {});
        seasonPostsCountMap = Map<String, int>.from(progressData['seasonPostsCountMap'] ?? {});
      }

      final List<_HeroTaskItem> items = [];
      for (final task in allTasks) {
        final taskPosts = postedPosts.where((p) => p.taskName == task.title).toList();
        final sId = task.seasonId ?? 'debug_season_test';
        items.add(_HeroTaskItem(
          name: task.title, 
          trigger: task.trigger,
          reward: task.reward,
          completedPosts: taskPosts,
          isOneTime: task.isOneTime,
          isSeason: task.isSeason,
          seasonId: task.seasonId,
          season: (task.isSeason) 
              ? (seasonsMap[sId] ?? seasonsMap['debug_season'] ?? seasonsMap['debug_season_test']) 
              : null,
          currentSeasonCount: (task.isSeason) ? (seasonPostsCountMap[sId] ?? 0) : 0,
        ));
      }

      // リアクションしたユーザーの情報を取得
      final Set<String> uidsToFetch = {};
      for (final item in items) {
        for (final post in item.completedPosts) {
          uidsToFetch.addAll(post.emojiReactedUserIds);
          uidsToFetch.addAll(post.userReactions.keys);
        }
      }

      final Map<String, String?> photoMap = {};
      final Map<String, String> nameMap = {};

      if (uidsToFetch.isNotEmpty) {
        final profiles =
            await _postService.getFriendsListFromUids(uidsToFetch.toList());
        for (final p in profiles) {
          final uid = p['uid'] as String;
          photoMap[uid] = p['photoUrl'] as String?;
          nameMap[uid] = p['username'] as String? ?? 'Unknown';
        }
      }

      setState(() {
        _streak = (homeData['streak'] as num?)?.toInt() ?? 0;
        _streakProtections = (homeData['streakProtections'] as num?)?.toInt() ?? 0;
        _taskItems = items;
        _userPhotos.addAll(photoMap);
        _userNames.addAll(nameMap);
        _loading = false;
      });
      widget.onLoadingChanged?.call(false);

      _analytics.setStreakTier(_streak);
      _analytics.setTaskCount(_taskItems.length);
      _analytics.setFriendCount(friendUids.length);
      _analytics.setTaskCategories(allTasks.map((t) => t.title).toList());

    } catch (e) {
      debugPrint('Load data error: $e');
      if (mounted) {
        setState(() => _loading = false);
        widget.onLoadingChanged?.call(false);
      }
    }
  }



  void _onTabChanged() {
    if (!mounted) return;
    if (MainShell.activeTabIndex.value == 1 && _expandedIndex != null) {
      // 炎タブに戻ってきた時、拡大中なら音楽を再開する
      final currentFocused = _focusedIndex;
      if (_taskItems.isNotEmpty && currentFocused >= 0 && currentFocused < _taskItems.length) {
        final focusedTask = _taskItems[currentFocused];
        if (focusedTask.isCompleted && focusedTask.completedPosts.isNotEmpty) {
          final sortedPosts = List<Post>.from(focusedTask.completedPosts)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final targetPost = sortedPosts.first;
          if (targetPost.bgmUrl != null) {
            _soundService.playBgm(targetPost.bgmUrl!);
          }
        }
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _soundService.stopBgm();
    } else if (state == AppLifecycleState.resumed) {
      // 復帰時に自動で鳴らさない
    }
  }

  Future<void> _deleteHeroPost(String postId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppColors.bgElevated,
            title: Text(AppLocalizations.of(context)!.heroTasksDeletePostTitle, style: const TextStyle(color: AppColors.white)),
            content: Text(AppLocalizations.of(context)!.heroTasksDeletePostDesc),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(AppLocalizations.of(context)!.heroTasksDeletePostCancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  AppLocalizations.of(context)!.heroTasksDeletePostButton,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      setState(() => _loading = true);
      try {
        await _postService.deletePost(postId);
        if (mounted) {
          setState(() {
            if (_expandedIndex != null) {
              _expandedIndex = null; // 拡大状態をリセット
              SoundService.instance.stopBgm(); // スワイプ時に音楽を止める
            }
          });
        }
        await _loadData();
      } catch (e) {
        debugPrint('Delete post error: $e');
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  void _showSeasonHint(_HeroTaskItem item) {
    final fallbackSeason = item.season ?? Season.createFallback(
      item.name,
      seasonId: item.seasonId,
    );
    
    SeasonHintModal.show(
      context,
      AppTask(
        title: item.name,
        trigger: item.trigger,
        reward: item.reward,
        isSeason: item.isSeason,
        seasonId: item.seasonId,
      ),
      fallbackSeason,
      (newTrigger, newReward) async {
        final uid = _userService.currentUid;
        if (uid == null) return;
        final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (!snap.exists) return;
        final tasks = (snap.data()?['tasks'] as List? ?? [])
            .map((e) => AppTask.fromFirestore(e))
            .toList();
        final updatedTasks = tasks.map((t) {
          if (t.title == item.name) {
            return t.copyWith(
              trigger: newTrigger.isEmpty ? null : newTrigger,
              clearTrigger: newTrigger.isEmpty,
              reward: newReward.isEmpty ? null : newReward,
              clearReward: newReward.isEmpty,
            );
          }
          return t;
        }).toList();
        await _userService.updateProfile(tasks: updatedTasks);
      },
    );
  }

  Future<void> _selectHeroTask(int index) async {
    HapticFeedback.lightImpact();

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => CameraScreen(heroTaskName: _taskItems[index].name),
      ),
    );

    if (result != null && result['posted'] == true && mounted) {
      final String? localImagePath = result['imagePath'] as String?;
      final int newStreak = result['newStreak'] as int;
      final bool isRecordUpdating = result['isRecordUpdating'] as bool;

      // 1. 一時的に「完了」状態にしてUI上の反映漏れを防ぐ
      final originalItem = _taskItems[index];
      final newTempPosts = List<Post>.from(originalItem.completedPosts)
        ..add(Post(
          id: 'temp',
          userId: 'temp',
          imageUrl: null, // まだURLはないが、後続の演出でlocalImagePathを使う
          taskName: originalItem.name,
          reactionCount: 0,
          emojiReactedUserIds: const [],
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 24)),
        ));

        _taskItems[index] = _HeroTaskItem(
          name: originalItem.name,
          trigger: originalItem.trigger,
          reward: originalItem.reward,
          completedPosts: newTempPosts,
          isOneTime: originalItem.isOneTime,
        );

      setState(() {
        _heroIndex = index;
        _isSublimating = true;
      });

      // 2. 再誕の V-Entropic 演出を実行
      await EntropicConversionOverlay.show(
        context,
        finishedImagePath: localImagePath,
        taskName: originalItem.name,
      );

      if (mounted) {
        setState(() {
          _isSublimating = false;
        });
      }

      // 3. 演出完了後に結果ダイアログを表示
      if (mounted) {
        await PostSuccessDialog.show(
          context,
          streakDays: newStreak,
          isRecordUpdating: isRecordUpdating,
        );
        
        // ダイアログ（7秒間の演出）が完了した直後に、必要に応じてレビューをリクエスト
        await AppReviewService.instance.requestReviewIfNeeded(newStreak);
        
        // 4. 最後にデータを最新化して、NetworkImageなどへの切り替えを完了させる
        await _loadData();
      }
    }
  }





  Color _getTierColor(int streak) {
    if (streak >= 100) return const Color(0xFFE5E4E2); // Platinum
    if (streak >= 30) return AppColors.accentGoldLight;
    if (streak >= 7) return const Color(0xFFC0C0C0); // Silver
    if (streak >= 3) return const Color(0xFFCD7F32); // Bronze
    return AppColors.accentGold;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SplashLoading();

    return VisibilityDetector(
      key: const Key('hero_tasks_screen_visibility'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction < 0.1) {
          SoundService.instance.stopBgm();
        }
      },
      child: Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        children: [
          if (_isSublimating) _buildSublimationBackgroundDim(),
          if (_isSublimating) _buildSublimationAura(),
          SafeArea(
            child: Column(
              children: [
                _buildTitleBar(),
                SizedBox(
                  height: 76, // 固定高さで全画面統一
                  child: Center(
                    child: _streak > 0
                        ? _buildStreakRow()
                        : const SizedBox.shrink(),
                  ),
                ),
                Expanded(
                  child: _buildCardStack(),
                ),
              ],
            ),
          ),
          if (_isSublimating)
            IgnorePointer(child: _buildSublimationFlash()),
          if (_isSublimating)
            IgnorePointer(child: _buildVictoryOverlay()),
        ],
      ),
    ));
  }



  Widget _buildSublimationBackgroundDim() {
    return AnimatedBuilder(
      animation: _sublimationBgDim,
      builder: (context, _) {
        return Positioned.fill(
          child: Container(
            color: AppColors.black.withValues(alpha: _sublimationBgDim.value * 0.7),
          ),
        );
      },
    );
  }

  Widget _buildSublimationAura() {
    return AnimatedBuilder(
      animation: _sublimationAura,
      builder: (context, _) {
        final t = _sublimationAura.value;
        final size = 200.0 + t * 400.0;
        final opacity = (1.0 - t).clamp(0.0, 1.0) * 0.4;
        final tierColor = _getTierColor(_streak);

        return Center(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: tierColor.withValues(alpha: opacity),
                  blurRadius: 100,
                  spreadRadius: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSublimationFlash() {
    return AnimatedBuilder(
      animation: _sublimationFlash,
      builder: (context, _) {
        final opacity = _sublimationFlash.value;
        if (opacity <= 0) return const SizedBox.shrink();
        return Positioned.fill(
          child: IgnorePointer(
            child: Container(
              color: AppColors.white.withValues(alpha: opacity),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVictoryOverlay() {
    return AnimatedBuilder(
      animation: _sublimationController,
      builder: (context, _) {
        final opacity = _sublimationTextOpacity.value;
        final scale = _sublimationTextScale.value;
        if (opacity <= 0) return const SizedBox.shrink();

        return Center(
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: Text(
                'VICTORY',
                style: GoogleFonts.outfit(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: _getTierColor(_streak),
                  letterSpacing: 12.0,
                  shadows: [
                    Shadow(
                      color: _getTierColor(_streak).withValues(alpha: 0.5),
                      blurRadius: 20,
                    ),
                    const Shadow(
                      color: AppColors.white,
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTitleBar() => VEffectHeader(
        leading: Consumer(
          builder: (context, ref, _) {
            final hasUnreadBlog = ref.watch(hasUnreadBlogProvider);
            return Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  // 左上のブックマーク（本）アイコン。ベルマークの色と統一するために白（AppColors.white）に設定
                  icon: const Icon(Icons.menu_book_rounded, color: AppColors.white, size: 22),
                  onPressed: () {
                    SoundService.instance.stopBgm();
                    Navigator.pushNamed(context, AppRoutes.vPractice);
                  },
                ),
                if (hasUnreadBlog)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        trailing: const NotificationBellIcon(),
        hideLogo: _isSublimating,
      );

  Widget _buildStreakRow() {
    return ValueListenableBuilder<double>(
      valueListenable: _scrollPositionNotifier,
      builder: (context, _, __) {
        final focusedTask =
            _taskItems.isNotEmpty ? _taskItems[_focusedIndex] : null;
        final isCompleted = focusedTask?.isCompleted ?? false;
        final tierColor = _getTierColor(_streak);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 32,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Tooltip(
                  message: 'ストリークが途切れるのを1回防ぎます',
                  triggerMode: TooltipTriggerMode.longPress,
                  preferBelow: true,
                  verticalOffset: 24,
                  decoration: BoxDecoration(
                    color: AppColors.black.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tierColor.withValues(alpha: 0.5)),
                  ),
                  textStyle: GoogleFonts.notoSansJp(
                    color: AppColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: tierColor.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: tierColor.withValues(alpha: 0.15),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const StreakFlame(size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '$_streak Day Streak',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (_streakProtections > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: AppColors.grey50,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.shield_rounded,
                            size: 14,
                            color: tierColor.withValues(alpha: 0.9),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (isCompleted && _expandedIndex == _focusedIndex)
                  Positioned(
                    right: 0,
                    child: IconButton(
                      onPressed:
                          () => _deleteHeroPost(focusedTask!.latestPost!.id),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardStack() {
    if (_taskItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.layers_outlined,
              size: 48,
              color: AppColors.grey20,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.heroTasksNoTasks,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.grey50,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context)!.heroTasksNoTasksDesc,
              style: const TextStyle(fontSize: 12, color: AppColors.grey30),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth * 0.85;
        final cardHeight = cardWidth * (16 / 9);
        final maxCardHeight = (constraints.maxHeight - 40).clamp(
          0.0,
          cardHeight,
        );
        final finalCardWidth = maxCardHeight * (9 / 16);

        return ValueListenableBuilder<double>(
          valueListenable: _scrollPositionNotifier,
          builder: (context, scrollPos, _) {
            final sortedIndices = _sortedCardIndices(scrollPos);
            // 描画負荷軽減：手前にある一定数（最大5枚）のカードのみ描画
            // ※sortedIndicesは奥から順に並んでいる（Stack用）
            final visibleIndices =
                sortedIndices.length > 5
                    ? sortedIndices.sublist(sortedIndices.length - 5)
                    : sortedIndices;

            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                for (final i in visibleIndices)
                  _buildStackedCard(
                    index: i,
                    total: _taskItems.length,
                    cardWidth: finalCardWidth,
                    cardHeight: maxCardHeight,
                    scrollPos: scrollPos,
                  ),

                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: _isSublimating,
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const _FrictionlessPageScrollPhysics(),
                      itemBuilder: (context, rawIndex) {
                        if (_taskItems.isEmpty) return const SizedBox.shrink();
                        final actualIndex = rawIndex % _taskItems.length;
                        final item = _taskItems[actualIndex];

                        return Center(
                          child: SizedBox(
                            width: finalCardWidth,
                            height: maxCardHeight,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // 全体検知（タップで拡大・タスク選択）
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTapUp: (details) {
                                    if (_expandedIndex != null) {
                                      setState(() => _expandedIndex = null);
                                      SoundService.instance.stopBgm();
                                      return;
                                    }
                                    // カードが中央にない場合はスナップして終了
                                    if (actualIndex != _focusedIndex) {
                                      _pageController.animateToPage(
                                        rawIndex,
                                        duration:
                                            const Duration(milliseconds: 300),
                                        curve: Curves.easeOutCubic,
                                      );
                                      return;
                                    }
                                    final item = _taskItems[actualIndex];
                                    if (item.isCompleted) {
                                      // カードの真ん中付近（追いVボタン）か判定
                                      final cardCenter = Offset(finalCardWidth / 2, maxCardHeight / 2);
                                      final tapPos = details.localPosition;
                                      final dist = (tapPos - cardCenter).distance;
                                      if (dist < 60) { // 半径60以内なら追加撮影へ
                                        _selectHeroTask(actualIndex);
                                      } else {
                                        // それ以外は拡大
                                        HapticFeedback.mediumImpact();
                                        setState(
                                            () => _expandedIndex = actualIndex);
                                        // [New] 拡大時に音楽を流す
                                        if (item.latestPost?.bgmUrl != null) {
                                          SoundService.instance.playBgm(item.latestPost!.bgmUrl!);
                                        }
                                      }
                                    } else {
                                      // 未完了ならカメラへ
                                      _selectHeroTask(actualIndex);
                                    }
                                  },
                                  child: const SizedBox.expand(),
                                ),

                                // [New] ヒントボタン（SEASONタスクの場合のみ、右上に配置）
                                // 手前のフォーカスされたカード、または拡大されている時に表示する
                                if (item.isSeason && 
                                    (actualIndex == _focusedIndex || actualIndex == _expandedIndex) &&
                                    !_isSublimating)
                                  ValueListenableBuilder<double>(
                                    valueListenable: _scrollPositionNotifier,
                                    builder: (context, scrollPos, _) {
                                      final isExpanded = actualIndex == _expandedIndex;
                                      
                                      // 拡大中でない場合、スワイプ中はズレを防ぐため＆スワイプの邪魔をしないために非表示にする
                                      if (!isExpanded) {
                                        final diff = (scrollPos - actualIndex).abs();
                                        if (diff > 0.05) return const SizedBox.shrink();
                                      }

                                      // カードは通常0.9倍、拡大時は1.0倍でスケールされる
                                      final scale = isExpanded ? 1.0 : 0.9;
                                      final postCount = item.completedPosts.length;
                                      final rightOffset = (item.isCompleted && postCount > 1) ? 72.0 : 16.0;

                                      return Transform.scale(
                                        scale: scale,
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Positioned(
                                              top: 16,
                                              right: rightOffset,
                                              child: IconButton(
                                                icon: const Icon(Icons.lightbulb_outline, color: AppColors.accentGold, size: 28),
                                                onPressed: () {
                                                  _showSeasonHint(item);
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // ── Swipe Guide Tutorial UI ──
                // 初めてのユーザー向けに左右のスワイプガイド矢印を表示（揺れるアニメーション付き）
                if (_showSwipeGuide && _taskItems.length > 1)
                  IgnorePointer(
                    child: SizedBox(
                      width: finalCardWidth + 64, // カードの左右端の少し外側（32pxずつ）にガイドを配置
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 左側のゴールド矢印（◀）をバウンス（往復）移動させます
                          AnimatedBuilder(
                            animation: _swipeGuideTranslation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(-_swipeGuideTranslation.value, 0),
                                child: child,
                              );
                            },
                            child: Icon(
                              Icons.chevron_left_rounded,
                              color: AppColors.accentGold.withValues(alpha: 0.7),
                              size: 40,
                            ),
                          ),
                          // 右側のゴールド矢印（▶）をバウンス（往復）移動させます
                          AnimatedBuilder(
                            animation: _swipeGuideTranslation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(_swipeGuideTranslation.value, 0),
                                child: child,
                              );
                            },
                            child: Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.accentGold.withValues(alpha: 0.7),
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  List<int> _sortedCardIndices(double scrollPos) {
    final indices = List.generate(_taskItems.length, (i) => i);
    indices.sort((a, b) {
      if (a == _expandedIndex) return 1;
      if (b == _expandedIndex) return -1;

      if (_taskItems.isEmpty) return 0;
      final halfLength = _taskItems.length / 2.0;

      double distA = (a - scrollPos) % _taskItems.length;
      if (distA > halfLength) distA -= _taskItems.length;
      if (distA < -halfLength) distA += _taskItems.length;
      final depthA = distA.abs();

      double distB = (b - scrollPos) % _taskItems.length;
      if (distB > halfLength) distB -= _taskItems.length;
      if (distB < -halfLength) distB += _taskItems.length;
      final depthB = distB.abs();

      return depthB.compareTo(depthA);
    });
    return indices;
  }

  Widget _buildStackedCard({
    required int index,
    required int total,
    required double cardWidth,
    required double cardHeight,
    required double scrollPos,
  }) {
    final halfLength = _taskItems.length / 2.0;

    double fanPosition = (index - scrollPos) % _taskItems.length;
    if (fanPosition > halfLength) fanPosition -= _taskItems.length;
    if (fanPosition < -halfLength) fanPosition += _taskItems.length;

    final double smoothDepth = fanPosition.abs();
    const fanSpreadDeg = 6.0;
    final fanAngleDeg = fanPosition * fanSpreadDeg;
    final fanAngleRad = fanAngleDeg * 3.14159265 / 180.0;

    final item = _taskItems[index];
    final isExpanded = index == _expandedIndex;

    // 通常時は0.9倍、拡大時はホームと同じ1.0倍
    final baseScale = isExpanded ? 1.0 : 0.9;
    final scale = isExpanded
        ? 1.0
        : (baseScale - smoothDepth * 0.04).clamp(0.4, baseScale);
    final dimAlpha = isExpanded ? 0.0 : (smoothDepth * 0.15).clamp(0.0, 0.85);

    return AnimatedBuilder(
      animation: _sublimation,
      builder: (context, child) {
        double currentOpacity = (_isSublimating && index == _heroIndex) ? 0.0 : 1.0;
        double currentScale = scale;
        double currentAngle = isExpanded ? 0.0 : fanAngleRad;
        double currentSublimateY = 0;

        if (currentOpacity <= 0) return const SizedBox.shrink();

        return Transform.translate(
          offset: Offset(0, currentSublimateY),
          child: Transform(
            alignment: Alignment.center,
            transform:
                Matrix4.identity()
                  ..rotateZ(currentAngle)
                  ..scale(currentScale, currentScale, currentScale),
            child: Opacity(opacity: currentOpacity, child: child),
          ),
        );
      },
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          RepaintBoundary(
            child: SizedBox(
              width: cardWidth,
              height: cardHeight,
              child: _TaskCard(
                item: item,
                index: index + 1,
                total: total,
                depth: smoothDepth.round(),
                showCamera: !_isSublimating && index == _focusedIndex,
                tierColor: _getTierColor(_streak),
                isExpanded: isExpanded,
                userPhotos: _userPhotos,
                onDelete: item.latestPost != null
                    ? () => _deleteHeroPost(item.latestPost!.id)
                    : null,
              ),
            ),
          ),
          if (dimAlpha > 0 && !isExpanded)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.black.withValues(alpha: dimAlpha),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
          if (index == _focusedIndex && 
              item.name == 'Welcome to V EFFECT' && 
              !item.isCompleted &&
              !_isSublimating)
            Positioned(
              top: -80,
              child: IgnorePointer(
                child: Container(
                  width: cardWidth * 0.95,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.accentGold,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentGold.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.heroTasksWelcomeMessage,
                        style: GoogleFonts.notoSansJp(
                          color: AppColors.black,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatefulWidget {
  final _HeroTaskItem item;
  final int index;
  final int total;
  final int depth;
  final bool showCamera;
  final Color tierColor;
  final bool isExpanded;
  final Map<String, String?> userPhotos;
  final VoidCallback? onDelete;

  const _TaskCard({
    required this.item,
    required this.index,
    required this.total,
    required this.depth,
    required this.showCamera,
    required this.tierColor,
    required this.isExpanded,
    required this.userPhotos,
    this.onDelete,
  });

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(covariant _TaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isExpanded && oldWidget.isExpanded) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      _currentPage = 0;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildHabitStepSequence({
    required _HeroTaskItem item,
    required bool isCompleted,
    required int depth,
  }) {
    final hasTrigger = item.trigger != null && item.trigger!.isNotEmpty;
    final hasReward = item.reward != null && item.reward!.isNotEmpty;
    final isTop = depth == 0;

    // トリガーもご褒美もない場合は、単にタスク名を表示する
    if (!hasTrigger && !hasReward) {
      return Text(
        item.name,
        style: GoogleFonts.notoSerifJp(
          fontSize: isTop ? 22 : 16,
          fontWeight: FontWeight.w600,
          color: isTop ? AppColors.white : AppColors.grey50,
          height: 1.4,
          letterSpacing: 1.5,
          shadows: isTop
              ? [
                  Shadow(
                    color: AppColors.black.withValues(alpha: 0.8),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
      );
    }

    // 奥のカード（depth > 0）の場合は簡略化して1行で表示する
    if (!isTop) {
      final sb = StringBuffer();
      if (hasTrigger) sb.write('${item.trigger} ➜ ');
      sb.write(item.name);
      if (hasReward) sb.write(' ➜ ${item.reward}');
      return Text(
        sb.toString(),
        style: GoogleFonts.notoSansJp(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.grey50,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    // 手前のカード（depth == 0）の場合は美麗なステップUIを表示する
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasTrigger) ...[
          Row(
            children: [
              Icon(
                Icons.alarm_rounded,
                size: 14,
                color: AppColors.accentGold.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.trigger!,
                  style: GoogleFonts.notoSansJp(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.grey70,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 6, top: 2, bottom: 2),
            child: Container(
              width: 1.5,
              height: 10,
              color: AppColors.border.withValues(alpha: 0.5),
            ),
          ),
        ],
        Row(
          children: [
            Icon(
              Icons.task_alt_rounded,
              size: 16,
              color: isCompleted ? AppColors.accentGold : AppColors.white.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                item.name,
                style: GoogleFonts.notoSerifJp(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                  height: 1.3,
                  letterSpacing: 1.5,
                  shadows: [
                    Shadow(
                      color: AppColors.black.withValues(alpha: 0.8),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
        if (hasReward) ...[
          Padding(
            padding: const EdgeInsets.only(left: 6, top: 2, bottom: 2),
            child: Container(
              width: 1.5,
              height: 10,
              color: AppColors.border.withValues(alpha: 0.5),
            ),
          ),
          Row(
            children: [
              const Icon(
                Icons.emoji_events_rounded,
                size: 14,
                color: AppColors.accentGold,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.reward!,
                  style: GoogleFonts.notoSansJp(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentGold.withValues(alpha: 0.9),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  List<Post> get _sortedPosts {
    final posts = List<Post>.from(widget.item.completedPosts);
    posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return posts;
  }

  Widget _buildBackgroundImage(String? imageUrl, bool isExpanded, bool isTop) {
    if (imageUrl == null) return const SizedBox.shrink();
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        AppColors.black.withValues(
          alpha: isExpanded ? 0.1 : (isTop ? 0.3 : 0.6),
        ),
        BlendMode.darken,
      ),
      child: Image(
        image: ResizeImage(
          CachedNetworkImageProvider(imageUrl),
          width: 540,
        ),
        fit: BoxFit.cover,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final depth = widget.depth;
    final tierColor = widget.tierColor;
    final isExpanded = widget.isExpanded;
    final showCamera = widget.showCamera;
    final userPhotos = widget.userPhotos;

    final isTop = depth == 0;
    final isCompleted = item.isCompleted;
    final sortedPosts = _sortedPosts;
    final postCount = sortedPosts.length;
    final currentPost = (isExpanded && postCount > 1) 
        ? sortedPosts[_currentPage] 
        : (sortedPosts.isNotEmpty ? sortedPosts.first : null);

    int totalReactionCount = 0;
    final Map<String, String> totalUserReactions = {};
    final Set<String> totalEmojiReactedUserIds = {};

    for (final post in sortedPosts) {
      totalReactionCount += post.reactionCount;
      totalUserReactions.addAll(post.userReactions);
      totalEmojiReactedUserIds.addAll(post.emojiReactedUserIds);
    }

    const bgColorTop = Color(0xFF1C1D21);
    const bgColorBottom = Color(0xFF121316);

    final bool isSeason = item.isSeason;

    final borderColor = isCompleted
        ? (isTop
            ? (postCount >= 2 ? AppColors.accentGold : AppColors.accentGold.withValues(alpha: 0.8))
            : tierColor.withValues(alpha: 0.1))
        : (isSeason
            ? (isTop ? AppColors.accentGold.withValues(alpha: 0.6) : AppColors.accentGold.withValues(alpha: 0.2))
            : (isTop
                ? AppColors.white.withValues(alpha: 0.12)
                : AppColors.white.withValues(alpha: 0.05)));

    final borderWidth = isCompleted 
        ? (isTop ? (postCount >= 2 ? 2.5 : 1.5) : 0.5) 
        : (isSeason && isTop ? 1.5 : 0.8);

    final blurRadius = isTop ? (postCount >= 2 ? 40.0 : 30.0) : 10.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: bgColorBottom,
        gradient: isCompleted
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  bgColorTop.withValues(alpha: isTop ? 0.95 : 0.4),
                  bgColorTop.withValues(alpha: isTop ? 0.65 : 0.3),
                  bgColorBottom.withValues(alpha: isTop ? 0.85 : 0.2),
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: isTop ? 0.6 : 0.2),
            blurRadius: isTop ? 20 : 10,
            offset: Offset(0, isTop ? 10 : 5),
            spreadRadius: -2,
          ),
          if (isTop)
            BoxShadow(
              color: isCompleted
                  ? AppColors.accentGold.withValues(alpha: postCount >= 2 ? 0.6 : 0.3)
                  : (isSeason 
                      ? AppColors.accentGold.withValues(alpha: 0.2) 
                      : tierColor.withValues(alpha: 0.04)),
              blurRadius: blurRadius,
              spreadRadius: isCompleted && postCount >= 2 ? 4 : 2,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isCompleted && sortedPosts.isNotEmpty)
              if (isExpanded && postCount > 1)
                PageView.builder(
                  controller: _pageController,
                  onPageChanged: (idx) {
                    setState(() {
                      _currentPage = idx;
                    });
                  },
                  itemCount: postCount,
                  itemBuilder: (context, i) {
                    final p = sortedPosts[i];
                    return _buildBackgroundImage(p.imageUrl, isExpanded, isTop);
                  },
                )
              else
                _buildBackgroundImage(sortedPosts.first.imageUrl, isExpanded, isTop),

            _buildStack(item, isCompleted, postCount, isTop, depth, isExpanded, showCamera, tierColor, totalReactionCount, totalUserReactions, totalEmojiReactedUserIds.toList(), userPhotos, currentPost),
          ],
        ),
      ),
    );
  }

  Widget _buildStack(
    _HeroTaskItem item,
    bool isCompleted,
    int postCount,
    bool isTop,
    int depth,
    bool isExpanded,
    bool showCamera,
    Color tierColor,
    int totalReactionCount,
    Map<String, String> totalUserReactions,
    List<String> totalEmojiReactedUserIds,
    Map<String, String?> userPhotos,
    Post? currentPost,
  ) {
    return Stack(
      children: [
        // テキスト上部エリア（カメラは別レイヤー）
        Padding(
          padding: const EdgeInsets.fromLTRB(40, 40, 40, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isCompleted && depth == 0) ...[
                _buildHabitStepSequence(item: item, isCompleted: true, depth: depth),
                const SizedBox(height: 8),
                if (item.isSeason) ...[
                  Row(
                    children: [
                      Text(
                        'Season ${item.currentSeasonCount}/${item.season?.requiredPostsCount ?? 12}',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          color: AppColors.accentGold,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final requiredCount = item.season?.requiredPostsCount ?? 12;
                            final progress = (item.currentSeasonCount / requiredCount).clamp(0.0, 1.0);
                            return Stack(
                              children: [
                                Container(
                                  height: 2,
                                  decoration: BoxDecoration(
                                    color: AppColors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 800),
                                  curve: Curves.easeOutCubic,
                                  height: 2,
                                  width: constraints.maxWidth * progress,
                                  decoration: BoxDecoration(
                                    color: AppColors.accentGold,
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      Container(width: 16, height: 1, color: AppColors.accentGold),
                      const SizedBox(width: 8),
                      Text(
                        postCount >= 2 ? 'VICTORY x$postCount' : 'DONE',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          color: AppColors.accentGold,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                ],
                if (currentPost != null && currentPost.bgmTitle != null && depth == 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          await SoundService.instance.toggleBgmMute(currentPost.bgmUrl);
                          setState(() {}); // ミュートアイコンの更新
                        },
                        child: currentPost.bgmArtworkUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      CachedNetworkImage(
                                        imageUrl: currentPost.bgmArtworkUrl!,
                                        fit: BoxFit.cover,
                                      ),
                                      if (SoundService.instance.isBgmMuted)
                                        Container(
                                          color: AppColors.black.withValues(alpha: 0.5),
                                          child: const Icon(
                                            Icons.music_off_rounded,
                                            color: AppColors.white,
                                            size: 16,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.black.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  SoundService.instance.isBgmMuted
                                      ? Icons.music_off_rounded
                                      : Icons.music_note_rounded,
                                  color: SoundService.instance.isBgmMuted
                                      ? AppColors.grey50
                                      : AppColors.white,
                                  size: 16,
                                ),
                              ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentPost.bgmTitle!,
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (currentPost.bgmArtist != null)
                              Text(
                                currentPost.bgmArtist!,
                                style: const TextStyle(
                                  color: AppColors.grey50,
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ] else ...[
                _buildHabitStepSequence(item: item, isCompleted: false, depth: depth),
                if (depth == 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 16,
                        height: 1,
                        color: AppColors.accentGold.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.isSeason
                            ? AppLocalizations.of(context)!.heroTaskSeasonDaysLeft(item.season != null ? item.season!.endDate.difference(DateTime.now()).inDays.clamp(0, 999) : 0)
                            : item.isOneTime
                                ? 'ONE-TIME'
                                : 'READY',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          color: AppColors.accentGold,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                ],
                if (currentPost?.bgmTitle != null && depth == 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          await SoundService.instance.toggleBgmMute(currentPost?.bgmUrl);
                          setState(() {}); // ミュートアイコンの更新
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            SoundService.instance.isBgmMuted
                                ? Icons.music_off_rounded
                                : Icons.music_note_rounded,
                            color: SoundService.instance.isBgmMuted
                                ? AppColors.grey50
                                : AppColors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentPost!.bgmTitle!,
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (currentPost.bgmArtist != null)
                              Text(
                                currentPost.bgmArtist!,
                                style: const TextStyle(
                                  color: AppColors.grey50,
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),

        if (isCompleted && postCount > 1 && depth == 0)
          Positioned(
            top: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accentGold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.accentGold,
                  width: 1.5,
                ),
              ),
              child: Text(
                'x$postCount',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accentGold,
                ),
              ),
            ),
          ),

        // カメラボタン：ど真ん中に絶対配置
        if (!isCompleted && showCamera && depth == 0)
          Positioned.fill(
            child: Center(
              child: _PulseCameraButton(tierColor: tierColor),
            ),
          ),

        // 達成済みの場合の「追いV」カメラアイコン（中央）
        if (isCompleted && showCamera && depth == 0 && !isExpanded)
          Positioned.fill(
            child: Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.black.withValues(alpha: 0.4),
                  border: Border.all(
                    color: AppColors.white.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.white,
                  size: 28,
                ),
              ),
            ),
          ),

        // depth!=0 の場合の小さいカメラアイコン（中央）
        if (!isCompleted && showCamera && depth != 0)
          const Positioned.fill(
            child: Center(
              child: Icon(
                Icons.camera_alt_outlined,
                color: AppColors.grey30,
                size: 20,
              ),
            ),
          ),

        // ──── ホーム画面と同じ配置 (固定座標方式に変更) ────
        if (isCompleted && depth == 0) ...[
          // V FIRE ボタン (本体 + カウントテキスト)
          Positioned(
            bottom: 32,
            right: 20,
            child: IgnorePointer(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.local_fire_department,
                      color: AppColors.accentGold,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 16,
                    child: Text(
                      '$totalReactionCount',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // リアクションアバター (V FIREの左横)
          if (totalReactionCount > 0)
            Positioned(
              bottom: 54,
              right: 88,
              child: IgnorePointer(
                child: ReactionAvatarsStack(
                  userReactions: totalUserReactions,
                  reactorUids: totalEmojiReactedUserIds,
                  userPhotos: userPhotos,
                  reactionCount: totalReactionCount,
                  avatarSize: 44,
                  overlapOffset: 28,
                ),
              ),
            ),
        ],

        // ドットインジケーター
        if (isExpanded && postCount > 1 && depth == 0)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(postCount, (i) {
                final isActive = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isActive ? 12 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.accentGold : AppColors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

// ────────────────────────────────────────────
// ドーパミン刺激カメラボタン（呼吸 + ゴールドシマー）
// ────────────────────────────────────────────
class _PulseCameraButton extends StatefulWidget {
  const _PulseCameraButton({required this.tierColor});
  final Color tierColor;

  @override
  State<_PulseCameraButton> createState() => _PulseCameraButtonState();
}

class _PulseCameraButtonState extends State<_PulseCameraButton>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _shimmerController;
  late final Animation<double> _shimmerAngle;

  bool _isVisible = true;
  bool _isAppForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // ゴールドシマー：3秒で一周
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _shimmerAngle = Tween<double>(begin: 0, end: 2 * 3.14159265).animate(
      _shimmerController,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isFg = state == AppLifecycleState.resumed;
    if (_isAppForeground == isFg) return;
    _isAppForeground = isFg;
    _syncTickers();
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    if (!mounted) return;
    final visible = info.visibleFraction > 0.01;
    if (_isVisible == visible) return;
    _isVisible = visible;
    _syncTickers();
  }

  void _syncTickers() {
    final shouldRun = _isVisible && _isAppForeground;
    if (shouldRun) {
      if (!_shimmerController.isAnimating) {
        _shimmerController.repeat();
      }
    } else {
      _shimmerController.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: const Key('pulse_camera_button'),
      onVisibilityChanged: _handleVisibilityChanged,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _shimmerAngle,
          builder: (context, _) {
            const innerSize = 76.0;
            const outerSize = 104.0;

            return SizedBox(
              width: outerSize,
              height: outerSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 内側サークル＋アイコン (ゴールドの縁取り)
                  Container(
                    width: innerSize,
                    height: innerSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.white.withValues(alpha: 0.06),
                      border: Border.all(
                        color: AppColors.accentGold.withValues(alpha: 0.8),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      color: AppColors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FrictionlessPageScrollPhysics extends PageScrollPhysics {
  const _FrictionlessPageScrollPhysics({super.parent});

  @override
  _FrictionlessPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _FrictionlessPageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring =>
      // ζ ≈ 0.97（臨界減衰に近い）→ 約0.8秒で収束。旧値は実質無減衰だった。
      const SpringDescription(mass: 4.0, stiffness: 60.0, damping: 30.0);

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    return offset * 1.2;
  }

  @override
  double get minFlingVelocity => 20.0;
}
