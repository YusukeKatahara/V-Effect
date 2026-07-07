import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_colors.dart';
import '../providers/service_providers.dart';

/// ヒーロータスク単体をシェアするためのプレビュー画面
/// 縦長(9:16)のインスタストーリー画角で写真にロゴとストリーク数を載せます
class HeroTaskSharePreviewScreen extends ConsumerStatefulWidget {
  final String? imageUrl;
  final int currentStreak;

  const HeroTaskSharePreviewScreen({
    super.key,
    this.imageUrl,
    required this.currentStreak,
  });

  @override
  ConsumerState<HeroTaskSharePreviewScreen> createState() => _HeroTaskSharePreviewScreenState();
}

class _HeroTaskSharePreviewScreenState extends ConsumerState<HeroTaskSharePreviewScreen> {
  final GlobalKey _previewKey = GlobalKey();
  bool _isSharing = false;

  /// 表示されている領域を画像（PNG）化して、OSの共有機能（share_plus）を呼び出します
  Future<void> _shareImage() async {
    if (_isSharing) return;

    // 非同期処理の途中で画面が破棄された時のために、あらかじめ多言語化テキストを抽出しておきます
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isSharing = true);

    try {
      // RepaintBoundary からレンダリングオブジェクトを取得
      final boundary = _previewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      // 画像を高解像度（pixelRatio: 3.0）でキャプチャ
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      // 一時ディレクトリに保存（Web はファイル書き込み不可のため bytes を直接共有）
      final XFile shareFile;
      if (kIsWeb) {
        shareFile = XFile.fromData(
          pngBytes,
          mimeType: 'image/png',
          name: 'hero_task_share.png',
        );
      } else {
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/hero_task_share_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = File(path);
        await file.writeAsBytes(pngBytes);
        shareFile = XFile(path);
      }

      if (!mounted) return;

      // share_plus を利用して画像ファイルと設定した共有文言を送信
      await SharePlus.instance.share(
        ShareParams(
          files: [shareFile],
          text: l10n.heroTaskShareText(widget.currentStreak),
        ),
      );
      if (mounted) {
        ref.read(analyticsServiceProvider).logPostShared(platform: 'hero_task_share_card');
      }
    } catch (e) {
      debugPrint('Hero task share error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.sharePreviewFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(AppLocalizations.of(context)!.sharePreviewTitle, style: TextStyle(color: AppColors.white)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: AspectRatio(
                    aspectRatio: 9 / 16, // Instagram ストーリー用のアスペクト比（縦横比）
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: RepaintBoundary(
                        key: _previewKey,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // 背景画像（投稿された写真）
                            if (widget.imageUrl != null)
                              CachedNetworkImage(
                                imageUrl: widget.imageUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => Container(color: AppColors.black),
                              )
                            else
                              Container(color: AppColors.black),
                            
                            // 文字が見やすくなるように、上下に暗めのグラデーションをかけます
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    AppColors.black.withValues(alpha: 0.3),
                                    Colors.transparent,
                                    AppColors.black.withValues(alpha: 0.8),
                                  ],
                                  stops: const [0.0, 0.4, 1.0],
                                ),
                              ),
                            ),

                            // 上部に表示する V EFFECT ロゴ
                            Positioned(
                              top: 40,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Text(
                                  'V EFFECT',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.white,
                                    fontSize: isTablet ? 24 : 18,
                                    letterSpacing: isTablet ? 6.0 : 4.0,
                                  ),
                                ),
                              ),
                            ),

                            // 下部中央にストリークをロゴと同じフォントスタイル・位置で配置
                            Positioned(
                              bottom: 40,
                              left: 16,
                              right: 16,
                              child: Center(
                                child: Text(
                                  '${widget.currentStreak} STREAK',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.white,
                                    fontSize: isTablet ? 24 : 18,
                                    letterSpacing: isTablet ? 6.0 : 4.0,
                                    shadows: [
                                      Shadow(
                                        offset: const Offset(0, 2),
                                        blurRadius: 4,
                                        color: AppColors.black.withValues(alpha: 0.5),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // シェアボタンの配置エリア
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              color: AppColors.bgBase,
              child: ElevatedButton.icon(
                onPressed: _isSharing ? null : _shareImage,
                icon: _isSharing
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.bgBase,
                        ),
                      )
                    : Icon(Icons.share, color: AppColors.bgBase),
                label: Text(
                  _isSharing
                      ? AppLocalizations.of(context)!.sharePreviewPreparing
                      : AppLocalizations.of(context)!.sharePreviewShareButton,
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.bgBase),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGold,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


}
