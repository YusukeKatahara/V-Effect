import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
    // 画面が描画された直後にOSのパーミッション要求を呼び出します
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerPermissionRequest();
    });
  }

  Future<void> _triggerPermissionRequest() async {
    // モーダルのスライドアニメーション完了を待つために少し遅延を挟みます
    await Future.delayed(const Duration(milliseconds: 600));
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
            const Icon(
              Icons.notifications_active_rounded,
              color: AppColors.accentGold,
              size: 60,
            ),
            const SizedBox(height: 20),

            // ── タイトル ──
            Text(
              '「仲間の努力」を習慣の味方にしますか？',
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
              'V EFFECTで最も強い習慣化の力は「仲間の存在」です。\n\n通知をONにすることで、仲間の達成がリアルタイムにあなたの刺激になり、あなたの努力も仲間に届きます。\nお互いの存在を背中に感じながら、強固な習慣を築きましょう。',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansJp(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 32),

            // ── インジケータ ──
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentGold),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
