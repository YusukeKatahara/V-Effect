import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import '../config/app_colors.dart';
import '../services/push_notification_service.dart';

/// プッシュ通知の許可を促すプレ・ダイアログ (ハーフモーダル)
///
/// ユーザーに「仲間の存在」という適度なピアプレッシャーを感じてもらうためのメッセージを表示し、
/// アプリ側のボタン操作なしで、直接OS標準の通知許可ダイアログへ繋ぎます。
class NotificationPromptSheet extends StatefulWidget {
  const NotificationPromptSheet({super.key});

  /// ハーフモーダルを表示する静的メソッド
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // 背景を透過させてカスタムの角丸を適用
      isScrollControlled: true,
      isDismissible: false, // OSダイアログ処理中に背景タップで閉じられるのを防ぎます
      enableDrag: false,    // スワイプで勝手に閉じられるのを防ぎます
      builder: (_) => const NotificationPromptSheet(),
    );
  }

  @override
  State<NotificationPromptSheet> createState() => _NotificationPromptSheetState();
}

class _NotificationPromptSheetState extends State<NotificationPromptSheet> {
  @override
  void initState() {
    super.initState();
    // 以前はここで自動的にOSダイアログを呼び出していましたが、
    // ユーザーが文章を読み終わってからボタンで呼び出せるように削除しました。
  }

  Future<void> _triggerPermissionRequest() async {
    if (!mounted) return;

    // システム標準の通知許可ダイアログを呼び出します（ユーザーの選択を待ちます）
    await PushNotificationService().requestPermission();

    // ユーザーがOSダイアログで「許可」または「許可しない」を選択したら自動的にこのモーダルを閉じます
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.grey08, // ダークでプレミアムな背景色
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28), // 上部のみ角を丸く
        ),
        border: Border.all(
          color: AppColors.accentGold.withValues(alpha: 0.25), // 金色の光彩ボーダー
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentGold.withValues(alpha: 0.12),
            blurRadius: 40,
            spreadRadius: 4,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min, // コンテンツの大きさに合わせる
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── 上部のインジケータ ──
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 32),

            // ── 🔔 アイコン ──
            Icon(
              Icons.notifications_active_rounded,
              color: AppColors.accentGold,
              size: 60,
            ),
            const SizedBox(height: 20),

            // ── タイトル ──
            Text(
              AppLocalizations.of(context)!.notificationPromptTitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansJp(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),

            // ── 説明文 ──
            Text(
              AppLocalizations.of(context)!.notificationPromptDesc,
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansJp(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 32),

            // ── アクションボタン群 ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _triggerPermissionRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGold,
                  foregroundColor: AppColors.bgBase, // ゴールド背景に黒文字で目立たせる
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  AppLocalizations.of(context)!.notificationPromptNext,
                  style: GoogleFonts.notoSansJp(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── あとでボタン ──
            TextButton(
              onPressed: () {
                if (mounted) {
                  Navigator.pop(context);
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              ),
              child: Text(
                AppLocalizations.of(context)!.notificationPromptLater,
                style: GoogleFonts.notoSansJp(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
