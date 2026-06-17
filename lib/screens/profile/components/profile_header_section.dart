import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import '../../../config/app_colors.dart';
import '../../../models/app_user.dart';
import '../../../widgets/v_badge_widget.dart';
import '../../../widgets/full_screen_image_viewer.dart';

// ---────────────────────────────────────────────
// ---プロフィールヘッダーセクション
// （アバター、ユーザー名、フォロー統計などを表示する）
// ---────────────────────────────────────────────
class ProfileHeaderSection extends StatelessWidget {
  const ProfileHeaderSection({
    super.key,
    required this.user,
    required this.uid,
    required this.onQrPressed,
  });

  /// 表示するユーザー情報
  final AppUser user;
  /// 現在のユーザーUID
  final String uid;
  /// QRコードボタンが押されたときのコールバック
  final VoidCallback onQrPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: [
          Row(
            children: [
              // ---プロフィール画像
              _buildAvatar(context),
              const SizedBox(width: 20),
              // ---ユーザー名とID
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.username ?? '',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (user.equippedBadgeUrl != null && user.equippedBadgeUrl!.isNotEmpty) ...[
                          VBadgeWidget(
                            imageUrl: user.equippedBadgeUrl,
                            animationType: user.equippedBadgeAnimation ?? 'none',
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (user.instagramId != null && user.instagramId!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () async {
                              final instagramId = user.instagramId!;
                              final appUri = Uri.parse('instagram://user?username=$instagramId');
                              final webUri = Uri.parse('https://instagram.com/$instagramId');
                              try {
                                if (await canLaunchUrl(appUri)) {
                                  await launchUrl(appUri);
                                } else {
                                  await launchUrl(webUri, mode: LaunchMode.externalApplication);
                                }
                              } catch (e) {
                                debugPrint('Could not launch instagram: $e');
                              }
                            },
                            child: FaIcon(
                              FontAwesomeIcons.instagram,
                              color: AppColors.white,
                              size: 22,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${user.userId ?? ''}',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // ---QRコードボタン
              Container(
                decoration: BoxDecoration(
                  color: AppColors.grey15.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.white.withValues(alpha: 0.08),
                    width: 0.5,
                  ),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.qr_code,
                    color: AppColors.textPrimary,
                    size: 26,
                  ),
                  tooltip: AppLocalizations.of(context)!.profileScreenQrTooltip,
                  onPressed: onQrPressed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          // ---フォロー統計バー
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 18,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.grey15.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.white.withValues(alpha: 0.08),
                      width: 0.5,
                    ),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildFollowStat(
                            context,
                            AppLocalizations.of(context)!.profileScreenFollowing,
                            user.following.length,
                            onTap:
                                () => Navigator.pushNamed(
                                  context,
                                  '/follow-list',
                                  arguments: {
                                    'uid': uid,
                                    'isFollowing': true,
                                    'title': AppLocalizations.of(context)!.profileScreenFollowingTitle,
                                  },
                                ),
                          ),
                        ),
                        VerticalDivider(
                          color: AppColors.white.withValues(alpha: 0.1),
                          thickness: 1,
                          width: 1,
                        ),
                        Expanded(
                          child: _buildFollowStat(
                            context,
                            AppLocalizations.of(context)!.profileScreenFollowers,
                            user.followers.length,
                            onTap:
                                () => Navigator.pushNamed(
                                  context,
                                  '/follow-list',
                                  arguments: {
                                    'uid': uid,
                                    'isFollowing': false,
                                    'title': AppLocalizations.of(context)!.profileScreenFollowersTitle,
                                  },
                                ),
                          ),
                        ),
                        VerticalDivider(
                          color: AppColors.white.withValues(alpha: 0.1),
                          thickness: 1,
                          width: 1,
                        ),
                        Expanded(
                          child: _buildFollowStat(
                            context,
                            AppLocalizations.of(context)!.profileScreenStreak,
                            user.streak,
                            icon: Icons.local_fire_department_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// プロフィール画像ウィジェット（タップで拡大表示）
  Widget _buildAvatar(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient:
            user.photoUrl == null
                ? AppColors.primaryGradient
                : null,
        boxShadow: [
          BoxShadow(
            color: AppColors.white.withValues(alpha: 0.1),
            blurRadius: 20,
          ),
        ],
      ),
      child:
          user.photoUrl != null
              ? GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        opaque: false,
                        barrierColor: Colors.black.withValues(alpha: 0.9),
                        pageBuilder: (context, _, __) => FullScreenImageViewer(
                          imageUrl: user.photoUrl!,
                          heroTag: 'profile_image_${user.uid}',
                        ),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          return FadeTransition(opacity: animation, child: child);
                        },
                      ),
                    );
                  },
                  child: Hero(
                    tag: 'profile_image_${user.uid}',
                    child: CircleAvatar(
                      radius: 40,
                      backgroundImage: ResizeImage(
                        CachedNetworkImageProvider(user.photoUrl!),
                        width: 240,
                      ),
                    ),
                  ),
                )
              : CircleAvatar(
                radius: 40,
                backgroundColor: Colors.transparent,
                child: Icon(
                  Icons.person_rounded,
                  size: 40,
                  color: AppColors.black,
                ),
              ),
    );
  }

  Color _getTierColor(int streak) {
    if (streak >= 365) return const Color(0xFFE0A33B); // Challenger (Gold/Blue)
    if (streak >= 270) return const Color(0xFFB53030); // Grandmaster (Red)
    if (streak >= 180) return const Color(0xFF8D2D9E); // Master (Purple)
    if (streak >= 100) return const Color(0xFF4A60AB); // Diamond (Vivid Blue)
    if (streak >= 66) return const Color(0xFF10825B);  // Emerald (Green)
    if (streak >= 30) return const Color(0xFF327A8A);  // Platinum (Teal)
    if (streak >= 14) return const Color(0xFFC89C3C);  // Gold (Gold)
    if (streak >= 7) return const Color(0xFF8091A0);   // Silver (Blue-Gray)
    if (streak >= 3) return const Color(0xFF8F5338);   // Bronze (Copper)
    return const Color(0xFF5E4B43);                    // Iron (Dark Brown-Gray)
  }

  /// フォロー数・フォロワー数・ストリーク数の統計表示
  Widget _buildFollowStat(
    BuildContext context,
    String label,
    int count, {
    IconData? icon,
    VoidCallback? onTap,
  }) {
    final themeColor = icon != null ? _getTierColor(count) : AppColors.accentGold;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: themeColor),
              const SizedBox(width: 4),
            ],
            Text(
              '$count',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color:
                    icon != null ? themeColor : AppColors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.notoSansJp(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: content,
        ),
      );
    }
    return content;
  }
}
