import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../config/app_colors.dart';

class SharePreviewScreen extends StatefulWidget {
  final String? imageUrl;
  final int postsCount;
  final int currentStreak;
  final int totalVFire;
  final int totalReactions;

  const SharePreviewScreen({
    super.key,
    this.imageUrl,
    required this.postsCount,
    required this.currentStreak,
    required this.totalVFire,
    required this.totalReactions,
  });

  @override
  State<SharePreviewScreen> createState() => _SharePreviewScreenState();
}

class _SharePreviewScreenState extends State<SharePreviewScreen> {
  final GlobalKey _previewKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _shareImage() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final boundary = _previewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/v_effect_share_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(path);
      await file.writeAsBytes(pngBytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          text: '今週も${widget.postsCount}回のヒーロータスクを完遂！\n現在のストリーク: ${widget.currentStreak}日 🔥\n#VEffect',
        ),
      );
    } catch (e) {
      debugPrint('Share error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('シェアに失敗しました。もう一度お試しください。')),
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
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('プレビュー', style: TextStyle(color: AppColors.white)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: AspectRatio(
                    aspectRatio: 9 / 16, // シェアしやすい縦長比率
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: RepaintBoundary(
                        key: _previewKey,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // 背景画像
                            if (widget.imageUrl != null)
                              CachedNetworkImage(
                                imageUrl: widget.imageUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => Container(color: AppColors.black),
                              )
                            else
                              Container(color: AppColors.black),
                            
                            // 暗めのグラデーションフィルター
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

                            // 上部の V EFFECT ロゴ
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

                            // 下部のスタッツ
                            Positioned(
                              bottom: 40,
                              left: 16,
                              right: 16,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildStatColumn('TASKS', '${widget.postsCount}'),
                                  _buildStatColumn('STREAK', '${widget.currentStreak}'),
                                  _buildStatColumn('VFIRE', '${widget.totalVFire}'),
                                  _buildStatColumn('REACTIONS', '${widget.totalReactions}'),
                                ],
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
            // シェアボタン
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              color: AppColors.bgBase,
              child: ElevatedButton.icon(
                onPressed: _isSharing ? null : _shareImage,
                icon: _isSharing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bgBase))
                    : const Icon(Icons.share, color: AppColors.bgBase),
                label: Text(_isSharing ? '準備中...' : 'SNSへシェア', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.bgBase)),
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

  Widget _buildStatColumn(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.white,
            shadows: [
              Shadow(
                offset: const Offset(0, 2),
                blurRadius: 4,
                color: AppColors.black.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.white.withValues(alpha: 0.8),
            letterSpacing: 1.0,
            shadows: [
              Shadow(
                offset: const Offset(0, 1),
                blurRadius: 2,
                color: AppColors.black.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
