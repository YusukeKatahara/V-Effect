import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_colors.dart';
import '../models/app_notification.dart';
import 'confetti_widget.dart';

/// ストリーク達成時に表示される、贅沢な余白とApple風の高級感を持たせた全画面お祝いダイアログ
class StreakCelebrationDialog extends StatelessWidget {
  final AppNotification notification;

  const StreakCelebrationDialog({
    super.key,
    required this.notification,
  });

  /// お祝いダイアログを表示するための静的メソッド
  static Future<void> show(BuildContext context, AppNotification notification) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'StreakCelebration',
      barrierColor: Colors.black.withValues(alpha: 0.85), // 背景を深みのある暗さに
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return StreakCelebrationDialog(notification: notification);
      },
      transitionBuilder: (context, anim1, anim2, child) {
        // Apple風の滑らかなズーム＆フェードイン効果
        final curve = Curves.easeOutQuart.transform(anim1.value);
        return Transform.scale(
          scale: 0.94 + (curve * 0.06),
          child: Opacity(
            opacity: anim1.value,
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleText = notification.title;
    final bodyText = notification.body;
    final isJa = Localizations.localeOf(context).languageCode == 'ja';

    // 1. ストリーク日数のパース
    final relatedId = notification.relatedId ?? '';
    int streakDays = 0;
    if (relatedId.startsWith('streak_')) {
      streakDays = int.tryParse(relatedId.replaceFirst('streak_', '')) ?? 0;
    }
    if (streakDays == 0) {
      // 本文やタイトルから数値を抽出するフォールバック
      final numRegExp = RegExp(r'(\d+)');
      final matchNum = numRegExp.firstMatch(titleText.isNotEmpty ? titleText : bodyText);
      if (matchNum != null) {
        streakDays = int.tryParse(matchNum.group(1)!) ?? 0;
      }
    }

    // 2. メッセージ本文から「」内のお茶目なシステムメッセージを抽出
    String message = bodyText;
    final regExp = RegExp(r'「([^」]+)」');
    final match = regExp.firstMatch(bodyText);
    if (match != null) {
      message = match.group(1)!;
    }
    
    // 3. タイトルのクリーンアップ
    String mainTitle = titleText;
    if (isJa && titleText.contains('あなたが') && titleText.contains('達成！')) {
      mainTitle = titleText.replaceAll('あなたが', '').replaceAll('達成！', '達成');
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 背景のブラー効果（元の通知画面をすりガラス越しに見せる）
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
          
          // 上品に舞う紙吹雪演出
          const Positioned.fill(
            child: ConfettiWidget(),
          ),

          // メインコンテンツ
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36.0, vertical: 24.0),
              child: Column(
                children: [
                  // Apple UI特有の贅沢な上部余白
                  const Spacer(flex: 3),

                  // 4. 中央の光り輝くストリーク日数表示 (アイコンの代わり)
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.black,
                      border: Border.all(
                        color: AppColors.accentGold.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentGold.withValues(alpha: 0.22),
                          blurRadius: 45,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$streakDays',
                          style: GoogleFonts.outfit(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: AppColors.accentGold,
                            height: 1.0,
                            shadows: [
                              Shadow(
                                color: AppColors.accentGold.withValues(alpha: 0.35),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isJa ? 'ストリーク' : 'STREAK',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white70,
                            letterSpacing: isJa ? 1.0 : 2.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 1),

                  // 5. お祝いタイトル（Outfitで力強くかつプレミアムに）
                  Text(
                    mainTitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accentGold,
                      letterSpacing: 0.5,
                      height: 1.2,
                      shadows: [
                        Shadow(
                          color: AppColors.accentGold.withValues(alpha: 0.35),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 6. 洗練されたラベル（日本語と英語で完全に分離）
                  Text(
                    isJa ? 'ストリーク達成祝い' : 'STREAK CELEBRATION',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white54,
                      letterSpacing: isJa ? 2.0 : 3.5,
                    ),
                  ),

                  const Spacer(flex: 1),

                  // 7. お茶目なシステムメッセージ用の磨りガラス調カード
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
                    decoration: BoxDecoration(
                      color: AppColors.grey10.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.grey20.withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.terminal_rounded,
                          size: 22,
                          color: AppColors.accentGold.withValues(alpha: 0.8),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            color: Colors.white, // 透過させない純白
                            height: 1.65,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 下部のボタンに向けての余白
                  const Spacer(flex: 4),

                  // 8. 継続を促すエレガントなモノトーンボタン（日本語と英語で完全に分離）
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.white,
                        foregroundColor: AppColors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        isJa ? '続ける' : 'Keep Going',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
