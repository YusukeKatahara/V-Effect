import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
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
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    if (!mounted) return;
    final isVisible = info.visibleFraction > 0.01;
    if (_isVisible != isVisible) {
      setState(() {
        _isVisible = isVisible;
      });
      if (isVisible) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  Color _kagerouColor(double time, double offset) {
    // 負荷軽減のためサイン波の計算を少し簡略化
    final wave = (math.sin(time * 2.5 - offset * 1.5) + 1.0) * 0.5;
    // 細かい揺らめきは固定値や周期を調整して負荷バランスを取る
    final intensity = 135 + (wave * 120).toInt();
    return Color.fromARGB(255, intensity, intensity, intensity);
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('animated_v_logo_${widget.hashCode}'),
      onVisibilityChanged: _handleVisibilityChanged,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final time = _controller.value * math.pi * 2;

            // 仄かな明るさの揺らめき
            final flicker = (math.sin(time * 3) + 1) * 0.5;
            final spread = 2.0 + (flicker * 3.0);
            final blur = 20.0 + (flicker * 6.0);

            return Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: AppColors.black,
                borderRadius: BorderRadius.circular(widget.size * 0.25),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.white.withValues(alpha: 0.12 + (flicker * 0.05)),
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
                    return LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      stops: const [0.0, 0.33, 0.66, 1.0],
                      colors: [
                        _kagerouColor(time, 0.0),
                        _kagerouColor(time, math.pi * 0.6),
                        _kagerouColor(time, math.pi * 1.2),
                        _kagerouColor(time, math.pi * 1.8),
                      ],
                    ).createShader(bounds);
                  },
                  child: Image.asset('assets/icon/app_icon.png', fit: BoxFit.cover),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
