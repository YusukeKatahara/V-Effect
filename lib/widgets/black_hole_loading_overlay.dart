import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_colors.dart';

/// 投稿アップロード中に表示される、ブラックホール型のローディングエフェクト。
/// 待機中はずっと心臓の鼓動のような Haptic Feedback が鳴り続ける。
class BlackHoleLoadingOverlay extends StatefulWidget {
  final Future<void> uploadTask;

  const BlackHoleLoadingOverlay({
    super.key,
    required this.uploadTask,
  });

  /// このダイアログを表示し、`uploadTask` が完了するまで待機する
  static Future<void> show(BuildContext context, {required Future<void> uploadTask}) async {
    await showGeneralDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: BlackHoleLoadingOverlay(uploadTask: uploadTask),
        );
      },
    );
  }

  @override
  State<BlackHoleLoadingOverlay> createState() => _BlackHoleLoadingOverlayState();
}

class _BlackHoleLoadingOverlayState extends State<BlackHoleLoadingOverlay> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;
  Timer? _hapticTimer;

  // 吸い込まれるパーティクル群
  final List<_VoidParticle> _particles = [];
  late AnimationController _particleController;

  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();

    // 1. ブラックホールの鼓動アニメーション
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 0.95, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    // 2. 吸い込まれるパーティクルアニメーション
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _initParticles();

    // 3. 鼓動のHaptic
    _startHeartbeat();

    // 4. アップロード完了の監視
    _waitForUpload();
  }

  void _initParticles() {
    final rand = Random();
    for (int i = 0; i < 40; i++) {
      _particles.add(_VoidParticle(
        angle: rand.nextDouble() * 2 * pi,
        distance: rand.nextDouble() * 200 + 40,
        speed: rand.nextDouble() * 2.0 + 1.0,
        size: rand.nextDouble() * 3 + 1,
      ));
    }

    _particleController.addListener(() {
      for (final p in _particles) {
        p.distance -= p.speed;
        p.angle += 0.05; // 渦を巻くように回転
        if (p.distance < 10) {
          // 吸い込まれたら再生成
          p.distance = rand.nextDouble() * 150 + 100;
          p.angle = rand.nextDouble() * 2 * pi;
        }
      }
    });
  }

  void _startHeartbeat() {
    // 最初の1発目
    HapticFeedback.heavyImpact();
    
    // 1.2秒周期でドクン...ドクン...
    _hapticTimer = Timer.periodic(const Duration(milliseconds: 1200), (timer) {
      if (!_isCompleted && mounted) {
        HapticFeedback.heavyImpact();
      }
    });
  }

  Future<void> _waitForUpload() async {
    try {
      await widget.uploadTask;
    } finally {
      if (mounted) {
        setState(() {
          _isCompleted = true;
        });
        _hapticTimer?.cancel();
        // 完了したら少しの余韻を残して閉じる
        await Future.delayed(const Duration(milliseconds: 200));
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _particleController.dispose();
    _hapticTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 背景の暗転
          Container(
            color: AppColors.black.withValues(alpha: 0.85),
          ),
          
          // パーティクル（吸い込まれる光）
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, child) {
              return CustomPaint(
                painter: _VoidParticlePainter(_particles),
              );
            },
          ),

          // ブラックホール本体
          Center(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseScale.value,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.black,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentGold.withValues(alpha: 0.4),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                        BoxShadow(
                          color: AppColors.white.withValues(alpha: 0.1),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _VoidParticle {
  double angle;
  double distance;
  double speed;
  double size;

  _VoidParticle({
    required this.angle,
    required this.distance,
    required this.speed,
    required this.size,
  });
}

class _VoidParticlePainter extends CustomPainter {
  final List<_VoidParticle> particles;

  _VoidParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = AppColors.accentGold.withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

    for (final p in particles) {
      final x = center.dx + cos(p.angle) * p.distance;
      final y = center.dy + sin(p.angle) * p.distance;
      // 中心に近いほど小さく・不透明に
      final scale = (p.distance / 150).clamp(0.2, 1.0);
      canvas.drawCircle(Offset(x, y), p.size * scale, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _VoidParticlePainter oldDelegate) => true;
}
