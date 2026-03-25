import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_colors.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'hero_tasks_screen.dart';

/// Spatial Shell — ジェスチャー主導のUI空間
///
/// ボトムナビゲーションを排除。
/// 画面下部に最小限のナビゲーションヒントのみ配置。
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  bool _isHomeLoading = true;

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
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        children: [
          // ── Screens ──
          IndexedStack(index: _currentIndex, children: _screens),

          // ── Bottom spatial nav ──
          if (!_isHomeLoading || _currentIndex != 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildSpatialNav(),
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
          margin: const EdgeInsets.only(bottom: 20),
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: AppColors.white.withValues(alpha: 0.08),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.05),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.white.withValues(alpha: 0.08),
                      AppColors.white.withValues(alpha: 0.02),
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
