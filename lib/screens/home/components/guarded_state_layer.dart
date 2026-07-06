import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/home/refresh_ring_button.dart';

/// ユーザーが今日の分の投稿をしていない状態（未投稿ガード）を表すレイヤー。
class GuardedStateLayer extends StatefulWidget {
  final String? backgroundImageUrl;
  final List<Map<String, dynamic>> postedFriends;
  final VoidCallback? onRefresh;
  final bool isUnlocked;

  const GuardedStateLayer({
    super.key,
    this.backgroundImageUrl,
    required this.postedFriends,
    this.onRefresh,
    this.isUnlocked = false,
  });

  @override
  State<GuardedStateLayer> createState() => _GuardedStateLayerState();
}

class _GuardedStateLayerState extends State<GuardedStateLayer> {
  Widget _buildFriendAvatars() {
    // 5人以上の場合は、4つのアバターと「+N」サークルを合わせた最大5個の要素を表示します。
    final showOverflow = widget.postedFriends.length >= 5;
    final displayCount = showOverflow ? 5 : widget.postedFriends.length;
    return SizedBox(
      height: 32,
      width: (24.0 * displayCount) + 8,
      child: Stack(
        children: [
          for (int i = 0; i < displayCount; i++)
            Positioned(
              left: i * 20.0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.black,
                    width: 2,
                  ),
                ),
                child: (showOverflow && i == 4)
                    ? CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.grey30,
                        child: Text(
                          '+${widget.postedFriends.length - 4}',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                          ),
                        ),
                      )
                    : CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.grey20,
                        backgroundImage: widget.postedFriends[i]['photoUrl'] != null
                            ? CachedNetworkImageProvider(widget.postedFriends[i]['photoUrl'])
                            : null,
                        child: widget.postedFriends[i]['photoUrl'] == null
                            ? Text(
                                (widget.postedFriends[i]['username'] as String).characters.isNotEmpty 
                                    ? (widget.postedFriends[i]['username'] as String).characters.first.toUpperCase() 
                                    : '?',
                                style: const TextStyle(fontSize: 10),
                              )
                            : null,
                      ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (widget.backgroundImageUrl != null)
          Positioned.fill(
            child: RepaintBoundary(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Opacity(
                  opacity: 0.4,
                  child: CachedNetworkImage(
                    imageUrl: widget.backgroundImageUrl!,
                    fit: BoxFit.cover,
                    memCacheWidth: 400,
                  ),
                ),
              ),
            ),
          ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RefreshRingButton(
                icon: widget.isUnlocked
                    ? Icons.lock_open_rounded
                    : Icons.lock_outline_rounded,
                isUnlocked: widget.isUnlocked,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)!.homePostToSeeFriends),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  if (widget.onRefresh != null) {
                    widget.onRefresh!();
                  }
                },
              ),

              const SizedBox(height: 48),

              if (widget.postedFriends.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildFriendAvatars(),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!.homeFriendPostsTitle,
                      style: GoogleFonts.notoSansJp(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.grey50,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              Text(
                AppLocalizations.of(context)!.homeProveVictory,
                style: GoogleFonts.notoSansJp(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.homeStreakResetMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSansJp(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.grey50,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
