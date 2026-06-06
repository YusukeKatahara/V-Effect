import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import 'refresh_ring_button.dart';

import '../../l10n/app_localizations.dart';

class HomeEmptyState extends StatelessWidget {
  final VoidCallback onRefresh;

  const HomeEmptyState({super.key, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RefreshRingButton(
            icon: Icons.local_fire_department_outlined,
            onTap: onRefresh,
          ),
          const SizedBox(height: 32),
          Text(
            AppLocalizations.of(context)!.homeMotivationText1,
            style: GoogleFonts.notoSansJp(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.grey50,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.homeMotivationText2,
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSansJp(
              fontSize: 13,
              color: AppColors.grey30,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
