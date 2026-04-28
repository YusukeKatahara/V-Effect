import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../config/routes.dart';
import '../../services/user_service.dart';
import '../../widgets/gradient_button.dart';

class CoreFeatureScreen extends StatefulWidget {
  const CoreFeatureScreen({super.key});

  @override
  State<CoreFeatureScreen> createState() => _CoreFeatureScreenState();
}

class _CoreFeatureScreenState extends State<CoreFeatureScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<Animation<double>> _anims;

  static const _intervals = [
    [0.00, 0.16], // タイトル
    [0.14, 0.28], // 1. V Quest ラベル
    [0.26, 0.40], // Vを証明しよう…
    [0.36, 0.50], // 今日の達成を写真に…
    [0.46, 0.60], // やり遂げたその事実が…
    [0.56, 0.70], // 2. V Feed ラベル
    [0.64, 0.78], // お互いの努力が…
    [0.72, 0.86], // 今日Vを達成した…
    [0.80, 0.93], // 努力証明した者だけが…
    [0.90, 1.00], // ボタン
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
    _anims = _intervals.map((iv) {
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
    unawaited(UserService.instance.saveOnboardingStep('profile_settings'));
    Navigator.pushNamed(context, AppRoutes.onboardingProfile);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Scaffold(
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
                      'V EFFECT のコア機能',
                      style: GoogleFonts.outfit(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: AppColors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  FadeTransition(
                    opacity: _anims[1],
                    child: Text(
                      '1.  V Quest',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FadeTransition(
                    opacity: _anims[2],
                    child: Text(
                      'V を証明しよう。きれいじゃなくていい。',
                      style: GoogleFonts.notoSansJp(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FadeTransition(
                    opacity: _anims[3],
                    child: Text(
                      '今日の達成を写真にする、それだけです。',
                      style: GoogleFonts.notoSansJp(
                        fontSize: 13,
                        color: AppColors.grey50,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  FadeTransition(
                    opacity: _anims[4],
                    child: Text(
                      'やり遂げたその事実があなたを作りあげます。',
                      style: GoogleFonts.notoSansJp(
                        fontSize: 13,
                        color: AppColors.grey50,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  FadeTransition(
                    opacity: _anims[5],
                    child: Text(
                      '2.  V Feed',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FadeTransition(
                    opacity: _anims[6],
                    child: Text(
                      'お互いの努力が繋がりになる。',
                      style: GoogleFonts.notoSansJp(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FadeTransition(
                    opacity: _anims[7],
                    child: Text(
                      '今日 V を達成した仲間が見える。',
                      style: GoogleFonts.notoSansJp(
                        fontSize: 13,
                        color: AppColors.grey50,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  FadeTransition(
                    opacity: _anims[8],
                    child: Text(
                      '努力証明した者だけが届き、届けられる。',
                      style: GoogleFonts.notoSansJp(
                        fontSize: 13,
                        color: AppColors.grey50,
                      ),
                    ),
                  ),
                  const Spacer(),
                  FadeTransition(
                    opacity: _anims[9],
                    child: GradientButton(
                      onPressed: _next,
                      child: Text(
                        'V EFFECT に参加する →',
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
        );
      },
    );
  }
}
