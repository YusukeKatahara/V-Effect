import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import '../../../config/app_colors.dart';

/// ホーム画面でエラーが発生した際に表示されるエラーボディコンポーネント
class HomeErrorBody extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const HomeErrorBody({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: AppColors.accentGold, size: 48),
          const SizedBox(height: 16),
          Text(AppLocalizations.of(context)!.homeErrorOccurred,
              style: GoogleFonts.outfit(color: AppColors.white)),
          const SizedBox(height: 8),
          Text('$error', style: TextStyle(color: AppColors.grey50, fontSize: 12)),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.grey10,
              foregroundColor: AppColors.white,
            ),
            onPressed: onRetry,
            child: Text(AppLocalizations.of(context)!.homeRetry),
          )
        ],
      ),
    );
  }
}
