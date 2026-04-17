import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config/app_colors.dart';
import '../config/routes.dart';
import '../models/post.dart';
import '../services/post_service.dart';
import '../widgets/v_effect_header.dart';
import '../widgets/weekly_review_banner.dart';
import 'weekly_review_screen.dart';
import '../providers/home_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final ValueChanged<bool>? onLoadingChanged;

  const HomeScreen({super.key, this.onLoadingChanged});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  final PostService _postService = PostService.instance;
  bool _postedToday = false;
  List<Post> _feedPosts = [];
  List<Map<String, dynamic>> _postedFriends = []; // [{uid, username, photoUrl}]
  Map<String, String> _userNames = {}; // userId -> username
  Map<String, String?> _userPhotos = {}; // userId -> photoUrl
  Map<String, int> _userStreaks = {}; // userId -> streak
  HomeData? _lastHomeData;
  final Set<String> _reactingPostIds = {}; // 通信中の投稿IDを追跡
  // 送信済みだが Firestore 未確認の emoji。{emoji, uid} を記録して myUid null 問題を回避
  final Map<String, ({String emoji, String uid})> _pendingEmojis = {};

  // ── VFIRE デバウンス用 ──
  Timer? _flameDebounceTimer;
  int _pendingFlameCount = 0;
  String? _pendingFlamePostId;

  // ── Card Swiping ──
  // ── Card Swiping (Performance: Using AnimatedBuilder instead of setState) ──
  late final PageController _pageController;
  // pageController.page を直接参照するように変更
  int get _focusedIndex {
    if (_feedPosts.isEmpty) return 0;
    final len = _feedPosts.length;
    final pos = (_pageController.hasClients ? _pageController.page ?? 10000.0 : 10000.0).round();
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
  final GlobalKey<_DopamineEmojiExplosionLayerState> _explosionKey =
      GlobalKey();

  // ── ロックアイコンは子 Widget に切り出し ──

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

    _reactionMenuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    // _pulseController と _shakeController は _GuardedStateLayer 内に移動

    final initialPage = 10000;
    _pageController = PageController(initialPage: initialPage);
    // addListener 内の setState を削除（全画面リビルド回避）

    // データの読み込みは homeDataProvider (Riverpod) が担当するため
    // 手動の _loadData() は廃止
  }

  @override
  void dispose() {
    _pageController.dispose();
    _flashController.dispose();
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
        ResizeImage(CachedNetworkImageProvider(nextPost.imageUrl!), width: 800),
        context,
      );
    }
    // ここでの setState も不要。必要な部分は AnimatedBuilder で連動済み
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
    // _applyHomeDataUpdate が myUid=null 等で localHasEmoji を取れない場合のフォールバック
    if (emoji != null) {
      _pendingEmojis[post.id] = (emoji: emoji, uid: myUid);
    }
    setState(() {
      if (emoji != null) {
        // 絵文字リアクション：1回のみ
        final newUserReactions = Map<String, String>.from(post.userReactions);
        final currentEmoji = newUserReactions[myUid];
        if (currentEmoji == null || currentEmoji == '🔥') {
          newUserReactions[myUid] = emoji;
          debugPrint('[EMOJI_DEBUG] ✅ Optimistic update: post=${post.id.substring(0, 6)} emoji=$emoji uid=$myUid');
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
      // ※ updateStream が自動的にhomeDataProviderをソフトリフレッシュするため
      //   ref.invalidate() は不要（invalidateはUIをちらつかせる原因になる）
      try {
        _reactingPostIds.add(post.id);
        await _postService.addEmojiReaction(post.id, emoji);
      } catch (e) {
        debugPrint('Emoji reaction error: $e');
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
          } catch (e) {
            debugPrint('Flame sync error: $e');
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
          _pendingEmojis.remove(postId); // 3秒後フェイルセーフ
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
          builder:
              (context) =>
                  WeeklyReviewScreen(posts: posts, currentStreak: streak),
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

    // ── UIスレッドでの実行を保証し、ローカル状態を同期 (データがある場合のみ) ──
    homeAsync.whenData((homeData) {
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
            final localPost = _feedPosts.firstWhere(
              (p) => p.id == fetchedPost.id,
              orElse: () => fetchedPost,
            );
            final localHasEmoji = localPost.hasEmojiReacted(myUid);
            final fetchedHasEmoji = fetchedPost.hasEmojiReacted(myUid);

            if (localHasEmoji && !fetchedHasEmoji) {
              newPosts.add(localPost);
            } else {
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
    });


    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        children: [
          // 1. 背景
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

          // 2. メインコンテンツ
          // ガードレール: 一度でもデータを受信したら、プロバイダーの
          // loading/refreshing 状態に関わらず、絶対にスケルトンに戻さない。
          // ローカル状態変数 (_postedToday, _feedPosts 等) が常に最新であり、
          // UIの信頼できる唯一の情報源 (Single Source of Truth) として扱う。
          if (_lastHomeData == null) ...[
            // 初回ロード: まだ一度もデータを受信していない
            homeAsync.when(
              loading: () => _buildHomeSkeletonBody(),
              error: (err, stack) => _buildErrorBody(err),
              data: (_) => _buildMainContent(),
            ),
          ] else ...[
            // データ受信済み: 常にコンテンツを表示（リフレッシュ中もちらつかない）
            _buildMainContent(),
          ],

          // 3. V-Flash 演出レイヤー (永続)
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

          // 4. 炎のエフェクトレイヤー (永続)
          Positioned.fill(
            child: IgnorePointer(
              child: _FloatingFlamesLayer(key: _flamesKey),
            ),
          ),

          // 5. ドーパミン爆発レイヤー (永続)
          Positioned.fill(
            child: IgnorePointer(
              child: _DopamineEmojiExplosionLayer(key: _explosionKey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeSkeletonBody() {
    return SafeArea(
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
    );
  }

  /// ローカル状態変数を使ってメインコンテンツを構築する。
  /// プロバイダーの AsyncValue に依存しないため、リフレッシュ中もちらつかない。
  Widget _buildMainContent() {
    return SafeArea(
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
            child: !_postedToday
                ? _GuardedStateLayer(
                    feedPosts: _feedPosts,
                    postedFriends: _postedFriends,
                  )
                : (_feedPosts.isEmpty
                    ? _buildEmptyState()
                    : _buildCardStack()),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBody(Object err) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppColors.accentGold, size: 48),
          const SizedBox(height: 16),
          Text('エラーが発生しました', style: GoogleFonts.outfit(color: Colors.white)),
          const SizedBox(height: 8),
          Text('$err', style: TextStyle(color: AppColors.grey50, fontSize: 12)),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.grey10,
              foregroundColor: AppColors.white,
            ),
            onPressed: () => ref.invalidate(homeDataProvider),
            child: const Text('再試行'),
          )
        ],
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
            '誰もやらないなら、自分がやる。',
            style: GoogleFonts.notoSansJp(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.grey50,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '圧倒的な努力の証明を、今ここに。\nフィードが空なのは、あなたがトップランナーである証拠です。',
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



  Widget _buildCardStack() {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        if (_feedPosts.isEmpty) return const SizedBox.shrink();
        final scrollPos = _pageController.hasClients ? _pageController.page ?? 10000.0 : 10000.0;

        return LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth * 0.85;
            final cardHeight = cardWidth * (16 / 9);
            final maxCardHeight = (constraints.maxHeight - 40).clamp(0.0, cardHeight);
            final finalCardWidth = maxCardHeight * (9 / 16);

            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                for (final i in _sortedCardIndices(scrollPos))
                  _buildStackedCard(
                    index: i,
                    cardWidth: finalCardWidth,
                    cardHeight: maxCardHeight,
                    scrollPosition: scrollPos,
                  ),

                Positioned.fill(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const _FrictionlessPageScrollPhysics(),
                    onPageChanged: _onPageChanged,
                    itemBuilder: (context, index) {
                      final actualIndex = index % _feedPosts.length;
                      final post = _feedPosts[actualIndex];

                      final myUid = FirebaseAuth.instance.currentUser?.uid;
                      final alreadyReacted = post.hasEmojiReacted(myUid);

                      return Center(
                        child: SizedBox(
                          width: finalCardWidth,
                          height: maxCardHeight,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // 1. 写真エリア（上部タップ域）
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                bottom: 180,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
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
                              // (以下略: 他のボタン等も必要に応じて AnimatedBuilder で参照可能)

                          // 2. アバタータップエリア (中心をVFIREと合わせる: bottom 32 + text 16 + gap 16 + avatar 40 = 104 -> center 84)
                          Positioned(
                            bottom: 32,
                            left: 20,
                            width: 60,
                            height: 72,
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
                              bottom: 66, // 中心を84に合わせる (height約36 / 2 = 18)
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
                            bottom: 62, // 中心を84に合わせる (44 / 2 = 22)
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
                            bottom: 32, // テキスト領域(16) + 間隔(8) + 本体(56) の中心を84に合わせる
                            right: 20,
                            width: 56,
                            height: 80,
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
  },
);
}

  List<int> _sortedCardIndices(double scrollPosition) {
    if (_feedPosts.isEmpty) return [];
    final indices = List.generate(_feedPosts.length, (i) => i);
    indices.sort((a, b) {
      final halfLength = _feedPosts.length / 2.0;

      double distA = (a - scrollPosition) % _feedPosts.length;
      if (distA > halfLength) distA -= _feedPosts.length;
      if (distA < -halfLength) distA += _feedPosts.length;
      final depthA = distA.abs();

      double distB = (b - scrollPosition) % _feedPosts.length;
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
    required double scrollPosition,
  }) {
    final halfLength = _feedPosts.length / 2.0;
    double relativePos = (index - scrollPosition) % _feedPosts.length;
    if (relativePos > halfLength) relativePos -= _feedPosts.length;
    if (relativePos < -halfLength) relativePos += _feedPosts.length;

    final double smoothDepth = relativePos.abs();

    if (smoothDepth > 3) return const SizedBox.shrink(); // パフォーマンス最適化

    final double scale = (1.0 - smoothDepth * 0.05).clamp(0.8, 1.0);
    final double offsetY = smoothDepth * -20.0;
    final double offsetX = relativePos * cardWidth * 1.2;
    final double dimAlpha = (smoothDepth * 0.2).clamp(0.0, 0.6);
    final double rotateZ = relativePos * 0.1;

    final post = _feedPosts[index];
    final username = _userNames[post.userId] ?? 'Unknown';
    final photoUrl = _userPhotos[post.userId];
    final streak = _userStreaks[post.userId] ?? 0;
    final tierColor = _getTierColor(streak);

    return Transform.translate(
      offset: Offset(offsetX, offsetY),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..rotateZ(rotateZ)
          ..scale(scale, scale, scale),
        child: RepaintBoundary( // パフォーマンス: カード単位でキャッシュ
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
      ),
    );
  }
}

// ────────────────────────────────────────────
// Guarded State Layer (Performance optimization)
// ────────────────────────────────────────────
class _GuardedStateLayer extends StatefulWidget {
  final List<Post> feedPosts;
  final List<Map<String, dynamic>> postedFriends;

  const _GuardedStateLayer({
    required this.feedPosts,
    required this.postedFriends,
  });

  @override
  State<_GuardedStateLayer> createState() => _GuardedStateLayerState();
}

class _GuardedStateLayerState extends State<_GuardedStateLayer> with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (widget.feedPosts.isNotEmpty)
          Positioned.fill(
            child: RepaintBoundary( // ブラー計算をキャッシュ
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Opacity(
                  opacity: 0.4,
                  child: CachedNetworkImage(
                    imageUrl: widget.feedPosts.first.imageUrl!,
                    fit: BoxFit.cover,
                    memCacheWidth: 400,
                  ),
                ),
              ),
            ),
          ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.heavyImpact();
                  _shakeController.forward(from: 0);
                },
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _pulseController,
                      _shakeController,
                    ]),
                    builder: (context, child) {
                      final shakeOffset =
                          sin(_shakeController.value * pi * 4) * 8.0;
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

              if (widget.postedFriends.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 32,
                      width: (24.0 * widget.postedFriends.length.clamp(1, 5)) + 8,
                      child: Stack(
                        children: [
                          for (int i = 0; i < min(widget.postedFriends.length, 5); i++)
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
                                  backgroundImage: widget.postedFriends[i]['photoUrl'] != null
                                      ? CachedNetworkImageProvider(widget.postedFriends[i]['photoUrl'])
                                      : null,
                                  child: widget.postedFriends[i]['photoUrl'] == null
                                      ? Text(
                                          widget.postedFriends[i]['username'][0].toUpperCase(),
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
              isTop
                  ? AppColors.accentGold.withValues(alpha: 0.8)
                  : tierColor.withValues(alpha: 0.1),
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
              child:
                  post.imageUrl != null
                      ? AspectRatio(
                        aspectRatio: 9 / 16,
                        child: CachedNetworkImage(
                          imageUrl: post.imageUrl!,
                          fit: BoxFit.cover,
                          memCacheWidth: 800,
                          placeholder:
                              (ctx, url) => Container(
                                color: AppColors.grey10,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.accentGold,
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                          errorWidget:
                              (ctx, url, error) => const Center(
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
                          child: Icon(
                            Icons.image,
                            color: AppColors.grey30,
                            size: 60,
                          ),
                        ),
                      ),
            ),

            // [New] タスク名を左上に配置
            Positioned(
              top: 24,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.grey15.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(12),
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
              bottom: 32, // 絶対基準線の起点
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
                              horizontal: 16,
                              vertical: 12,
                            ),
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
                                height: 1.2, // 高さを制御
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
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 22,
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
                              const SizedBox(height: 14), // チェックマーク側(44px)と同期。中心を84pxに維持。
                              SizedBox(
                                height: 16,
                                child: Text(
                                  username,
                                  textAlign: TextAlign.center,
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
                                    color: AppColors.white.withValues(
                                      alpha: 0.1,
                                    ),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  Icons.local_fire_department,
                                  color: AppColors.accentGold,
                                  size: 32,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8), // 基準値
                            SizedBox(
                              height: 16, // 高さを固定して中心を安定させる
                              child: Text(
                                '${post.reactionCount}',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.white,
                                ),
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
                child: ColoredBox(
                  color: AppColors.black.withValues(alpha: dimAlpha),
                ),
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
    return Stack(children: _flames.values.toList());
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
        color: widget.isGold ? AppColors.accentGoldLight : AppColors.accentGold,
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
// CustomPainter ベース: 56ウィジェット×setState/frame → 1回のキャンバス再描画/frame
// ────────────────────────────────────────────

/// パーティクル1個の不変パラメータ（ウィジェットツリー不使用）
class _ParticleData {
  final double vx0;
  final double vy0;
  final double rotation0;
  final double rotationSpeed;
  final double startTime;
  final TextPainter textPainter; // レイアウト済みキャッシュ

  static const double lifetime = 1.2; // 秒

  _ParticleData({
    required String emoji,
    required this.vx0,
    required this.vy0,
    required this.rotation0,
    required this.rotationSpeed,
    required this.startTime,
    required double size,
  }) : textPainter = TextPainter(
         text: TextSpan(text: emoji, style: TextStyle(fontSize: size)),
         textDirection: TextDirection.ltr,
       )..layout();

  bool isDone(double elapsed) => elapsed - startTime >= lifetime;
}

class _DopamineEmojiExplosionLayer extends StatefulWidget {
  const _DopamineEmojiExplosionLayer({super.key});

  @override
  State<_DopamineEmojiExplosionLayer> createState() =>
      _DopamineEmojiExplosionLayerState();
}

class _DopamineEmojiExplosionLayerState
    extends State<_DopamineEmojiExplosionLayer>
    with SingleTickerProviderStateMixin {
  final List<_ParticleData> _particles = [];
  late final Ticker _ticker;
  double _elapsed = 0.0;
  Duration? _prevTickTime;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  void _onTick(Duration now) {
    if (_prevTickTime != null) {
      _elapsed += (now - _prevTickTime!).inMicroseconds / 1e6;
    }
    _prevTickTime = now;

    _particles.removeWhere((p) => p.isDone(_elapsed));

    if (!mounted) return;
    if (_particles.isEmpty) {
      _ticker.stop();
      _prevTickTime = null;
      _elapsed = 0.0;
    }
    setState(() {});
  }

  void explode(String emoji) {
    final random = Random();
    final t = _elapsed;

    final newParticles = List.generate(56, (_) {
      final angle = (pi + 0.3) + (random.nextDouble() * (pi - 0.6));
      final speed = 700.0 + random.nextDouble() * 1300.0;
      return _ParticleData(
        emoji: emoji,
        vx0: cos(angle) * speed,
        vy0: sin(angle) * speed,
        rotation0: random.nextDouble() * 2 * pi,
        rotationSpeed: (random.nextDouble() - 0.5) * 6.0,
        startTime: t,
        size: 20.0 + random.nextDouble() * 52.0,
      );
    });

    setState(() {
      _particles.addAll(newParticles);
      if (!_ticker.isActive) {
        _prevTickTime = null;
        _ticker.start();
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_particles.isEmpty) return const SizedBox.expand();
    return CustomPaint(
      painter: _EmojiExplosionPainter(particles: _particles, elapsed: _elapsed),
    );
  }
}

/// 全パーティクルをキャンバスに直接描画（ウィジェットリビルドなし）
class _EmojiExplosionPainter extends CustomPainter {
  final List<_ParticleData> particles;
  final double elapsed;

  static const double _gravity = 800.0; // px/秒²
  static const double _k = 0.7; // 空気抵抗係数

  _EmojiExplosionPainter({required this.particles, required this.elapsed});

  /// Elastic out イージング
  static double _elasticOut(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    return exp(log(2) * (-10 * t)) * sin((t * 10 - 0.75) * (2 * pi / 3)) + 1.0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = (elapsed - p.startTime).clamp(0.0, _ParticleData.lifetime);
      if (t <= 0) continue;

      // 解析的物理演算（フレームレート非依存）
      final expDecay = exp(-_k * t);
      final dx = p.vx0 / _k * (1.0 - expDecay);
      final dy =
          p.vy0 / _k * (1.0 - expDecay) +
          _gravity / _k * (t - (1.0 - expDecay) / _k);

      // キャンバス座標（下端120pxから上方向）
      final x = size.width / 2 + dx;
      final y = size.height - 120 + dy;

      final progress = t / _ParticleData.lifetime;

      // フェードアウト: 進行度70%以降で消える
      final opacity =
          progress < 0.7 ? 1.0 : (1.0 - (progress - 0.7) / 0.3).clamp(0.0, 1.0);
      if (opacity <= 0) continue;

      // スケール: elastic out で 0→1.5 (最初の30%), 線形で 1.5→1.0 (残り70%)
      final double scale;
      if (progress < 0.3) {
        scale = _elasticOut(progress / 0.3) * 1.5;
      } else {
        scale = 1.5 - 0.5 * ((progress - 0.3) / 0.7);
      }

      final rotation = p.rotation0 + p.rotationSpeed * t;
      final textSize = p.textPainter.size;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      canvas.scale(scale, scale);
      canvas.translate(-textSize.width / 2, -textSize.height / 2);

      if (opacity < 0.995) {
        // フェードアウト区間のみ saveLayer でアルファ合成（大半は不要）
        canvas.saveLayer(
          Rect.fromLTWH(0, 0, textSize.width, textSize.height),
          Paint()
            ..color = Color.fromARGB((opacity * 255).round(), 255, 255, 255),
        );
        p.textPainter.paint(canvas, Offset.zero);
        canvas.restore();
      } else {
        p.textPainter.paint(canvas, Offset.zero);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_EmojiExplosionPainter old) =>
      elapsed != old.elapsed || particles.length != old.particles.length;
}
