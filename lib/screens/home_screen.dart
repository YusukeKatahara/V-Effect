import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../config/app_colors.dart';
import '../config/routes.dart';
import '../models/post.dart';
import '../services/post_service.dart';
import '../services/notification_service.dart';
import '../services/analytics_service.dart';


class HomeScreen extends StatefulWidget {
  final ValueChanged<bool>? onLoadingChanged;

  const HomeScreen({super.key, this.onLoadingChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final PostService _postService = PostService.instance;
  final NotificationService _notificationService = NotificationService.instance;
  StreamSubscription? _updateSubscription;
  late final Stream<int> _notificationStream;
  bool _loading = true;
  bool _postedToday = false;
  List<Post> _feedPosts = [];
  Map<String, String> _userNames = {}; // userId -> username
  Map<String, String?> _userPhotos = {}; // userId -> photoUrl
  Map<String, int> _userStreaks = {}; // userId -> streak

  // ── Card Swiping ──
  late final PageController _pageController;
  double _scrollPosition = 10000.0; // 擬似的な無限スクロール
  int get _focusedIndex {
    if (_feedPosts.isEmpty) return 0;
    final len = _feedPosts.length;
    final pos = _scrollPosition.round();
    return (pos % len + len) % len;
  }

  // ── リアクションアニメーション制御用 ──
  final GlobalKey<_FloatingFlamesLayerState> _flamesKey = GlobalKey();

  // ── V-Flash 演出用 ──
  late final AnimationController _flashController;
  late final Animation<double> _flashAnimation;

  @override
  void initState() {
    super.initState();
    _notificationStream = _notificationService.getNotificationCount();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flashAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.8), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 0.0), weight: 80),
    ]).animate(_flashController);

    final initialPage = 10000;
    _pageController = PageController(initialPage: initialPage)..addListener(() {
      if (mounted) {
        setState(() {
          _scrollPosition = _pageController.page ?? initialPage.toDouble();
        });
      }
    });

    // データの更新通知を監視
    _updateSubscription = _postService.updateStream.listen((_) {
      if (mounted) _loadData();
    });

    _loadData();
  }

  @override
  void dispose() {
    _updateSubscription?.cancel();
    _pageController.dispose();
    _flashController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (_feedPosts.isEmpty) return;
    final nextIndex = (index + 1) % _feedPosts.length;


    // 次のカードの画像をプリキャッシュ
    final nextPost = _feedPosts[nextIndex];
    if (nextPost.imageUrl != null) {
      precacheImage(
        ResizeImage(
          CachedNetworkImageProvider(nextPost.imageUrl!),
          width: 800,
        ),
        context,
      );
    }

    setState(() {
      _scrollPosition = index.toDouble();
    });
  }

  Future<void> _loadData() async {
    try {
      final homeData = await _postService.getHomeData();
      final friendUids =
          (homeData['friends'] as List<dynamic>?)?.cast<String>() ?? [];

      final postedToday = homeData['postedToday'] as bool? ?? false;

      // フレンドの投稿とフレンド情報を並列で取得
      final results = await Future.wait([
        _postService.getAllFriendsPosts(friendUids),
        friendUids.isNotEmpty
            ? _postService.getFriendsListFromUids(friendUids)
            : Future.value(<Map<String, dynamic>>[]),
      ]);

      final posts = results[0] as List<Post>;
      final friendStatuses = results[1] as List<Map<String, dynamic>>;

      final names = <String, String>{};
      final photos = <String, String?>{};
      final streaks = <String, int>{};
      for (final f in friendStatuses) {
        names[f['uid']] = f['username'] as String;
        photos[f['uid']] = f['photoUrl'] as String?;
        streaks[f['uid']] = (f['streak'] as num?)?.toInt() ?? 0;
      }

      if (!mounted) return;

      // 最初の数枚の画像をプリキャッシュ
      if (posts.isNotEmpty) {
        for (var i = 0; i < min(posts.length, 3); i++) {
          if (posts[i].imageUrl != null) {
            precacheImage(
              ResizeImage(
                CachedNetworkImageProvider(posts[i].imageUrl!),
                width: 800,
              ),
              context,
            );
          }
        }
      }

      setState(() {
        _postedToday = postedToday;
        _feedPosts = posts;
        _userNames = names;
        _userPhotos = photos;
        _userStreaks = streaks;
        _loading = false;
      });
      widget.onLoadingChanged?.call(false);

      AnalyticsService.instance.logFriendFeedViewed(); // フィード閲覧として記録
    } catch (e) {
      debugPrint('Feed load error: $e');
      if (mounted) {
        setState(() => _loading = false);
        widget.onLoadingChanged?.call(false);
      }
    }
  }

  Future<void> _sendReaction(int index) async {
    if (_feedPosts.isEmpty) return;

    final isVFlash = Random().nextInt(100) == 0; // 1/100の確率

    if (isVFlash) {
      HapticFeedback.heavyImpact();
      _flashController.forward(from: 0);
      _flamesKey.currentState?.addFlame(isGold: true);
    } else {
      HapticFeedback.lightImpact();
      _flamesKey.currentState?.addFlame(isGold: false);
    }

    final post = _feedPosts[index];
    // Optimistic UI update
    setState(() {
      _feedPosts = List.from(_feedPosts)
        ..[index] = Post(
          id: post.id,
          userId: post.userId,
          imageUrl: post.imageUrl,
          taskName: post.taskName,
          caption: post.caption,
          createdAt: post.createdAt,
          expiresAt: post.expiresAt,
          reactionCount: post.reactionCount + 1,
        );
    });

    await _postService.addReaction(post.id);
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
    if (_loading) return _buildHomeSkeleton();

    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        children: [
          // ── 背景 ──
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.grey08, AppColors.black],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildTitleBar(),
                Expanded(
                  child:
                      !_postedToday
                          ? _buildGuardedState()
                          : (_feedPosts.isEmpty
                              ? _buildEmptyState()
                              : _buildCardStack()),
                ),
              ],
            ),
          ),

          // ── Floating Flames Layer (setStateの影響を分離) ──
          _FloatingFlamesLayer(key: _flamesKey),

          // ── V-Flash 演出レイヤー ──
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _flashAnimation,
              builder: (context, _) {
                if (_flashAnimation.value == 0) return const SizedBox.shrink();
                return Container(
                  color: Colors.white.withValues(alpha: _flashAnimation.value),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeSkeleton() {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTitleBar(),
            const Spacer(),
            Center(
              child: Container(
                width: MediaQuery.sizeOf(context).width * 0.72,
                height: MediaQuery.sizeOf(context).height * 0.6,
                decoration: BoxDecoration(
                  color: AppColors.grey10,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.white,
                ),
                onPressed: () => Navigator.pushNamed(context, '/search'),
              ),
            ),
          ),
          Text(
            'V EFFECT',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.white,
              letterSpacing: 6.0,
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: StreamBuilder<int>(
                stream: _notificationStream,
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return IconButton(
                    icon: Badge(
                      isLabelVisible: count > 0,
                      label: Text('$count'),
                      child: const Icon(
                        Icons.notifications_outlined,
                        color: AppColors.white,
                      ),
                    ),
                    onPressed:
                        () => Navigator.pushNamed(context, AppRoutes.notifications),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department_outlined,
            color: AppColors.grey20,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'まだ投稿がありません',
            style: GoogleFonts.notoSansJp(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.grey50,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'フレンドを追加するか、\nみんなの投稿を待ちましょう',
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSansJp(
              fontSize: 13,
              color: AppColors.grey30,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuardedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.grey10,
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: Color(0xFFD4AF37),
                size: 48,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Victory を証明しましょう',
              style: GoogleFonts.notoSansJp(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '仲間の努力を見るには、まずあなた自身の今日の「V」を投稿する必要があります。',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansJp(
                fontSize: 14,
                color: AppColors.grey50,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardStack() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth * 0.85;
        final cardHeight = cardWidth * (16 / 9);
        final maxCardHeight = (constraints.maxHeight - 40).clamp(
          0.0,
          cardHeight,
        );
        final finalCardWidth = maxCardHeight * (9 / 16);

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            for (final i in _sortedCardIndices())
              _buildStackedCard(
                index: i,
                cardWidth: finalCardWidth,
                cardHeight: maxCardHeight,
              ),

            Positioned.fill(
              child: PageView.builder(
                controller: _pageController,
                physics: const _FrictionlessPageScrollPhysics(),
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  if (_feedPosts.isEmpty) return const SizedBox.shrink();
                  final actualIndex = index % _feedPosts.length;
                  final post = _feedPosts[actualIndex];

                  return Stack(
                    children: [
                      // 背景全体：タップでリアクション
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _sendReaction(_focusedIndex),
                        child: const SizedBox.expand(),
                      ),

                      // カード内の特定のインタラクティブエリア（プロフィール、リアクションボタンなど）
                      // カードのサイズと位置に合わせる
                      Center(
                        child: SizedBox(
                          width: finalCardWidth,
                          height: maxCardHeight,
                          child: Stack(
                            children: [
                              // プロフィールエリア（アイコンと名前）へのタップ
                              Positioned(
                                bottom: 30, // _FeedCardのPositionedと合わせる
                                left: 20,
                                width: finalCardWidth * 0.7, // 左側の概ね3/4
                                height: 80, // アイコンと名前を含むエリア
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    final photoUrl = _userPhotos[post.userId];
                                    final username = _userNames[post.userId] ?? 'User';
                                    Navigator.pushNamed(
                                      context,
                                      AppRoutes.userProfile,
                                      arguments: {
                                        'uid': post.userId,
                                        'username': username,
                                        'photoUrl': photoUrl,
                                      },
                                    );
                                  },
                                ),
                              ),

                              // 右下のリアクションボタンエリア
                              // 既に画面全体でタップを拾っているが、ここを明示的にタップした場合のフィードバック用（将来的に）
                              Positioned(
                                bottom: 30,
                                right: 20,
                                width: 60,
                                height: 80,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _sendReaction(_focusedIndex),
                                ),
                              ),
                            ],
                          ),
                        ),
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
  }

  List<int> _sortedCardIndices() {
    final indices = List.generate(_feedPosts.length, (i) => i);
    indices.sort((a, b) {
      if (_feedPosts.isEmpty) return 0;
      final halfLength = _feedPosts.length / 2.0;

      double distA = (a - _scrollPosition) % _feedPosts.length;
      if (distA > halfLength) distA -= _feedPosts.length;
      if (distA < -halfLength) distA += _feedPosts.length;
      final depthA = distA.abs();

      double distB = (b - _scrollPosition) % _feedPosts.length;
      if (distB > halfLength) distB -= _feedPosts.length;
      if (distB < -halfLength) distB += _feedPosts.length;
      final depthB = distB.abs();

      return depthB.compareTo(depthA);
    });
    return indices;
  }

  Widget _buildStackedCard({
    required int index,
    required double cardWidth,
    required double cardHeight,
  }) {
    final halfLength = _feedPosts.length / 2.0;
    double relativePos = (index - _scrollPosition) % _feedPosts.length;
    if (relativePos > halfLength) relativePos -= _feedPosts.length;
    if (relativePos < -halfLength) relativePos += _feedPosts.length;

    final double smoothDepth = relativePos.abs();

    // Tinder/Pokepoke風のスタック
    final scale = (1.0 - smoothDepth * 0.05).clamp(0.8, 1.0);
    final offsetY = smoothDepth * -20.0; // 奥のカードは少し上に配置される
    // 横方向へのスワイプ時の移動
    final offsetX = relativePos * cardWidth * 1.2;

    final dimAlpha = (smoothDepth * 0.2).clamp(0.0, 0.6); // 奥は暗く

    // スワイプ中のカードは回転させる（Tinder風）
    final rotateZ = relativePos * 0.1;

    // 現在フォーカスされているカード（一番手前）からどれくらい離れているか
    if (smoothDepth > 3) return const SizedBox.shrink(); // 3枚目以降は描画しない（軽量化）

    final post = _feedPosts[index];
    final username = _userNames[post.userId] ?? 'Unknown';
    final photoUrl = _userPhotos[post.userId];
    final streak = _userStreaks[post.userId] ?? 0;
    final tierColor = _getTierColor(streak);

    return Transform.translate(
      offset: Offset(offsetX, offsetY),
      child: Transform(
        alignment: Alignment.bottomCenter,
        transform:
            Matrix4.identity()
              ..rotateZ(rotateZ)
              ..scaleByDouble(scale, scale, scale, 1.0),
        child: SizedBox(
          width: cardWidth,
          height: cardHeight,
          child: _FeedCard(
            post: post,
            username: username,
            userPhotoUrl: photoUrl,
            dimAlpha: dimAlpha,
            onReaction: () => _sendReaction(index),
            isTop: index == _focusedIndex,
            tierColor: tierColor,
            onProfileTap: () {
              Navigator.pushNamed(
                context,
                AppRoutes.userProfile,
                arguments: {
                  'uid': post.userId,
                  'username': username,
                  'photoUrl': photoUrl,
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────
// Feed Card
// ────────────────────────────────────────────
class _FeedCard extends StatelessWidget {
  const _FeedCard({
    required this.post,
    required this.username,
    this.userPhotoUrl,
    required this.dimAlpha,
    required this.onReaction,
    required this.isTop,
    required this.tierColor,
    this.onProfileTap,
  });

  final Post post;
  final String username;
  final String? userPhotoUrl;
  final double dimAlpha;
  final VoidCallback onReaction;
  final bool isTop;
  final Color tierColor;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: AppColors.grey15,
        border: Border.all(
          color:
              isTop ? tierColor.withValues(alpha: 0.6) : tierColor.withValues(alpha: 0.1),
          width: isTop ? 1.5 : 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.6),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
          if (isTop)
            BoxShadow(
              color: tierColor.withValues(alpha: 0.15),
              blurRadius: 40,
              spreadRadius: 2,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 写真 (RepaintBoundary + CachedNetworkImage)
            RepaintBoundary(
              child: post.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: post.imageUrl!,
                      fit: BoxFit.cover,
                      memCacheWidth: 800, // カード表示なのでサイズを控えめにデコード
                      placeholder: (ctx, url) => Container(
                        color: AppColors.grey10,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFD4AF37),
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (ctx, url, error) => const Center(
                        child: Icon(
                          Icons.broken_image,
                          color: AppColors.grey30,
                          size: 40,
                        ),
                      ),
                    )
                  : Container(
                      color: AppColors.grey10,
                      child: const Center(
                        child:
                            Icon(Icons.image, color: AppColors.grey30, size: 60),
                      ),
                    ),
            ),

            // グラデーションオーバーレイ（下部を暗くしてテキストを読みやすく）
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 240,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      AppColors.black.withValues(alpha: 0.9),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ユーザー情報とタスク情報
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: onProfileTap,
                          child: Row(
                            mainAxisSize: MainAxisSize.min, // 行の幅を内容に合わせる
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.grey20,
                                backgroundImage: userPhotoUrl != null
                                    ? ResizeImage(
                                        CachedNetworkImageProvider(
                                            userPhotoUrl!),
                                        width: 100,
                                        height: 100)
                                    : null,
                                child: userPhotoUrl == null
                                    ? Text(
                                        username[0].toUpperCase(),
                                        style: const TextStyle(
                                          color: AppColors.white,
                                          fontSize: 12,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                username,
                                style: GoogleFonts.outfit(
                                  color: AppColors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (post.caption != null && post.caption!.isNotEmpty) ...[
                          Text(
                            post.caption!,
                            style: GoogleFonts.notoSerifJp(
                              color: AppColors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        Text(
                          post.taskName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.grey50,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // リアクションボタン
                  if (isTop)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: onReaction,
                          child: Container(
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
                              color: tierColor,
                              size: 32,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${post.reactionCount}',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // 暗幕レイヤー（奥にあるカードを暗くする）
            if (dimAlpha > 0)
              Positioned.fill(
                child: ColoredBox(color: AppColors.black.withValues(alpha: dimAlpha)),
              ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────
// リアクション層の分離
// ────────────────────────────────────────────
class _FloatingFlamesLayer extends StatefulWidget {
  const _FloatingFlamesLayer({super.key});

  @override
  State<_FloatingFlamesLayer> createState() => _FloatingFlamesLayerState();
}

class _FloatingFlamesLayerState extends State<_FloatingFlamesLayer> {
  int _counter = 0;
  final Map<int, Widget> _flames = {};

  void addFlame({bool isGold = false}) {
    final id = _counter++;
    final randomX = (Random().nextDouble() - 0.5) * 60;

    setState(() {
      _flames[id] = Positioned(
        key: ValueKey(id),
        bottom: 120,
        right: 40 + randomX,
        child: _FloatingFlameWidget(
          key: ValueKey('flame_$id'),
          isGold: isGold,
          onComplete: () {
            if (mounted) {
              setState(() => _flames.remove(id));
            }
          },
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: _flames.values.toList(),
    );
  }
}

// ────────────────────────────────────────────
// 連打で飛んでいく🔥アニメーションヴィジェット
// ────────────────────────────────────────────
class _FloatingFlameWidget extends StatefulWidget {
  final VoidCallback onComplete;
  final bool isGold;

  const _FloatingFlameWidget({
    super.key,
    required this.onComplete,
    this.isGold = false,
  });

  @override
  State<_FloatingFlameWidget> createState() => _FloatingFlameWidgetState();
}

class _FloatingFlameWidgetState extends State<_FloatingFlameWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _dy;
  late Animation<double> _opacity;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.isGold ? 1500 : 1000),
    );

    _dy = Tween<double>(
      begin: 0,
      end: widget.isGold ? -500 : -300,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.5, 1.0)));
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.5, end: widget.isGold ? 2.5 : 1.5),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: widget.isGold ? 2.5 : 1.5, end: 1.0),
        weight: 80,
      ),
    ]).animate(_ctrl);

    _ctrl.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _dy.value),
          child: Transform.scale(
            scale: _scale.value,
            child: Opacity(opacity: _opacity.value, child: child),
          ),
        );
      },
      child: Icon(
        Icons.whatshot,
        color:
            widget.isGold ? const Color(0xFFFFD700) : const Color(0xFFD4AF37),
        size: widget.isGold ? 64 : 44,
        shadows: [
          Shadow(
            color: widget.isGold ? Colors.white : Colors.white24,
            blurRadius: widget.isGold ? 24 : 12,
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────
// Custom Physics
// ────────────────────────────────────────────
class _FrictionlessPageScrollPhysics extends PageScrollPhysics {
  const _FrictionlessPageScrollPhysics({super.parent});

  @override
  _FrictionlessPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _FrictionlessPageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring =>
      // ζ ≈ 0.9（やや不足減衰）→ 約0.7秒で収束。旧値(damping:0.8)は実質無減衰で数十秒振動していた。
      const SpringDescription(mass: 4.0, stiffness: 100.0, damping: 36.0);

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    return offset * 1.2;
  }

  @override
  double get minFlingVelocity => 20.0;
}
