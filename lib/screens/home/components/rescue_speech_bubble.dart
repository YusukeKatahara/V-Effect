import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/app_colors.dart';

/// カード外上部に配置される、下向きポインター（先端）付きのパルス発光救済吹き出しバッジ
class RescueSpeechBubble extends StatefulWidget {
  final int currentCount;
  final int targetCount;

  const RescueSpeechBubble({
    super.key,
    this.currentCount = 0,
    this.targetCount = 150,
  });

  @override
  State<RescueSpeechBubble> createState() => _RescueSpeechBubbleState();
}

class _RescueSpeechBubbleState extends State<RescueSpeechBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAchieved = widget.currentCount >= widget.targetCount;
    final remaining = (widget.targetCount - widget.currentCount).clamp(0, widget.targetCount);

    final borderColor = isAchieved ? AppColors.accentGold : Colors.redAccent;
    final shadowColor1 = isAchieved ? AppColors.accentGold : Colors.redAccent;
    final shadowColor2 = isAchieved ? AppColors.accentGoldLight : Colors.orangeAccent;

    final badgeText = isAchieved
        ? '✨ 救済達成！不死鳥復活 🎉'
        : '🔥 あと ${remaining}VFIREで救済！';

    final badgeIcon = isAchieved
        ? Icons.auto_awesome_rounded
        : Icons.local_fire_department_rounded;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final glowAlpha = 0.35 + (_pulseController.value * 0.45);
        final borderAlpha = 0.7 + (_pulseController.value * 0.3);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 吹き出し本体
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.pureBlack.withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: borderColor.withValues(alpha: borderAlpha),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor1.withValues(alpha: glowAlpha),
                    blurRadius: isAchieved ? 22 : 16,
                    spreadRadius: isAchieved ? 3 : 2,
                  ),
                  BoxShadow(
                    color: shadowColor2.withValues(alpha: glowAlpha * 0.6),
                    blurRadius: isAchieved ? 32 : 28,
                    spreadRadius: isAchieved ? 5 : 4,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    badgeIcon,
                    color: isAchieved ? AppColors.accentGold : Colors.orangeAccent,
                    size: 15,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    badgeText,
                    style: GoogleFonts.notoSansJp(
                      color: isAchieved ? AppColors.accentGoldLight : AppColors.pureWhite,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            // 下向き三角形（ポインター）
            CustomPaint(
              size: const Size(12, 6),
              painter: _TrianglePointerPainter(
                color: borderColor.withValues(alpha: borderAlpha),
                bgColor: AppColors.pureBlack.withValues(alpha: 0.90),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TrianglePointerPainter extends CustomPainter {
  final Color color;
  final Color bgColor;

  _TrianglePointerPainter({required this.color, required this.bgColor});

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePointerPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.bgColor != bgColor;
  }
}
