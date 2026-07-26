import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_colors.dart';
import '../l10n/app_localizations.dart';
import 'confetti_widget.dart';

/// 150 VFIRE達成時に表示される、不死鳥の如くストリークが完全復活する全画面ダイアログ
class VPhoenixRebirthDialog extends StatefulWidget {
  final int streakDays;

  const VPhoenixRebirthDialog({
    super.key,
    required this.streakDays,
  });

  static Future<void> show(BuildContext context, {required int streakDays}) {
    HapticFeedback.heavyImpact();
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'VPhoenixRebirth',
      barrierColor: Colors.black.withValues(alpha: 0.90),
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (context, anim1, anim2) {
        return VPhoenixRebirthDialog(streakDays: streakDays);
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final curve = Curves.elasticOut.transform(anim1.value);
        return Transform.scale(
          scale: 0.8 + (curve * 0.2),
          child: Opacity(
            opacity: anim1.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<VPhoenixRebirthDialog> createState() => _VPhoenixRebirthDialogState();
}

class _VPhoenixRebirthDialogState extends State<VPhoenixRebirthDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 背景の深みのあるブラー効果
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(color: Colors.transparent),
            ),
          ),

          // 紙吹雪演出
          const Positioned.fill(
            child: ConfettiWidget(),
          ),

          // メインコンテンツ
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // 不死鳥の燃え上がるオーラアイコン
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final scale = 1.0 + (_pulseController.value * 0.08);
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.black,
                            border: Border.all(
                              color: Colors.orangeAccent.withValues(alpha: 0.8),
                              width: 2.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orangeAccent.withValues(alpha: 0.45),
                                blurRadius: 50,
                                spreadRadius: 15,
                              ),
                              BoxShadow(
                                color: AppColors.accentGold.withValues(alpha: 0.3),
                                blurRadius: 80,
                                spreadRadius: 25,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.whatshot_rounded,
                                color: Colors.orangeAccent,
                                size: 48,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${widget.streakDays}',
                                style: GoogleFonts.outfit(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.accentGold,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const Spacer(flex: 1),

                  // REIGNITE タイトル
                  Text(
                    l.vPhoenixRebirthDialogTitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: AppColors.accentGold,
                      letterSpacing: 4.0,
                      shadows: [
                        Shadow(
                          color: AppColors.accentGold.withValues(alpha: 0.5),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 説明本文
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      l.vPhoenixRebirthDialogDesc(widget.streakDays),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.notoSansJp(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.pureWhite,
                        height: 1.6,
                      ),
                    ),
                  ),

                  const Spacer(flex: 3),

                  // 続行ボタン
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
                        'OK',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
