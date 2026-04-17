import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_colors.dart';

// ────────────────────────────────────────────
// リアクションアバタースタック
// VFIREボタンの左に、個別絵文字バッジ付きで最大3名を重ねて表示
// ────────────────────────────────────────────
class ReactionAvatarsStack extends StatelessWidget {
  const ReactionAvatarsStack({
    super.key,
    required this.userReactions,
    required this.reactorUids,
    required this.userPhotos,
    this.reactionCount = 0,
    this.avatarSize = 44.0,
    this.overlapOffset = 28.0,
  });

  final Map<String, String> userReactions; // uid -> 絵文字
  final List<String> reactorUids;          // 旧データのUID一覧 (fallback)
  final Map<String, String?> userPhotos;
  final int reactionCount;                 // データ不整合時のフォールバック用
  final double avatarSize;
  final double overlapOffset;

  static const int _maxAvatars = 3;

  @override
  Widget build(BuildContext context) {
    // userReactions と reactorUids をマージ
    final allMap = <String, String>{};
    for (final uid in reactorUids) {
      allMap[uid] = userReactions[uid] ?? '🔥';
    }
    allMap.addAll(userReactions);

    // VFIRE（🔥）リアクションを除外して、絵文字リアクションのみに絞り込む
    final emojiMap = <String, String>{};
    allMap.forEach((uid, emoji) {
      if (emoji != '🔥') {
        emojiMap[uid] = emoji;
      }
    });

    if (emojiMap.isEmpty) return const SizedBox.shrink();

    final uids = emojiMap.keys.toList().reversed.toList();
    final displayUids = uids.take(_maxAvatars).toList();
    final actualExtraCount = uids.length - displayUids.length;

    final totalWidth = avatarSize +
        (displayUids.length - 1).clamp(0, _maxAvatars) * overlapOffset +
        (actualExtraCount > 0 ? overlapOffset : 0);

    return SizedBox(
      width: totalWidth,
      height: avatarSize + 8,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = displayUids.length - 1; i >= 0; i--)
            Positioned(
              left: i * overlapOffset,
              top: 0,
              child: _ReactorAvatar(
                uid: displayUids[i],
                emoji: emojiMap[displayUids[i]] ?? '🔥',
                photoUrl: userPhotos[displayUids[i]],
                size: avatarSize,
              ),
            ),
          if (actualExtraCount > 0)
            Positioned(
              left: displayUids.length * overlapOffset,
              top: 0,
              child: Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  color: AppColors.grey20,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.black,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    '+$actualExtraCount',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReactorAvatar extends StatelessWidget {
  const _ReactorAvatar({
    required this.uid,
    required this.emoji,
    required this.photoUrl,
    required this.size,
  });

  final String uid;
  final String emoji;
  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.black,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: size / 2,
              backgroundColor: AppColors.grey15,
              backgroundImage: photoUrl != null
                  ? CachedNetworkImageProvider(photoUrl!)
                  : null,
              child: photoUrl == null
                  ? Icon(Icons.person, size: size * 0.6, color: AppColors.grey50)
                  : null,
            ),
          ),
          Positioned(
            right: -6,
            bottom: -4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.black,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.grey15,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
