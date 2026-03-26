import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:ui';

import '../config/app_colors.dart';
import '../models/post.dart';
import '../services/analytics_service.dart';
import '../services/notification_service.dart';
import '../services/post_service.dart';
import '../services/user_service.dart';
import '../widgets/splash_loading.dart';
import '../widgets/streak_flame.dart';
import 'camera_screen.dart';

/// 内部管理用のタスクアイテム
class _HeroTaskItem {
  final String name;
  final Post? completedPost;
  bool get isCompleted => completedPost != null;
  _HeroTaskItem({required this.name, this.completedPost});
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
  String _username = '';
  List<_HeroTaskItem> _taskItems = [];
  bool _isAllTasksCompleted = false;

  // ── Card Expansion ──
  int? _expandedIndex; // 長押しで拡大中のカードインデックス

  // ── Zen Mode ──
  late final AnimationController _zenController;
  late final Animation<double> _zenGlow;

  // ── Sublimation ──
  late final AnimationController _sublimationController;
  late final Animation<double> _sublimation;
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

    _zenController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _zenGlow = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _zenController, curve: Curves.easeInOut));

    _sublimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _sublimation = CurvedAnimation(
      parent: _sublimationController,
      curve: Curves.easeInOutCubic,
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
    _zenController.dispose();
    _sublimationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final homeData = await _postService.getHomeData();
      final friendUids =
          (homeData['friends'] as List<dynamic>?)?.cast<String>() ?? [];

      if (!mounted) return;

      final allTasks =
          (homeData['tasks'] as List<dynamic>?)?.cast<String>() ?? [];
      final postedPosts =
          (homeData['postedTasksToday'] as List<dynamic>?)?.cast<Post>() ?? [];

      final List<_HeroTaskItem> items = [];
      for (final taskName in allTasks) {
        Post? completedPost;
        for (final p in postedPosts) {
          if (p.taskName == taskName) {
            completedPost = p;
            break;
          }
        }
        items.add(_HeroTaskItem(name: taskName, completedPost: completedPost));
      }

      setState(() {
        _streak = (homeData['streak'] as num?)?.toInt() ?? 0;
        _postedToday = homeData['postedToday'] as bool? ?? false;
        _isAllTasksCompleted =
            homeData['isAllTasksCompleted'] as bool? ?? false;
        _username = homeData['username'] as String? ?? '';
        _taskItems = items;
        _loading = false;
      });
      widget.onLoadingChanged?.call(false);

      if (_isAllTasksCompleted && allTasks.isNotEmpty) {
        _zenController.repeat(reverse: true);
      }

      _analytics.setStreakTier(_streak);
      _analytics.setTaskCount(_taskItems.length);
      _analytics.setFriendCount(friendUids.length);
      _analytics.setTaskCategories(allTasks);

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

    final posted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CameraScreen(heroTaskName: _taskItems[index].name),
      ),
    );

    if (posted == true && mounted) {
      setState(() {
        _heroIndex = index;
        _isSublimating = true;
        _postedToday = true;
      });

      HapticFeedback.heavyImpact();
      await _sublimationController.forward();

      if (mounted) {
        setState(() => _isSublimating = false);
        await _loadData();
        await _checkAndShowPostTutorial();
      }
    }
  }

  Color _getTierColor(int streak) {
    if (streak >= 100) return const Color(0xFFE5E4E2); // Platinum
    if (streak >= 30) return const Color(0xFFD4AF37); // Gold
    if (streak >= 7) return const Color(0xFFC0C0C0); // Silver
    if (streak >= 3) return const Color(0xFFCD7F32); // Bronze
    return const Color(0xFFD4AF37); // Default Gold accent
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SplashLoading();

    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        children: [
          _buildDeepBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildTitleBar(),
                if (_streak > 0 && !(_isAllTasksCompleted && !_isSublimating))
                  _buildStreakRow(),
                Expanded(
                  child:
                      _isAllTasksCompleted && !_isSublimating
                          ? _buildZenMode()
                          : _buildCardStack(),
                ),
              ],
            ),
          ),
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

  Widget _buildTitleBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Center(
        child: Text(
          'V EFFECT',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.white,
            letterSpacing: 6.0,
          ),
        ),
      ),
    );
  }

  Widget _buildStreakRow() {
    return ValueListenableBuilder<double>(
      valueListenable: _scrollPositionNotifier,
      builder: (context, _, __) {
        final focusedTask =
            _taskItems.isNotEmpty ? _taskItems[_focusedIndex] : null;
        final isCompleted = focusedTask?.isCompleted ?? false;

        return Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2, left: 20, right: 20),
          child: SizedBox(
            width: double.infinity,
            height: 32,
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
                if (isCompleted)
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
        final cardWidth = constraints.maxWidth * 0.72;
        final cardHeight = cardWidth * (16 / 9);
        final maxCardHeight = (constraints.maxHeight - 60).clamp(
          0.0,
          cardHeight,
        );
        final finalCardWidth = maxCardHeight * (9 / 16);

        return ValueListenableBuilder<double>(
          valueListenable: _scrollPositionNotifier,
          builder: (context, scrollPos, _) {
            final sortedIndices = _sortedCardIndices(scrollPos);
            // 描画負荷軽減：手前にある一定数（最大8枚）のカードのみ描画
            // ※sortedIndicesは奥から順に並んでいる（Stack用）
            final visibleIndices =
                sortedIndices.length > 8
                    ? sortedIndices.sublist(sortedIndices.length - 8)
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

                if (!_isSublimating)
                  Positioned.fill(
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const _FrictionlessPageScrollPhysics(),
                      itemBuilder: (context, rawIndex) {
                        final actualIndex = rawIndex % _taskItems.length;

                        return Stack(
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
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOutCubic,
                                  );
                                  return;
                                }
                                final item = _taskItems[actualIndex];
                                if (item.isCompleted) {
                                  // タップで拡大
                                  HapticFeedback.mediumImpact();
                                  setState(() => _expandedIndex = actualIndex);
                                } else {
                                  // 未完了ならカメラへ
                                  _selectHeroTask(actualIndex);
                                }
                              },
                              child: const SizedBox.expand(),
                            ),
                          ],
                        );
                      },
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

    final scale =
        isExpanded
            ? 1.15
            : (1.0 - smoothDepth * 0.04).clamp(0.5, 1.0);
    final dimAlpha = isExpanded ? 0.0 : (smoothDepth * 0.10).clamp(0.0, 0.8);

    return AnimatedBuilder(
      animation: _sublimation,
      builder: (context, child) {
        double currentOpacity = 1.0;
        double currentScale = scale;
        double currentAngle = isExpanded ? 0.0 : fanAngleRad;
        double currentSublimateY = 0;

        if (_isSublimating && _heroIndex != null) {
          final t = _sublimation.value;
          if (index == _heroIndex) {
            currentScale = scale + t * 0.05;
            currentOpacity = 1.0 - t * 0.3;
          } else {
            currentAngle = fanAngleRad * (1.0 + t * 1.5);
            currentSublimateY = -t * 300 - smoothDepth * 40 * t;
            currentOpacity = (1.0 - t * 1.2).clamp(0.0, 1.0);
            currentScale = scale * (1.0 + t * 0.15);
          }
        }

        if (currentOpacity <= 0) return const SizedBox.shrink();

        return Transform.translate(
          offset: Offset(0, currentSublimateY),
          child: Transform(
            alignment: Alignment.bottomCenter,
            transform:
                Matrix4.identity()
                  ..rotateZ(currentAngle)
                  ..scale(currentScale),
            child: Opacity(opacity: currentOpacity, child: child),
          ),
        );
      },
      child: RepaintBoundary(
        child: SizedBox(
          width: cardWidth,
          height: cardHeight,
          child: _TaskCard(
            item: item,
            index: index + 1,
            total: total,
            depth: smoothDepth.round(),
            dimAlpha: dimAlpha,
            showCamera:
                !item.isCompleted && !_isSublimating && index == _focusedIndex,
            tierColor: _getTierColor(_streak),
            isExpanded: isExpanded,
            onDelete:
                item.completedPost != null
                    ? () => _deleteHeroPost(item.completedPost!.id)
                    : null,
          ),
        ),
      ),
    );
  }

  Widget _buildZenMode() {
    return AnimatedBuilder(
      animation: _zenGlow,
      builder: (context, _) {
        final glow = _zenGlow.value;
        final glowSize = 180 + glow * 60;
        final glowAlpha = 0.06 + glow * 0.08;

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: glowSize,
                height: glowSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.white.withValues(alpha: glowAlpha),
                      blurRadius: 100 + glow * 40,
                      spreadRadius: 20 + glow * 20,
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.white.withValues(alpha: 0.12 + glow * 0.06),
                        AppColors.white.withValues(alpha: 0.03),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ShaderMask(
                shaderCallback:
                    (bounds) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.white, AppColors.grey70],
                    ).createShader(bounds),
                child: Text(
                  '$_streak',
                  style: GoogleFonts.outfit(
                    fontSize: 96,
                    fontWeight: FontWeight.w900,
                    color: AppColors.white,
                    height: 1,
                    letterSpacing: -4,
                  ),
                ),
              ),
              Text(
                'Day Streak',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: AppColors.grey50,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _username.isNotEmpty ? _username : '',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.grey30,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.grey20, width: 1),
                ),
                child: Text(
                  'ALL CLEAR',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.grey50,
                    letterSpacing: 3,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.item,
    required this.index,
    required this.total,
    required this.depth,
    required this.dimAlpha,
    required this.showCamera,
    required this.tierColor,
    required this.isExpanded,
    this.onDelete,
  });

  final _HeroTaskItem item;
  final int index;
  final int total;
  final int depth;
  final double dimAlpha;
  final bool showCamera;
  final Color tierColor;
  final bool isExpanded;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isTop = depth == 0;
    final isCompleted = item.isCompleted;
    const bgColorTop = Color(0xFF1C1D21);
    const bgColorBottom = Color(0xFF121316);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: bgColorBottom,
        gradient:
            isCompleted
                ? null
                : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    bgColorTop.withValues(alpha: isTop ? 0.85 : 0.4),
                    bgColorBottom.withValues(alpha: isTop ? 0.75 : 0.2),
                  ],
                ),
        image:
            isCompleted && item.completedPost?.imageUrl != null
                ? DecorationImage(
                  image: ResizeImage(
                    CachedNetworkImageProvider(item.completedPost!.imageUrl!),
                    width: 540, // カード表示に十分なサイズにリサイズ
                    height: 960,
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
          color:
              isCompleted
                  ? tierColor.withValues(alpha: isTop ? 0.8 : 0.3)
                  : (isTop
                      ? tierColor.withValues(alpha: 0.3)
                      : AppColors.white.withValues(alpha: 0.05)),
          width: isCompleted ? 1.5 : 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: isTop ? 0.4 : 0.2),
            blurRadius: 40,
            offset: const Offset(0, 20),
            spreadRadius: -4,
          ),
          if (isTop)
            BoxShadow(
              color:
                  isCompleted
                      ? tierColor.withValues(alpha: 0.3)
                      : tierColor.withValues(alpha: 0.03),
              blurRadius: isCompleted ? 40 : 60,
              spreadRadius: isCompleted ? 4 : 10,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: _buildCardContent(isTop),
      ),
    );
  }

  Widget _buildCardContent(bool isTop) {
    // BackdropFilterは負荷が高いため、トップのカードかつ非拡大時のみ適用
    if (isTop && !isExpanded) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
        child: _buildStack(),
      );
    }
    return _buildStack();
  }

  Widget _buildStack() {
    final isCompleted = item.isCompleted;
    return Stack(
      children: [
        if (dimAlpha > 0 && !isExpanded)
          Positioned.fill(
            child: ColoredBox(
              color: AppColors.black.withValues(alpha: dimAlpha),
            ),
          ),

        if (isCompleted && !isExpanded)
          Positioned(
            top: 40,
            right: 40,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: tierColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: tierColor, width: 1),
              ),
              child: Icon(
                Icons.check_rounded,
                color: tierColor,
                size: 20,
              ),
            ),
          ),

        Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 1,
                    height: 16,
                    color: tierColor.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'QUEST ${index.toString().padLeft(2, '0')}',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isCompleted ? AppColors.white : AppColors.grey50,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              if (!isCompleted) ...[
                if (showCamera && depth == 0) ...[
                  Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            tierColor.withValues(alpha: 0.1),
                            Colors.transparent,
                          ],
                        ),
                        border: Border.all(
                          color: tierColor.withValues(alpha: 0.3),
                          width: 0.5,
                        ),
                      ),
                      child: Icon(
                        Icons.camera_alt_outlined,
                        color: tierColor,
                        size: 24,
                      ),
                    ),
                  ),
                ] else if (showCamera && depth != 0) ...[
                  Center(
                    child: Icon(
                      Icons.camera_alt_outlined,
                      color: AppColors.grey30.withValues(alpha: 0.3),
                      size: 20,
                    ),
                  ),
                ],
              ],

              const Spacer(),

              Text(
                item.name,
                style: GoogleFonts.notoSerifJp(
                  fontSize: depth == 0 ? 22 : 16,
                  fontWeight: FontWeight.w500,
                  color: depth == 0 ? AppColors.white : AppColors.grey50,
                  height: 1.4,
                  letterSpacing: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 16),

              if (depth == 0)
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 1,
                      color: tierColor.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isCompleted ? 'COMPLETED' : 'TARGET',
                      style: GoogleFonts.outfit(
                        fontSize: 8,
                        color: tierColor.withValues(alpha: 0.7),
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
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
