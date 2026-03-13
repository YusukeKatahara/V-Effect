import 'dart:math' as math;
import 'package:flutter/material.dart';

/// アメーバ型の流体アバター
///
/// [isAnimating] が true のとき、Blob が呼吸するように変形し続ける。
/// false のとき形は固定される。
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

  // 各頂点のランダムオフセット（固定時の形状を決める）
  late final List<double> _phaseOffsets;

  @override
  void initState() {
    super.initState();
    final rng = math.Random();
    _phaseOffsets = List.generate(8, (_) => rng.nextDouble() * math.pi * 2);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    if (widget.isAnimating) {
      _controller.repeat();
    } else {
      _controller.value = 0.0;
    }
  }

  @override
  void didUpdateWidget(FluidBlobAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimating && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isAnimating && _controller.isAnimating) {
      // 現在位置で止めるとスムーズ
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
      width: widget.size + 8, // glow 分のマージン
      height: widget.size + 8,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _BlobPainter(
              progress: _controller.value,
              phaseOffsets: _phaseOffsets,
              gradient: widget.gradient,
              glowColor: glowColor,
              borderWidth: widget.borderWidth,
              isAnimating: widget.isAnimating,
            ),
            child: Center(child: child),
          );
        },
        child: ClipPath(
          clipper: _BlobClipper(
            progress: widget.isAnimating ? null : 0.0,
            phaseOffsets: _phaseOffsets,
            controller: _controller,
          ),
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

/// Blob のパスを生成するユーティリティ
Path _createBlobPath(
  Size size,
  double progress,
  List<double> phaseOffsets, {
  double inset = 0,
}) {
  final cx = size.width / 2;
  final cy = size.height / 2;
  final baseRadius = (math.min(cx, cy)) - inset;

  const pointCount = 8;
  const smoothFactor = 0.55; // cubic bezier の滑らかさ

  // 各頂点の角度と半径を計算
  final points = <Offset>[];
  final radii = <double>[];
  for (int i = 0; i < pointCount; i++) {
    final angle = (i / pointCount) * math.pi * 2;
    // 変形量: sin波の重ね合わせでアメーバ感を出す
    final deform = math.sin(progress * math.pi * 2 + phaseOffsets[i]) * 0.08 +
        math.sin(progress * math.pi * 4 + phaseOffsets[i] * 1.5) * 0.04;
    final r = baseRadius * (1.0 + deform);
    radii.add(r);
    points.add(Offset(cx + r * math.cos(angle), cy + r * math.sin(angle)));
  }

  // ベジェ曲線でスムーズなBlobパスを構築
  final path = Path();
  for (int i = 0; i < pointCount; i++) {
    final curr = points[i];
    final next = points[(i + 1) % pointCount];
    final prev = points[(i - 1 + pointCount) % pointCount];
    final nextNext = points[(i + 2) % pointCount];

    if (i == 0) {
      path.moveTo(curr.dx, curr.dy);
    }

    // コントロールポイントを計算
    final cp1 = Offset(
      curr.dx + (next.dx - prev.dx) * smoothFactor / 3,
      curr.dy + (next.dy - prev.dy) * smoothFactor / 3,
    );
    final cp2 = Offset(
      next.dx - (nextNext.dx - curr.dx) * smoothFactor / 3,
      next.dy - (nextNext.dy - curr.dy) * smoothFactor / 3,
    );

    path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, next.dx, next.dy);
  }

  path.close();
  return path;
}

class _BlobPainter extends CustomPainter {
  _BlobPainter({
    required this.progress,
    required this.phaseOffsets,
    required this.gradient,
    required this.glowColor,
    required this.borderWidth,
    required this.isAnimating,
  });

  final double progress;
  final List<double> phaseOffsets;
  final Gradient? gradient;
  final Color glowColor;
  final double borderWidth;
  final bool isAnimating;

  @override
  void paint(Canvas canvas, Size size) {
    final blobPath = _createBlobPath(size, progress, phaseOffsets, inset: 4);

    // ── Glow（発光）──
    final glowPaint = Paint()
      ..color = glowColor.withValues(alpha: isAnimating ? 0.35 : 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawPath(blobPath, glowPaint);

    // ── グラデーション塗り ──
    if (gradient != null) {
      final fillPaint = Paint()
        ..shader = gradient!.createShader(Offset.zero & size);
      canvas.drawPath(blobPath, fillPaint);
    }

    // ── Border (soft glow border) ──
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          glowColor,
          glowColor.withValues(alpha: 0.4),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(blobPath, borderPaint);
  }

  @override
  bool shouldRepaint(_BlobPainter old) =>
      old.progress != progress || old.isAnimating != isAnimating;
}

/// ClipPath 用の Clipper — AnimationController で動的に更新
class _BlobClipper extends CustomClipper<Path> {
  _BlobClipper({
    required this.phaseOffsets,
    this.progress,
    this.controller,
  }) : super(reclip: controller);

  final List<double> phaseOffsets;
  final double? progress;
  final AnimationController? controller;

  @override
  Path getClip(Size size) {
    final p = progress ?? controller?.value ?? 0.0;
    return _createBlobPath(size, p, phaseOffsets, inset: 2);
  }

  @override
  bool shouldReclip(_BlobClipper old) => true;
}
