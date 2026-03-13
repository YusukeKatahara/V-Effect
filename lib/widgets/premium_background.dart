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
                    Colors.white.withValues(alpha: topGlowAlpha),
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
                    Colors.white.withValues(alpha: bottomGlowAlpha),
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
