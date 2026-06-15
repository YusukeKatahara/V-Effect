import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_colors.dart';
import '../../../models/post.dart';
import '../../../widgets/v_badge_widget.dart';

/// フィード画面に表示される各投稿のカード型UIコンポーネント。
class FeedCard extends StatelessWidget {
  const FeedCard({
    super.key,
    required this.post,
    required this.username,
    this.userPhotoUrl,
    this.userBadgeUrl,
    this.userBadgeAnimation,
    required this.dimAlpha,
    required this.onReaction,
    required this.isTop,
    required this.tierColor,
    this.onProfileTap,
    this.onOptionsTap,
    this.reactionCountNotifier,
  });

  final Post post;
  final String username;
  final String? userPhotoUrl;
  final String? userBadgeUrl;
  final String? userBadgeAnimation;
  final double dimAlpha;
  final void Function({String? emoji}) onReaction;
  final bool isTop;
  final Color tierColor;
  final VoidCallback? onProfileTap;
  final VoidCallback? onOptionsTap;
  final ValueNotifier<int>? reactionCountNotifier;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.6),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
          if (isTop)
            BoxShadow(
              color: AppColors.accentGold.withValues(alpha: 0.15),
              blurRadius: 40,
              spreadRadius: 2,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 背景色 (白枠対策で内側に移動)
            Container(color: AppColors.grey15),

            // 写真 (RepaintBoundary + CachedNetworkImage)
            RepaintBoundary(
              child: post.imageUrl != null
                  ? SizedBox.expand(
                      child: CachedNetworkImage(
                        imageUrl: post.imageUrl!,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        memCacheWidth: 1600,
                        placeholder: (ctx, url) => Container(
                          color: AppColors.grey10,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.accentGold,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        errorWidget: (ctx, url, error) => const Center(
                          child: Icon(
                            Icons.broken_image,
                            color: AppColors.grey30,
                            size: 40,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      color: AppColors.grey10,
                      child: const Center(
                        child: Icon(
                          Icons.image,
                          color: AppColors.grey30,
                          size: 60,
                        ),
                      ),
                    ),
            ),

            // 三点リーダーボタン
            Positioned(
              top: 14,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.more_horiz_rounded, color: AppColors.white),
                onPressed: onOptionsTap,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.black.withValues(alpha: 0.2),
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ),

            // グラデーションオーバーレイ（下部を暗くしてテキストを読みやすく）
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 240,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      AppColors.black.withValues(alpha: 0.9),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ユーザー情報とタスク情報 (Zenly-style Thought Bubble)
            Positioned(
              bottom: 32, // 絶対基準線の起点
              left: 20,
              right: 20,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // IG Reels style
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar + Username (triggers profile tap)
                        GestureDetector(
                          onTap: onProfileTap,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.grey20,
                                backgroundImage: userPhotoUrl != null
                                    ? ResizeImage(
                                        CachedNetworkImageProvider(userPhotoUrl!),
                                        width: 120)
                                    : null,
                                child: userPhotoUrl == null
                                    ? Text(
                                        username[0].toUpperCase(),
                                        style: const TextStyle(
                                          color: AppColors.white,
                                          fontSize: 12,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                username,
                                textAlign: TextAlign.left,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.white,
                                  letterSpacing: 0.5,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                              if (userBadgeUrl != null && userBadgeUrl!.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                VBadgeWidget(
                                  imageUrl: userBadgeUrl,
                                  animationType: userBadgeAnimation ?? 'none',
                                  size: 14,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (post.caption != null && post.caption!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          // Caption (no tap handler — not a profile link)
                          Text(
                            post.caption!,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              height: 1.3,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // リアクションボタン: [アバター] [＋/チェック] [🔥]
                  if (isTop)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // V Fire ボタン＋カウント（表示専用）
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () => onReaction(),
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: AppColors.white.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.white.withValues(
                                      alpha: 0.1,
                                    ),
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.local_fire_department,
                                  color: AppColors.accentGold,
                                  size: 32,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8), // 基準値
                            SizedBox(
                              height: 16, // 高さを固定して中心を安定させる
                              child: ValueListenableBuilder<int>(
                                valueListenable: reactionCountNotifier ?? ValueNotifier(post.reactionCount),
                                builder: (context, count, _) {
                                  return Text(
                                    '$count',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.white,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // 暗幕レイヤー（奥にあるカードを暗くする）
            if (dimAlpha > 0)
              Positioned.fill(
                child: ColoredBox(
                  color: AppColors.black.withValues(alpha: dimAlpha),
                ),
              ),

            // 最前面にボーダーを配置してアンチエイリアスの隙間(白枠)を隠す
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isTop
                          ? AppColors.accentGold.withValues(alpha: 0.8)
                          : tierColor.withValues(alpha: 0.1),
                      width: isTop ? 1.5 : 0.5,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
