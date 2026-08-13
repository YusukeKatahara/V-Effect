import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_effect/l10n/app_localizations.dart';

import '../../../config/app_colors.dart';
import '../../../models/hero_pick.dart';
import '../../../providers/service_providers.dart';
import '../../../services/sound_service.dart';
import '../../../widgets/shimmer_container.dart';



/// Hero Pick の全画面詳細ビューアー
class HeroPickViewerDialog extends ConsumerStatefulWidget {
  final HeroPick pick;
  final bool isOwner;
  final VoidCallback? onDelete;

  const HeroPickViewerDialog({
    super.key,
    required this.pick,
    this.isOwner = false,
    this.onDelete,
  });

  static Future<void> show({
    required BuildContext context,
    required HeroPick pick,
    bool isOwner = false,
    VoidCallback? onDelete,
  }) async {
    try {
      await showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'HeroPickViewer',
        barrierColor: Colors.black.withValues(alpha: 0.85),
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (ctx, anim1, anim2) {
          return HeroPickViewerDialog(
            pick: pick,
            isOwner: isOwner,
            onDelete: onDelete,
          );
        },
        transitionBuilder: (ctx, anim, secondaryAnim, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          );
        },
      );
    } finally {
      // ダイアログが完全に閉じた際に確実にBGMを停止
      SoundService.instance.stopBgm();
    }
  }


  @override
  ConsumerState<HeroPickViewerDialog> createState() => _HeroPickViewerDialogState();
}

class _HeroPickViewerDialogState extends ConsumerState<HeroPickViewerDialog> {
  SoundService get _soundService => ref.read(soundServiceProvider);

  @override
  void initState() {
    super.initState();
    // BGMがある場合は自動再生
    if (widget.pick.bgmUrl != null && widget.pick.bgmUrl!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _soundService.playBgm(widget.pick.bgmUrl!);
      });
    }
  }

  @override
  void dispose() {
    // ダイアログを閉じる際にBGMを停止
    if (widget.pick.bgmUrl != null && widget.pick.bgmUrl!.isNotEmpty) {
      _soundService.stopBgm();
    }
    super.dispose();
  }

  void _confirmDelete() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: Text(
          l10n.profileHeroPicksRemoveConfirmTitle,
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),

        content: Text(
          l10n.profileHeroPicksRemoveConfirmDesc,
          style: TextStyle(color: AppColors.grey50, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              l10n.profileScreenDeleteTaskCancel,
              style: TextStyle(color: AppColors.grey50),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // 確認ダイアログを閉じる
              Navigator.pop(context); // ビューアーを閉じる
              widget.onDelete?.call();
            },
            child: Text(
              l10n.profileHeroPicksRemove,
              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy.MM.dd').format(widget.pick.createdAt);
    final hasBgm = widget.pick.bgmUrl != null && widget.pick.bgmUrl!.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            // 背景タップで閉じる
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  _soundService.stopBgm();
                  Navigator.pop(context);
                },
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.expand(),
              ),
            ),


            // メインカードコンテナ
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 写真カード（画面サイズに応じて9:16の比率で自動計算）
                    Flexible(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final screenHeight = MediaQuery.sizeOf(context).height;
                          // 画面高さの62%を上限（最大540px）に設定
                          final maxCardHeight = (screenHeight * 0.62).clamp(340.0, 540.0);
                          // 9:16 の比率から最適なカード幅を算出
                          final idealWidth = maxCardHeight * (9 / 16);
                          // 画面横幅の制約を超えないようにクランプ
                          final finalWidth = idealWidth.clamp(240.0, constraints.maxWidth * 0.9);
                          final finalHeight = finalWidth * (16 / 9);

                          return SizedBox(
                            width: finalWidth,
                            height: finalHeight > maxCardHeight ? maxCardHeight : finalHeight,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: AppColors.accentGold.withValues(alpha: 0.5),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    blurRadius: 28,
                                    offset: const Offset(0, 10),
                                  ),
                                  BoxShadow(
                                    color: AppColors.accentGold.withValues(alpha: 0.15),
                                    blurRadius: 20,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(22.5),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    // 背景（画像読み込み前の黒ベース）
                                    Container(color: AppColors.bgElevated),

                                    // 写真本体（ピンチズーム対応）
                                    InteractiveViewer(
                                      minScale: 1.0,
                                      maxScale: 3.0,
                                      child: SizedBox.expand(
                                        child: CachedNetworkImage(
                                          imageUrl: widget.pick.imageUrl,
                                          fit: BoxFit.cover,
                                          alignment: Alignment.center,
                                          placeholder: (context, url) => const ShimmerContainer(
                                            width: double.infinity,
                                            height: double.infinity,
                                            borderRadius: 0,
                                          ),
                                          errorWidget: (context, url, error) => Container(
                                            color: AppColors.bgElevated,
                                            child: const Icon(Icons.broken_image, color: Colors.white38),
                                          ),
                                        ),
                                      ),
                                    ),


                                    // 上部グラデーション ＆ タスク情報
                                    Positioned(
                                      top: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.black.withValues(alpha: 0.75),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            // タスク名バッジ
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.65),
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: AppColors.accentGold,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.emoji_events,
                                                    color: AppColors.accentGold,
                                                    size: 13,
                                                  ),
                                                  const SizedBox(width: 5),
                                                  ConstrainedBox(
                                                    constraints: BoxConstraints(maxWidth: finalWidth * 0.45),
                                                    child: Text(
                                                      widget.pick.taskName,
                                                      style: GoogleFonts.notoSansJp(
                                                        color: Colors.white,
                                                        fontSize: 11.5,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // 日付
                                            Text(
                                              dateStr,
                                              style: GoogleFonts.outfit(
                                                color: Colors.white.withValues(alpha: 0.85),
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // 下部グラデーション ＆ BGM / キャプション
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                            colors: [
                                              Colors.black.withValues(alpha: 0.88),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // BGM情報
                                            if (hasBgm) ...[
                                              Row(
                                                children: [
                                                  Icon(Icons.music_note, color: AppColors.accentGold, size: 13),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      '${widget.pick.bgmTitle ?? 'Music'} - ${widget.pick.bgmArtist ?? ''}',
                                                      style: TextStyle(
                                                        color: AppColors.accentGold,
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                            ],

                                            // キャプション
                                            if (widget.pick.caption != null && widget.pick.caption!.isNotEmpty) ...[
                                              Text(
                                                widget.pick.caption!,
                                                style: GoogleFonts.notoSansJp(
                                                  color: Colors.white,
                                                  fontSize: 12.5,
                                                  height: 1.35,
                                                ),
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],

                                            // リアクション数（ある場合）
                                            if (widget.pick.reactionCount > 0) ...[
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Text(
                                                    '🔥 ${widget.pick.reactionCount}',
                                                    style: GoogleFonts.outfit(
                                                      color: Colors.white,
                                                      fontSize: 12.5,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),


                    const SizedBox(height: 20),

                    // 操作アクションバー（閉じる・削除）
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 閉じるボタン
                        IconButton(
                          onPressed: () {
                            _soundService.stopBgm();
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.close, color: Colors.white, size: 28),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.15),
                            padding: const EdgeInsets.all(12),
                          ),
                        ),


                        if (widget.isOwner) ...[
                          const SizedBox(width: 24),
                          // 削除ボタン
                          IconButton(
                            onPressed: _confirmDelete,
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 28),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                              padding: const EdgeInsets.all(12),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
