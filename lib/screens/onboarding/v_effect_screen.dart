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
  // 次のオンボーディング画面（プロフィール設定）へ進みます。
  void _next() {
    unawaited(UserService.instance.saveOnboardingStep('profile_settings'));
    Navigator.pushNamed(context, AppRoutes.onboardingProfile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        // 1枚のスリムな使い方画面（_FeaturePage）のみを直接表示します。
        // これにより、余計なスワイプ操作や認知負荷を取り除きました。
        child: _FeaturePage(onPressed: _next),
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

  // アニメーションのフェードイン間隔を定義します。
  static const _intervals = [
    [0.0, 0.2], // タイトル (V EFFECT の使い方)
    [0.1, 0.4], // 1. 習慣化したいことを決めよう
    [0.3, 0.6], // 2. 写真付きで証明しよう
    [0.5, 0.7], // ボタン
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
          // タイトル部分
          FadeTransition(
            opacity: _anims[0],
            child: Text(
              AppLocalizations.of(context)!.vEffectCoreTitle,
              style: GoogleFonts.notoSansJp(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 32),
          // ステップ1: 習慣化したいことを決めよう
          FadeTransition(
            opacity: _anims[1],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.vEffectStep1Title,
                  style: GoogleFonts.notoSansJp(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppLocalizations.of(context)!.vEffectStep1Desc,
                  style: GoogleFonts.notoSansJp(
                    fontSize: 13,
                    color: AppColors.grey50,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // ステップ2: 写真付きで証明しよう
          FadeTransition(
            opacity: _anims[2],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.vEffectStep2Title,
                  style: GoogleFonts.notoSansJp(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppLocalizations.of(context)!.vEffectStep2Desc,
                  style: GoogleFonts.notoSansJp(
                    fontSize: 13,
                    color: AppColors.grey50,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // 参加するボタン
          FadeTransition(
            opacity: _anims[3],
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
          const SizedBox(height: 56), // インジケーターが不要になったため、下部余白を少し縮小してバランスを整えます
        ],
      ),
    );
  }
}
