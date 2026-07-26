import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// V EFFECT 独自のシャープなゴールド炎アイコン (Cyber Gold Flame Icon)
/// 丸っこい水滴・玉ねぎ・一般的な雫型アイコンを100%追放し、最高にスタイリッシュな幾何学火炎を描画。
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
    final iconWidget = Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.04),
      child: Image.asset(
        'assets/icon/v_fire_gold_icon.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
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
