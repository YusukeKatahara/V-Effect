import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_colors.dart';
import '../services/friend_service.dart';
import '../models/friend_request.dart';
import '../services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../widgets/notification_prompt_sheet.dart';
import '../services/sound_service.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'hero_tasks_screen.dart';

/// Spatial Shell — ジェスチャー主導のUI空間
///
/// ボトムナビゲーションを排除。
/// 画面下部に最小限のナビゲーションヒントのみ配置。
class MainShell extends StatefulWidget {
  final int initialIndex;
  const MainShell({super.key, this.initialIndex = 0});

  /// 外部からタブを切り替えるためのグローバル変数
  static final ValueNotifier<int> activeTabIndex = ValueNotifier<int>(0);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;
  bool _isHomeLoading = true;

  @override
  void initState() {
    super.initState();
    // 起動時の初期値をセット
    MainShell.activeTabIndex.value = widget.initialIndex;
    _currentIndex = widget.initialIndex;

    // 外部からのタブ切り替えを監視
    MainShell.activeTabIndex.addListener(_onGlobalTabChanged);

    // 再インストール時やオンボーディングスキップ時のためのフォールバック
    // ホーム画面が表示された直後に通知許可ダイアログをチェック・表示する
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNotificationPrompt();
    });
  }

  void _onGlobalTabChanged() {
    if (mounted && _currentIndex != MainShell.activeTabIndex.value) {
      // 外部からのタブ切り替え時に確実にBGMを止める
      SoundService.instance.stopBgm();
      setState(() {
        _currentIndex = MainShell.activeTabIndex.value;
      });
    }
  }

  @override
  void dispose() {
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
    final uid = UserService.instance.currentUid;
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
    const HeroTasksScreen(),
    const ProfileScreen(),
  ];

  void _onTap(int index) {
    if (_currentIndex != index) {
      // タブ切り替え時に確実にBGMを止める
      SoundService.instance.stopBgm();
    }
    HapticFeedback.selectionClick();
    MainShell.activeTabIndex.value = index;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bool isTablet = mq.size.width > 600;
    final double extraBottom = isTablet ? 80 : 30;

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

          // ── Bottom spatial nav ──
          if (!_isHomeLoading || _currentIndex != 0)
            Positioned(left: 0, right: 0, bottom: 0, child: _buildSpatialNav()),
        ],
      ),
    );
  }

  Widget _buildSpatialNav() {
    return SafeArea(
      top: false,
      child: Center(
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: AppColors.white.withValues(alpha: 0.12),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.5),
                blurRadius: 24,
                spreadRadius: -4,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.06),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.white.withValues(alpha: 0.1),
                      AppColors.white.withValues(alpha: 0.03),
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

                    // Hero Tasks
                    _SpatialNavItem(
                      icon: Icons.whatshot_rounded,
                      isActive: _currentIndex == 1,
                      onTap: () => _onTap(1),
                    ),

                    // Profile
                    StreamBuilder<List<FriendRequest>>(
                      stream: FriendService.instance.getReceivedRequests(),
                      builder: (context, snapshot) {
                        final hasRequests = snapshot.hasData && snapshot.data!.isNotEmpty;
                        return _SpatialNavItem(
                          icon: Icons.person_rounded,
                          isActive: _currentIndex == 2,
                          onTap: () => _onTap(2),
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
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isActive ? AppColors.white : AppColors.grey30,
                ),
                if (hasBadge)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isActive ? 3 : 0,
              height: 3,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
