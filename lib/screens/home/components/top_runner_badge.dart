import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/app_colors.dart';

/// 本日（0:00以降）フレンドサークル内で一番早くタスクをクリアして投稿したユーザーに輝くバッジ
class TopRunnerBadge extends StatelessWidget {
  const TopRunnerBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1605).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.accentGold,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentGold.withValues(alpha: 0.5),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '🥇',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(width: 4),
          Text(
            '今日のトップランナー',
            style: GoogleFonts.notoSansJp(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: AppColors.accentGold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
