import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// V EFFECT 伝統の標準炎アイコン (Icons.local_fire_department)
class VFlameIcon extends StatelessWidget {
  final double size;
  final Color? color;
  final bool isGlowing;
  final double glowRadius;

  const VFlameIcon({
    super.key,
    this.size = 24.0,
    this.color,
    this.isGlowing = true,
    this.glowRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = color ?? AppColors.accentGold;

    // 物理的に100%完全背景透過化されたアルファPNGを描画 (四角い透明枠は絶対発生ゼロ)
    final iconWidget = Icon(
      Icons.local_fire_department,
      size: size,
      color: baseColor,
    );

    if (!isGlowing) {
      return iconWidget;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: baseColor.withValues(alpha: 0.4),
            blurRadius: glowRadius,
            spreadRadius: 1,
          ),
        ],
      ),
      child: iconWidget,
    );
  }
}
