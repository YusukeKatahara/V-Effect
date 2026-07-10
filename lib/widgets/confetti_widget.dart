import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 上品に舞い散る紙吹雪を再現するアニメーションウィジェット
class ConfettiWidget extends StatefulWidget {
  const ConfettiWidget({super.key});

  @override
  State<ConfettiWidget> createState() => _ConfettiWidgetState();
}

class _ConfettiWidgetState extends State<ConfettiWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_ConfettiParticle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    // 常にアニメーションループを回して毎フレーム更新する
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addListener(() {
        if (mounted) {
          setState(() {
            for (final p in _particles) {
              p.update();
            }
          });
        }
      });
    _controller.repeat();
  }

  void _initParticles(Size size) {
    if (_particles.isNotEmpty) return;
    // 贅沢感を出しつつ、画面がうるさくならない程度の適度な数（55個）
    for (int i = 0; i < 55; i++) {
      _particles.add(_ConfettiParticle.random(_random, size));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (size.width > 0 && size.height > 0) {
          _initParticles(size);
        }
        return CustomPaint(
          size: size,
          painter: _ConfettiPainter(_particles),
        );
      },
    );
  }
}

class _ConfettiParticle {
  double x;
  double y;
  double speedY;
  double speedX;
  double angle;
  double rotationSpeed;
  double width;
  double height;
  Color color;
  final math.Random random;
  final Size maxBounds;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.speedY,
    required this.speedX,
    required this.angle,
    required this.rotationSpeed,
    required this.width,
    required this.height,
    required this.color,
    required this.random,
    required this.maxBounds,
  });

  factory _ConfettiParticle.random(math.Random random, Size bounds) {
    // V EFFECTのブランドカラー（ゴールド、ホワイト、シルバー）を基調とした高級感ある配色
    final colors = [
      const Color(0xFFFFD700), // ブライトゴールド
      const Color(0xFFD4AF37), // メタリックゴールド
      const Color(0xFFF3E5AB), // ソフトゴールド
      const Color(0xFFFFFFFF), // ピュアホワイト
      const Color(0xFFE0E0E0), // シルバーグレー
      const Color(0xFF9E9E9E), // ミディアムグレー
    ];
    
    return _ConfettiParticle(
      x: random.nextDouble() * bounds.width,
      // 画面上部から自然に降り注ぐよう、初期位置を画面外（負の値）に分散させる
      y: random.nextDouble() * -bounds.height * 1.5,
      speedY: 1.0 + random.nextDouble() * 2.0, // ゆったり舞い落ちる速度
      speedX: -0.5 + random.nextDouble() * 1.0,
      angle: random.nextDouble() * math.pi * 2,
      rotationSpeed: -0.04 + random.nextDouble() * 0.08,
      width: 5.0 + random.nextDouble() * 6.0,
      height: 3.5 + random.nextDouble() * 4.0,
      color: colors[random.nextInt(colors.length)]
          .withValues(alpha: 0.5 + random.nextDouble() * 0.5), // 透明度を散らして立体感を出す
      random: random,
      maxBounds: bounds,
    );
  }

  void update() {
    y += speedY;
    // ゆらゆら揺れる動きをサイン波で表現
    x += speedX + math.sin(y / 25) * 0.4;
    angle += rotationSpeed;

    // 画面最下部に到達したら再び上部に戻して無限ループ
    if (y > maxBounds.height) {
      y = -20;
      x = random.nextDouble() * maxBounds.width;
      speedY = 1.0 + random.nextDouble() * 2.0;
    }
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  _ConfettiPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      // 画面外のパーティクルは描画しない（描画パフォーマンス最適化）
      if (p.y < -10 || p.y > size.height) continue;
      
      paint.color = p.color;
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.angle);
      
      // 角丸の紙吹雪を描画することで、Appleらしい柔らかさを演出
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.width, height: p.height),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
