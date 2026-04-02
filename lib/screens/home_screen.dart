import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config/app_colors.dart';
import '../config/routes.dart';
import '../models/post.dart';
import '../services/post_service.dart';
import '../services/analytics_service.dart';
import '../widgets/v_effect_header.dart';


class HomeScreen extends StatefulWidget {
  final ValueChanged<bool>? onLoadingChanged;

  const HomeScreen({super.key, this.onLoadingChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final PostService _postService = PostService.instance;
  StreamSubscription? _updateSubscription;
  bool _loading = true;
  bool _postedToday = false;
  List<Post> _feedPosts = [];
  List<Map<String, dynamic>> _postedFriends = []; // [{uid, username, photoUrl}]
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
  // ── リアクションメニュー用 ──
  bool _reactionMenuOpen = false;
  late final AnimationController _reactionMenuController;
  static const _reactionEmojis = ['❤️', '🔥', '👍'];
  final GlobalKey<_DopamineEmojiExplosionLayerState> _explosionKey = GlobalKey();


  // ── ガード状態演出用 ──
  late final AnimationController _pulseController;

  // ── ロックアイコン シェイク演出用 ──
  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flashAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.8), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 0.0), weight: 80),
    ]).animate(_flashController);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _reactionMenuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );


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
    _pulseController.dispose();
    _shakeController.dispose();
    _reactionMenuController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (_feedPosts.isEmpty) return;
    final nextIndex = (index + 1) % _feedPosts.length;


    // 次의 카드의 画像をプリキャッシュ
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

      // 投稿済みのフレンドを抽出
      final postedFriends = <Map<String, dynamic>>[];
      final seenUids = <String>{};
      for (final post in posts) {
        if (!seenUids.contains(post.userId)) {
          seenUids.add(post.userId);
          postedFriends.add({
            'uid': post.userId,
            'username': names[post.userId] ?? 'Unknown',
            'photoUrl': photos[post.userId],
          });
        }
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
        _postedFriends = postedFriends;
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

  Future<void> _sendReaction(int index, {String? emoji}) async {
    if (_feedPosts.isEmpty) return;
    final post = _feedPosts[index];
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    // 絵文字リアクションの1回制限チェック
    if (emoji != null && myUid != null) {
      if (post.emojiReactedUserIds.contains(myUid)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('絵文字リアクションは1回までです'),
            duration: Duration(seconds: 1),
          ),
        );
        return;
      }
    }

    final isVFlash = emoji == null && Random().nextInt(100) == 0;

    if (isVFlash) {
      HapticFeedback.heavyImpact();
      _flashController.forward(from: 0);
      _flamesKey.currentState?.addFlame(isGold: true);
    } else {
      // 絵文字リアクション、または通常のV Fire
      if (emoji != null) {
        // ドーパミン演出！
        HapticFeedback.heavyImpact();
        _explosionKey.currentState?.explode(emoji);
      } else {
        HapticFeedback.mediumImpact();
        _flamesKey.currentState?.addFlame(isGold: false);
      }
    }

    // Optimistic UI update
    setState(() {
      final updatedIds = emoji != null && myUid != null
          ? [...post.emojiReactedUserIds, myUid]
          : post.emojiReactedUserIds;

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
          emojiReactedUserIds: updatedIds,
        );
    });

    try {
      await _postService.addReaction(post.id, emoji: emoji);
    } catch (e) {
      debugPrint('Reaction error: $e');
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

          // ── 炎のエフェクトレイヤー (最前面) ──
          Positioned.fill(
            child: IgnorePointer(
              child: _FloatingFlamesLayer(key: _flamesKey),
            ),
          ),

          // ── ドーパミン爆発レイヤー (最前面) ──
          Positioned.fill(
            child: IgnorePointer(
              child: _DopamineEmojiExplosionLayer(key: _explosionKey),
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

  Widget _buildTitleBar() => VEffectHeader(
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.search_rounded, color: AppColors.white),
              onPressed: () => Navigator.pushNamed(context, '/search'),
            ),
            const NotificationBellIcon(),
          ],
        ),
      );

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
    return Stack(
      alignment: Alignment.center,
      children: [
        // ── 背面プレビュー (Blur) ──
        if (_feedPosts.isNotEmpty)
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Opacity(
                opacity: 0.4,
                child: CachedNetworkImage(
                  imageUrl: _feedPosts.first.imageUrl!,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

        // ── コンテンツ ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 鍵アイコン + パルスアニメーション (固定サイズでレイアウトを安定させる)
              GestureDetector(
                onTap: () {
                  HapticFeedback.heavyImpact();
                  _shakeController.forward(from: 0);
                },
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_pulseController, _shakeController]),
                    builder: (context, child) {
                      final shakeOffset = sin(_shakeController.value * pi * 4) * 8.0;
                      return Transform.translate(
                        offset: Offset(shakeOffset, 0),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 100 + (20 * _pulseController.value),
                              height: 100 + (20 * _pulseController.value),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.accentGold.withValues(
                                    alpha: 1.0 - _pulseController.value,
                                  ),
                                  width: 2,
                                ),
                              ),
                            ),
                            child!,
                          ],
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.grey10.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.accentGold.withValues(alpha: 0.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentGold.withValues(alpha: 0.2),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        color: AppColors.accentGold,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 48),

              // ソーシャル・プレゼンス
              if (_postedFriends.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 32,
                      width: (24.0 * _postedFriends.length.clamp(1, 5)) + 8,
                      child: Stack(
                        children: [
                          for (int i = 0; i < min(_postedFriends.length, 5); i++)
                            Positioned(
                              left: i * 20.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.black,
                                    width: 2,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppColors.grey20,
                                  backgroundImage: _postedFriends[i]['photoUrl'] != null
                                      ? CachedNetworkImageProvider(_postedFriends[i]['photoUrl'])
                                      : null,
                                  child: _postedFriends[i]['photoUrl'] == null
                                      ? Text(
                                          _postedFriends[i]['username'][0].toUpperCase(),
                                          style: const TextStyle(fontSize: 10),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '仲間の努力が届いています',
                      style: GoogleFonts.notoSansJp(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.grey50,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              Text(
                'Victory を証明しましょう',
                style: GoogleFonts.notoSansJp(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'あなたの「V」を投稿して、\n今日という日を完成させよう。',
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
      ],
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
                      // 1. 写真エリア（上部のみ）: タップでリアクション
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        bottom: 180,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            // メニューが開いているときは閉じる、そうでなければリアクション
                            if (_reactionMenuOpen) {
                              setState(() => _reactionMenuOpen = false);
                              _reactionMenuController.reverse();
                            } else {
                              _sendReaction(actualIndex);
                            }
                          },
                          child: const SizedBox.expand(),
                        ),
                      ),

                      // 2. アバタータップエリア (アイコンのみ)
                      Center(
                        child: SizedBox(
                          width: finalCardWidth,
                          height: maxCardHeight,
                          child: Stack(
                            children: [
                              Positioned(
                                bottom: 30,
                                left: 20,
                                width: 50,
                                height: 50,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    final photoUrl = _userPhotos[post.userId];
                                    final username =
                                        _userNames[post.userId] ?? 'User';
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

                              // 拡張リアクション エモジピルズ
                              if (_reactionMenuOpen)
                                Positioned(
                                  bottom: 62,
                                  right: 142,
                                  child: AnimatedOpacity(
                                    opacity: _reactionMenuOpen ? 1.0 : 0.0,
                                    duration: const Duration(milliseconds: 200),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: AppColors.grey15
                                            .withValues(alpha: 0.95),
                                        borderRadius: BorderRadius.circular(30),
                                        border: Border.all(
                                          color: AppColors.white
                                              .withValues(alpha: 0.1),
                                          width: 0.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.black
                                                .withValues(alpha: 0.3),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: _reactionEmojis.map((emoji) {
                                          return GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () {
                                              _sendReaction(actualIndex,
                                                  emoji: emoji);
                                              setState(() =>
                                                  _reactionMenuOpen = false);
                                              _reactionMenuController.reverse();
                                            },
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
                                              child: Text(
                                                emoji,
                                                style: const TextStyle(
                                                    fontSize: 28),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),

                              // ＋ トグルボタン
                              Positioned(
                                bottom: 62, // 火炎アイコンと中心位置を完全に同期 (84px - 22px)
                                right: 88, // V Fire(56) + 間隔(10) + 22
                                width: 44,
                                height: 44,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    setState(() =>
                                        _reactionMenuOpen = !_reactionMenuOpen);
                                    if (_reactionMenuOpen) {
                                      _reactionMenuController.forward();
                                    } else {
                                      _reactionMenuController.reverse();
                                    }
                                  },
                                  child: AnimatedBuilder(
                                    animation: _reactionMenuController,
                                    builder: (context, child) =>
                                        AnimatedRotation(
                                      turns:
                                          _reactionMenuOpen ? 0.125 : 0.0,
                                      duration:
                                          const Duration(milliseconds: 220),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.white
                                              .withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppColors.white
                                                .withValues(alpha: 0.15),
                                            width: 1,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.add_rounded,
                                          color: AppColors.white,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // V Fire ボタン
                              Positioned(
                                bottom: 56, // カウントテキスト(約20) + 間隔(6) + 基底(30)
                                right: 20,
                                width: 56,
                                height: 56,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _sendReaction(actualIndex),
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
        alignment: Alignment.center,
        transform:
            Matrix4.identity()
              ..rotateZ(rotateZ)
              ..scale(scale, scale, scale),
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
                  ? AspectRatio(
                      aspectRatio: 9 / 16,
                      child: CachedNetworkImage(
                        imageUrl: post.imageUrl!,
                        fit: BoxFit.cover,
                        memCacheWidth: 800,
                        placeholder: (ctx, url) => Container(
                          color: AppColors.grey10,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.accentGold,
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

            // [New] タスク名を左上に配置
            Positioned(
              top: 24,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.white.withValues(alpha: 0.1),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  post.taskName,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.grey50,
                    letterSpacing: 1,
                  ),
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

            // ユーザー情報とタスク情報 (Zenly-style Thought Bubble)
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Zenly-style vertical stack (Bubble -> Dot -> Avatar -> Name)
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (post.caption != null &&
                            post.caption!.isNotEmpty) ...[
                          // Main bubble (no tap handler — not a profile link)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            constraints: const BoxConstraints(maxWidth: 240),
                            decoration: BoxDecoration(
                              color: AppColors.grey15.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: AppColors.white.withValues(alpha: 0.1),
                                width: 0.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.black.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              post.caption!,
                              style: GoogleFonts.notoSerifJp(
                                color: AppColors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                          ),
                          // Tiny thought dot
                          Padding(
                            padding: const EdgeInsets.only(left: 18, top: 2),
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.grey15.withValues(alpha: 0.95),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.white.withValues(alpha: 0.1),
                                  width: 0.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        // Avatar + Username — only these trigger profile tap
                        GestureDetector(
                          onTap: onProfileTap,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AppColors.grey20,
                                  backgroundImage: userPhotoUrl != null
                                      ? ResizeImage(
                                          CachedNetworkImageProvider(userPhotoUrl!),
                                          width: 120)
                                      : null,
                                  child: userPhotoUrl == null
                                      ? Text(
                                          username[0].toUpperCase(),
                                          style: const TextStyle(
                                            color: AppColors.white,
                                            fontSize: 14,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 21), // 中心を 84px (30+13+21+20) に合わせる
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Text(
                                  username,
                                  style: GoogleFonts.outfit(
                                    color: AppColors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // リアクションボタン: [🔥] （表示専用、＋はPV層に集約）
                  if (isTop)
                    IgnorePointer(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // ＋ボタン用のスペースのみ確保して、二重表示を回避
                          const SizedBox(width: 54), // 44 + 10
                          // V Fire ボタン＋カウント（表示専用）
                          Column(
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
                                  color: tierColor,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(height: 12), // 中心を 84px (30+14+12+28) に合わせる
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
// 拡張リアクションメニュー
// ────────────────────────────────────────────
class _ExpandableReactionMenu extends StatefulWidget {
  final void Function(String emoji) onReact;

  const _ExpandableReactionMenu({required this.onReact});

  @override
  State<_ExpandableReactionMenu> createState() =>
      _ExpandableReactionMenuState();
}

class _ExpandableReactionMenuState extends State<_ExpandableReactionMenu>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late AnimationController _controller;
  late Animation<double> _widthFactor;
  late Animation<double> _opacity;

  static const _emojis = ['❤️', '🔥', '👍'];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _widthFactor = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _isOpen = !_isOpen);
    if (_isOpen) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _react(String emoji) {
    widget.onReact(emoji);
    setState(() => _isOpen = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Expanded emoji pills (slides in from the right)
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return ClipRect(
              child: Align(
                alignment: Alignment.centerRight,
                widthFactor: _widthFactor.value,
                child: Opacity(
                  opacity: _opacity.value,
                  child: child,
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.grey15.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: AppColors.white.withValues(alpha: 0.1),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: _emojis.map((emoji) {
                return GestureDetector(
                  onTap: () => _react(emoji),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Toggle button
        GestureDetector(
          onTap: _toggle,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.white.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: AnimatedRotation(
              turns: _isOpen ? 0.125 : 0.0,
              duration: const Duration(milliseconds: 220),
              child: const Icon(
                Icons.add_rounded,
                color: AppColors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ],
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
            widget.isGold ? AppColors.accentGoldLight : AppColors.accentGold,
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

// ────────────────────────────────────────────
// ドーパミン全開！絵文字爆発レイヤー
// ────────────────────────────────────────────
class _DopamineEmojiExplosionLayer extends StatefulWidget {
  const _DopamineEmojiExplosionLayer({super.key});

  @override
  State<_DopamineEmojiExplosionLayer> createState() =>
      _DopamineEmojiExplosionLayerState();
}

class _DopamineEmojiExplosionLayerState
    extends State<_DopamineEmojiExplosionLayer> {
  final List<Widget> _particles = [];
  int _counter = 0;

  void explode(String emoji) {
    final newParticles = List.generate(24, (i) {
      final id = _counter++;
      return _DopamineParticle(
        key: ValueKey(id),
        emoji: emoji,
        onComplete: () {
          if (mounted) {
            setState(() {
              _particles.removeWhere((p) => p.key == ValueKey(id));
            });
          }
        },
      );
    });

    setState(() {
      _particles.addAll(newParticles);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: _particles);
  }
}

class _DopamineParticle extends StatefulWidget {
  final String emoji;
  final VoidCallback onComplete;

  const _DopamineParticle({
    super.key,
    required this.emoji,
    required this.onComplete,
  });

  @override
  State<_DopamineParticle> createState() => _DopamineParticleState();
}

class _DopamineParticleState extends State<_DopamineParticle>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late double _vx;
  late double _vy;
  late double _rotation;
  late double _rotationSpeed;
  late Offset _position;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // 下部メニュー付近 (画面中央下寄り) から噴出
    _position = const Offset(0, 300);

    // 放射状にランダムなベクトル
    final angle = (_random.nextDouble() * pi) + pi; // 上方向 180度
    final speed = 8.0 + _random.nextDouble() * 12.0;
    _vx = cos(angle) * speed;
    _vy = sin(angle) * speed;

    _rotation = _random.nextDouble() * 2 * pi;
    _rotationSpeed = (_random.nextDouble() - 0.5) * 0.4;

    _ctrl.addListener(() {
      setState(() {
        _position += Offset(_vx, _vy);
        _vy += 0.4; // 重力
        _vx *= 0.98; // 空気抵抗
        _rotation += _rotationSpeed;
      });
    });

    _ctrl.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 100 - _position.dy,
      left: MediaQuery.of(context).size.width / 2 + _position.dx - 20,
      child: FadeTransition(
        opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
          CurvedAnimation(parent: _ctrl, curve: const Interval(0.6, 1.0)),
        ),
        child: Transform.rotate(
          angle: _rotation,
          child: Text(
            widget.emoji,
            style: const TextStyle(fontSize: 32),
          ),
        ),
      ),
    );
  }
}
