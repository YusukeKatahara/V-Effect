import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import 'animated_v_logo.dart';

/// 統一されたフルスクリーンローディング画面
class BrandedFullPageLoading extends StatelessWidget {
  const BrandedFullPageLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: const Center(
        child: AnimatedVLogo(size: 80),
      ),
    );
  }
}

/// アクション処理中（保存・更新など）に画面をブロックする軽量なオーバーレイ
class BrandedLoadingOverlay extends StatelessWidget {
  const BrandedLoadingOverlay({super.key});

  /// オーバーレイを表示する
  static void show(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierColor: AppColors.black.withValues(alpha: 0.5),
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: const BrandedLoadingOverlay(),
        );
      },
    );
  }

  /// オーバーレイを閉じる
  static void hide(BuildContext context) {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: AnimatedVLogo(size: 64),
      ),
    );
  }
}
