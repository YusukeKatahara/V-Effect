import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_colors.dart';

/// 現在選択（フォーカス）されている投稿に紐づくBGM情報を表示し、ミュート切り替えを提供するコンポーネント。
class BgmIndicator extends StatelessWidget {
  final String title;
  final String? artist;
  final String? url;
  final String? artworkUrl;
  final bool isMuted;
  final VoidCallback onMuteToggle;

  const BgmIndicator({
    super.key,
    required this.title,
    this.artist,
    this.url,
    this.artworkUrl,
    required this.isMuted,
    required this.onMuteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onMuteToggle();
          },
          child: artworkUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: artworkUrl!,
                          fit: BoxFit.cover,
                        ),
                        if (isMuted)
                          Container(
                            color: Colors.black.withValues(alpha: 0.5),
                            child: Icon(
                              Icons.music_off_rounded,
                              color: AppColors.pureWhite,
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                  ),
                )
              : Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isMuted ? Icons.music_off_rounded : Icons.music_note_rounded,
                    color: isMuted ? AppColors.grey50 : AppColors.pureWhite,
                    size: 16,
                  ),
                ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: GoogleFonts.notoSansJp(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.pureWhite,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (artist != null)
                Text(
                  artist!,
                  style: GoogleFonts.notoSansJp(
                    fontSize: 10,
                    color: AppColors.grey50,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
