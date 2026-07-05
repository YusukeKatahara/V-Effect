import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import '../../../config/app_colors.dart';

/// 新着投稿がある場合に画面上部に表示されるピル型のボタンコンポーネント
class NewPostsButton extends StatelessWidget {
  final VoidCallback onTap;

  const NewPostsButton({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.accentGold.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_upward_rounded, color: AppColors.black, size: 16),
            const SizedBox(width: 6),
            Text(
              AppLocalizations.of(context)!.homeNewPostsAvailable,
              style: GoogleFonts.outfit(
                color: AppColors.black,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
