import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../config/app_colors.dart';
import '../models/app_notification.dart';
import 'confetti_widget.dart';

/// ストリーク達成時に表示される、思わずInstagramストーリーにシェアしたくなる
/// 圧倒的プレミアム感（トロフィー・オブシディアン・ゴールド）を放つ全画面ダイアログ
class StreakCelebrationDialog extends StatefulWidget {
  final AppNotification notification;

  const StreakCelebrationDialog({
    super.key,
    required this.notification,
  });

  /// お祝いダイアログを表示するための静的メソッド
  static Future<void> show(BuildContext context, AppNotification notification) {
    HapticFeedback.heavyImpact();
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'StreakCelebration',
      barrierColor: Colors.black.withValues(alpha: 0.92), // 背景を深淵な漆黒に
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, anim1, anim2) {
        return StreakCelebrationDialog(notification: notification);
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final curve = Curves.easeOutBack.transform(anim1.value);
        return Transform.scale(
          scale: 0.90 + (curve * 0.10),
          child: Opacity(
            opacity: anim1.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<StreakCelebrationDialog> createState() => _StreakCelebrationDialogState();
}

class _StreakCelebrationDialogState extends State<StreakCelebrationDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  final GlobalKey _shareCardKey = GlobalKey();
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// スクリーンショットを生成してSNS / Instagramストーリーへ直接シェアする
  Future<void> _shareToStory(int streakDays, String mainTitle) async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    HapticFeedback.mediumImpact();

    try {
      final boundary = _shareCardKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final XFile shareFile;
      if (kIsWeb) {
        shareFile = XFile.fromData(
          pngBytes,
          mimeType: 'image/png',
          name: 'v_effect_streak_$streakDays.png',
        );
      } else {
        final directory = await getTemporaryDirectory();
        final path =
            '${directory.path}/v_effect_streak_${streakDays}_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = File(path);
        await file.writeAsBytes(pngBytes);
        shareFile = XFile(path);
      }

      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [shareFile],
          text: '⚡️ V EFFECT - $streakDays DAYS STREAK ACHIEVED! 🔥 #VEffect #Habit',
        ),
      );
    } catch (e) {
      debugPrint('Streak share error: $e');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleText = widget.notification.title;
    final bodyText = widget.notification.body;
    final isJa = Localizations.localeOf(context).languageCode == 'ja';

    // 1. ストリーク日数のパース
    final relatedId = widget.notification.relatedId ?? '';
    int streakDays = 0;
    if (relatedId.startsWith('streak_')) {
      streakDays = int.tryParse(relatedId.replaceFirst('streak_', '')) ?? 0;
    }
    if (streakDays == 0) {
      final numRegExp = RegExp(r'(\d+)');
      final matchNum =
          numRegExp.firstMatch(titleText.isNotEmpty ? titleText : bodyText);
      if (matchNum != null) {
        streakDays = int.tryParse(matchNum.group(1)!) ?? 0;
      }
    }

    // 2. メッセージ本文の整形（冒頭のプレフィックスを除去し、全文を取得）
    String cleanMessage = bodyText;
    final prefixRegExp = RegExp(
        r'^(あなたが\s*\d+日連続達成[！!]?\s*|You hit a \d+-day streak[！!]?\s*)');
    if (prefixRegExp.hasMatch(cleanMessage)) {
      cleanMessage = cleanMessage.replaceFirst(prefixRegExp, '').trim();
    }
    if (cleanMessage.isEmpty) {
      cleanMessage = bodyText;
    }

    // 3. タイトルのクリーンアップ
    String mainTitle = titleText;
    if (isJa && titleText.contains('あなたが') && titleText.contains('達成！')) {
      mainTitle = titleText.replaceAll('あなたが', '').replaceAll('達成！', '達成');
    }

    final formattedDate =
        DateFormat('yyyy.MM.dd').format(widget.notification.createdAt);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 背景の深遠なブラー効果
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                color: AppColors.pureBlack.withValues(alpha: 0.88),
              ),
            ),
          ),

          // 上品に舞う紙吹雪演出
          const Positioned.fill(
            child: ConfettiWidget(),
          ),

          // メインコンテンツ（RepaintBoundaryでカード全体をシェア画像化可能に）
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Column(
                children: [
                  // シェア対象の美しいグラフィックエリア
                  Expanded(
                    child: RepaintBoundary(
                      key: _shareCardKey,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.pureBlack.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // ── ブランドヘッダー ──
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.bolt_rounded,
                                  color: AppColors.accentGold,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'V  E F F E C T',
                                  style: GoogleFonts.orbitron(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 4.0,
                                    color: AppColors.accentGold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isJa ? '• 公式ストリークレコード •' : '• OFFICIAL STREAK RECORD •',
                              style: GoogleFonts.outfit(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.5,
                                color: AppColors.textMuted,
                              ),
                            ),

                            const SizedBox(height: 24),

                            // ── 黄金のトロフィーエンブレム（パルスアニメーション） ──
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                final pulse = _pulseController.value;
                                return Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // 外側の光の輪（オーラグロー）
                                    Container(
                                      width: 156 + (pulse * 10),
                                      height: 156 + (pulse * 10),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.accentGold
                                                .withValues(alpha: 0.25 + (pulse * 0.15)),
                                            blurRadius: 40 + (pulse * 15),
                                            spreadRadius: 8 + (pulse * 6),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // メタリックエンブレム本体
                                    Container(
                                      width: 148,
                                      height: 148,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            const Color(0xFF221F17),
                                            const Color(0xFF0F0F0E),
                                            AppColors.pureBlack,
                                          ],
                                          stops: const [0.0, 0.7, 1.0],
                                        ),
                                        border: Border.all(
                                          color: AppColors.accentGold,
                                          width: 2.0,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            '$streakDays',
                                            style: GoogleFonts.orbitron(
                                              fontSize: 48,
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.accentGold,
                                              height: 1.0,
                                              shadows: [
                                                Shadow(
                                                  color: AppColors.accentGold
                                                      .withValues(alpha: 0.6),
                                                  blurRadius: 16,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.accentGold
                                                  .withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: AppColors.accentGold
                                                    .withValues(alpha: 0.4),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Text(
                                              'DAYS STREAK',
                                              style: GoogleFonts.outfit(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 2.0,
                                                color: AppColors.accentGold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),

                            const SizedBox(height: 22),

                            // ── お祝いタイトル ──
                            Text(
                              mainTitle,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: AppColors.pureWhite,
                                letterSpacing: 0.5,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isJa ? '圧倒的な継続力と勝利の証明' : 'Proof of Unyielding Discipline',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accentGold,
                                letterSpacing: 1.5,
                              ),
                            ),

                            const SizedBox(height: 20),

                            // ── サイバーパンク・インサイトカード ──
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20.0, vertical: 20.0),
                              decoration: BoxDecoration(
                                color: AppColors.grey10.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: AppColors.accentGold.withValues(alpha: 0.35),
                                  width: 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.accentGold
                                        .withValues(alpha: 0.08),
                                    blurRadius: 24,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // インサイトバッジ
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.auto_awesome,
                                        size: 13,
                                        color: AppColors.accentGold,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isJa
                                            ? 'WINNER EFFECT INSIGHT'
                                            : 'NEUROSCIENCE INSIGHT',
                                        style: GoogleFonts.orbitron(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 2.0,
                                          color: AppColors.accentGold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _buildRichCelebrationMessage(cleanMessage),
                                  const SizedBox(height: 14),
                                  // フッターメタ情報
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        formattedDate,
                                        style: GoogleFonts.outfit(
                                          fontSize: 10,
                                          color: AppColors.textMuted,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                      Text(
                                        'VERIFIED PROTOCOL',
                                        style: GoogleFonts.orbitron(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.accentGold
                                              .withValues(alpha: 0.6),
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── アクションエリア（シェア ＆ 閉じる） ──
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. Instagramストーリーにシェアするゴールドボタン
                      Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFE5B54F),
                              Color(0xFFD4AF37),
                              Color(0xFFA67C1E),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accentGold.withValues(alpha: 0.35),
                              blurRadius: 18,
                              spreadRadius: 1,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isSharing
                              ? null
                              : () => _shareToStory(streakDays, mainTitle),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.black,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isSharing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.ios_share_rounded,
                                      size: 18,
                                      color: Colors.black,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isJa
                                          ? 'ストーリーにシェアする'
                                          : 'Share to Story',
                                      style: GoogleFonts.outfit(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.black,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // 2. 閉じる（続ける）控えめなテキストボタン
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textMuted,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            isJa ? '閉じる' : 'Close',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 称賛メッセージをリッチテキストで構築（「」内の重要キーワードをゴールド＆太字で強調）
  Widget _buildRichCelebrationMessage(String text) {
    final spans = <TextSpan>[];
    final regExp = RegExp(r'「([^」]+)」');
    int lastEnd = 0;

    for (final match in regExp.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      final highlighted = match.group(1)!;
      spans.add(
        TextSpan(
          text: '「$highlighted」',
          style: TextStyle(
            color: AppColors.accentGold,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: text));
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.white,
          height: 1.65,
          fontFamily: 'Inter',
        ),
        children: spans,
      ),
    );
  }
}
