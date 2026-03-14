import 'dart:math' as math;
import 'package:flutter/material.dart';

/// モノクロの炎アイコンを CustomPaint で描画し、
/// 揺らめきアニメーションを付けるウィジェット。
class StreakFlame extends StatefulWidget {
  const StreakFlame({super.key, this.size = 28});

  final double size;

  @override
  State<StreakFlame> createState() => _StreakFlameState();
}

class _StreakFlameState extends State<StreakFlame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
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
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.size, widget.size * 1.3),
          painter: _FlamePainter(progress: _controller.value),
        );
      },
    );
  }
}

class _FlamePainter extends CustomPainter {
  _FlamePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // 揺らぎパラメータ
    final t = progress * math.pi * 2;
    final sway = math.sin(t) * w * 0.04;
    final tipSway = math.sin(t * 1.3 + 0.5) * w * 0.06;
    final scaleBreath = 1.0 + math.sin(t * 0.7) * 0.03;

    canvas.save();
    canvas.translate(cx, h);
    canvas.scale(scaleBreath, -scaleBreath); // Y反転（下→上に描画）

    // ── 外炎（薄いグロー） ──
    final outerPath = _buildFlamePath(
      w: w,
      h: h,
      sway: sway * 1.2,
      tipSway: tipSway * 1.3,
      widthFactor: 1.15,
      heightFactor: 1.05,
    );
    final outerGlow = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(outerPath, outerGlow);

    // ── 主炎 ──
    final mainPath = _buildFlamePath(
      w: w,
      h: h,
      sway: sway,
      tipSway: tipSway,
      widthFactor: 1.0,
      heightFactor: 1.0,
    );
    final mainPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          const Color(0xFFFFFFFF).withValues(alpha: 0.7),
          const Color(0xFFFFFFFF).withValues(alpha: 0.35),
          const Color(0xFFFFFFFF).withValues(alpha: 0.05),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(-w / 2, 0, w, h));
    canvas.drawPath(mainPath, mainPaint);

    // ── 内炎（コア） ──
    final innerPath = _buildFlamePath(
      w: w,
      h: h,
      sway: sway * 0.5,
      tipSway: tipSway * 0.6,
      widthFactor: 0.5,
      heightFactor: 0.7,
    );
    final innerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          const Color(0xFFFFFFFF).withValues(alpha: 0.9),
          const Color(0xFFFFFFFF).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(-w / 2, 0, w, h));
    canvas.drawPath(innerPath, innerPaint);

    canvas.restore();
  }

  Path _buildFlamePath({
    required double w,
    required double h,
    required double sway,
    required double tipSway,
    required double widthFactor,
    required double heightFactor,
  }) {
    final hw = w * 0.42 * widthFactor; // 半幅
    final fh = h * 0.92 * heightFactor; // 炎の高さ

    final path = Path();
    // 底部中央からスタート
    path.moveTo(0, 0);
    // 左側の膨らみ
    path.cubicTo(
      -hw * 0.3 + sway, fh * 0.15,
      -hw * 1.1 + sway, fh * 0.35,
      -hw * 0.7 + sway, fh * 0.6,
    );
    // 左側から先端へ
    path.cubicTo(
      -hw * 0.35 + tipSway, fh * 0.82,
      -hw * 0.1 + tipSway, fh * 0.95,
      tipSway, fh,
    );
    // 先端から右側へ
    path.cubicTo(
      hw * 0.1 + tipSway, fh * 0.95,
      hw * 0.35 + tipSway, fh * 0.82,
      hw * 0.7 + sway, fh * 0.6,
    );
    // 右側の膨らみから底部へ
    path.cubicTo(
      hw * 1.1 + sway, fh * 0.35,
      hw * 0.3 + sway, fh * 0.15,
      0, 0,
    );
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(_FlamePainter old) => old.progress != progress;
}
