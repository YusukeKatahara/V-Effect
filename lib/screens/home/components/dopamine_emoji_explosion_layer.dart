import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// パーティクル1個の不変パラメータ（ウィジェットツリー不使用）。
class ParticleData {
  final double vx0;
  final double vy0;
  final double rotation0;
  final double rotationSpeed;
  final double startTime;
  final TextPainter textPainter; // レイアウト済みキャッシュ

  static const double lifetime = 1.2; // 秒

  ParticleData({
    required String emoji,
    required this.vx0,
    required this.vy0,
    required this.rotation0,
    required this.rotationSpeed,
    required this.startTime,
    required double size,
  }) : textPainter = TextPainter(
         text: TextSpan(text: emoji, style: TextStyle(fontSize: size)),
         textDirection: TextDirection.ltr,
       )..layout();

  bool isDone(double elapsed) => elapsed - startTime >= lifetime;
}

/// リアクションメニューで絵文字を選択した際に、ドーパミン全開の爆発エフェクトを描画するレイヤー。
class DopamineEmojiExplosionLayer extends StatefulWidget {
  final double bottomOffset;

  const DopamineEmojiExplosionLayer({
    super.key,
    this.bottomOffset = 120.0,
  });

  @override
  State<DopamineEmojiExplosionLayer> createState() =>
      DopamineEmojiExplosionLayerState();
}

class DopamineEmojiExplosionLayerState
    extends State<DopamineEmojiExplosionLayer>
    with SingleTickerProviderStateMixin {
  final List<ParticleData> _particles = [];
  late final Ticker _ticker;
  double _elapsed = 0.0;
  Duration? _prevTickTime;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  void _onTick(Duration now) {
    if (_prevTickTime != null) {
      _elapsed += (now - _prevTickTime!).inMicroseconds / 1e6;
    }
    _prevTickTime = now;

    _particles.removeWhere((p) => p.isDone(_elapsed));

    if (!mounted) return;
    if (_particles.isEmpty) {
      _ticker.stop();
      _prevTickTime = null;
      _elapsed = 0.0;
    }
    setState(() {});
  }

  void explode(String emoji) {
    final random = Random();
    final t = _elapsed;

    final newParticles = List.generate(56, (_) {
      final angle = (pi + 0.3) + (random.nextDouble() * (pi - 0.6));
      final speed = 700.0 + random.nextDouble() * 1300.0;
      return ParticleData(
        emoji: emoji,
        vx0: cos(angle) * speed,
        vy0: sin(angle) * speed,
        rotation0: random.nextDouble() * 2 * pi,
        rotationSpeed: (random.nextDouble() - 0.5) * 6.0,
        startTime: t,
        size: 20.0 + random.nextDouble() * 52.0,
      );
    });

    setState(() {
      _particles.addAll(newParticles);
      if (!_ticker.isActive) {
        _prevTickTime = null;
        _ticker.start();
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_particles.isEmpty) return const SizedBox.expand();
    return CustomPaint(
      painter: EmojiExplosionPainter(
        particles: _particles,
        elapsed: _elapsed,
        bottomOffset: widget.bottomOffset,
      ),
    );
  }
}

/// 全パーティクルをキャンバスに直接描画（ウィジェットリビルドなし）。
class EmojiExplosionPainter extends CustomPainter {
  final List<ParticleData> particles;
  final double elapsed;
  final double bottomOffset;

  static const double _gravity = 800.0; // px/秒²
  static const double _k = 0.7; // 空気抵抗係数

  EmojiExplosionPainter({
    required this.particles,
    required this.elapsed,
    required this.bottomOffset,
  });

  /// Elastic out イージング
  static double _elasticOut(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    return exp(log(2) * (-10 * t)) * sin((t * 10 - 0.75) * (2 * pi / 3)) + 1.0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = (elapsed - p.startTime).clamp(0.0, ParticleData.lifetime);
      if (t <= 0) continue;

      // 解析的物理演算（フレームレート非依存）
      final expDecay = exp(-_k * t);
      final dx = p.vx0 / _k * (1.0 - expDecay);
      final dy =
          p.vy0 / _k * (1.0 - expDecay) +
          _gravity / _k * (t - (1.0 - expDecay) / _k);

      // キャンバス座標（下端bottomOffsetから上方向）
      final x = size.width / 2 + dx;
      final y = size.height - bottomOffset + dy;

      final progress = t / ParticleData.lifetime;

      // フェードアウト: 進行度70%以降で消える
      final opacity =
          progress < 0.7 ? 1.0 : (1.0 - (progress - 0.7) / 0.3).clamp(0.0, 1.0);
      if (opacity <= 0) continue;

      // スケール: elastic out で 0→1.5 (最初の30%), 線形で 1.5→1.0 (残り70%)
      final double scale;
      if (progress < 0.3) {
        scale = _elasticOut(progress / 0.3) * 1.5;
      } else {
        scale = 1.5 - 0.5 * ((progress - 0.3) / 0.7);
      }

      final rotation = p.rotation0 + p.rotationSpeed * t;
      final textSize = p.textPainter.size;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      canvas.scale(scale, scale);
      canvas.translate(-textSize.width / 2, -textSize.height / 2);

      if (opacity < 0.995) {
        // フェードアウト区間のみ saveLayer でアルファ合成（大半は不要）
        canvas.saveLayer(
          Rect.fromLTWH(0, 0, textSize.width, textSize.height),
          Paint()
            ..color = Color.fromARGB((opacity * 255).round(), 255, 255, 255),
        );
        p.textPainter.paint(canvas, Offset.zero);
        canvas.restore();
      } else {
        p.textPainter.paint(canvas, Offset.zero);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(EmojiExplosionPainter old) =>
      elapsed != old.elapsed || particles.length != old.particles.length;
}
