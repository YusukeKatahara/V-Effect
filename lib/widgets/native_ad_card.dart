import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import '../config/app_colors.dart';

class NativeAdCard extends StatelessWidget {
  final double dimAlpha;
  final bool isTop;
  final NativeAd? nativeAd;
  final bool isAdLoaded;
  final bool isAdLoadFailed;

  const NativeAdCard({
    super.key,
    required this.dimAlpha,
    required this.isTop,
    required this.nativeAd,
    required this.isAdLoaded,
    this.isAdLoadFailed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: AppColors.bgSurface,
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.6),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
          if (isTop)
            BoxShadow(
              color: AppColors.accentGold.withValues(alpha: 0.15),
              blurRadius: 40,
              spreadRadius: 2,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Premium Background Gradient
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.accentGold.withValues(alpha: 0.15),
                      AppColors.grey15,
                      AppColors.grey15,
                      AppColors.black.withValues(alpha: 0.4),
                    ],
                    stops: const [0.0, 0.3, 0.7, 1.0],
                  ),
                ),
              ),
            ),

            // Center Area: Thank You Message & Ad Content
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  if (isAdLoaded && nativeAd != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.black.withValues(alpha: 0.4),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          // medium テンプレートの自然な高さ(本文によって変動)を
                          // クリップしないよう、固定 360 から余裕のある 440 に拡大。
                          // 高さが足りないと NativeAdView の枠外にアセットがはみ出し、
                          // バリデーターが "Advertiser assets outside native ad view"
                          // を表示する。
                          child: SizedBox(
                            height: 440,
                            child: AdWidget(ad: nativeAd!),
                          ),
                        ),
                      ),
                    )
                  else if (isAdLoadFailed)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Icon(Icons.campaign_rounded, color: AppColors.grey30, size: 64),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(color: AppColors.accentGold),
                    ),
                ],
              ),
            ),

            // Top Left Badge
            Positioned(
              top: 24,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.3)),
                ),
                child: Text(
                  AppLocalizations.of(context)!.adLabel,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentGold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),

            // NOTE: 広告主名・アイコン・"広告" 表記といったアセットは、すべて
            // ネイティブ広告テンプレート (AdWidget) が NativeAdView の *内部* に
            // 描画する。広告主アセットをビュー外に偽装描画すると AdMob の
            // ネイティブ広告ポリシー違反 (advertiser assets outside native ad view)
            // になるため、従来あった偽の広告主プロフィールは撤去している。

            // Dim Overlay for un-focused cards
            if (dimAlpha > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: Colors.black.withValues(alpha: dimAlpha),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
