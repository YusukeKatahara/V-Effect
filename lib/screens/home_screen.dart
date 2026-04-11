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
import '../widgets/weekly_review_banner.dart';
import 'weekly_review_screen.dart';
import '../widgets/reaction_avatars.dart';
import '../providers/home_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final ValueChanged<bool>? onLoadingChanged;

  const HomeScreen({super.key, this.onLoadingChanged});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with TickerProviderStateMixin {
  final PostService _postService = PostService.instance;
  bool _postedToday = false;
  List<Post> _feedPosts = [];
  List<Map<String, dynamic>> _postedFriends = []; // [{uid, username, photoUrl}]
  Map<String, String> _userNames = {}; // userId -> username
  Map<String, String?> _userPhotos = {}; // userId -> photoUrl
  Map<String, int> _userStreaks = {}; // userId -> streak
  HomeData? _lastHomeData;
  final Set<String> _reactingPostIds = {}; // 通信中の投稿IDを追跡

  // ── VFIRE デバウンス用 ──
  Timer? _flameDebounceTimer;
  int _pendingFlameCount = 0;
  String? _pendingFlamePostId;

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

    // データの読み込みは homeDataProvider (Riverpod) が担当するため
    // 手動の _loadData() は廃止
  }

  @override
  void dispose() {
    _pageController.dispose();
    _flashController.dispose();
    _pulseController.dispose();
    _shakeController.dispose();
    _reactionMenuController.dispose();
    _flameDebounceTimer?.cancel();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (_feedPosts.isEmpty) return;
    
    // 次のカードの画像をプリキャッシュ
    final nextIndex = (index + 1) % _feedPosts.length;
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

  Future<void> _sendReaction(int index, {String? emoji}) async {
    if (_feedPosts.isEmpty) return;
    final post = _feedPosts[index];
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    if (myUid == null) return;

    // 絵文字リアクションは1回までに制限
    if (emoji != null) {
      if (post.hasEmojiReacted(myUid) || _reactingPostIds.contains(post.id)) {
        debugPrint('User already reacted or reaction is in progress');
        return;
      }
    }

    final isVFlash = emoji == null && Random().nextInt(100) == 0;

    // 演出の実行（これはタップごとに即座に行う）
    if (isVFlash) {
      HapticFeedback.heavyImpact();
      _flashController.forward(from: 0);
      _flamesKey.currentState?.addFlame(isGold: true);
    } else {
      if (emoji != null) {
        HapticFeedback.heavyImpact();
        _explosionKey.currentState?.explode(emoji);
      } else {
        HapticFeedback.mediumImpact();
        _flamesKey.currentState?.addFlame(isGold: false);
      }
    }

    // 1. Optimistic UI update (ローカル状態を即座に反映)
    setState(() {
      if (emoji != null) {
        // 絵文字リアクション：1回のみ
        final newUserReactions = Map<String, String>.from(post.userReactions);
        final currentEmoji = newUserReactions[myUid];
        if (currentEmoji == null || currentEmoji == '🔥') {
          newUserReactions[myUid] = emoji;
          final updatedIds = List<String>.from(post.emojiReactedUserIds);
          if (!updatedIds.contains(myUid)) updatedIds.add(myUid);
          
          _feedPosts = List.from(_feedPosts)
            ..[index] = post.copyWith(
              userReactions: newUserReactions,
              emojiReactedUserIds: updatedIds,
            );
        }
      } else {
        // VFIRE: カウントを増やす
        _feedPosts = List.from(_feedPosts)
            ..[index] = post.copyWith(reactionCount: post.reactionCount + 1);
      }
    });

    // 2. 通信処理
    if (emoji != null) {
      // 絵文字は即座に送信
      try {
        _reactingPostIds.add(post.id);
        await _postService.addEmojiReaction(post.id, emoji);
        ref.invalidate(homeDataProvider);
      } catch (e) {
        debugPrint('Emoji reaction error: $e');
        ref.invalidate(homeDataProvider);
      } finally {
        _cleanupReactionLock(post.id);
      }
    } else {
      // VFIRE はデバウンス（1秒間タップが止まるまで待機）
      _pendingFlameCount++;
      _pendingFlamePostId = post.id;
      _reactingPostIds.add(post.id); // 連打中もガードレールを維持

      _flameDebounceTimer?.cancel();
      _flameDebounceTimer = Timer(const Duration(seconds: 1), () async {
        final countToSend = _pendingFlameCount;
        final postIdToSend = _pendingFlamePostId;
        
        // バッファをリセット
        _pendingFlameCount = 0;
        _pendingFlamePostId = null;

        if (postIdToSend != null && countToSend > 0) {
          try {
            await _postService.incrementFlameCount(postIdToSend, countToSend);
            ref.invalidate(homeDataProvider);
          } catch (e) {
            debugPrint('Flame sync error: $e');
            ref.invalidate(homeDataProvider);
          } finally {
            _cleanupReactionLock(postIdToSend);
          }
        }
      });
    }
  }

  void _cleanupReactionLock(String postId) {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _reactingPostIds.remove(postId);
        });
      }
    });
  }

  Future<void> _openWeeklyReview() async {
    // 画面遷移中もホームのローディング通知を送る
    widget.onLoadingChanged?.call(true);
    try {
      final posts = await _postService.getWeeklyReviewPosts();
      final streak = await _postService.getStreak();
      if (!mounted) return;
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WeeklyReviewScreen(posts: posts, currentStreak: streak),
        ),
      );
    } on FirebaseException catch (e, stack) {
      debugPrint('WeeklyReview Load Error (Firebase): ${e.code}\n$e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('振り返りデータの取得に失敗しました (${e.code})')),
        );
      }
    } catch (e, stack) {
      debugPrint('WeeklyReview Load Error (Unexpected): $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('予期せぬエラーが発生しました')),
        );
      }
    } finally {
      if (mounted) widget.onLoadingChanged?.call(false);
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
    final homeAsync = ref.watch(homeDataProvider);

    return homeAsync.when(
      loading: () => _buildHomeSkeleton(),
      error: (err, stack) => Scaffold(
        backgroundColor: AppColors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.accentGold, size: 48),
              const SizedBox(height: 16),
              Text('エラーが発生しました: $err', style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(homeDataProvider),
                child: const Text('再試行'),
              )
            ],
          ),
        ),
      ),
      data: (homeData) {
        // UIスレッドでの実行を保証し、ローカル状態を同期
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onLoadingChanged?.call(false);
        });

        if (_lastHomeData != homeData) {
          _postedToday = homeData.postedToday;
          _postedFriends = homeData.postedFriends;
          _userNames = homeData.userNames;
          _userPhotos = homeData.userPhotos;
          _userStreaks = homeData.userStreaks;
          _lastHomeData = homeData;

          final myUid = FirebaseAuth.instance.currentUser?.uid;
          final newPosts = <Post>[];
          final List<String> idsToRemove = [];

          for (final fetchedPost in homeData.feedPosts) {
            if (_reactingPostIds.contains(fetchedPost.id)) {
              // 通信中または反映待ちの投稿
              final localPost = _feedPosts.firstWhere(
                (p) => p.id == fetchedPost.id,
                orElse: () => fetchedPost,
              );

              // Smart Merge:
              // 自分が絵文字を送った場合、最新データにその絵文字が反映されるまでローカルデータを優先
              final localHasEmoji = localPost.hasEmojiReacted(myUid);
              final fetchedHasEmoji = fetchedPost.hasEmojiReacted(myUid);

              if (localHasEmoji && !fetchedHasEmoji) {
                // まだデータが届いていないのでローカル（チェックマーク状態）を維持
                newPosts.add(localPost);
              } else {
                // 反映されたか、そもそも絵文字ではない（炎のみの更新など）場合は最新データを採用
                newPosts.add(fetchedPost);
                idsToRemove.add(fetchedPost.id);
              }
            } else {
              newPosts.add(fetchedPost);
            }
          }
          
          _feedPosts = newPosts;
          
          if (idsToRemove.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  for (final id in idsToRemove) {
                    _reactingPostIds.remove(id);
                  }
                });
              }
            });
          }
        }

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
                    SizedBox(
                      height: 76, 
                      child: Center(
                        child: (DateTime.now().weekday == DateTime.saturday ||
                                DateTime.now().weekday == DateTime.sunday)
                            ? WeeklyReviewBanner(onTap: _openWeeklyReview)
                            : const SizedBox.shrink(),
                      ),
                    ),
                    Expanded(
                      child: !homeData.postedToday
                          ? _buildGuardedState()
                          : (homeData.feedPosts.isEmpty
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
      },
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
        leading: IconButton(
          icon: const Icon(Icons.search_rounded, color: AppColors.white),
          onPressed: () => Navigator.pushNamed(context, '/search'),
        ),
        trailing: const NotificationBellIcon(),
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
                  memCacheWidth: 400, // ぼかすので低解像度で十分
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

                  final myUid = FirebaseAuth.instance.currentUser?.uid;
                  // 絵文字（VFIREの'🔥'以外）を送った場合のみチェックマークにする
                  final alreadyReacted = post.hasEmojiReacted(myUid);

                  return Center(
                    child: SizedBox(
                      width: finalCardWidth,
                      height: maxCardHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // 1. 写真エリア（上部タップ域）: タップでリアクション
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
                              bottom: 62, // トグルボタンと高さを合わせる
                              right: 140, // トグルボタン(88) + 幅(44) + 余白(8) = 140 から左へ展開
                              child: AnimatedOpacity(
                                opacity: _reactionMenuOpen ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 200),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
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
                                      return Opacity(
                                        opacity: alreadyReacted ? 0.4 : 1.0,
                                        child: AbsorbPointer(
                                          absorbing: alreadyReacted,
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () {
                                              _sendReaction(actualIndex,
                                                  emoji: emoji);
                                              setState(() =>
                                                  _reactionMenuOpen = false);
                                              _reactionMenuController.reverse();
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 10, vertical: 4),
                                              child: Text(
                                                emoji,
                                                style:
                                                    const TextStyle(fontSize: 24),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),

                          // ＋ または ✓ トグルボタン
                          Positioned(
                            bottom: 62,
                            right: 88,
                            width: 44,
                            height: 44,
                            child: Opacity(
                              opacity: alreadyReacted ? 0.7 : 1.0,
                              child: AbsorbPointer(
                                absorbing: alreadyReacted,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    setState(() => _reactionMenuOpen =
                                        !_reactionMenuOpen);
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
                                      turns: _reactionMenuOpen ? 0.125 : 0.0,
                                      duration:
                                          const Duration(milliseconds: 220),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.white
                                              .withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: alreadyReacted
                                                ? AppColors.white
                                                    .withValues(alpha: 0.4)
                                                : AppColors.white
                                                    .withValues(alpha: 0.15),
                                            width: 1,
                                          ),
                                        ),
                                        child: Icon(
                                          alreadyReacted
                                              ? Icons.check_rounded
                                              : Icons.add_rounded,
                                          color: AppColors.white,
                                          size: 24,
                                        ),
                                      ),
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

                          // 以前表示していたリアクションアバター群は、ユーザー要望により削除
                        ],
                      ),
                    ),
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
            onReaction: ({emoji}) => _sendReaction(index, emoji: emoji),
            isTop: index == _focusedIndex,
            tierColor: tierColor,
            userPhotos: _userPhotos,
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
    required this.userPhotos,
    this.onProfileTap,
  });

  final Post post;
  final String username;
  final String? userPhotoUrl;
  final double dimAlpha;
  final Function({String? emoji}) onReaction;
  final bool isTop;
  final Color tierColor;
  final Map<String, String?> userPhotos;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: AppColors.grey15,
        border: Border.all(
          color:
              isTop ? AppColors.accentGold.withValues(alpha: 0.8) : tierColor.withValues(alpha: 0.1),
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
              color: AppColors.accentGold.withValues(alpha: 0.15),
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
                              const SizedBox(height: 8), // 間隔を詰める
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

                  // リアクションボタン: [アバター] [＋/チェック] [🔥]
                  if (isTop)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // [修正] リアクションアバターと拡張メニューを非表示化（PageViewレイヤーかHeroTasksScreenで管理）

                        // V Fire ボタン＋カウント（表示専用）
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
    // パーティクル数を大幅増量 (24 -> 56)
    final newParticles = List.generate(56, (i) {
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

    // 下部メニュー付近から噴出
    _position = const Offset(0, 100);

    // 放射状にランダムなベクトル (より広角・高速に)
    final angle = (pi + 0.3) + (_random.nextDouble() * (pi - 0.6)); // 上方広角
    final speed = 12.0 + _random.nextDouble() * 22.0; // 初速アップ
    _vx = cos(angle) * speed;
    _vy = sin(angle) * speed;

    _rotation = _random.nextDouble() * 2 * pi;
    _rotationSpeed = (_random.nextDouble() - 0.5) * 0.6;

    _ctrl.addListener(() {
      if (mounted) {
        setState(() {
          _position += Offset(_vx, _vy);
          _vy += 0.5; // 重力
          _vx *= 0.97; // 空気抵抗
          _rotation += _rotationSpeed;
        });
      }
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
    // サイズを大小ランダムに散らす (20px 〜 72px)
    final randomSize = 20.0 + (_random.nextDouble() * 52.0);

    return Positioned(
      bottom: 120 - _position.dy,
      left: MediaQuery.of(context).size.width / 2 + _position.dx - 20,
      child: FadeTransition(
        opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
          CurvedAnimation(parent: _ctrl, curve: const Interval(0.7, 1.0)),
        ),
        child: ScaleTransition(
          scale: TweenSequence<double>([
            TweenSequenceItem(
              tween: Tween(begin: 0.0, end: 1.5).chain(CurveTween(curve: Curves.elasticOut)),
              weight: 30,
            ),
            TweenSequenceItem(
              tween: Tween(begin: 1.5, end: 1.0),
              weight: 70,
            ),
          ]).animate(_ctrl),
          child: Transform.rotate(
            angle: _rotation,
            child: Text(
              widget.emoji,
              style: TextStyle(fontSize: randomSize),
            ),
          ),
        ),
      ),
    );
  }
}


