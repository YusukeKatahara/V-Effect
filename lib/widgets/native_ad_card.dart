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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
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
            // 背景色 (FeedCard と同じ AppColors.grey15)
            Container(color: AppColors.grey15),

            // 広告コンテンツの埋め込み (AdWidget)
            if (isAdLoaded && nativeAd != null)
              Positioned.fill(
                child: AdWidget(ad: nativeAd!),
              )
            else if (isAdLoadFailed)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // プレミアム感を演出するゴールドの王冠アイコン
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accentGold.withValues(alpha: 0.1),
                          border: Border.all(
                            color: AppColors.accentGold.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.workspace_premium_rounded,
                          color: AppColors.accentGold,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'V-PREMIUM',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accentGold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '広告を非表示にして、より快適に。',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.pureWhite,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '限定BGMの解放や特別なプロフィールバッジなど、すべてのプレミアム特典にアクセス。',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: AppColors.grey70,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          // 将来的にプレミアムプラン課金シートを開くなどの拡張が可能です
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentGold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'プレミアムプラン詳細',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Center(
                child: CircularProgressIndicator(
                  color: AppColors.accentGold,
                  strokeWidth: 2,
                ),
              ),

            // 左上のスマートな「広告」バッジ (透過背景でオーガニックに溶け込ませる)
            // 広告ロード成功時のみ表示（自社プロモ表示時は隠す）
            if (isAdLoaded && nativeAd != null)
              Positioned(
                top: 14,
                left: 10, // 三点リーダーボタン (right: 10) と対称に配置
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // 高さと余白を統一
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2), // 三点リーダーと同じ黒透過20%
                    borderRadius: BorderRadius.circular(12), // 他の丸型パーツと親和性の高い角丸
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.adLabel,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.pureWhite,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),



            // 暗幕レイヤー (奥にあるカードを暗くする処理)
            if (dimAlpha > 0)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: dimAlpha),
                ),
              ),

            // 最前面のボーダー (アンチエイリアスの隙間/白枠を隠す + 輪郭の強調)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isTop
                          ? AppColors.accentGold.withValues(alpha: 0.8)
                          : AppColors.grey15.withValues(alpha: 0.1),
                      width: isTop ? 1.5 : 0.5,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
