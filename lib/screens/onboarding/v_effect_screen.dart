import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import '../../config/app_colors.dart';
import '../../config/routes.dart';
import '../../services/user_service.dart';
import '../../widgets/gradient_button.dart';

class VEffectScreen extends StatefulWidget {
  const VEffectScreen({super.key});

  @override
  State<VEffectScreen> createState() => _VEffectScreenState();
}

class _VEffectScreenState extends State<VEffectScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    unawaited(UserService.instance.saveOnboardingStep('profile_settings'));
    Navigator.pushNamed(context, AppRoutes.onboardingProfile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Stack(
          children: [

            // メインコンテンツ (PageView)
            Positioned.fill(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  const _ConceptPage(),
                  _FeaturePage(onPressed: _next),
                ],
              ),
            ),

            // ページインジケーター（下部中央）
            Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(2, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index ? AppColors.white : AppColors.grey30,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConceptPage extends StatefulWidget {
  const _ConceptPage();

  @override
  State<_ConceptPage> createState() => _ConceptPageState();
}

class _ConceptPageState extends State<_ConceptPage> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<Animation<double>> _anims;

  static const _intervals = [
    [0.0, 0.2], // 1. V EFFECT とは
    [0.1, 0.4], // 2. V EFFECT の V は Victory（勝利）のVである。
    [0.3, 0.5], // 3. V (巨大文字)
    [0.4, 0.7], // 4. 小さな勝利の積み重ねが理想のあなたに近づける。
    [0.6, 0.8], // 5. このプラットフォームはそんなあなたの勝利と習慣をサポートします。
    [0.7, 1.0], // 6. さあ、仲間と共にV EFFECT(勝利者効果)を起こそう。
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 72),
          FadeTransition(
            opacity: _anims[0],
            child: Text(
              AppLocalizations.of(context)!.vEffectConceptTitle,
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
              AppLocalizations.of(context)!.vEffectDefinition,
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
              'V',
              style: GoogleFonts.outfit(
                fontSize: 56,
                fontWeight: FontWeight.w900,
                color: AppColors.white,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 36),
          FadeTransition(
            opacity: _anims[3],
            child: Text(
              AppLocalizations.of(context)!.vEffectConceptLine1,
              style: GoogleFonts.notoSansJp(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),
          FadeTransition(
            opacity: _anims[4],
            child: Text(
              AppLocalizations.of(context)!.vEffectConceptLine2,
              style: GoogleFonts.notoSansJp(
                fontSize: 14,
                color: AppColors.grey50,
              ),
            ),
          ),
          const SizedBox(height: 28),
          FadeTransition(
            opacity: _anims[5],
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.notoSansJp(
                  fontSize: 14,
                  color: AppColors.grey50,
                ),
                children: [
                  TextSpan(text: AppLocalizations.of(context)!.vEffectConceptLine3Prefix),
                  TextSpan(
                    text: AppLocalizations.of(context)!.vEffectTerm,
                    style: GoogleFonts.notoSansJp(
                      fontWeight: FontWeight.bold,
                      color: AppColors.white, // 強調のために白色にします
                    ),
                  ),
                  TextSpan(text: AppLocalizations.of(context)!.vEffectConceptLine3Suffix),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturePage extends StatefulWidget {
  final VoidCallback onPressed;
  const _FeaturePage({required this.onPressed});

  @override
  State<_FeaturePage> createState() => _FeaturePageState();
}

class _FeaturePageState extends State<_FeaturePage> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<Animation<double>> _anims;

  static const _intervals = [
    [0.0, 0.2], // タイトル (V EFFECT のコア機能)
    [0.1, 0.3], // 1. V Quest
    [0.2, 0.4], // V を証明しよう。きれいじゃなくていい。
    [0.3, 0.5], // 今日の達成を写真にする、それだけです。
    [0.4, 0.6], // やり遂げたその事実があなたを作りあげます。
    [0.6, 0.8], // 2. V Feed
    [0.7, 0.9], // お互いの努力が繋がりになる。
    [0.8, 1.0], // 今日 V を達成した仲間が見える。
    [0.9, 1.1], // 努力証明した者だけが届き、届けられる。
    [1.1, 1.3], // ボタン
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 72),
          FadeTransition(
            opacity: _anims[0],
            child: Text(
              AppLocalizations.of(context)!.vEffectCoreTitle,
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
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '1.  V Quest',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
                  TextSpan(
                    text: AppLocalizations.of(context)!.vEffectHeroTaskLabel,
                    style: GoogleFonts.notoSansJp(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.grey50,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FadeTransition(
            opacity: _anims[2],
            child: Text(
              AppLocalizations.of(context)!.vEffectSlogan,
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
              AppLocalizations.of(context)!.vEffectFeatureLine1,
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
              AppLocalizations.of(context)!.vEffectFeatureLine2,
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
              AppLocalizations.of(context)!.vEffectFeatureLine3,
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
              AppLocalizations.of(context)!.vEffectFeatureLine4,
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
              AppLocalizations.of(context)!.vEffectFeatureLine5,
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
              onPressed: widget.onPressed,
              child: Text(
                AppLocalizations.of(context)!.vEffectJoinButton,
                style: GoogleFonts.notoSansJp(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 96), // インジケーター用のスペースを考慮
        ],
      ),
    );
  }
}
