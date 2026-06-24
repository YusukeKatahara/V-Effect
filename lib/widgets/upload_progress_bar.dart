import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_colors.dart';
import '../providers/upload_provider.dart';

/// 投稿のアップロード状況（進行中・成功・エラー）を控えめに通知するプログレスバーウィジェット
class UploadProgressBar extends ConsumerWidget {
  const UploadProgressBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploadState = ref.watch(uploadProvider);

    // idle（待機）状態の場合は何も描画しない
    if (uploadState.status == UploadStatus.idle) {
      return const SizedBox.shrink();
    }

    // エラー状態：赤色のエラーバナーを表示し、タップで再試行させる
    if (uploadState.status == UploadStatus.error) {
      return GestureDetector(
        onTap: () {
          ref.read(uploadProvider.notifier).retryUpload();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: AppColors.error.withValues(alpha: 0.15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, color: AppColors.error, size: 14),
              const SizedBox(width: 8),
              Text(
                '送信失敗。タップして再送信',
                style: GoogleFonts.notoSansJp(
                  color: AppColors.error,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 成功状態：ゴールドの控えめな送信完了バナー
    if (uploadState.status == UploadStatus.success) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        color: AppColors.accentGold.withValues(alpha: 0.1),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline_rounded, color: AppColors.accentGold, size: 12),
            const SizedBox(width: 6),
            Text(
              '送信完了しました！',
              style: GoogleFonts.notoSansJp(
                color: AppColors.accentGold,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    // アップロード中：細いゴールドの進捗バーと%表記
    final progressPercent = (uploadState.progress * 100).toInt();

    return Container(
      width: double.infinity,
      color: AppColors.bgSurface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '投稿を送信中...',
                  style: GoogleFonts.notoSansJp(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '$progressPercent%',
                  style: GoogleFonts.outfit(
                    color: AppColors.accentGold,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 2, // 細く控えめなデザイン
            child: LinearProgressIndicator(
              value: uploadState.progress,
              backgroundColor: AppColors.grey20,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentGold),
            ),
          ),
        ],
      ),
    );
  }
}
