import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../config/routes.dart';
import '../../services/user_service.dart';
import '../../widgets/gradient_button.dart';

class VEffectScreen extends StatefulWidget {
  const VEffectScreen({super.key});

  @override
  State<VEffectScreen> createState() => _VEffectScreenState();
}

class _VEffectScreenState extends State<VEffectScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<Animation<double>> _anims;

  static const _intervals = [
    [0.00, 0.00], // タイトル
    [0.05, 0.25], // VはVictoryのV
    [0.40, 0.50], // V EFFECTは
    [0.40, 0.50], // あなたと仲間の間で
    [0.55, 0.65], // V（大文字）
    [0.55, 0.65], // を積み重ねる…
    [0.70, 0.80], // 圧倒的な自信が…
    [0.85, 1.00], // ボタン
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );
    _anims =
        _intervals.map((iv) {
          return CurvedAnimation(
            parent: _ctrl,
            curve: Interval(iv[0], iv[1], curve: Curves.easeOut),
          );
        }).toList();
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _next() {
    unawaited(UserService.instance.saveOnboardingStep('core_feature'));
    Navigator.pushNamed(context, AppRoutes.onboardingCoreFeature);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return GestureDetector(
          onTap: _ctrl.isCompleted ? _next : null,
          child: Scaffold(
            backgroundColor: AppColors.black,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 72),
                    FadeTransition(
                      opacity: _anims[0],
                      child: Text(
                        'V EFFECT とは',
                        style: GoogleFonts.outfit(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: AppColors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    FadeTransition(
                      opacity: _anims[1],
                      child: Text(
                        'V EFFECT の V は Victory（勝利）の V',
                        style: GoogleFonts.notoSansJp(
                          fontSize: 15,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    FadeTransition(
                      opacity: _anims[2],
                      child: Text(
                        'V EFFECT は',
                        style: GoogleFonts.notoSansJp(
                          fontSize: 14,
                          color: AppColors.grey50,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FadeTransition(
                      opacity: _anims[3],
                      child: Text(
                        'あなたと仲間の間で',
                        style: GoogleFonts.notoSansJp(
                          fontSize: 14,
                          color: AppColors.grey50,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FadeTransition(
                      opacity: _anims[4],
                      child: Text(
                        'V',
                        style: GoogleFonts.outfit(
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          color: AppColors.white,
                          height: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FadeTransition(
                      opacity: _anims[5],
                      child: Text(
                        'を積み重ねるプラットフォームになることで',
                        style: GoogleFonts.notoSansJp(
                          fontSize: 14,
                          color: AppColors.grey50,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    FadeTransition(
                      opacity: _anims[6],
                      child: Text(
                        '圧倒的な自信がつくようサポートします。',
                        style: GoogleFonts.notoSansJp(
                          fontSize: 14,
                          color: AppColors.grey50,
                        ),
                      ),
                    ),
                    const Spacer(),
                    FadeTransition(
                      opacity: _anims[7],
                      child: GradientButton(
                        onPressed: _next,
                        child: Text(
                          '2つのコア機能 →',
                          style: GoogleFonts.notoSansJp(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
