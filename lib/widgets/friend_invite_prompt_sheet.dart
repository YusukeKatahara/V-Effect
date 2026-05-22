import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_colors.dart';
import '../models/app_user.dart';
import '../services/invite_service.dart';
import '../screens/qr_display_screen.dart';
import '../screens/qr_scanner_screen.dart';

/// ハーフモーダルの結果を表す列挙型（どのアクションが選ばれたか）
enum FriendInviteResult {
  /// 「QRコードで繋がる」ボタンが押された
  qrCode,
  /// 閉じた（スキップした）
  dismissed,
}

/// 初めてのタスク投稿後にフレンド登録・招待を促すハーフモーダル (下から出てくるシート)
class FriendInvitePromptSheet extends StatelessWidget {
  final AppUser user;

  const FriendInvitePromptSheet({
    super.key,
    required this.user,
  });

  /// ハーフモーダルを表示する静的メソッド
  /// 戻り値で「QRコードを選んだか」を呼び出し元に伝えます
  static Future<FriendInviteResult?> show(BuildContext context, AppUser user) {
    return showModalBottomSheet<FriendInviteResult>(
      context: context,
      backgroundColor: Colors.transparent, // 背景を透過させてカスタムの角丸を適用します
      isScrollControlled: true, // 高さをコンテンツに合わせるための設定です
      builder: (_) => FriendInvitePromptSheet(user: user),
    );
  }

  /// QRコード表示 or 読み取り を選択するダイアログを表示
  /// 呼び出し元のcontextを使うことで、ボトムシート破棄後もナビゲーションが正常に機能します
  static void showQrDialog(BuildContext context, AppUser user) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'QRコード',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        ),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QrDisplayScreen(user: user),
                ),
              );
            },
            child: const Row(
              children: [
                Icon(Icons.qr_code_rounded, color: AppColors.textSecondary),
                SizedBox(width: 12),
                Text(
                  'マイQRコードを表示',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QrScannerScreen()),
              );
            },
            child: const Row(
              children: [
                Icon(Icons.qr_code_scanner_rounded, color: AppColors.textSecondary),
                SizedBox(width: 12),
                Text(
                  'QRコードをスキャン',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.grey08, // ダークでプレミアムな背景色
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28), // 上部のみ角を丸くします
        ),
        border: Border.all(
          color: AppColors.accentGold.withValues(alpha: 0.25), // 金色の光彩を表すボーダー
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min, // コンテンツの大きさに合わせます
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── 上部のインジケータ (引っ張るバー) ──
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 28),

            // ── V ロゴ & タイトル ──
            ShaderMask(
              shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
              child: Text(
                'V',
                style: GoogleFonts.outfit(
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  color: AppColors.white,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'V (勝利) を仲間と証明しよう！',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansJp(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // ── 説明文 ──
            Text(
              '最初のタスク投稿が完了しました！\n習慣化を成功させる鍵は、仲間とお互いの「やり遂げた証明 (V)」を監視・応援し合うことです。さあ、フレンドを登録しましょう！',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansJp(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),

            // ── ボタン1: 未プレイの友達を招待する (LINE等でシェア) ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient, // 美しい金色のグラデーション
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentGold.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // システムのシェアシートを開いて紹介リンクを送ります
                    await InviteService.instance.shareInviteCard(
                      userId: user.uid,
                      username: user.username ?? 'ユーザー',
                    );
                  },
                  icon: const Icon(Icons.share_rounded, color: AppColors.black, size: 20),
                  label: const Text(
                    '友達を招待する (LINE等でシェア)',
                    style: TextStyle(
                      color: AppColors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── ボタン2: 近くの友達と繋がる (QRコード) ──
            // ※ タップ時にボトムシートを閉じて結果を返し、呼び出し元でQRダイアログを表示します
            // ※ ボトムシート内のcontextは閉じた瞬間に無効になるため、
            //    ここではNavigator.pop()で結果だけ返すのが正しいパターンです
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () {
                  // 結果として FriendInviteResult.qrCode を返し、ハーフモーダルを閉じます
                  Navigator.pop(context, FriendInviteResult.qrCode);
                },
                icon: const Icon(Icons.qr_code_2_rounded, color: AppColors.accentGold, size: 20),
                label: const Text(
                  'すでにやっている友達と繋がる (QRコード)',
                  style: TextStyle(
                    color: AppColors.accentGold,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                    color: AppColors.accentGold,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── スキップボタン (今はしない) ──
            TextButton(
              onPressed: () => Navigator.pop(context, FriendInviteResult.dismissed),
              child: Text(
                '今はしない',
                style: GoogleFonts.notoSansJp(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
