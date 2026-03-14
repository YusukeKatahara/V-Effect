import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 円形アバター with 縁の輝きアニメーション
///
/// [isAnimating] が true のとき、縁に光の回転エフェクトが走る。
/// false のときは静的な縁表示。
class FluidBlobAvatar extends StatefulWidget {
  const FluidBlobAvatar({
    super.key,
    required this.child,
    this.size = 64,
    this.isAnimating = true,
    this.glowColor,
    this.gradient,
    this.borderWidth = 2.5,
  });

  final Widget child;
  final double size;
  final bool isAnimating;
  final Color? glowColor;
  final Gradient? gradient;
  final double borderWidth;

  @override
  State<FluidBlobAvatar> createState() => _FluidBlobAvatarState();
}

class _FluidBlobAvatarState extends State<FluidBlobAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    if (widget.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(FluidBlobAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimating && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isAnimating && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glowColor = widget.glowColor ?? const Color(0xFFFFFFFF);

    return SizedBox(
      width: widget.size + 8,
      height: widget.size + 8,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _ShimmerRingPainter(
              progress: _controller.value,
              gradient: widget.gradient,
              glowColor: glowColor,
              borderWidth: widget.borderWidth,
              isAnimating: widget.isAnimating,
            ),
            child: Center(child: child),
          );
        },
        child: ClipOval(
          child: SizedBox(
            width: widget.size - 4,
            height: widget.size - 4,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _ShimmerRingPainter extends CustomPainter {
  _ShimmerRingPainter({
    required this.progress,
    required this.gradient,
    required this.glowColor,
    required this.borderWidth,
    required this.isAnimating,
  });

  final double progress;
  final Gradient? gradient;
  final Color glowColor;
  final double borderWidth;
  final bool isAnimating;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = math.min(cx, cy) - 4;

    // ── 背景グラデーション塗り ──
    if (gradient != null) {
      final fillPaint = Paint()
        ..shader = gradient!.createShader(
          Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        );
      canvas.drawCircle(Offset(cx, cy), radius, fillPaint);
    }

    // ── 静的なベースの縁 ──
    final baseBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..color = glowColor.withValues(alpha: 0.3);
    canvas.drawCircle(Offset(cx, cy), radius, baseBorderPaint);

    // ── 輝きエフェクト（回転するハイライト） ──
    final sweepAngle = progress * math.pi * 2;

    // 光の弧を SweepGradient で描画
    final shimmerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth + (isAnimating ? 1.0 : 0.0)
      ..shader = SweepGradient(
        startAngle: sweepAngle,
        endAngle: sweepAngle + math.pi * 2,
        colors: [
          glowColor.withValues(alpha: 0.0),
          glowColor.withValues(alpha: 0.0),
          glowColor.withValues(alpha: isAnimating ? 0.9 : 0.3),
          glowColor.withValues(alpha: isAnimating ? 1.0 : 0.4),
          glowColor.withValues(alpha: isAnimating ? 0.9 : 0.3),
          glowColor.withValues(alpha: 0.0),
          glowColor.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.25, 0.40, 0.50, 0.60, 0.75, 1.0],
        transform: GradientRotation(sweepAngle),
      ).createShader(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      );
    canvas.drawCircle(Offset(cx, cy), radius, shimmerPaint);

    // ── 光源付近に柔らかいグロー ──
    if (isAnimating) {
      final glowAngle = sweepAngle + math.pi * 0.5;
      final glowX = cx + radius * math.cos(glowAngle);
      final glowY = cy + radius * math.sin(glowAngle);

      final spotGlow = Paint()
        ..color = glowColor.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(glowX, glowY), 6, spotGlow);
    }
  }

  @override
  bool shouldRepaint(_ShimmerRingPainter old) =>
      old.progress != progress || old.isAnimating != isAnimating;
}
