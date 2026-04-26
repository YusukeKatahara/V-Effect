import "package:v_effect/config/app_colors.dart";
import 'package:flutter/material.dart';

/// Stack-based radial gradient glow overlay for premium dark theme screens.
class PremiumBackground extends StatelessWidget {
  const PremiumBackground({
    super.key,
    this.topGlowAlpha = 0.15,
    this.bottomGlowAlpha = 0.08,
  });

  final double topGlowAlpha;
  final double bottomGlowAlpha;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.white.withValues(alpha: topGlowAlpha),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.white.withValues(alpha: bottomGlowAlpha),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
