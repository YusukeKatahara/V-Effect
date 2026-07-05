import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';

/// ホーム画面でのカードスワイプ案内（チュートリアル）を表示するオーバーレイコンポーネント
class SwipeGuideOverlay extends StatelessWidget {
  final double cardWidth;
  final Animation<double> translationAnimation;

  const SwipeGuideOverlay({
    super.key,
    required this.cardWidth,
    required this.translationAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: cardWidth + 64, // カードの左右端の少し外側に配置
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AnimatedBuilder(
              animation: translationAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(-translationAnimation.value, 0),
                  child: child,
                );
              },
              child: Icon(
                Icons.chevron_left_rounded,
                color: AppColors.accentGold.withValues(alpha: 0.7),
                size: 40,
              ),
            ),
            AnimatedBuilder(
              animation: translationAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(translationAnimation.value, 0),
                  child: child,
                );
              },
              child: Icon(
                Icons.chevron_right_rounded,
                color: AppColors.accentGold.withValues(alpha: 0.7),
                size: 40,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
