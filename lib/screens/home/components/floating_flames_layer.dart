import 'dart:math';
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';

/// 連打したときに画面下部から炎が浮かび上がるエフェクトレイヤー。
class FloatingFlamesLayer extends StatefulWidget {
  const FloatingFlamesLayer({super.key});

  @override
  State<FloatingFlamesLayer> createState() => FloatingFlamesLayerState();
}

class FloatingFlamesLayerState extends State<FloatingFlamesLayer> {
  int _counter = 0;
  final Map<int, Widget> _flames = {};

  void addFlame({
    Color? color,
    Color? glowColor,
    double? size,
    bool isGold = false,
    double bottomOffset = 120.0,
  }) {
    final id = _counter++;
    final randomX = (Random().nextDouble() - 0.5) * 60;

    setState(() {
      _flames[id] = Positioned(
        key: ValueKey(id),
        bottom: bottomOffset,
        right: 40 + randomX,
        child: _FloatingFlameWidget(
          key: ValueKey('flame_$id'),
          isGold: isGold,
          color: color,
          glowColor: glowColor,
          size: size,
          onComplete: () {
            if (mounted) {
              setState(() => _flames.remove(id));
            }
          },
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: _flames.values.toList());
  }
}

/// 連打で飛んでいく🔥アニメーションウィジェット。
class _FloatingFlameWidget extends StatefulWidget {
  final VoidCallback onComplete;
  final bool isGold;
  final Color? color;
  final Color? glowColor;
  final double? size;

  const _FloatingFlameWidget({
    super.key,
    required this.onComplete,
    this.isGold = false,
    this.color,
    this.glowColor,
    this.size,
  });

  @override
  State<_FloatingFlameWidget> createState() => _FloatingFlameWidgetState();
}

class _FloatingFlameWidgetState extends State<_FloatingFlameWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _dy;
  late Animation<double> _opacity;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.isGold ? 1500 : 1000),
    );

    _dy = Tween<double>(
      begin: 0,
      end: widget.isGold ? -500 : -300,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.5, 1.0)));
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.5, end: widget.isGold ? 2.5 : 1.5),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: widget.isGold ? 2.5 : 1.5, end: 1.0),
        weight: 80,
      ),
    ]).animate(_ctrl);

    _ctrl.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _dy.value),
          child: Transform.scale(
            scale: _scale.value,
            child: Opacity(opacity: _opacity.value, child: child),
          ),
        );
      },
      child: Icon(
        Icons.whatshot,
        color: widget.color ?? (widget.isGold ? AppColors.accentGoldLight : AppColors.accentGold),
        size: widget.size ?? (widget.isGold ? 64 : 44),
        shadows: [
          Shadow(
            color: widget.glowColor ?? (widget.isGold ? AppColors.white : AppColors.white.withValues(alpha: 0.24)),
            blurRadius: widget.isGold ? 24 : 12,
          ),
        ],
      ),
    );
  }
}
