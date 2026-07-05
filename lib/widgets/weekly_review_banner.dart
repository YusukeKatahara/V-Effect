
import 'package:flutter/material.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import '../config/app_colors.dart';

/// 週末にだけ表示される、今週の振り返りへの誘導バナー
class WeeklyReviewBanner extends StatefulWidget {
  final VoidCallback onTap;

  const WeeklyReviewBanner({super.key, required this.onTap});

  @override
  State<WeeklyReviewBanner> createState() => _WeeklyReviewBannerState();
}

class _WeeklyReviewBannerState extends State<WeeklyReviewBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // パルス発光エフェクト (Positioned.fillで本体サイズに自動追随)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentGold.withValues(alpha: 0.2 * _pulseAnimation.value),
                          blurRadius: 20 * _pulseAnimation.value,
                          spreadRadius: 2 * _pulseAnimation.value,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // 本体
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: AppColors.isDark
                      ? const [
                          Color(0xFF1E1E1E), // 暗いグレー
                          Color(0xFF2C2A20), // ほんのりゴールドがかったグレー
                        ]
                      : [
                          AppColors.grey10, // ライトモード時の薄いグレー
                          AppColors.grey15, // ライトモード時の極薄グレー
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: AppColors.accentGold.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // テキスト
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'WEEKLY REVIEW',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.isDark
                                ? AppColors.accentGold.withValues(alpha: 0.8)
                                : AppColors.accentGold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppLocalizations.of(context)!.weeklyReviewBannerTitle,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // 矢印
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
