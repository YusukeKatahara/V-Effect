import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // kIsWeb 用
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/app_colors.dart';
import '../config/routes.dart';
import '../models/post.dart';
import '../providers/service_providers.dart';
import '../services/post_service.dart';
import '../services/sound_service.dart';
import '../widgets/v_effect_header.dart';
import '../widgets/native_ad_card.dart';
import '../utils/ad_helper.dart';
import 'home/components/floating_flames_layer.dart';
import 'home/components/dopamine_emoji_explosion_layer.dart';
import 'home/components/feed_card.dart';

/// 全体公開（Vタイムライン）用の投稿を配信するStreamProvider
final vTimelinePostsProvider = StreamProvider.autoDispose<List<Post>>((ref) {
  final postService = ref.watch(postServiceProvider);
  return postService.getPublicPostsStream();
});

/// 推薦ユーザー限定のパブリックVタイムライン画面
/// 自分が未投稿でも、推薦ユーザーが全体公開した努力ログをぼかし制限なしで閲覧可能
class VTimelineScreen extends ConsumerStatefulWidget {
  const VTimelineScreen({super.key});

  @override
  ConsumerState<VTimelineScreen> createState() => _VTimelineScreenState();
}

class _VTimelineScreenState extends ConsumerState<VTimelineScreen> with TickerProviderStateMixin {
  late final PostService _postService;
  late final SoundService _soundService;

  final PageController _pageController = PageController(viewportFraction: 0.85);
  final GlobalKey<FloatingFlamesLayerState> _flamesKey = GlobalKey<FloatingFlamesLayerState>();
  final GlobalKey<DopamineEmojiExplosionLayerState> _explosionKey = GlobalKey<DopamineEmojiExplosionLayerState>();

  List<dynamic> _feedItems = []; // Post または 'ad'
  int _focusedGlobalIndex = 100000;
  bool _loadingProfiles = true;

  // ユーザープロフィールのマッピング情報キャッシュ
  final Map<String, String> _userNames = {};
  final Map<String, String?> _userPhotos = {};
  final Map<String, String?> _userBadgeUrls = {};
  final Map<String, String?> _userBadgeAnimations = {};

  // 広告管理
  final Map<int, NativeAd> _nativeAds = {};
  final Map<int, bool> _adLoadStatus = {}; // true: loaded, false: failed
  Timer? _adRefreshTimer;

  // VFIRE リアクション処理用
  final Map<String, int> _pendingFlameCounts = {};
  final Map<String, Timer> _flameDebounceTimers = {};
  final Map<String, int> _localFlameIncrements = {};

  // BGM再生アニメーション
  late final AnimationController _bumpController;

  @override
  void initState() {
    super.initState();
    _postService = ref.read(postServiceProvider);
    _soundService = ref.read(soundServiceProvider);

    _bumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // PageViewの初期インデックスを設定
    _pageController.addListener(() {
      if (_pageController.hasClients) {
        final page = _pageController.page ?? 100000.0;
        final index = page.round();
        if (index != _focusedGlobalIndex) {
          setState(() {
            _focusedGlobalIndex = index;
          });
          _onFocusedIndexChanged(index);
        }
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bumpController.dispose();
    _adRefreshTimer?.cancel();
    for (final ad in _nativeAds.values) {
      ad.dispose();
    }
    for (final timer in _flameDebounceTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  // ── ユーザープロフィール取得＆マッピング ──
  Future<void> _loadUserProfiles(List<Post> posts) async {
    final uids = posts.map((p) => p.userId).toSet().toList();
    if (uids.isEmpty) {
      if (mounted) setState(() => _loadingProfiles = false);
      return;
    }

    try {
      final profiles = await _postService.getFriendsListFromUids(uids);
      if (!mounted) return;

      setState(() {
        for (final p in profiles) {
          final uid = p['uid'] as String;
          _userNames[uid] = p['username'] as String? ?? 'Unknown';
          _userPhotos[uid] = p['photoUrl'] as String?;
          _userBadgeUrls[uid] = p['equippedBadgeUrl'] as String?;
          _userBadgeAnimations[uid] = p['equippedBadgeAnimation'] as String?;
        }
        _loadingProfiles = false;
      });
    } catch (e) {
      debugPrint('Error loading profiles for V-Timeline: $e');
      if (mounted) setState(() => _loadingProfiles = false);
    }
  }

  // ── フィードアイテムの構築（広告挿入） ──
  void _setupFeedItems(List<Post> posts) {
    final newItems = <dynamic>[];
    final bool shouldInsertAd = !kIsWeb && posts.length >= 3;

    for (int i = 0; i < posts.length; i++) {
      newItems.add(posts[i]);
      // 2枚目(インデックス1)の直後に広告、その後は5投稿ごとに広告
      if (shouldInsertAd) {
        if (i == 1 || (i > 1 && (i - 1) % 5 == 0)) {
          newItems.add('ad');
        }
      }
    }

    if (_feedItems.length != newItems.length) {
      setState(() {
        _feedItems = newItems;
      });
      // 初回ロード完了時は、初期表示位置のプリキャッシュとBGM再生
      if (newItems.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _precacheInitialFeed();
          _playBgmForFocusedPost();
        });
      }
    }
  }

  // ── 広告の管理 ──
  void _loadAdForGlobalIndex(int globalIndex) {
    if (_nativeAds.containsKey(globalIndex) || _adLoadStatus.containsKey(globalIndex)) return;

    final ad = NativeAd(
      adUnitId: AdHelper.nativeAdUnitId,
      request: const AdRequest(),
      factoryId: 'customNativeAd',
      listener: NativeAdListener(
        onAdLoaded: (loadedAd) {
          if (mounted) {
            setState(() {
              _adLoadStatus[globalIndex] = true;
            });
          }
        },
        onAdFailedToLoad: (failedAd, error) {
          debugPrint('V-Timeline NativeAd failed: $error');
          failedAd.dispose();
          if (mounted) {
            setState(() {
              _adLoadStatus[globalIndex] = false;
            });
          }
        },
      ),
    );
    _nativeAds[globalIndex] = ad;
    ad.load();
  }

  void _preloadAdsNearFocusedIndex() {
    if (_feedItems.isEmpty) return;
    for (int i = -1; i <= 1; i++) {
      final targetPage = _focusedGlobalIndex + i;
      final actualIndex = (targetPage % _feedItems.length + _feedItems.length) % _feedItems.length;
      if (_feedItems[actualIndex] is String && _feedItems[actualIndex] == 'ad') {
        _loadAdForGlobalIndex(targetPage);
      }
    }
  }

  void _startAdRefreshTimer(int globalIndex) {
    _adRefreshTimer?.cancel();
    _adRefreshTimer = Timer(const Duration(seconds: 30), () {
      if (_focusedGlobalIndex == globalIndex) {
        final ad = _nativeAds[globalIndex];
        if (ad != null) {
          ad.dispose();
          _nativeAds.remove(globalIndex);
          _adLoadStatus.remove(globalIndex);
        }
        _loadAdForGlobalIndex(globalIndex);
        _startAdRefreshTimer(globalIndex);
      }
    });
  }

  void _onFocusedIndexChanged(int index) {
    if (_feedItems.isEmpty) return;
    _playBgmForFocusedPost();

    final actualIndex = (index % _feedItems.length + _feedItems.length) % _feedItems.length;
    final item = _feedItems[actualIndex];

    if (item is String && item == 'ad') {
      _startAdRefreshTimer(index);
    } else {
      _adRefreshTimer?.cancel();
    }
  }

  // ── BGM再生 ──
  void _playBgmForFocusedPost() {
    if (_feedItems.isEmpty) return;
    final actualIndex = (_focusedGlobalIndex % _feedItems.length + _feedItems.length) % _feedItems.length;
    final item = _feedItems[actualIndex];

    if (item is Post && item.bgmUrl != null) {
      _soundService.playBgm(item.bgmUrl!);
      _bumpController.forward(from: 0.0);
    } else {
      _soundService.stopBgm();
    }
  }

  void _precacheInitialFeed() {
    for (int i = 0; i < 5 && i < _feedItems.length; i++) {
      final item = _feedItems[i];
      if (item is Post && item.imageUrl != null) {
        precacheImage(CachedNetworkImageProvider(item.imageUrl!), context);
      }
    }
  }

  void _onPageChanged(int index) {
    if (_feedItems.isEmpty) return;

    final actualIndex = (index % _feedItems.length + _feedItems.length) % _feedItems.length;
    final currentItem = _feedItems[actualIndex];
    if (currentItem is Post) {
      _adRefreshTimer?.cancel();
    } else if (currentItem is String && currentItem == 'ad') {
      _startAdRefreshTimer(index);
    } else {
      _adRefreshTimer?.cancel();
    }

    // 次の5枚の画像をプリキャッシュ
    for (int i = 1; i <= 5; i++) {
      final nextIndex = (index + i) % _feedItems.length;
      final item = _feedItems[nextIndex];
      if (item is Post && item.imageUrl != null) {
        precacheImage(CachedNetworkImageProvider(item.imageUrl!), context);
      }
    }
  }

  // ── VFIREリアクション処理（炎ボタン） ──
  void _onFlameReaction(Post post) {
    HapticFeedback.lightImpact();

    // 炎の浮遊エフェクトを発火
    _flamesKey.currentState?.addFlame();

    // ドーパミンエフェクト
    _explosionKey.currentState?.explode('🔥');

    setState(() {
      _localFlameIncrements[post.id] = (_localFlameIncrements[post.id] ?? 0) + 1;
    });

    // 送信デバウンス処理
    _pendingFlameCounts[post.id] = (_pendingFlameCounts[post.id] ?? 0) + 1;
    _flameDebounceTimers[post.id]?.cancel();
    _flameDebounceTimers[post.id] = Timer(const Duration(milliseconds: 500), () async {
      final countToSend = _pendingFlameCounts[post.id] ?? 0;
      _pendingFlameCounts.remove(post.id);
      _flameDebounceTimers.remove(post.id);

      if (countToSend > 0) {
        try {
          await _postService.incrementFlameCount(
            post.id,
            countToSend,
            targetUid: post.userId,
            targetTaskName: post.taskName,
            triggerUpdateStream: false,
          );

          if (mounted) {
            setState(() {
              final current = _localFlameIncrements[post.id] ?? 0;
              _localFlameIncrements[post.id] = (current - countToSend).clamp(0, 100000);
              
              _feedItems = _feedItems.map((item) {
                if (item is Post && item.id == post.id) {
                  return item.copyWith(reactionCount: item.reactionCount + countToSend);
                }
                return item;
              }).toList();
            });
          }
        } catch (e) {
          debugPrint('Flame sync error: $e');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(vTimelinePostsProvider);

    return postsAsync.when(
      loading: () => Scaffold(
        backgroundColor: AppColors.black,
        body: Center(child: CircularProgressIndicator(color: AppColors.accentGold)),
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: AppColors.black,
        body: Center(
          child: Text(
            '読み込みエラーが発生しました\n$err',
            style: GoogleFonts.notoSansJp(color: AppColors.pureWhite),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (posts) {
        if (posts.isEmpty) {
          return Scaffold(
            backgroundColor: AppColors.black,
            body: Stack(
              children: [
                Center(
                  child: Text(
                    '現在公開されている投稿はありません。',
                    style: GoogleFonts.notoSansJp(color: AppColors.grey50, fontSize: 14),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: VEffectHeader(key: UniqueKey()),
                  ),
                ),
              ],
            ),
          );
        }

        // プロフィールのロード開始
        if (_userNames.isEmpty && _loadingProfiles) {
          _loadUserProfiles(posts);
        }

        _setupFeedItems(posts);

        if (_loadingProfiles) {
          return Scaffold(
            backgroundColor: AppColors.black,
            body: Center(child: CircularProgressIndicator(color: AppColors.accentGold)),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.black,
          body: Stack(
            children: [
              // メインカードフィード（ヘッダー分の余白を下げる）
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 60),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cardWidth = constraints.maxWidth * 0.85;
                      final cardHeight = cardWidth * (16 / 9);
                      final maxCardHeight = (constraints.maxHeight - 40).clamp(0.0, cardHeight);
                      final finalCardWidth = maxCardHeight * (9 / 16);

                      return NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification is ScrollStartNotification) {
                            _preloadAdsNearFocusedIndex();
                          } else if (notification is ScrollEndNotification) {
                            _preloadAdsNearFocusedIndex();
                          }
                          return false;
                        },
                        child: PageView.builder(
                          controller: _pageController,
                          scrollDirection: Axis.vertical,
                          onPageChanged: _onPageChanged,
                          itemCount: _feedItems.length,
                          itemBuilder: (context, index) {
                            final item = _feedItems[index];

                            if (item is String && item == 'ad') {
                              return Center(
                                child: SizedBox(
                                  width: finalCardWidth,
                                  height: maxCardHeight,
                                  child: NativeAdCard(
                                    dimAlpha: 0.0,
                                    isTop: index == _focusedGlobalIndex,
                                    nativeAd: _nativeAds[index],
                                    isAdLoaded: _adLoadStatus[index] == true,
                                    isAdLoadFailed: _adLoadStatus[index] == false,
                                  ),
                                ),
                              );
                            }

                            if (item is Post) {
                              final username = _userNames[item.userId] ?? 'User';
                              final photoUrl = _userPhotos[item.userId];
                              final badgeUrl = _userBadgeUrls[item.userId];
                              final badgeAnimation = _userBadgeAnimations[item.userId];

                              final currentLocalInc = _localFlameIncrements[item.id] ?? 0;
                              final displayReactionCount = item.reactionCount + currentLocalInc;

                              return Center(
                                child: SizedBox(
                                  width: finalCardWidth,
                                  height: maxCardHeight,
                                  child: FeedCard(
                                    post: item,
                                    username: username,
                                    userPhotoUrl: photoUrl,
                                    userBadgeUrl: badgeUrl,
                                    userBadgeAnimation: badgeAnimation,
                                    dimAlpha: index == _focusedGlobalIndex ? 0.0 : 0.4,
                                    onReaction: ({emoji}) => _onFlameReaction(item),
                                    isTop: index == _focusedGlobalIndex,
                                    tierColor: AppColors.accentGold,
                                    reactionCountNotifier: ValueNotifier(displayReactionCount),
                                    onProfileTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        AppRoutes.userProfile,
                                        arguments: {
                                          'uid': item.userId,
                                          'username': username,
                                          'photoUrl': photoUrl,
                                        },
                                      );
                                    },
                                  ),
                                ),
                              );
                            }

                            return const SizedBox.shrink();
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),

              // 浮遊炎エフェクトレイヤー
              Positioned.fill(
                child: IgnorePointer(
                  child: FloatingFlamesLayer(key: _flamesKey),
                ),
              ),

              // ドーパミン爆発レイヤー
              Positioned.fill(
                child: IgnorePointer(
                  child: DopamineEmojiExplosionLayer(
                    key: _explosionKey,
                    bottomOffset: MediaQuery.paddingOf(context).bottom + 120.0,
                  ),
                ),
              ),

              // 共通ヘッダーを最前面に配置
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: VEffectHeader(key: UniqueKey()),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
