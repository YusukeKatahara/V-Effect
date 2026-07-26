import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// カード外上部に配置される、下向きポインター（先端）付きのパルス発光救済吹き出しバッジ
class RescueSpeechBubble extends StatefulWidget {
  const RescueSpeechBubble({super.key});

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
    final l = AppLocalizations.of(context)!;

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
                color: AppColors.black.withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: borderAlpha),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withValues(alpha: glowAlpha),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.orangeAccent.withValues(alpha: glowAlpha * 0.6),
                    blurRadius: 28,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.whatshot_rounded,
                    color: Colors.orangeAccent,
                    size: 15,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    l.vPhoenixRescueBadge,
                    style: GoogleFonts.notoSansJp(
                      color: AppColors.pureWhite,
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
                color: Colors.redAccent.withValues(alpha: borderAlpha),
                bgColor: AppColors.black.withValues(alpha: 0.90),
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
