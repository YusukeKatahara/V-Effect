import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import 'animated_v_logo.dart';

class SplashLoading extends StatelessWidget {
  const SplashLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AnimatedVLogo(size: 100),
            const SizedBox(height: 24),
            // Instagram like subtle loading text or just nothing
            Text(
              'V EFFECT',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 4.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
