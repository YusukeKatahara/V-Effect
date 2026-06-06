import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/app_colors.dart';

class RefreshRingButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const RefreshRingButton({super.key, required this.icon, this.onTap});

  @override
  State<RefreshRingButton> createState() => _RefreshRingButtonState();
}

class _RefreshRingButtonState extends State<RefreshRingButton>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.heavyImpact();
    _spinController.forward(from: 0).then((_) {
      HapticFeedback.lightImpact();
    });
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: SizedBox(
        width: 130,
        height: 130,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulseController, _spinController]),
          builder: (context, child) {
            final spinAngle =
                Curves.easeInOut.transform(_spinController.value) * 2 * pi;

            return Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: spinAngle,
                  child: CustomPaint(
                    size: const Size(108, 108),
                    painter: _RefreshRingPainter(
                      color: AppColors.accentGold,
                    ),
                  ),
                ),
                child!,
              ],
            );
          },
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppColors.grey10.withValues(alpha: 0.92),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentGold.withValues(alpha: 0.25),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(
              widget.icon,
              color: AppColors.accentGold,
              size: 36,
            ),
          ),
        ),
      ),
    );
  }
}

class _RefreshRingPainter extends CustomPainter {
  final Color color;

  const _RefreshRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    final paint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;

    const startAngle = 0.2;
    const sweepAngle = 5.3;

    final arcRect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(arcRect, startAngle, sweepAngle, false, paint);

    const endAngle = startAngle + sweepAngle;
    final tipX = center.dx + radius * cos(endAngle);
    final tipY = center.dy + radius * sin(endAngle);
    final tip = Offset(tipX, tipY);

    const tangentAngle = endAngle + pi / 2;
    const arrowLen = 8.0;
    const arrowSpread = 0.44;

    final a1 = Offset(
      tip.dx + arrowLen * cos(tangentAngle + pi - arrowSpread),
      tip.dy + arrowLen * sin(tangentAngle + pi - arrowSpread),
    );
    final a2 = Offset(
      tip.dx + arrowLen * cos(tangentAngle + pi + arrowSpread),
      tip.dy + arrowLen * sin(tangentAngle + pi + arrowSpread),
    );

    final arrowPaint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(tip, a1, arrowPaint);
    canvas.drawLine(tip, a2, arrowPaint);
  }

  @override
  bool shouldRepaint(_RefreshRingPainter old) => old.color != color;
}
