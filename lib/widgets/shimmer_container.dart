import 'package:flutter/material.dart';

/// 骨組み（スケルトン）表示用の、アニメーション付きプレースホルダーウィジェット
///
/// 2026年のダークテーマデザインに調和するよう、暗いグレーをベースにした
/// スライド式のグラデーション（シマー効果）を描画します。
class ShimmerContainer extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final ShapeBorder shape;

  const ShimmerContainer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
    this.shape = const RoundedRectangleBorder(),
  });

  /// 円形（アバター画像など）のプレースホルダー用コンストラクタ
  const ShimmerContainer.circular({
    super.key,
    required double size,
  })  : width = size,
        height = size,
        borderRadius = size / 2,
        shape = const CircleBorder();

  @override
  State<ShimmerContainer> createState() => _ShimmerContainerState();
}

class _ShimmerContainerState extends State<ShimmerContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // アニメーション周期は1.5秒で繰り返します
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: ShapeDecoration(
            shape: widget.shape is CircleBorder
                ? const CircleBorder()
                : RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                  ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                Color(0xFF161616), // 基本の背景色（暗いグレー）
                Color(0xFF262626), // 流れる光の色（少し明るいグレー）
                Color(0xFF161616), // 基本の背景色
              ],
              stops: const [0.3, 0.5, 0.7],
              transform: _SlidingGradientTransform(slidePercent: _controller.value),
            ),
          ),
        );
      },
    );
  }
}

/// グラデーションの位置を横方向に移動させるための変形クラス
class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    // slidePercent (0.0 〜 1.0) に基づいて、X軸方向の平行移動行列（Matrix）を計算します
    return Matrix4.translationValues(
      bounds.width * (slidePercent - 0.5) * 2,
      0.0,
      0.0,
    );
  }
}
