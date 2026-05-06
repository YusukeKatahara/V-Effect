import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_colors.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'hero_tasks_screen.dart';

// NavBarがコンテンツに被らないようSafeAreaのbottomに追加するオフセット
// 60(bar) + 12(margin) + 8(buffer) = 80
const double _kNavBarExtraBottom = 30;

/// Spatial Shell — ジェスチャー主導のUI空間
///
/// ボトムナビゲーションを排除。
/// 画面下部に最小限のナビゲーションヒントのみ配置。
class MainShell extends StatefulWidget {
  final int initialIndex;
  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;
  bool _isHomeLoading = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
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
    HapticFeedback.selectionClick();
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
                    _SpatialNavItem(
                      icon: Icons.person_rounded,
                      isActive: _currentIndex == 2,
                      onTap: () => _onTap(2),
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
  });

  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

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
            Icon(
              icon,
              size: 22,
              color: isActive ? AppColors.white : AppColors.grey30,
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isActive ? 3 : 0,
              height: 3,
              decoration: const BoxDecoration(
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
