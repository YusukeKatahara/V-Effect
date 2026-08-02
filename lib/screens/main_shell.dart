import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_colors.dart';
import '../models/friend_request.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../widgets/notification_prompt_sheet.dart';
import '../services/sound_service.dart';
import '../providers/service_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home_screen.dart';
import 'v_timeline_screen.dart';
import 'profile_screen.dart';
import 'hero_tasks_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home/components/floating_flames_layer.dart';
import 'home/components/dopamine_emoji_explosion_layer.dart';
import '../services/deep_link_service.dart';

/// Spatial Shell — ジェスチャー主導のUI空間
///
/// ボトムナビゲーションを排除。
/// 画面下部に最小限のナビゲーションヒントのみ配置。
class MainShell extends ConsumerStatefulWidget {
  final int initialIndex;
  const MainShell({super.key, this.initialIndex = 0});

  /// 外部からタブを切り替えるためのグローバル変数
  static final ValueNotifier<int> activeTabIndex = ValueNotifier<int>(0);

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  late int _currentIndex;
  bool _isHomeLoading = true;
  late final SoundService _soundService; // BGM制御用サービス（アンマウント時のクラッシュ防止のため保持）

  final GlobalKey<FloatingFlamesLayerState> _globalFlamesKey = GlobalKey();
  final GlobalKey<DopamineEmojiExplosionLayerState> _globalExplosionKey = GlobalKey();
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  DateTime? _lastNotificationHandledTime;

  String? _topBannerMessage;
  Timer? _topBannerTimer;
  final Map<String, String> _usernameCache = {};

  @override
  void initState() {
    super.initState();
    _soundService = ref.read(soundServiceProvider);
    // 起動時の初期値をセット
    MainShell.activeTabIndex.value = widget.initialIndex;
    _currentIndex = widget.initialIndex;

    // 外部からのタブ切り替えを監視
    MainShell.activeTabIndex.addListener(_onGlobalTabChanged);

    // 再インストール時やオンボーディングスキップ時のためのフォールバック
    // ホーム画面が表示された直後に通知許可ダイアログをチェック・表示する
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNotificationPrompt();
      _initRealtimeEffectListener();
      DeepLinkService().onNavigatorReady();
    });
  }

  void _initRealtimeEffectListener() {
    final uid = ref.read(userServiceProvider).currentUid;
    if (uid == null) return;

    _notificationSubscription?.cancel();
    _lastNotificationHandledTime = DateTime.now();

    // リアルタイムに自分宛てのリアクション通知を監視
    _notificationSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('toUid', isEqualTo: uid)
        .where('type', isEqualTo: 'reactionReceived')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
          final data = change.doc.data();
          if (data == null) continue;

          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
          if (createdAt != null &&
              _lastNotificationHandledTime != null &&
              createdAt.isAfter(_lastNotificationHandledTime!)) {
            _lastNotificationHandledTime = createdAt;

            final emoji = data['emoji'] as String?;
            final lastInc = (data['lastIncrement'] as int?) ?? 1;
            final flameEffectCount = lastInc.clamp(1, 20);
            HapticFeedback.mediumImpact();

            if (emoji != null && emoji.isNotEmpty) {
              // 送られてきた具体的な絵文字を画面下から爆発・演出！
              final emojiCount = flameEffectCount.clamp(1, 5);
              for (int i = 0; i < emojiCount; i++) {
                Future.delayed(Duration(milliseconds: i * 120), () {
                  if (mounted) _globalExplosionKey.currentState?.explode(emoji);
                });
              }
            } else {
              // VFIRE(🔥)の場合、今回の送信数(lastInc)の分だけ画面中央の下からメラメラ連続で立ち上げる！
              for (int i = 0; i < flameEffectCount; i++) {
                Future.delayed(Duration(milliseconds: i * 80), () {
                  if (!mounted) return;
                  _globalFlamesKey.currentState?.addFlame(
                    color: AppColors.accentGold,
                    glowColor: AppColors.accentGoldLight,
                    size: 55.0,
                    isCentered: true,
                    bottomOffset: 80.0,
                  );
                });
              }
            }
            _handleIncomingReactionNotification(data, lastInc, emoji);
          }
        }
      }
    }, onError: (e) {
      debugPrint('Realtime effect listener error: $e');
    });
  }

  void _showTopBannerNotification(String message) {
    _topBannerTimer?.cancel();
    setState(() {
      _topBannerMessage = message;
    });
    _topBannerTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _topBannerMessage = null;
        });
      }
    });
  }

  Future<void> _handleIncomingReactionNotification(
    Map<String, dynamic> data,
    int incrementCount,
    String? emoji,
  ) async {
    final fromUid = data['fromUid'] as String?;
    String senderName = 'フレンド';

    if (fromUid != null && fromUid.isNotEmpty) {
      if (_usernameCache.containsKey(fromUid)) {
        senderName = _usernameCache[fromUid]!;
      } else {
        try {
          final userSnap = await FirebaseFirestore.instance.collection('users').doc(fromUid).get();
          if (userSnap.exists) {
            final userData = userSnap.data();
            senderName = userData?['username'] ?? userData?['displayName'] ?? 'フレンド';
            _usernameCache[fromUid] = senderName;
          }
        } catch (e) {
          debugPrint('Error fetching sender username: $e');
        }
      }
    }

    String bannerText;
    if (emoji != null && emoji.isNotEmpty) {
      bannerText = '$senderNameさんから「$emoji」が届きました！';
    } else {
      bannerText = incrementCount > 1
          ? '$senderNameさんから$incrementCount回のV FIREが届きました！'
          : '$senderNameさんからV FIREが届きました！';
    }

    _showTopBannerNotification(bannerText);
  }

  void _onGlobalTabChanged() {
    if (mounted && _currentIndex != MainShell.activeTabIndex.value) {
      // 外部からのタブ切り替え時に確実にBGMを止める
      _soundService.stopBgm();
      setState(() {
        _currentIndex = MainShell.activeTabIndex.value;
      });
    }
  }

  @override
  void dispose() {
    _topBannerTimer?.cancel();
    _notificationSubscription?.cancel();
    MainShell.activeTabIndex.removeListener(_onGlobalTabChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex) {
      setState(() {
        _currentIndex = widget.initialIndex;
      });
    }
  }

  Future<void> _checkNotificationPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = ref.read(userServiceProvider).currentUid;
    if (uid == null) return;

    // すでに表示済みの場合は何もしません
    final hasShown = prefs.getBool('notification_prompt_shown_$uid') ?? false;
    if (hasShown) return;

    try {
      // すでに通知許可済みの場合はモーダルを表示する必要がないため、フラグだけ立ててスキップします
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        await prefs.setBool('notification_prompt_shown_$uid', true);
        return;
      }

      if (mounted) {
        // ハーフモーダル (プレ・ダイアログ) を表示し、その中で自動でOS通知パーミッション要求をトリガーします
        await NotificationPromptSheet.show(context);
        
        // 次回以降表示されないようにフラグを保存します
        await prefs.setBool('notification_prompt_shown_$uid', true);
      }
    } catch (e) {
      debugPrint('通知プロンプト表示エラー: $e');
    }
  }

  late final List<Widget> _screens = [
    HomeScreen(
      onLoadingChanged: (isLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _isHomeLoading = isLoading);
        });
      },
    ),
    const VTimelineScreen(),
    const HeroTasksScreen(),
    const ProfileScreen(),
  ];

  void _onTap(int index) {
    if (_currentIndex != index) {
      // タブ切り替え時に確実にBGMを止める
      _soundService.stopBgm();
    }
    HapticFeedback.selectionClick();
    MainShell.activeTabIndex.value = index;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bool isTablet = mq.size.width > 600;
    final double extraBottom = isTablet ? 70 : 20; // ピルバー縮小に合わせて、背後コンテンツの下部セーフエリアパディングも調整 (iPad: 70, iPhone: 20)

    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        children: [
          // ── Screens ── MediaQueryをオーバーライドしてNavBarの高さ分だけ
          // 子画面のSafeArea.bottomを増やし、コンテンツが重ならないようにする
          MediaQuery(
            data: mq.copyWith(
              padding: mq.padding.copyWith(
                bottom: mq.padding.bottom + extraBottom,
              ),
            ),
            child: IndexedStack(index: _currentIndex, children: _screens),
          ),

          // ── Global Real-Time Live Flame & Emoji Waves ──
          Positioned.fill(
            child: IgnorePointer(
              child: FloatingFlamesLayer(key: _globalFlamesKey),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DopamineEmojiExplosionLayer(
                key: _globalExplosionKey,
                bottomOffset: 40.0,
              ),
            ),
          ),

          // ── Bottom spatial nav ──
          if (!_isHomeLoading || _currentIndex != 0)
            Positioned(left: 0, right: 0, bottom: 0, child: _buildSpatialNav()),

          // ── Real-Time Top Reaction Banner (UploadProgressBarと同一UI) ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _topBannerMessage != null
                    ? Container(
                        key: ValueKey(_topBannerMessage),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                        color: AppColors.accentGold.withValues(alpha: 0.1),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.local_fire_department,
                              color: AppColors.accentGold,
                              size: 12,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _topBannerMessage!,
                                style: GoogleFonts.notoSansJp(
                                  color: AppColors.accentGold,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('empty_top_banner')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpatialNav() {
    return SafeArea(
      top: false,
      child: Center(
        child: Container(
          margin: const EdgeInsets.only(bottom: 8), // 下部マージンを縮小 (プランC)
          height: 48, // 全体の高さを 60 から 48 にスリム化 (プランA)
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24), // 高さ48pxに合わせた角丸 (半円状にするため高さの半分の24pxに設定)
            border: Border.all(
              color: AppColors.isDark
                  ? AppColors.white.withValues(alpha: 0.12)
                  : AppColors.border,
              width: AppColors.isDark ? 0.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.pureBlack.withValues(
                  alpha: AppColors.isDark ? 0.5 : 0.15,
                ),
                blurRadius: 24,
                spreadRadius: -4,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24), // 角丸を24pxに統一
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4), // 左右パディングの微調整
                decoration: BoxDecoration(
                  color: AppColors.isDark
                      ? AppColors.white.withValues(alpha: 0.06)
                      : AppColors.pureWhite.withValues(alpha: 0.8),
                  gradient: AppColors.isDark
                      ? LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.white.withValues(alpha: 0.1),
                            AppColors.white.withValues(alpha: 0.03),
                          ],
                        )
                      : LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.pureWhite.withValues(alpha: 0.85),
                            AppColors.pureWhite.withValues(alpha: 0.75),
                          ],
                        ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Home (Feed)
                    _SpatialNavItem(
                      icon: Icons.explore_rounded,
                      isActive: _currentIndex == 0,
                      onTap: () => _onTap(0),
                    ),

                    // V Timeline (Public)
                    _SpatialNavItem(
                      icon: Icons.public_rounded,
                      isActive: _currentIndex == 1,
                      onTap: () => _onTap(1),
                    ),

                    // Hero Tasks
                    _SpatialNavItem(
                      icon: Icons.whatshot_rounded,
                      isActive: _currentIndex == 2,
                      onTap: () => _onTap(2),
                    ),

                    // Profile
                    StreamBuilder<List<FriendRequest>>(
                      stream: ref.watch(friendServiceProvider).getReceivedRequests(),
                      builder: (context, snapshot) {
                        final hasRequests = !snapshot.hasError && snapshot.hasData && snapshot.data!.isNotEmpty;
                        return _SpatialNavItem(
                          icon: Icons.person_rounded,
                          isActive: _currentIndex == 3,
                          onTap: () => _onTap(3),
                          hasBadge: hasRequests,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────
// Spatial Nav Item — Icon-driven
// ────────────────────────────────────────────
class _SpatialNavItem extends StatelessWidget {
  const _SpatialNavItem({
    required this.icon,
    required this.isActive,
    required this.onTap,
    this.hasBadge = false,
  });

  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final bool hasBadge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), // タップ有効領域（当たり判定）を広く維持しつつ余白を調整
        child: Center(
          widthFactor: 1.0,
          heightFactor: 1.0,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedScale(
                scale: isActive ? 1.15 : 1.0, // アクティブ時に拡大するスムーズなアニメーション効果 (プランB)
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: Icon(
                  icon,
                  size: 20, // 基準のアイコンサイズを20に変更 (アクティブ時は23相当に拡大)
                  color: isActive
                      ? AppColors.white
                      : (AppColors.isDark ? AppColors.grey30 : AppColors.grey50),
                ),
              ),
              if (hasBadge)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 7, // バーの縮小に合わせてバッジのサイズもわずかに縮小 (8 -> 7)
                    height: 7,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
