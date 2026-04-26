import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../widgets/v_effect_header.dart';

class VPracticeScreen extends StatelessWidget {
  const VPracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Column(
          children: [
            VEffectHeader(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: AppColors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.construction_rounded,
                      size: 64,
                      color: AppColors.white.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'V-Practice',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white.withValues(alpha: 0.8),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Coming Soon',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.white.withValues(alpha: 0.35),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 100), // ヘッダー分を調整して中央寄せを維持
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
