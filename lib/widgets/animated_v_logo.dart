import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/app_colors.dart';

class AnimatedVLogo extends StatefulWidget {
  const AnimatedVLogo({super.key, this.size = 88});

  final double size;

  @override
  State<AnimatedVLogo> createState() => _AnimatedVLogoState();
}

class _AnimatedVLogoState extends State<AnimatedVLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), // やや早めのループ
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _kagerouColor(double time, double offset) {
    // カゲロウ（陽炎）のように下から上へ昇る波を計算
    // timeが増加するとともに進むサイン波
    final wave = (math.sin(time * 2.5 - offset * 1.5) + 1.0) / 2.0;
    // 細かい揺らめきを追加
    final ripple = (math.sin(time * 6.0 + offset * 0.5) + 1.0) / 2.0;

    final noise = wave * 0.7 + ripple * 0.3;
    
    // 輝度に変換（255:白 〜 130:やや暗め）
    final intensity = 130 + (noise * 125).toInt();
    return Color.fromARGB(255, intensity, intensity, intensity);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final time = _controller.value * math.pi * 2;

        // 全体の仄かな明るさの揺らめき用
        final flicker = (math.sin(time * 3) + 1) / 2;
        final spread = 2.0 + (flicker * 4.0);
        final blur = 24.0 + (flicker * 8.0);

        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: AppColors.black,
            borderRadius: BorderRadius.circular(widget.size * 0.25),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.12 + (flicker * 0.08)),
                blurRadius: blur,
                spreadRadius: spread,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.size * 0.25),
            child: ShaderMask(
              blendMode: BlendMode.multiply,
              shaderCallback: (bounds) {
                // 下から上へ、カゲロウのように揺らめくグラデーションバンド
                return LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                  colors: [
                    _kagerouColor(time, 0.0),
                    _kagerouColor(time, math.pi * 0.5),
                    _kagerouColor(time, math.pi * 1.0),
                    _kagerouColor(time, math.pi * 1.5),
                    _kagerouColor(time, math.pi * 2.0),
                  ],
                ).createShader(bounds);
              },
              child: Image.asset('assets/icon/app_icon.png', fit: BoxFit.cover),
            ),
          ),
        );
      },
    );
  }
}
