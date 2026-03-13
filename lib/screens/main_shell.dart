import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_colors.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

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

  final List<Widget> _screens = const [
    HomeScreen(),
    ProfileScreen(),
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
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),

          // ── Bottom spatial nav ──
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
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                AppColors.black.withValues(alpha: 0.6),
                AppColors.black.withValues(alpha: 0.9),
              ],
              stops: const [0.0, 0.3, 1.0],
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(
                  left: 40, right: 40, bottom: 8, top: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Home
                  _SpatialNavItem(
                    label: 'HOME',
                    isActive: _currentIndex == 0,
                    onTap: () => _onTap(0),
                  ),

                  // Profile
                  _SpatialNavItem(
                    label: 'PROFILE',
                    isActive: _currentIndex == 1,
                    onTap: () => _onTap(1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────
// Spatial Nav Item — Typography-driven
// ────────────────────────────────────────────
class _SpatialNavItem extends StatelessWidget {
  const _SpatialNavItem({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
            color: isActive ? AppColors.white : AppColors.grey30,
            letterSpacing: 3,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

