import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../config/app_colors.dart';
import '../models/post.dart';
import '../models/app_task.dart';
import '../models/app_user.dart';
import '../services/analytics_service.dart';
import '../services/notification_service.dart';
import '../services/post_service.dart';
import '../services/user_service.dart';
import '../widgets/splash_loading.dart';
import '../widgets/streak_flame.dart';
import '../widgets/v_effect_header.dart';
import 'camera_screen.dart';
import '../widgets/reaction_avatars.dart';
import '../widgets/entropic_conversion_overlay.dart';
import '../widgets/post_success_dialog.dart';

/// 内部管理用のタスクアイテム
class _HeroTaskItem {
  final String name;
  final Post? completedPost;
  final bool isOneTime;
  bool get isCompleted => completedPost != null;
  _HeroTaskItem({required this.name, this.completedPost, this.isOneTime = false});
}

class HeroTasksScreen extends StatefulWidget {
  final ValueChanged<bool>? onLoadingChanged;

  const HeroTasksScreen({super.key, this.onLoadingChanged});

  @override
  State<HeroTasksScreen> createState() => _HeroTasksScreenState();
}

class _HeroTasksScreenState extends State<HeroTasksScreen>
    with TickerProviderStateMixin {
  final PostService _postService = PostService.instance;
  final UserService _userService = UserService.instance;
  final NotificationService _notificationService = NotificationService.instance;
  final AnalyticsService _analytics = AnalyticsService.instance;
  StreamSubscription? _updateSubscription;
  StreamSubscription? _userUpdateSubscription;

  int _streak = 0;
  bool _postedToday = false;
  bool _loading = true;
  List<_HeroTaskItem> _taskItems = [];
  bool _isAllTasksCompleted = false;

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

  int get _focusedIndex {
    if (_taskItems.isEmpty) return 0;
    final len = _taskItems.length;
    final pos = _scrollPositionNotifier.value.round();
    return (pos % len + len) % len;
  }

  @override
  void initState() {
    super.initState();
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
            }
            _scrollPositionNotifier.value = page;
          }
        }
      });
    _loadData().then((_) {
      _checkAndShowTutorial();
    });

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
    _updateSubscription?.cancel();
    _userUpdateSubscription?.cancel();
    _pageController.dispose();
    _sublimationController.dispose();
    super.dispose();
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

      final List<_HeroTaskItem> items = [];
      for (final task in allTasks) {
        Post? completedPost;
        for (final p in postedPosts) {
          if (p.taskName == task.title) {
            completedPost = p;
            break;
          }
        }
        items.add(_HeroTaskItem(
          name: task.title, 
          completedPost: completedPost,
          isOneTime: task.isOneTime,
        ));
      }

      // リアクションしたユーザーの情報を取得
      final Set<String> uidsToFetch = {};
      for (final item in items) {
        if (item.completedPost != null) {
          uidsToFetch.addAll(item.completedPost!.emojiReactedUserIds);
          uidsToFetch.addAll(item.completedPost!.userReactions.keys);
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
        _postedToday = homeData['postedToday'] as bool? ?? false;
        _isAllTasksCompleted =
            homeData['isAllTasksCompleted'] as bool? ?? false;
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

      _notificationService
          .checkAndCreateTimeReminders(streak: _streak)
          .catchError((e) => debugPrint('Time reminder error: $e'));
    } catch (e) {
      debugPrint('Load data error: $e');
      if (mounted) {
        setState(() => _loading = false);
        widget.onLoadingChanged?.call(false);
      }
    }
  }

  Future<void> _deleteHeroPost(String postId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppColors.bgElevated,
            title: const Text('投稿を削除', style: TextStyle(color: Colors.white)),
            content: const Text('この投稿を削除してもよろしいですか？\n(今日の達成記録も取り消されます)'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  '削除',
                  style: TextStyle(color: AppColors.error),
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
            _expandedIndex = null; // 拡大状態をリセット
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

  Future<void> _checkAndShowTutorial() async {
    if (!mounted || _postedToday) return;
    final prefs = await SharedPreferences.getInstance();
    final hasShown = prefs.getBool('v_quest_tutorial_shown') ?? false;
    if (hasShown) return;

    if (mounted) {
      showDialog(
        context: context,
        builder:
            (ctx) => AlertDialog(
              backgroundColor: AppColors.bgElevated,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'V-Quest',
                style: TextStyle(color: Colors.white),
              ),
              content: const Text(
                '今日の挑戦を選んでタップしましょう。\n証拠写真を投稿して Victory を獲得！',
                style: TextStyle(color: AppColors.grey70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('了解'),
                ),
              ],
            ),
      );
      await prefs.setBool('v_quest_tutorial_shown', true);
    }
  }

  Future<void> _checkAndShowPostTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final hasShown = prefs.getBool('v_feed_tutorial_shown') ?? false;
    if (hasShown) return;

    if (mounted) {
      showDialog(
        context: context,
        builder:
            (ctx) => AlertDialog(
              backgroundColor: AppColors.bgElevated,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Victory!',
                style: TextStyle(color: Colors.white),
              ),
              content: const Text(
                '投稿が完了しました！\nHOMEタブから仲間の努力を見に行きましょう。',
                style: TextStyle(color: AppColors.grey70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('了解'),
                ),
              ],
            ),
      );
      await prefs.setBool('v_feed_tutorial_shown', true);
    }
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
      _taskItems[index] = _HeroTaskItem(
        name: originalItem.name,
        completedPost: Post(
          id: 'temp',
          userId: 'temp',
          imageUrl: null, // まだURLはないが、後続の演出でlocalImagePathを使う
          taskName: originalItem.name,
          reactionCount: 0,
          emojiReactedUserIds: const [],
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 24)),
        ),
      );

      setState(() {
        _heroIndex = index;
        _postedToday = true;
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
        
        // 4. 最後にデータを最新化して、NetworkImageなどへの切り替えを完了させる
        await _loadData();
        await _checkAndShowPostTutorial();
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

    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        children: [
          _buildDeepBackground(),
          if (_isSublimating) _buildSublimationBackgroundDim(),
          if (_isSublimating) _buildSublimationAura(),
          SafeArea(
            child: Column(
              children: [
                _buildTitleBar(),
                SizedBox(
                  height: 76, // 固定高さで全画面統一
                  child: Center(
                    child: (_streak > 0 &&
                            !(_isAllTasksCompleted && !_isSublimating))
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
    );
  }

  Widget _buildDeepBackground() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [Color(0xFF1A1B1F), AppColors.black],
          ),
        ),
      ),
    );
  }

  Widget _buildSublimationBackgroundDim() {
    return AnimatedBuilder(
      animation: _sublimationBgDim,
      builder: (context, _) {
        return Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: _sublimationBgDim.value * 0.7),
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
              color: Colors.white.withValues(alpha: opacity),
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
                      color: Colors.white,
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

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 32,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const StreakFlame(size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '$_streak Day Streak',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.grey70,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                if (isCompleted && _expandedIndex == _focusedIndex)
                  Positioned(
                    right: 0,
                    child: IconButton(
                      onPressed:
                          () => _deleteHeroPost(focusedTask!.completedPost!.id),
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
            const Text(
              'ヒーロータスクが設定されていません',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.grey50,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'プロフィールからヒーロータスクを設定',
              style: TextStyle(fontSize: 12, color: AppColors.grey30),
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

                        return Center(
                          child: SizedBox(
                            width: finalCardWidth,
                            height: maxCardHeight,
                            child: Stack(
                              children: [
                                // 全体検知（タップで拡大・タスク選択）
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    if (_expandedIndex != null) {
                                      setState(() => _expandedIndex = null);
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
                                      // タップで拡大
                                      HapticFeedback.mediumImpact();
                                      setState(
                                          () => _expandedIndex = actualIndex);
                                    } else {
                                      // 未完了ならカメラへ
                                      _selectHeroTask(actualIndex);
                                    }
                                  },
                                  child: const SizedBox.expand(),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
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
                  ..scaleByDouble(currentScale, currentScale, currentScale, 1.0),
            child: Opacity(opacity: currentOpacity, child: child),
          ),
        );
      },
      child: Stack(
        alignment: Alignment.center,
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
                showCamera:
                    !item.isCompleted && !_isSublimating && index == _focusedIndex,
                tierColor: _getTierColor(_streak),
                isExpanded: isExpanded,
                userPhotos: _userPhotos,
                onDelete:
                    item.completedPost != null
                        ? () => _deleteHeroPost(item.completedPost!.id)
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
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isTop = depth == 0;
    final isCompleted = item.isCompleted;
    const bgColorTop = Color(0xFF1C1D21);
    const bgColorBottom = Color(0xFF121316);

    final borderColor = isCompleted
        ? (isTop
            ? AppColors.accentGold.withValues(alpha: 0.8)
            : tierColor.withValues(alpha: 0.1))
        : (isTop
            ? AppColors.white.withValues(alpha: 0.12)
            : AppColors.white.withValues(alpha: 0.05));

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
        image: isCompleted && item.completedPost?.imageUrl != null
            ? DecorationImage(
                image: ResizeImage(
                  CachedNetworkImageProvider(item.completedPost!.imageUrl!),
                  width: 540,
                ),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(
                    alpha: isExpanded ? 0.1 : (isTop ? 0.3 : 0.6),
                  ),
                  BlendMode.darken,
                ),
              )
            : null,
        border: Border.all(
          color: borderColor,
          width: isCompleted ? (isTop ? 1.5 : 0.5) : 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: isTop ? 0.6 : 0.2),
            blurRadius: isTop ? 20 : 10,
            offset: Offset(0, isTop ? 10 : 5),
            spreadRadius: -2,
          ),
          if (isTop) // 二重の重いシャドウは最前面のみにし、ぼかしを軽減
            BoxShadow(
              color: isCompleted
                  ? AppColors.accentGold.withValues(alpha: 0.3)
                  : tierColor.withValues(alpha: 0.04),
              blurRadius: 30, // 以前は80など過剰だったため30に制限
              spreadRadius: 2,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: _buildStack(),
      ),
    );
  }

  Widget _buildStack() {
    final isCompleted = item.isCompleted;
    return Stack(
      children: [
        // テキスト上部エリア（カメラは別レイヤー）
        Padding(
          padding: const EdgeInsets.fromLTRB(40, 40, 40, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isCompleted && depth == 0) ...[
                Text(
                  item.name,
                  style: GoogleFonts.notoSerifJp(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                    height: 1.4,
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(width: 16, height: 1, color: AppColors.accentGold),
                    const SizedBox(width: 8),
                    Text(
                      'DONE',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        color: AppColors.accentGold,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  item.name,
                  style: GoogleFonts.notoSerifJp(
                    fontSize: depth == 0 ? 22 : 16,
                    fontWeight: FontWeight.w500,
                    color: depth == 0 ? AppColors.white : AppColors.grey50,
                    height: 1.4,
                    letterSpacing: 1.5,
                    shadows: depth == 0
                        ? [
                            Shadow(
                              color: AppColors.black.withValues(alpha: 0.8),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            )
                          ]
                        : null,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
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
                        item.isOneTime ? 'ONE-TIME' : 'READY',
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
              ],
            ],
          ),
        ),

        // カメラボタン：ど真ん中に絶対配置
        if (!isCompleted && showCamera && depth == 0)
          Positioned.fill(
            child: Center(
              child: _PulseCameraButton(tierColor: tierColor),
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
                      '${item.completedPost?.reactionCount ?? 0}',
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
          if (item.completedPost != null &&
              (item.completedPost!.reactionCount > 0))
            Positioned(
              bottom: 62,  // Y=84pxの中心に合わせる (44px / 2 = 22)
              right: 88,  // VFIRE(56+20) + 余白(12) = 88
              child: IgnorePointer(
                child: ReactionAvatarsStack(
                  userReactions: item.completedPost!.userReactions,
                  reactorUids: item.completedPost!.emojiReactedUserIds,
                  userPhotos: userPhotos,
                  reactionCount: item.completedPost!.reactionCount,
                  avatarSize: 44,
                  overlapOffset: 28,
                ),
              ),
            ),
        ],
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
            const glowAlpha = 0.12;

            return SizedBox(
              width: outerSize,
              height: outerSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 背光オーラ（静止）
                  Container(
                    width: outerSize,
                    height: outerSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentGold.withValues(alpha: glowAlpha),
                          blurRadius: 40,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),

                  // ゴールドシマーボーダー
                  CustomPaint(
                    size: const Size(innerSize, innerSize),
                    painter: _GoldShimmerPainter(
                      angle: _shimmerAngle.value,
                    ),
                  ),

                  // 内側サークル＋アイコン
                  Container(
                    width: innerSize,
                    height: innerSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.white.withValues(alpha: 0.06),
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

// ゴールドの光がぐるりと走るカスタムペインター
class _GoldShimmerPainter extends CustomPainter {
  const _GoldShimmerPainter({required this.angle});
  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final center = Offset(radius, radius);

    // ベースの薄いゴールドリング
    final basePaint = Paint()
      ..color = AppColors.accentGold.withValues(alpha: 0.25)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius - 0.5, basePaint);

    // シマー光点（弧）
    final shimmerPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: angle - 0.6,
        endAngle: angle + 0.6,
        colors: [
          AppColors.accentGold.withValues(alpha: 0),
          AppColors.accentGold.withValues(alpha: 0.9),
          AppColors.accentGold.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 1),
      angle - 0.55,
      1.1,
      false,
      shimmerPaint,
    );
  }

  @override
  bool shouldRepaint(_GoldShimmerPainter old) => old.angle != angle;
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
