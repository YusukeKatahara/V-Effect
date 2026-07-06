import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/app_colors.dart';

class RefreshRingButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool isUnlocked;

  const RefreshRingButton({
    super.key,
    required this.icon,
    this.onTap,
    this.isUnlocked = false,
  });

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
      duration: const Duration(milliseconds: 800), // 回転速度を 800ms に最適化
    );

    // マウントされた時点で解錠状態の場合は安全に自動回転をトリガー
    if (widget.isUnlocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _triggerUnlockAnimation();
        }
      });
    }
  }

  @override
  void didUpdateWidget(RefreshRingButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部から解錠状態への切り替えがトリガーされた場合、自動で回転演出を開始
    if (!oldWidget.isUnlocked && widget.isUnlocked) {
      _triggerUnlockAnimation();
    }
  }

  void _triggerUnlockAnimation() {
    HapticFeedback.mediumImpact(); // 鍵が開く「カチッ」とした感触
    _spinController.forward(from: 0).then((_) {
      HapticFeedback.lightImpact();
    });
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
                Curves.fastOutSlowIn.transform(_spinController.value) * 2 * pi;

            // _pulseController (2秒ループ) を用いた鼓動スケール (1.0 〜 1.04) の計算
            final pulseScale = 1.0 + (sin(_pulseController.value * 2 * pi) * 0.04);

            return Stack(
              alignment: Alignment.center,
              children: [
                // 外側に広がるゴールドのパルス（波紋）エフェクト
                Opacity(
                  opacity: (1.0 - _pulseController.value) * 0.4,
                  child: Container(
                    width: 76 + (_pulseController.value * 32),
                    height: 76 + (_pulseController.value * 32),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.accentGold,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                Transform.rotate(
                  angle: spinAngle,
                  child: CustomPaint(
                    size: const Size(108, 108),
                    painter: _RefreshRingPainter(
                      color: AppColors.accentGold,
                    ),
                  ),
                ),
                // 中央の炎ボタン本体を優しく鼓動させる
                Transform.scale(
                  scale: pulseScale,
                  child: child!,
                ),
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
