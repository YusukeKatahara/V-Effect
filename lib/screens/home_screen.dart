import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/app_colors.dart';
import '../config/routes.dart';
import '../models/post.dart';
import '../services/post_service.dart';
import '../services/sound_service.dart';
import '../providers/service_providers.dart';
import '../utils/ad_helper.dart';
import '../widgets/v_effect_header.dart';
import '../widgets/native_ad_card.dart';
import '../widgets/home/home_skeleton_body.dart';
import '../widgets/home/friend_request_banner.dart';
import '../widgets/home/announcement_area.dart';
import '../widgets/home/home_empty_state.dart';
import 'weekly_review_screen.dart';
import '../providers/vfire_provider.dart';
import '../providers/weekly_review_provider.dart';
import '../services/migration_service.dart';

import '../providers/home_provider.dart';
import '../providers/upload_provider.dart';
import '../widgets/v_phoenix_rebirth_dialog.dart';
import '../widgets/upload_progress_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'main_shell.dart';
import 'home/components/feed_card.dart';
import 'home/components/guarded_state_layer.dart';
import 'home/components/floating_flames_layer.dart';
import 'home/components/dopamine_emoji_explosion_layer.dart';
import 'home/components/bgm_indicator.dart';
import '../widgets/frictionless_page_scroll_physics.dart';
import 'home/components/swipe_guide_overlay.dart';
import 'home/components/tooltip_tail_painter.dart';
import 'home/components/home_error_body.dart';
import 'home/components/new_posts_button.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final ValueChanged<bool>? onLoadingChanged;

  const HomeScreen({super.key, this.onLoadingChanged});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final PostService _postService;
  late final SoundService _soundService; // BGM制御用サービス（アンマウント時のクラッシュ防止のため保持）
  bool _postedToday = false;
  bool _isUnlockInitiated = false; // 解錠アニメーション（ボタン回転）を開始したかどうか
  bool _isUnlockedAnimated = false; // 実際にUIでガード解除演出を実行したかどうか
  bool _pendingUnlockAnimation = false; // 別タブで投稿完了し、ホーム遷移時に演出を実行すべきフラグ
  bool _friendFeedLogged = false; // friend_feed_viewed をフィード初回ロード時に1回だけ送るためのガード
  List<dynamic> _feedItems = [];
  final Set<String> _viewedPostIds = {}; // 閲覧済みポストのID
  bool _needsRefreshJump = true; // 初回ロード時やリフレッシュ時に先頭へジャンプするかどうか
  bool _needsResort = true; // リフレッシュ時のみ未読・既読の並び替えを行うためのフラグ
  List<String> _baseSortedPostIds = []; // 固定されたカードの順番を保持するリスト
  List<Map<String, dynamic>> _postedFriends = []; // [{uid, username, photoUrl}]
  Map<String, String> _userNames = {}; // userId -> username
  Map<String, String?> _userPhotos = {}; // userId -> photoUrl
  Map<String, int> _userStreaks = {}; // userId -> streak
  Map<String, String?> _userBadgeUrls = {};
  Map<String, String?> _userBadgeAnimations = {};
  HomeData? _lastHomeData;
  final Set<String> _reactingPostIds = {}; // 通信中の投稿IDを追跡
  // 送信済みだが Firestore 未確認の emoji。{emoji, uid} を記録して myUid null 問題を回避
  final Map<String, ({String emoji, String uid})> _pendingEmojis = {};
  
  DateTime? _lastPausedTime;
  bool _showNewPostsButton = false; // 新しい投稿ボタンの表示フラグ
  String? _lastFeedTopPostId; // 前回のフィードの先頭投稿ID




  // ── VFIRE コンボ状態 ──
  int _comboCount = 0;
  Timer? _comboResetTimer;

  // ── VFIRE 長押しオート連打用 ──
  // Timer（タイマー：時間制御や一定周期の定期実行を行うDartの標準クラス）を使用して、
  // 長押しされている間、一定間隔（100ミリ秒）ごとに炎を連打送信します。
  Timer? _flameAutoFireTimer;

  // ── Card Swiping ──
  // ── Card Swiping (Performance: Using AnimatedBuilder instead of setState) ──
  late final PageController _pageController;

  // ── Swipe Guide Tutorial ──
  bool _showSwipeGuide = false;
  late final AnimationController _swipeGuideController;
  late final Animation<double> _swipeGuideTranslation;
  
  // ── Ad Caching ──
  final Map<int, NativeAd> _nativeAds = {};
  final Map<int, bool> _adLoadStatus = {}; // true: loaded, false: failed
  Timer? _adRefreshTimer; // 広告自動リフレッシュ用のタイマー (30秒滞在でリフレッシュ)
  final Set<String> _celebratedRescuePostIds = {};
  bool _isScrolling = false; // スワイプ（スクロール）中かどうかのフラグ。スワイプ中のかくつきを防止するために使用



  // pageController.page を直接参照するように変更
  int get _focusedIndex {
    if (_feedItems.isEmpty) return 0;
    final len = _feedItems.length;
    final pos = (_pageController.hasClients ? _pageController.page ?? 10000.0 : 10000.0).round();
    return (pos % len + len) % len;
  }

  int _lastFocusedIndex = -1;
  double _lastVolume = 1.0;

  /// フィードがアンロックされているか（今日投稿済み、または投稿アップロード中/成功状態）を判定するゲッター
  bool get _isFeedUnlocked {
    if (!mounted) return false;
    final uploadState = ref.read(uploadProvider);
    return _postedToday ||
        uploadState.status == UploadStatus.uploading ||
        uploadState.status == UploadStatus.success;
  }

  void _playBgmForFocusedPost() async {
    // フィードがロックされている場合はBGMを再生せず、再生中のものがあれば停止する
    if (!_isFeedUnlocked) {
      await _soundService.stopBgm();
      return;
    }

    final currentFocused = _focusedIndex;
    if (_feedItems.isEmpty || currentFocused < 0 || currentFocused >= _feedItems.length) return;

    final item = _feedItems[currentFocused];
    if (item is Post && item.bgmUrl != null) {
      // 再生開始時にも現在のスワイプ割合に合わせた音量を計算して渡す
      final page = _pageController.hasClients ? _pageController.page ?? 10000.0 : 10000.0;
      final nearestPageIndex = page.round();
      final double offset = (page - nearestPageIndex).abs();
      final double volume = (1.0 - (offset * 2.0)).clamp(0.0, 1.0);

      await _soundService.playBgm(item.bgmUrl!, initialVolume: volume);
    } else {
      await _soundService.stopBgm();
    }
  }

  // ── リアクションアニメーション制御用 ──
  final GlobalKey<FloatingFlamesLayerState> _flamesKey = GlobalKey();
  double _flameBottomOffset = 120.0; // NavBar高さを考慮した炎アニメーション起点

  // ── V-Flash 演出用 ──
  late final AnimationController _flashController;
  late final Animation<double> _flashAnimation;
  // ── リアクションメニュー用 ──
  bool _reactionMenuOpen = false;
  late final AnimationController _reactionMenuController;
  static const _reactionEmojis = ['❤️', '🔥', '👍'];
  final GlobalKey<DopamineEmojiExplosionLayerState> _explosionKey = GlobalKey();

  // ── Shuffle Refresh 用 ──
  late final AnimationController _shuffleController;
  late final AnimationController _spreadController; // 束ねる用
  double _dragOffset = 0.0;
  bool _isRefreshing = false;
  double get _spreadFactor => _spreadController.value;


  // ── ロックアイコンは子 Widget に切り出し ──

  @override
  void initState() {
    super.initState();
    _postService = ref.read(postServiceProvider);
    _soundService = ref.read(soundServiceProvider);
    WidgetsBinding.instance.addObserver(this);
    MainShell.activeTabIndex.addListener(_onTabChanged);
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

    final initialPage = 10000;
    _pageController = PageController(initialPage: initialPage)
      ..addListener(() {
        if (mounted && _pageController.hasClients) {
          final page = _pageController.page;
          if (page != null && !page.isNaN) {
            if (_showSwipeGuide && (page - initialPage).abs() > 0.1) {
              _dismissSwipeGuide();
            }

            // ── V字型オーディオフェードのリアルタイム計算 ──
            final nearestPageIndex = page.round();
            final double offset = (page - nearestPageIndex).abs();
            // 0.0(中心) -> 音量1.0, 0.5(中間) -> 音量0.0
            final double volume = (1.0 - (offset * 2.0)).clamp(0.0, 1.0);
            
            // 負荷軽減：10%以上の変化があった場合、または端点(0.0, 1.0)に達した場合のみ通信を行う
            if ((_lastVolume - volume).abs() > 0.1 || volume == 0.0 || volume == 1.0) {
              if (_lastVolume != volume) {
                _soundService.setBgmVolume(volume);
                _lastVolume = volume;
              }
            }

            final currentFocused = _focusedIndex;
            if (currentFocused != _lastFocusedIndex) {
              _lastFocusedIndex = currentFocused;
              _playBgmForFocusedPost();
              _cleanupRemoteAds(_focusedGlobalIndex);

              // ── フォーカスが切り替わったタイミングで閲覧ログを送信 ──
              if (_feedItems.isNotEmpty &&
                  currentFocused >= 0 &&
                  currentFocused < _feedItems.length) {
                final item = _feedItems[currentFocused];
                if (item is Post) {
                  ref.read(analyticsServiceProvider).logFriendPostViewed(
                        friendUid: item.userId,
                        taskName: item.taskName,
                      );
                }
              }

              if (currentFocused == 0 && _showNewPostsButton) {
                setState(() {
                  _showNewPostsButton = false;
                });
              }
            }
          }
        }
      });

    _swipeGuideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
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
    _initSwipeGuide();
    // addListener 内の setState を削除（全画面リビルド回避）

    // データの読み込みは homeDataProvider (Riverpod) が担当するため
    // 手動の _loadData() は廃止

    _shuffleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600), // 少し速めに
    );

    _spreadController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1.0, // 最初は広がっている
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestTrackingAuthorization();
      MigrationService.instance.runTaskIdMigration();
    });
  }

  @override
  void dispose() {
    MainShell.activeTabIndex.removeListener(_onTabChanged);
    WidgetsBinding.instance.removeObserver(this);
    _soundService.stopBgm();
    for (final ad in _nativeAds.values) {
      ad.dispose();
    }
    _adRefreshTimer?.cancel();
    _pageController.dispose();
    _flashController.dispose();
    _reactionMenuController.dispose();
    _shuffleController.dispose();
    _spreadController.dispose();
    _comboResetTimer?.cancel();
    _flameAutoFireTimer?.cancel(); // 画面を離れる際にオート連打タイマーを確実に停止させます（メモリリーク防止）
    _swipeGuideController.dispose();
    super.dispose();
  }

  int get _focusedGlobalIndex {
    if (_feedItems.isEmpty) return 10000;
    return (_pageController.hasClients ? _pageController.page ?? 10000.0 : 10000.0).round();
  }

  void _loadAdForGlobalIndex(int globalIndex) {
    if (_nativeAds.containsKey(globalIndex) || _adLoadStatus.containsKey(globalIndex)) return;

    final ad = NativeAd(
      adUnitId: AdHelper.nativeAdUnitId,
      request: const AdRequest(),
      factoryId: 'customNativeAd',
      nativeAdOptions: NativeAdOptions(
        videoOptions: VideoOptions(
          startMuted: true,
          customControlsRequested: false,
          clickToExpandRequested: false,
        ),
        mediaAspectRatio: MediaAspectRatio.any,
      ),
      listener: NativeAdListener(
        onAdLoaded: (loadedAd) {
          if (mounted) {
            setState(() {
              _adLoadStatus[globalIndex] = true;
            });
          }
        },
        onAdFailedToLoad: (failedAd, error) {
          debugPrint('NativeAd failed to load at globalIndex $globalIndex: $error');
          failedAd.dispose();
          if (mounted) {
            setState(() {
              _adLoadStatus[globalIndex] = false;
            });
          }
        },
        onAdImpression: (ad) {
          ref.read(analyticsServiceProvider).logAdImpression(adUnitId: ad.adUnitId);
        },
        onAdClicked: (ad) {
          ref.read(analyticsServiceProvider).logAdClicked(adUnitId: ad.adUnitId);
        },
      ),
    );
    _nativeAds[globalIndex] = ad;
    ad.load();

    // 新しい広告がロードされた際にもクリーンアップを走らせる
    _cleanupRemoteAds(_focusedGlobalIndex);
  }

  void _preloadAdsNearFocusedIndex() {
    if (_feedItems.isEmpty) return;
    final focusedPage = _focusedGlobalIndex;
    
    // 2026 AdMob ベストプラクティス (遅延ロード / Lazy Loading):
    // 隣のカードの事前ロード（前後1ページのリクエスト）は破棄による表示率（Show Rate）の低下を引き起こすため廃止。
    // ユーザーが実際にフォーカスした（画面に到達した）タイミングで広告リクエストを安全に発行し、表示率 70%〜80%+ を維持します。
    final actualIndex = focusedPage % _feedItems.length;
    if (_feedItems[actualIndex] is String && _feedItems[actualIndex] == 'ad') {
      _loadAdForGlobalIndex(focusedPage);
    }
  }

  void _cleanupRemoteAds(int currentGlobalIndex) {
    final keysToRemove = <int>[];
    _nativeAds.forEach((key, ad) {
      // 距離が3つ以上離れた広告は安全に破棄してクリア
      if ((key - currentGlobalIndex).abs() >= 3) {
        ad.dispose();
        keysToRemove.add(key);
      }
    });

    for (final key in keysToRemove) {
      _nativeAds.remove(key);
      _adLoadStatus.remove(key);
    }

    // 実際に破棄が発生した場合はウィジェットを再構築し、古い参照を排除する
    if (keysToRemove.isNotEmpty && mounted) {
      setState(() {});
    }
  }

  // ── 広告タイマー関連の制御メソッド ──
  void _startAdRefreshTimer(int globalIndex) {
    _adRefreshTimer?.cancel();
    _adRefreshTimer = Timer(const Duration(seconds: 30), () {
      _refreshAdAt(globalIndex);
    });
  }

  void _cancelAdRefreshTimer() {
    _adRefreshTimer?.cancel();
    _adRefreshTimer = null;
  }

  void _refreshAdAt(int globalIndex) {
    if (!mounted) return;
    
    // 現在フォーカスされている位置と一致する場合のみリフレッシュする
    if (_focusedGlobalIndex != globalIndex) return;

    final ad = _nativeAds[globalIndex];
    if (ad != null) {
      ad.dispose();
      _nativeAds.remove(globalIndex);
      _adLoadStatus.remove(globalIndex);
    }
    
    // 新しくロードを実行
    _loadAdForGlobalIndex(globalIndex);
    
    // さらに滞在し続ける場合に備えてタイマーを再始動
    _startAdRefreshTimer(globalIndex);
  }


  Future<void> _handleUnlockDetected() async {
    final bool isCurrentTabHome = MainShell.activeTabIndex.value == 0;
    if (isCurrentTabHome) {
      // ホーム画面表示中にアンロックされた場合、その場でアニメーションを順番に行う
      setState(() {
        _isUnlockInitiated = true; // 1. 解錠演出開始（矢印回転＋解錠アイコン）
      });
      
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      setState(() {
        _isUnlockedAnimated = true; // 2. フィード開示
        _pendingUnlockAnimation = false;
      });
      HapticFeedback.heavyImpact(); // 開示のインパクト
    } else {
      _pendingUnlockAnimation = true;
      // 表示されるまでは両フラグとも false のまま維持
    }
  }

  void _onTabChanged() {
    if (!mounted) return;
    if (MainShell.activeTabIndex.value == 0) {
      // コンパスタブに戻ってきたらBGMを再開
      _playBgmForFocusedPost();

      // 他のタブで投稿が完了していて、まだガード解除演出を行っていない場合は遅延実行する
      if (_pendingUnlockAnimation) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await Future.delayed(const Duration(milliseconds: 300));
          if (!mounted || !_pendingUnlockAnimation) return;

          setState(() {
            _isUnlockInitiated = true; // 1. 解錠演出開始（矢印回転＋解錠アイコン）
          });
          
          // 2. 解錠演出（800ms）が終わるのを待ってからフィードを開示
          await Future.delayed(const Duration(milliseconds: 800));
          if (!mounted || !_pendingUnlockAnimation) return;

          setState(() {
            _isUnlockedAnimated = true;
            _pendingUnlockAnimation = false;
          });
          HapticFeedback.heavyImpact(); // 演出実行時に強めのバイブレーションで効果を高める
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _lastPausedTime ??= DateTime.now();
      _cancelAdRefreshTimer(); // バックグラウンド移行時は無駄なリクエストを防ぐためタイマーをクリア
    } else if (state == AppLifecycleState.resumed) {
      final page = _pageController.hasClients ? _pageController.page?.round() ?? 10000 : 10000;
      final actualIndex = _feedItems.isNotEmpty ? (page % _feedItems.length + _feedItems.length) % _feedItems.length : 0;
      final isTopPage = actualIndex == 0;

      if (_lastPausedTime != null) {
        final elapsed = DateTime.now().difference(_lastPausedTime!);
        _lastPausedTime = null; // リセット
        if (elapsed.inSeconds < 30) {
          // 30秒未満の復帰ならフィードはリフレッシュせず順番を保持する
          // ただし、現在広告が表示されているなら新鮮さを保つため広告を強制更新
          if (_feedItems.isNotEmpty) {
            if (_feedItems[actualIndex] is String && _feedItems[actualIndex] == 'ad') {
              _refreshAdAt(page); // 広告を更新し、タイマーも再始動
            }
          }
          return;
        }

        // 30秒以上のバックグラウンド経過があった場合はリフレッシュを実行する
        if (mounted) {
          setState(() {
            _needsResort = true;
            // 5分以上経過しており、かつ現在先頭ページ（1枚目の投稿）にいる場合のみ自動的に先頭へジャンプ
            if (elapsed.inMinutes >= 5 && isTopPage) {
              _needsRefreshJump = true;
            } else {
              _needsRefreshJump = false;
            }
          });
          // 復帰時にフィードをリフレッシュし、ローカル送信履歴もリセットします。
          ref.invalidate(homeDataProvider);
          ref.read(vfireProvider.notifier).clearSynced();
        }
      }

      // 3分以上経過しており全体がリフレッシュされる場合でも、もし現在が広告枠ならタイマーを再始動
      if (_feedItems.isNotEmpty) {
        if (_feedItems[actualIndex] is String && _feedItems[actualIndex] == 'ad') {
          _startAdRefreshTimer(page);
        }
      }
    }
  }

  Future<void> _requestTrackingAuthorization() async {
    if (!kIsWeb && Platform.isIOS) {
      try {
        final status = await AppTrackingTransparency.trackingAuthorizationStatus;
        if (status == TrackingStatus.notDetermined) {
          // iOS側のダイアログ表示タイミングを安定させるために少し待機する
          await Future.delayed(const Duration(milliseconds: 800));
          await AppTrackingTransparency.requestTrackingAuthorization();
        }
      } catch (e) {
        debugPrint('ATT Request Error: $e');
      }
    }
  }

  Future<void> _initSwipeGuide() async {
    final prefs = await SharedPreferences.getInstance();
    final hasShown = prefs.getBool('home_swipe_tutorial_shown') ?? false;
    if (!hasShown && mounted) {
      setState(() {
        _showSwipeGuide = true;
      });
      _swipeGuideController.repeat(reverse: true);
    }
  }

  Future<void> _dismissSwipeGuide() async {
    if (!mounted) return;
    setState(() {
      _showSwipeGuide = false;
    });
    _swipeGuideController.stop();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('home_swipe_tutorial_shown', true);
  }

  void _onPageChanged(int index) {
    if (_feedItems.isEmpty) return;

    final actualIndex = index % _feedItems.length;
    final currentItem = _feedItems[actualIndex];
    if (currentItem is Post) {
      _viewedPostIds.add(currentItem.id);
      _cancelAdRefreshTimer();
    } else if (currentItem is String && currentItem == 'ad') {
      _startAdRefreshTimer(index);
    } else {
      _cancelAdRefreshTimer();
    }
    
    // 次の5枚の画像をプリキャッシュしてスムーズなめくりを実現
    for (int i = 1; i <= 5; i++) {
      final nextIndex = (index + i) % _feedItems.length;
      final item = _feedItems[nextIndex];
      if (item is Post) {
        if (item.imageUrl != null) {
          precacheImage(
            ResizeImage(CachedNetworkImageProvider(item.imageUrl!), width: 1080),
            context,
          );
        }
        if (item.thumbnailUrl != null) {
          precacheImage(
            ResizeImage(CachedNetworkImageProvider(item.thumbnailUrl!), width: 150),
            context,
          );
        }
      }
    }
  }

  void _precacheInitialFeed() {
    if (!mounted || _feedItems.isEmpty) return;
    // 最初の5枚を先読み
    for (int i = 0; i < 5 && i < _feedItems.length; i++) {
      final item = _feedItems[i];
      if (item is Post) {
        if (item.imageUrl != null) {
          precacheImage(
            ResizeImage(CachedNetworkImageProvider(item.imageUrl!), width: 1080),
            context,
          );
        }
        if (item.thumbnailUrl != null) {
          precacheImage(
            ResizeImage(CachedNetworkImageProvider(item.thumbnailUrl!), width: 150),
            context,
          );
        }
      }
    }
  }

  // ── Shuffle Refresh Logic ──
  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_isRefreshing) return;
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dy).clamp(0.0, 150.0);
    });
    // debugPrint('Drag offset: $_dragOffset');
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_isRefreshing) return;
    // debugPrint('Drag ended with offset: $_dragOffset');
    if (_dragOffset >= 80.0) { // しきい値を少し下げて反応を良くする
      _triggerRefresh();
    } else {
      setState(() {
        _dragOffset = 0.0;
      });
    }
  }



  Future<void> _triggerRefresh() async {
    setState(() {
      _isRefreshing = true;
      _dragOffset = 100.0; 
      _needsRefreshJump = true;
      _needsResort = true;
    });
    
    // 束ねる
    _spreadController.animateTo(0.0, curve: Curves.easeOutBack);
    _shuffleController.repeat();
    HapticFeedback.mediumImpact();

    try {
      for (final ad in _nativeAds.values) {
        ad.dispose();
      }
      _nativeAds.clear();
      _adLoadStatus.clear();

      ref.invalidate(homeDataProvider);
      await ref.read(homeDataProvider.future);

      // 手動リフレッシュ成功後、メモリ上の確定済みローカル送信履歴をクリアして、
      // 新しくロードされた Firestore の値に同期を一本化します。
      ref.read(vfireProvider.notifier).clearSynced();
    } catch (e) {
      debugPrint('Refresh error: $e');
    } finally {
      if (mounted) {
        // 元に戻す
        _spreadController.animateTo(1.0, curve: Curves.elasticOut, duration: const Duration(milliseconds: 800));
        setState(() {
          _isRefreshing = false;
          _dragOffset = 0.0;
        });
        _shuffleController.stop();
        _shuffleController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        
        // パラパラとしたフィードバック
        for (int i = 0; i < 3; i++) {
          Future.delayed(Duration(milliseconds: i * 80), () {
            HapticFeedback.lightImpact();
          });
        }
      }
    }
  }

  double _getShuffleOffsetX(int index) {
    if (!_isRefreshing) return 0.0;
    if (_feedItems.length <= 1) return 0.0; // 1枚の時は動かさない

    final t = _shuffleController.value;
    final len = _feedItems.length;
    if (len == 0) return 0.0;

    // カードごとにタイミングをずらして「配る」
    // indexが若いほど先に配られる
    final double cardDelay = index / len;
    final double progress = (t - cardDelay).clamp(0.0, 1.0);
    
    if (progress == 0 || progress == 1) return 0.0;

    // 横に少し逸れながら飛ぶ
    final double sideSwing = sin(index * 1.5) * 50.0;
    return sideSwing * sin(progress * pi);
  }

  double _getShuffleOffsetY(int index) {
    if (!_isRefreshing) return 0.0;
    if (_feedItems.length <= 1) {
      // 1枚の時: わずかに上下に呼吸するように揺れる
      return sin(_shuffleController.value * pi * 2) * 10.0;
    }

    final t = _shuffleController.value;
    final len = _feedItems.length;
    if (len == 0) return 0.0;

    final double cardDelay = index / len;
    final double progress = (t - cardDelay).clamp(0.0, 1.0);

    if (progress == 0 || progress == 1) return 0.0;

    // 手前に向かって飛んでくるように見せるために下に大きく移動
    return progress * 600.0; 
  }

  double _getShuffleRotation(int index) {
    if (!_isRefreshing) return 0.0;
    if (_feedItems.length <= 1) return 0.0; // 1枚の時は3D回転で制御するため0

    final t = _shuffleController.value;
    final len = _feedItems.length;
    if (len == 0) return 0.0;

    final double cardDelay = index / len;
    final double progress = (t - cardDelay).clamp(0.0, 1.0);

    if (progress == 0 || progress == 1) return (index % 3 - 1) * 0.05; // 束ねている時の微かなズレ

    // 回転しながら飛ぶ
    return progress * pi * 0.5 * (index % 2 == 0 ? 1 : -1);
  }

  double _getShuffleScale(int index) {
    if (!_isRefreshing) return 1.0;
    if (_feedItems.length <= 1) {
      // 1枚の時: 少し浮き上がる
      return 1.05 + sin(_shuffleController.value * pi * 2) * 0.02;
    }

    final t = _shuffleController.value;
    final len = _feedItems.length;
    if (len == 0) return 1.0;

    final double cardDelay = index / len;
    final double progress = (t - cardDelay).clamp(0.0, 1.0);

    if (progress == 0 || progress == 1) return 1.0;

    // 飛んでいる間は少し大きく（手前に来る）
    return 1.0 + sin(progress * pi) * 0.3;
  }

  // ── VFIRE 長押しオート連打処理 ──
  
  /// 長押しが開始されたときに、タイマーを起動して自動連打を開始します。
  /// [index] は現在表示しているカードのインデックス（順番）です。
  void _startFlameAutoFire(int index) {
    // すでにタイマーが動いている場合は重複して起動しないようにガード（安全処理）します。
    if (_flameAutoFireTimer != null) return;
    
    // 長押しした瞬間に、まず最初の1回目のリアクションを即時に送ります。
    _sendReaction(index);
    
    // Timer.periodic（タイマー・ピリオディック：指定された時間間隔で処理を繰り返す仕組み）
    // を使用して、100ミリ秒（0.1秒）ごとに VFIRE を追加します。
    _flameAutoFireTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _sendReaction(index);
    });
  }

  /// 長押しが離された、またはキャンセルされたときにタイマーを停止します。
  void _stopFlameAutoFire() {
    _flameAutoFireTimer?.cancel(); // 動いているタイマーを停止します。
    _flameAutoFireTimer = null;    // 変数を空（null）に戻してリセットします。
  }

  Future<void> _sendReaction(int index, {String? emoji}) async {
    if (_feedItems.isEmpty) return;
    final item = _feedItems[index];
    if (item is! Post) return;
    final post = item;
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
    
    // VFIREの場合、Notifier経由で極小範囲のみ更新
    if (emoji == null) {
      ref.read(vfireProvider.notifier).increment(post);
    } else {
      // 絵文字は1回きりなので、安全にsetStateで全体反映
      setState(() {
        final newUserReactions = Map<String, String>.from(post.userReactions);
        final currentEmoji = newUserReactions[myUid];
        if (currentEmoji == null || currentEmoji == '🔥') {
          newUserReactions[myUid] = emoji;
          final updatedIds = List<String>.from(post.emojiReactedUserIds);
          if (!updatedIds.contains(myUid)) updatedIds.add(myUid);
          
          _feedItems = List.from(_feedItems)
            ..[index] = post.copyWith(
              userReactions: newUserReactions,
              emojiReactedUserIds: updatedIds,
            );
        }
      });
    }

    // 演出の実行（これはタップごとに即座に行う）
    if (isVFlash) {
      HapticFeedback.heavyImpact();
      _flashController.forward(from: 0);
      _flamesKey.currentState?.addFlame(
          color: AppColors.accentGold,
          glowColor: AppColors.accentGoldLight,
          size: 60.0,
          bottomOffset: _flameBottomOffset);
    } else {
      if (emoji != null) {
        HapticFeedback.heavyImpact();
        _explosionKey.currentState?.explode(emoji);
      } else {
        // --- VFIRE コンボ処理 ---
        _comboResetTimer?.cancel();
        _comboCount++;
        _comboResetTimer = Timer(const Duration(milliseconds: 1500), () {
          if (mounted) {
            setState(() => _comboCount = 0);
          }
        });

        Color flameColor;
        Color glowColor;
        double soundPitch;

        if (_comboCount <= 9) {
          flameColor = AppColors.accentGold;
          glowColor = AppColors.accentGoldLight;
          HapticFeedback.lightImpact();
        } else if (_comboCount <= 19) {
          flameColor = const Color(0xFF00E5FF);
          glowColor = const Color(0xFF80DEEA);
          HapticFeedback.mediumImpact();
        } else {
          // 20以降は虹色（タップするごとに色相が変わる）
          final hue = ((_comboCount - 20) * 20.0) % 360.0;
          flameColor = HSLColor.fromAHSL(1.0, hue, 1.0, 0.6).toColor();
          glowColor = HSLColor.fromAHSL(1.0, hue, 1.0, 0.8).toColor();
          HapticFeedback.heavyImpact();
        }
        
        // タップするごとに少しずつ連続的に音階を上げる（最大2.0まで）
        soundPitch = (1.0 + (_comboCount * 0.02)).clamp(1.0, 2.0);

        _flamesKey.currentState?.addFlame(
          color: flameColor,
          glowColor: glowColor,
          bottomOffset: _flameBottomOffset,
        );
        _soundService.playFireTapSound(playbackRate: soundPitch);
      }
    }

    // 救済投稿の150VFIRE達成判定と祝福ダイアログの自動発火
    if (post.isRescuePost && !_celebratedRescuePostIds.contains(post.id)) {
      final currentCount = ref.read(vfireProvider).getAdjustedReactionCount(post);
      if (currentCount >= 150) {
        _celebratedRescuePostIds.add(post.id);
        _stopFlameAutoFire();
        VPhoenixRebirthDialog.show(context, streakDays: 1);
      }
    }

    // 2. 絵文字の通信処理
    if (emoji != null) {
      // 絵文字は即座に送信
      // ※ updateStream が自動的にhomeDataProviderをソフトリフレッシュするため
      //   ref.invalidate() は不要（invalidateはUIをちらつかせる原因になる）
      try {
        _reactingPostIds.add(post.id);
        await _postService.addEmojiReaction(
          post.id,
          emoji,
          targetUid: post.userId,
          targetTaskName: post.taskName,
        );

        // ローカルキャッシュ（SharedPreferences）も即座に更新して再起動時のちらつきを防ぐ
        await updateHomeDataCacheWithReaction(
          myUid,
          post.id,
          emoji: emoji,
        );
      } catch (e) {
        debugPrint('Emoji reaction error: $e');
      } finally {
        _cleanupReactionLock(post.id);
      }
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
      // 今週の振り返りを既読（一度開いた）状態にする
      await markWeeklyReviewAsRead(ref);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const WeeklyReviewScreen(),
        ),
      );
    } on FirebaseException catch (e, stack) {
      debugPrint('WeeklyReview Load Error (Firebase): ${e.code}\n$e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.homeWeeklyReviewLoadFailed(e.code))),
        );
      }
    } catch (e, stack) {
      debugPrint('WeeklyReview Load Error (Unexpected): $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.homeUnexpectedError)),
        );
      }
    } finally {
      if (mounted) widget.onLoadingChanged?.call(false);
    }
  }

  void _showPostOptions(Post post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.block_rounded, color: AppColors.textPrimary),
              title: Text(AppLocalizations.of(context)!.homeBlockUser, style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _confirmBlock(post.userId);
              },
            ),
            ListTile(
              leading: Icon(Icons.report_problem_rounded, color: AppColors.error),
              title: Text(AppLocalizations.of(context)!.homeReportPost, style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                _showReportDialog(post);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _confirmBlock(String targetUid) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: Text(AppLocalizations.of(context)!.homeBlockConfirmTitle, style: TextStyle(color: AppColors.textPrimary)),
        content: Text(AppLocalizations.of(context)!.homeBlockConfirmDesc, style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.homeBlockConfirmCancel, style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(blockServiceProvider).blockUser(targetUid);
                ref.invalidate(homeDataProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context)!.homeBlockSuccess)),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context)!.homeBlockFailed)),
                  );
                }
              }
            },
            child: Text(AppLocalizations.of(context)!.homeBlockButton, style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(Post post) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: Text(AppLocalizations.of(context)!.homeReportTitle, style: TextStyle(color: AppColors.textPrimary)),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _reportOption(ctx, post, AppLocalizations.of(context)!.homeReportSpam, 'spam'),
            _reportOption(ctx, post, AppLocalizations.of(context)!.homeReportHarassment, 'harassment'),
            _reportOption(ctx, post, AppLocalizations.of(context)!.homeReportInappropriate, 'inappropriate'),
            _reportOption(ctx, post, AppLocalizations.of(context)!.homeReportOther, 'other'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.homeReportCancel, style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _reportOption(BuildContext ctx, Post post, String label, String reason) {
    return ListTile(
      title: Text(label, style: TextStyle(color: AppColors.textPrimary)),
      onTap: () async {
        Navigator.pop(ctx);
        try {
          await ref.read(blockServiceProvider).reportPost(post.id, post.userId, reason);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context)!.homeReportSuccess)),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context)!.homeReportFailed)),
            );
          }
        }
      },
    );
  }

  Color _getTierColor(int streak) {
    if (streak >= 365) return const Color(0xFFE0A33B); // Challenger (Gold/Blue)
    if (streak >= 270) return const Color(0xFFB53030); // Grandmaster (Red)
    if (streak >= 180) return const Color(0xFF8D2D9E); // Master (Purple)
    if (streak >= 100) return const Color(0xFF4A60AB); // Diamond (Vivid Blue)
    if (streak >= 66) return const Color(0xFF10825B);  // Emerald (Green)
    if (streak >= 30) return const Color(0xFF327A8A);  // Platinum (Teal)
    if (streak >= 14) return const Color(0xFFC89C3C);  // Gold (Gold)
    if (streak >= 7) return const Color(0xFF8091A0);   // Silver (Blue-Gray)
    if (streak >= 3) return const Color(0xFF8F5338);   // Bronze (Copper)
    return const Color(0xFF5E4B43);                    // Iron (Dark Brown-Gray)
  }

  @override
  Widget build(BuildContext context) {
    final homeAsync = ref.watch(homeDataProvider);
    final uploadState = ref.watch(uploadProvider);

    ref.listen<UploadState>(uploadProvider, (previous, next) {
      final wasUnlocked = _postedToday ||
          previous?.status == UploadStatus.uploading ||
          previous?.status == UploadStatus.success;
      final isUnlocked = _postedToday ||
          next.status == UploadStatus.uploading ||
          next.status == UploadStatus.success;
      
      if (wasUnlocked != isUnlocked) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _playBgmForFocusedPost();
            // ロックが解除された瞬間（未完了から完了へ移行した瞬間）に触覚フィードバックを実行
            if (!wasUnlocked && isUnlocked) {
              HapticFeedback.heavyImpact();
              _handleUnlockDetected();
            }
          }
        });
      }
    });

    ref.listen<AsyncValue<HomeData>>(homeDataProvider, (previous, next) {
      final prevUpload = ref.read(uploadProvider);
      final wasUnlocked = (previous?.valueOrNull?.postedToday ?? false) ||
          prevUpload.status == UploadStatus.uploading ||
          prevUpload.status == UploadStatus.success;
          
      final isUnlocked = (next.valueOrNull?.postedToday ?? false) ||
          prevUpload.status == UploadStatus.uploading ||
          prevUpload.status == UploadStatus.success;
      
      if (wasUnlocked != isUnlocked) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _playBgmForFocusedPost();
            // ロックが解除された瞬間（未完了から完了へ移行した瞬間）に触覚フィードバックを実行
            if (!wasUnlocked && isUnlocked) {
              HapticFeedback.heavyImpact();
              _handleUnlockDetected();
            }
          }
        });
      }
    });

    // ── UIスレッドでの実行を保証し、ローカル状態を同期 (データがある場合のみ) ──
    homeAsync.whenData((homeData) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onLoadingChanged?.call(false);
      });

      if (_lastHomeData != homeData) {
        // フィード初回ロード時に1回だけ、表示中の「今日の友達投稿数」を記録する。
        // （リアクション都度のソフトリフレッシュでの重複送信を防ぐ）
        if (!_friendFeedLogged) {
          final now = DateTime.now();
          final start = DateTime(now.year, now.month, now.day);
          final todayCount = homeData.feedPosts
              .where((p) => !p.createdAt.isBefore(start))
              .length;
          ref.read(analyticsServiceProvider)
              .logFriendFeedViewed(todayFriendPostsCount: todayCount);
          _friendFeedLogged = true;
        }

        // 新しい投稿の検知
        final activePosts = homeData.feedPosts;
        final latestPostId = activePosts.isNotEmpty ? activePosts.first.id : null;
        final page = _pageController.hasClients ? _pageController.page?.round() ?? 10000 : 10000;
        final actualIndex = _feedItems.isNotEmpty ? (page % _feedItems.length + _feedItems.length) % _feedItems.length : 0;
        final isTopPage = actualIndex == 0;

        if (_lastFeedTopPostId != null && latestPostId != null && _lastFeedTopPostId != latestPostId) {
          if (!isTopPage && !_needsRefreshJump) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _showNewPostsButton = true;
                });
              }
            });
          }
        }
        if (latestPostId != null) {
          _lastFeedTopPostId = latestPostId;
        }

        _postedToday = homeData.postedToday;

        // ── ガード解除アニメーションの同期処理 ──
        final uploadState = ref.read(uploadProvider);
        final isCurrentlyUnlocked = homeData.postedToday ||
            uploadState.status == UploadStatus.uploading ||
            uploadState.status == UploadStatus.success;

        // 初回ロード時（_lastHomeData == null）のみ自動同期を許可
        // これにより、起動中に新しく投稿された場合は listen 側の解錠演出（2段階）を必ず経由させる
        if (_lastHomeData == null) {
          _isUnlockInitiated = isCurrentlyUnlocked;
          _isUnlockedAnimated = isCurrentlyUnlocked;
        } else {
          // 既に起動中の場合：
          // もしロック状態に戻った（日付が変わったなど）場合は即座にフラグをリセットして再ロック
          if (!isCurrentlyUnlocked) {
            _isUnlockInitiated = false;
            _isUnlockedAnimated = false;
            _pendingUnlockAnimation = false;
          }
        }

        _postedFriends = homeData.postedFriends;
        _userNames = homeData.userNames;
        _userPhotos = homeData.userPhotos;
        _userStreaks = homeData.userStreaks;
        _userBadgeUrls = homeData.userBadgeUrls;
        _userBadgeAnimations = homeData.userBadgeAnimations;
        _lastHomeData = homeData;

        final myUid = FirebaseAuth.instance.currentUser?.uid;
        final newPosts = <Post>[];
        final List<String> idsToRemove = [];

        for (final fetchedPost in homeData.feedPosts) {
          // FeedCardがグローバルな vfireProvider をwatchするため、
          // ここでの localInc 加算と _flameNotifiers の更新は不要になりました。
          final displayedPost = fetchedPost;

          if (_reactingPostIds.contains(displayedPost.id)) {
            final existingLocal = _feedItems.firstWhere(
              (p) => p is Post && p.id == displayedPost.id,
              orElse: () => displayedPost,
            ) as Post;
            
            // 最新サーバーデータ + ローカル増分 でマージ
            newPosts.add(displayedPost);
            
            // 絵文字の状態チェック
            final localHasEmoji = existingLocal.hasEmojiReacted(myUid);
            final fetchedHasEmoji = displayedPost.hasEmojiReacted(myUid);

            if (localHasEmoji && !fetchedHasEmoji) {
              // 絵文字だけは localPost の状態を維持
              newPosts[newPosts.length - 1] = newPosts.last.copyWith(
                userReactions: existingLocal.userReactions,
                emojiReactedUserIds: existingLocal.emojiReactedUserIds,
              );
            } else {
              idsToRemove.add(displayedPost.id);
            }
          } else {
            newPosts.add(displayedPost);
          }
        }
        final List<Post> combinedPosts;
        
        if (_needsResort) {
          // 未読・既読の振り分け（リフレッシュ時や初回ロード時のみ）
          final unreadPosts = <Post>[];
          final readPosts = <Post>[];
          for (final p in newPosts) {
            if (_viewedPostIds.contains(p.id)) {
              readPosts.add(p);
            } else {
              unreadPosts.add(p);
            }
          }
          combinedPosts = [...unreadPosts, ...readPosts];
          _baseSortedPostIds = combinedPosts.map((p) => p.id).toList();
          _needsResort = false;
        } else {
          // 既存の並び順（_baseSortedPostIds）を維持する（VFIREリアクション時など）
          newPosts.sort((a, b) {
            final indexA = _baseSortedPostIds.indexOf(a.id);
            final indexB = _baseSortedPostIds.indexOf(b.id);
            if (indexA == -1 && indexB == -1) return 0; // 新規投稿同士はそのまま
            if (indexA == -1) return -1; // 新規投稿は先頭へ
            if (indexB == -1) return 1;
            return indexA.compareTo(indexB);
          });
          combinedPosts = newPosts;
          
          // 新規投稿があった場合は、_baseSortedPostIds も更新しておく
          _baseSortedPostIds = combinedPosts.map((p) => p.id).toList();
        }

        final newItems = <dynamic>[];
        // 投稿数が3件以上ある場合に広告を挿入する（少人数での利用を考慮）
        // google_mobile_ads は Web 非対応のため Web では広告枠を挿入しない
        final bool shouldInsertAd = !kIsWeb && combinedPosts.length >= 3;
        for (int i = 0; i < combinedPosts.length; i++) {
          newItems.add(combinedPosts[i]);
          // 1枚目（インデックス0）の直後には入れず、2枚目（インデックス1）の直後に最初の広告を挿入。
          // その後は5投稿ごと（i == 6, 11...）に挿入することで、過度な広告表示を防ぐ。
          if (shouldInsertAd) {
            if (i == 1 || (i > 1 && (i - 1) % 5 == 0)) {
              newItems.add('ad');
            }
          }
        }
        final oldLength = _feedItems.length;
        _feedItems = newItems;
        final newLength = _feedItems.length;
        
        // 1. リフレッシュ要求（手動プル）がある場合
        // 2. または、ユーザーが先頭にいて裏でデータ枚数が変わった場合（コールドスタート時など）
        // -> 無限スクロールの余り計算ズレを防ぐため、強制的に新しい先頭へジャンプさせる
        if ((_needsRefreshJump || (isTopPage && oldLength != newLength)) && _feedItems.isNotEmpty) {
          _needsRefreshJump = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _pageController.hasClients) {
              final targetIndex = 100000 - (100000 % _feedItems.length);
              _pageController.jumpToPage(targetIndex);
              
              // 先頭のアイテムを既読にする
              final item = _feedItems[0];
              if (item is Post) {
                _viewedPostIds.add(item.id);
              }
            }
          });
        }
        
        // 初回ロード時またはデータ更新時に先読みを開始
        if (_feedItems.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _precacheInitialFeed();
          });
        }

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

    _flameBottomOffset = MediaQuery.paddingOf(context).bottom + 120.0;

    return VisibilityDetector(
      key: const Key('home_screen_visibility'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction < 0.1) {
          // 画面がほぼ見えなくなった時（他のタブや別画面に移動した時）
          _soundService.stopBgm();
        }
      },
      child: Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        children: [
          // 2. メインコンテンツ
          // ガードレール: 一度でもデータを受信したら、プロバイダーの
          // loading/refreshing 状態に関わらず、絶対にスケルトンに戻さない。
          // ローカル状態変数 (_postedToday, _feedItems 等) が常に最新であり、
          // UIの信頼できる唯一の情報源 (Single Source of Truth) として扱う。
          if (_lastHomeData == null) ...[
            // 初回ロード: まだ一度もデータを受信していない
            homeAsync.when(
              loading: () => HomeSkeletonBody(titleBar: _buildTitleBar()),
              error: (err, stack) => HomeErrorBody(
                error: err,
                onRetry: () => ref.invalidate(homeDataProvider),
              ),
              data: (_) => _buildMainContent(uploadState),
            ),
          ] else ...[
            // データ受信済み: 常にコンテンツを表示（リフレッシュ中もちらつかない）
            _buildMainContent(uploadState),
          ],

          // 3. V-Flash 演出レイヤー (永続)
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _flashAnimation,
              builder: (context, _) {
                if (_flashAnimation.value == 0) return const SizedBox.shrink();
                return Container(
                  color: AppColors.white.withValues(alpha: _flashAnimation.value),
                );
              },
            ),
          ),

          // 4. 炎のエフェクトレイヤー (永続)
          Positioned.fill(
            child: IgnorePointer(
              child: FloatingFlamesLayer(key: _flamesKey),
            ),
          ),

          // 5. ドーパミン爆発レイヤー (永続)
          Positioned.fill(
            child: IgnorePointer(
              child: DopamineEmojiExplosionLayer(
                key: _explosionKey,
                bottomOffset: _flameBottomOffset,
              ),
            ),
          ),
          // 6. 「新しい投稿があります」ボタン (浮遊ピル型UI)
          if (_showNewPostsButton &&
              (_postedToday ||
                  uploadState.status == UploadStatus.uploading ||
                  uploadState.status == UploadStatus.success))
            Positioned(
              top: MediaQuery.paddingOf(context).top + 70.0,
              left: 0,
              right: 0,
              child: Align(
                alignment: Alignment.topCenter,
                child: NewPostsButton(
                  onTap: () {
                    if (_pageController.hasClients && _feedItems.isNotEmpty) {
                      setState(() {
                        _showNewPostsButton = false;
                      });
                      final targetIndex = 100000 - (100000 % _feedItems.length);
                      _pageController.animateToPage(
                        targetIndex,
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeInOutCubic,
                      );
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    ));
  }


  /// ローカル状態変数を使ってメインコンテンツを構築する。
  /// プロバイダーの AsyncValue に依存しないため、リフレッシュ中もちらつかない。
  Widget _buildMainContent(UploadState uploadState) {
    return SafeArea(
      child: Column(
        children: [
          const UploadProgressBar(), // 最上部にアップロード進捗バーを表示
          _buildTitleBar(),
          const FriendRequestBanner(),
          AnnouncementArea(onOpenWeeklyReview: _openWeeklyReview),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 800),
              switchInCurve: Curves.easeInOutCubic,
              switchOutCurve: Curves.easeInOutCubic,
              transitionBuilder: (Widget child, Animation<double> animation) {
                // 消えゆくガードレイヤー (鍵マーク画面) は縮小させず、その場でフェードアウトさせる
                final isEntering = child.key != const ValueKey('guarded_layer');

                final fadeAnimation = CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.2, 1.0, curve: Curves.easeIn),
                );

                if (isEntering) {
                  // 新しく入ってくる Widget（フィード）はズームイン＋フェードイン
                  final scaleAnimation = Tween<double>(begin: 0.96, end: 1.0).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                  );
                  return FadeTransition(
                    opacity: fadeAnimation,
                    child: ScaleTransition(
                      scale: scaleAnimation,
                      child: child,
                    ),
                  );
                } else {
                  // 消えていく Widget（ガードレイヤー）はその場でフェードアウト（縮小しない）
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                }
              },
              child: !_isUnlockedAnimated
                  ? GuardedStateLayer(
                      key: const ValueKey('guarded_layer'),
                      isUnlocked: _isUnlockInitiated,
                      backgroundImageUrl: _feedItems.whereType<Post>().isNotEmpty
                          ? _feedItems.whereType<Post>().first.imageUrl
                          : null,
                      postedFriends: _postedFriends,
                      onRefresh: () => ref.invalidate(homeDataProvider),
                    )
                  : (_feedItems.isEmpty
                      ? HomeEmptyState(
                          key: const ValueKey('empty_state'),
                          onRefresh: () => ref.invalidate(homeDataProvider),
                        )
                      : KeyedSubtree(
                          key: const ValueKey('card_stack'),
                          child: _buildCardStack(),
                        )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleBar() => VEffectHeader(
    leading: IconButton(
      icon: Icon(Icons.search_rounded, color: AppColors.white, size: 22),
      onPressed: () => Navigator.pushNamed(context, '/search'),
    ),
    trailing: const NotificationBellIcon(),
  );





  Widget _buildCardStack() {
    return AnimatedBuilder(
      animation: Listenable.merge([_pageController, _shuffleController, _spreadController]),
      builder: (context, child) {
        if (_feedItems.isEmpty) return const SizedBox.shrink();
        final scrollPos = _pageController.hasClients ? _pageController.page ?? 10000.0 : 10000.0;

        return LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth * 0.85;
            final cardHeight = cardWidth * (16 / 9);
            final maxCardHeight = (constraints.maxHeight - 40).clamp(0.0, cardHeight);
            final finalCardWidth = maxCardHeight * (9 / 16);

            return GestureDetector(
              onVerticalDragUpdate: _onVerticalDragUpdate,
              onVerticalDragEnd: _onVerticalDragEnd,
              behavior: HitTestBehavior.translucent,
              child: Stack(
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
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollStartNotification) {
                        if (!_isScrolling) {
                          _isScrolling = true;
                        }
                      } else if (notification is ScrollEndNotification) {
                        if (_isScrolling) {
                          setState(() {
                            _isScrolling = false;
                          });
                          // スワイプが完全に停止したタイミングで周辺の広告をロードする
                          _preloadAdsNearFocusedIndex();
                        }
                      }
                      return false;
                    },
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const FrictionlessPageScrollPhysics(),
                      onPageChanged: _onPageChanged,
                    itemBuilder: (context, index) {
                      final actualIndex = index % _feedItems.length;
                      final item = _feedItems[actualIndex];

                      // 広告スロットの場合：
                      // ガクつき（破棄・再生成）を防ぐため、常にプラットフォームビューを前面ツリーに保持します。
                      // ただし、2Dの横滑りが見えないよう、スワイプ中は透過させ、背面のプレースホルダーを透かして見せます。
                      // 広告スロットの場合：
                      // プラットフォームビューのネイティブタッチキャンセル問題（強制スワイプ）を防ぐため、
                      // PageView内では透明なスペーサーのみを返し、実体の広告は背面の固定レイヤーで描画します。
                      if (item is String && item == 'ad') {
                        final int globalIndex = index;
                        // サブピクセルレンダリングによる表示はみ出し判定エラー（AdMob Validator）を防ぐため、
                        // 広告の表示サイズを整数値に丸めます。
                        final double roundedWidth = finalCardWidth.roundToDouble();
                        final double roundedHeight = maxCardHeight.roundToDouble();

                        // 広告エリアが極端に狭い（縦横100未満）場合は、アセットが完全にはみ出すため
                        // 安全ガードとしてAdWidgetのマウントを行わずに自社プロモを表示させます。
                        final bool isSizeValid = roundedWidth >= 100.0 && roundedHeight >= 100.0;

                        return Center(
                          child: SizedBox(
                            width: roundedWidth,
                            height: roundedHeight,
                            child: AbsorbPointer(
                              absorbing: _isScrolling, // スワイプ中のみ広告へのタッチ入力を遮断してガクつきを防ぐ
                              child: NativeAdCard(
                                dimAlpha: 0.0,
                                isTop: actualIndex == _focusedGlobalIndex % _feedItems.length,
                                nativeAd: isSizeValid ? _nativeAds[globalIndex] : null,
                                isAdLoaded: isSizeValid && (_adLoadStatus[globalIndex] == true),
                                isAdLoadFailed: !isSizeValid || (_adLoadStatus[globalIndex] == false),
                              ),
                            ),
                          ),
                        );
                      }

                      final myUid = FirebaseAuth.instance.currentUser?.uid;
                      final alreadyReacted = item is Post ? item.hasEmojiReacted(myUid) : false;

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
                                    if (item is! Post) return;
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

                              // 三点リーダーのタップ領域（オーバーレイ側でキャッチしてVFIRE誤爆を防ぐ）
                              if (item is Post)
                                Positioned(
                                  top: 4,
                                  right: 0,
                                  width: 64, // タップしやすいように少し広めに
                                  height: 64,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      _showPostOptions(item);
                                    },
                                  ),
                                ),
                              // (以下略: 他のボタン等も必要に応じて AnimatedBuilder で参照可能)

                              // [New] タスク名とBGM情報を最前面のオーバーレイに配置
                              if (item is Post)
                                Positioned(
                                  top: 24,
                                  left: 20,
                                  right: 60, // 右上のメニューボタンと重ならないように制限
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.7),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.white.withValues(alpha: 0.1),
                                                width: 0.5,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.3),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Text(
                                              (item.isSecret && item.userId != myUid)
                                                  ? AppLocalizations.of(context)!.timelineSecretTaskLabel
                                                  : item.taskName,
                                              style: GoogleFonts.outfit(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.pureWhite,
                                                letterSpacing: 1,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _formatPostTime(item.createdAt, context),
                                            style: GoogleFonts.outfit(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.pureWhite.withValues(alpha: 0.8),
                                              shadows: [
                                                Shadow(
                                                  color: Colors.black.withValues(alpha: 0.5),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (item.bgmTitle != null) ...[
                                        const SizedBox(height: 8),
                                        BgmIndicator(
                                          title: item.bgmTitle!,
                                          artist: item.bgmArtist,
                                          url: item.bgmUrl,
                                          artworkUrl: item.bgmArtworkUrl,
                                          isMuted: _soundService.isBgmMuted,
                                          onMuteToggle: () async {
                                            await _soundService.toggleBgmMute(item.bgmUrl);
                                            setState(() {});
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                          // 2. アバタータップエリア (中心をVFIREと合わせる: bottom 32 + text 16 + gap 16 + avatar 40 = 104 -> center 84)
                          Positioned(
                            bottom: 32,
                            left: 20,
                            width: 60,
                            height: 72,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                if (item is! Post) return;
                                final photoUrl = _userPhotos[item.userId];
                                final username =
                                    _userNames[item.userId] ?? 'User';
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

                          // 拡張リアクション エモジピルズ
                          if (item is Post && _reactionMenuOpen)
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
                                      color: AppColors.pureWhite
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

                          // 絵文字＋ボタンのコーチマーク（初回のみ）
                          if (item is Post && _showSwipeGuide && !alreadyReacted)
                            Positioned(
                              bottom: 110, // ＋ボタンの上
                              right: 64, // しっぽが＋ボタンの中心（right: 110）を指すように調整
                              child: IgnorePointer(
                                child: AnimatedBuilder(
                                  animation: _swipeGuideTranslation,
                                  builder: (context, child) {
                                    // 縦方向にバウンスさせる
                                    return Transform.translate(
                                      offset: Offset(0, -_swipeGuideTranslation.value),
                                      child: child,
                                    );
                                  },
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: AppColors.accentGold,
                                          borderRadius: BorderRadius.circular(8),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.black.withValues(alpha: 0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          AppLocalizations.of(context)!.homeEmojiReactionHint,
                                          style: TextStyle(
                                            color: AppColors.black,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      // 吹き出しのしっぽ
                                      Container(
                                        margin: const EdgeInsets.only(right: 40),
                                        width: 12,
                                        height: 8,
                                        child: CustomPaint(
                                          painter: TooltipTailPainter(color: AppColors.accentGold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                          // ＋ または ✓ トグルボタン
                          if (item is Post)
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
                                    if (_showSwipeGuide) _dismissSwipeGuide();
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
                                          color: AppColors.pureWhite
                                              .withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: alreadyReacted
                                                ? AppColors.pureWhite
                                                    .withValues(alpha: 0.4)
                                                : AppColors.pureWhite
                                                    .withValues(alpha: 0.15),
                                            width: 1,
                                          ),
                                        ),
                                        child: Icon(
                                          alreadyReacted
                                              ? Icons.check_rounded
                                              : Icons.add_rounded,
                                          color: AppColors.pureWhite,
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
                          if (item is Post)
                            Positioned(
                            bottom: 32, // テキスト領域(16) + 間隔(8) + 本体(56) の中心を84に合わせる
                            right: 20,
                            width: 56,
                            height: 80,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _sendReaction(actualIndex),
                              // ── 長押し（ロングプレス）ジェスチャーの追加 ──
                              // 長押しが開始された瞬間にタイマーを起動し、オート連打を開始します。
                              onLongPressStart: (_) => _startFlameAutoFire(actualIndex),
                              // 指をボタンから離したときに連打タイマーを停止します。
                              onLongPressEnd: (_) => _stopFlameAutoFire(),
                              // スワイプ等の他のジェスチャーによって操作が中断されたときにも連打を停止させます。
                              onLongPressCancel: () => _stopFlameAutoFire(),
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
          ),

            // ── Swipe Guide Tutorial UI ──
            if (_showSwipeGuide && _feedItems.length > 1)
              SwipeGuideOverlay(
                cardWidth: finalCardWidth,
                translationAnimation: _swipeGuideTranslation,
              ),
          ],
        ),
      );
    },
  );
},
    );
  }

  List<int> _sortedCardIndices(double scrollPosition) {
    if (_feedItems.isEmpty) return [];
    final indices = List.generate(_feedItems.length, (i) => i);
    indices.sort((a, b) {
      final halfLength = _feedItems.length / 2.0;

      double distA = (a - scrollPosition) % _feedItems.length;
      if (distA > halfLength) distA -= _feedItems.length;
      if (distA < -halfLength) distA += _feedItems.length;
      final depthA = distA.abs();

      double distB = (b - scrollPosition) % _feedItems.length;
      if (distB > halfLength) distB -= _feedItems.length;
      if (distB < -halfLength) distB += _feedItems.length;
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
    final halfLength = _feedItems.length / 2.0;
    double relativePos = (index - scrollPosition) % _feedItems.length;
    if (relativePos > halfLength) relativePos -= _feedItems.length;
    if (relativePos < -halfLength) relativePos += _feedItems.length;

    // scrollPosition と relativePos からグローバルインデックスを算出
    final int globalIndex = (scrollPosition + relativePos).round();

    final double smoothDepth = relativePos.abs();

    if (smoothDepth > 3) return const SizedBox.shrink(); // パフォーマンス最適化

    final double scale = (1.0 - smoothDepth * 0.05 * _spreadFactor).clamp(0.8, 1.0);
    final double offsetY = smoothDepth * -20.0 * _spreadFactor;
    final double offsetX = relativePos * cardWidth * 1.2 * _spreadFactor;
    final double dimAlpha = (smoothDepth * 0.2 * _spreadFactor).clamp(0.0, 0.6);
    final double rotateZ = relativePos * 0.1 * _spreadFactor;

    final item = _feedItems[index];

    return Transform.translate(
      offset: Offset(
        offsetX + _getShuffleOffsetX(index), 
        offsetY + _dragOffset + _getShuffleOffsetY(index),
      ),
      child: AnimatedBuilder(
        animation: _shuffleController,
        builder: (context, child) {
          final isSingleCard = _feedItems.length <= 1;
          final matrix = Matrix4.identity();
          
          if (item is! String || item != 'ad') {
            matrix.setEntry(3, 2, 0.001); // 遠近感を追加
            if (_isRefreshing && isSingleCard) {
              // 3D 垂直回転 (Y軸回転)
              final double angle = _shuffleController.value * pi * 2;
              matrix.rotateY(index % 2 == 0 ? angle : -angle);
            } else {
              matrix.rotateZ(rotateZ + _getShuffleRotation(index));
            }
            matrix.scale(scale * _getShuffleScale(index));
          }

          return Transform(
            alignment: Alignment.center,
            transform: matrix,
            child: Stack(
              children: [
                child!,
                // 1枚の時のダイナミックな光沢
                if (_isRefreshing && isSingleCard)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            colors: [
                              AppColors.white.withValues(alpha: 0.0),
                              AppColors.white.withValues(alpha: 0.4),
                              AppColors.white.withValues(alpha: 0.0),
                            ],
                            stops: const [0.35, 0.5, 0.65],
                            begin: Alignment(sin(_shuffleController.value * pi * 2) * 2, -1.0),
                            end: Alignment(-sin(_shuffleController.value * pi * 2) * 2, 1.0),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
        child: RepaintBoundary(
          child: SizedBox(
            width: cardWidth.roundToDouble(),
            height: cardHeight.roundToDouble(),
            child: item is String && item == 'ad'
              ? () {
                  // 広告のプレースホルダー描画：
                  // 遠くにある時やスワイプ中は、他のカードと同じく 3D 空間にカード枠だけを描画します。
                  // プラットフォームビューの二重マウントを避けるため nativeAd は null を渡します。
                  // 2026ベストプラクティス：描画中の非同期副作用（ロード処理）を排除。
                  // 広告ロードはスクロール終了時（_preloadAdsNearFocusedIndex）と
                  // ページ切り替え時（_onPageChanged）に安全に行われます。

                  return NativeAdCard(
                    dimAlpha: dimAlpha,
                    isTop: globalIndex == _focusedGlobalIndex,
                    nativeAd: null, // 二重マウントを避けるため背面はプレースホルダー
                    isAdLoaded: _adLoadStatus[globalIndex] == true,
                    isAdLoadFailed: _adLoadStatus[globalIndex] == false,
                  );
                }()
              : () {
                  final post = item as Post;
                  final username = _userNames[post.userId] ?? 'Unknown';
                  final photoUrl = _userPhotos[post.userId];
                  final streak = _userStreaks[post.userId] ?? 0;
                  final badgeUrl = _userBadgeUrls[post.userId];
                  final badgeAnimation = _userBadgeAnimations[post.userId];
                  final tierColor = _getTierColor(streak);
                  return FeedCard(
                    post: post,
                    username: username,
                    userPhotoUrl: photoUrl,
                    userBadgeUrl: badgeUrl,
                    userBadgeAnimation: badgeAnimation,
                    dimAlpha: dimAlpha,
                    onReaction: ({emoji}) => _sendReaction(index, emoji: emoji),
                    isTop: index == _focusedIndex,
                    tierColor: tierColor,
                    // reactionCountNotifier: _flameNotifiers[post.id], は削除
                    onOptionsTap: () => _showPostOptions(post),
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
                  );
                }(),
          ),
        ),
      ),
    );
  }


  String _formatPostTime(DateTime createdAt, BuildContext context) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return AppLocalizations.of(context)!.timeNow;
    } else if (difference.inHours < 1) {
      return AppLocalizations.of(context)!.timeMinutesAgo(difference.inMinutes);
    } else if (difference.inDays < 1) {
      return AppLocalizations.of(context)!.timeHoursAgo(difference.inHours);
    } else {
      return AppLocalizations.of(context)!.timeDaysAgo(difference.inDays);
    }
  }
}

