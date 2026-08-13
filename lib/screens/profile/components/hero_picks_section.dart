import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:v_effect/l10n/app_localizations.dart';

import '../../../config/app_colors.dart';
import '../../../models/hero_pick.dart';
import '../../../services/user_service.dart';
import '../../../widgets/shimmer_container.dart';
import 'hero_pick_selection_sheet.dart';

import 'hero_pick_viewer_dialog.dart';

/// プロフィール画面の「Hero Picks」セクション
class HeroPicksSection extends StatelessWidget {
  final List<HeroPick> picks;
  final bool isOwner;
  final VoidCallback? onPicksChanged;
  final VoidCallback? onPreview;

  const HeroPicksSection({
    super.key,
    required this.picks,
    this.isOwner = false,
    this.onPicksChanged,
    this.onPreview,
  });


  Future<void> _addPick(BuildContext context) async {
    if (picks.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.profileHeroPicksMaxReached),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final selectedPick = await HeroPickSelectionSheet.show(
      context,
      currentPicks: picks,
    );

    if (selectedPick != null && context.mounted) {
      final success = await UserService.instance.addHeroPick(selectedPick);
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.profileHeroPicksSuccess),
            backgroundColor: AppColors.accentGold,
            behavior: SnackBarBehavior.floating,
          ),
        );
        onPicksChanged?.call();
      }
    }
  }

  Future<void> _removePick(BuildContext context, String postId) async {
    final success = await UserService.instance.removeHeroPick(postId);
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.profileHeroPicksRemoved),
          behavior: SnackBarBehavior.floating,
        ),
      );
      onPicksChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 相手のプロフィールでPicksが0件の場合は何も表示しない
    if (!isOwner && picks.isEmpty) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final isDark = AppColors.isDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── セクションヘッダー ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.accentGold,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.profileHeroPicksTitle,
                    style: GoogleFonts.notoSansJp(
                      color: isDark ? Colors.white : AppColors.pureBlack,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),

                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (picks.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.accentGold.withValues(alpha: 0.15)
                            : AppColors.accentGold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${picks.length} / 6',
                        style: GoogleFonts.outfit(
                          color: AppColors.accentGold,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (isOwner && onPreview != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onPreview,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.bgSurface
                              : Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? AppColors.border : AppColors.grey20,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.visibility_outlined,
                              size: 13,
                              color: isDark ? Colors.white70 : AppColors.grey70,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.profileHeroPicksPreview,
                              style: GoogleFonts.notoSansJp(
                                color: isDark ? Colors.white70 : AppColors.pureBlack,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),


        const SizedBox(height: 12),

        // ── コンテンツエリア ──
        if (isOwner && picks.isEmpty)
          _buildEmptyOwnerBanner(context)
        else
          _buildPicksCarousel(context),
      ],
    );
  }

  /// 自分のプロフィールでPicksが0件の時のバナー
  Widget _buildEmptyOwnerBanner(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = AppColors.isDark;

    return GestureDetector(
      onTap: () => _addPick(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.border : AppColors.grey20,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accentGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.accentGold.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.add_photo_alternate_outlined,
                color: AppColors.accentGold,
                size: 22,
              ),
            ),

            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.profileHeroPicksEmptyTitle,
                    style: GoogleFonts.notoSansJp(
                      color: isDark ? Colors.white : AppColors.pureBlack,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.profileHeroPicksEmptyDesc,
                    style: TextStyle(
                      color: AppColors.grey50,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.grey50,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// 横スクロールカードカルーセル
  Widget _buildPicksCarousel(BuildContext context) {
    final canAddMore = isOwner && picks.length < 6;

    return SizedBox(
      height: 165,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: picks.length + (canAddMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < picks.length) {
            final pick = picks[index];
            return Padding(
              padding: EdgeInsets.only(
                left: index == 0 ? 0 : 6,
                right: (index == picks.length - 1 && !canAddMore) ? 0 : 6,
              ),
              child: _buildPickCard(context, pick),
            );
          } else {
            // 末尾の「＋ 追加」スロット
            return Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _buildAddSlot(context),
            );
          }
        },
      ),
    );
  }

  /// 各Pickカード
  Widget _buildPickCard(BuildContext context, HeroPick pick) {
    final dateStr = DateFormat('M/d').format(pick.createdAt);
    final hasBgm = pick.bgmUrl != null && pick.bgmUrl!.isNotEmpty;

    return GestureDetector(
      onTap: () {
        HeroPickViewerDialog.show(
          context: context,
          pick: pick,
          isOwner: isOwner,
          onDelete: () => _removePick(context, pick.postId),
        );
      },
      child: Container(
        width: 115,
        height: 165,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.accentGold.withValues(alpha: 0.25),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 写真
              CachedNetworkImage(
                imageUrl: pick.thumbnailUrl ?? pick.imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => const ShimmerContainer(
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: 0,
                ),
                errorWidget: (context, url, error) => Container(
                  color: AppColors.bgSurface,
                  child: const Icon(Icons.broken_image, color: Colors.white24),
                ),
              ),


              // BGMアイコン（右上に配置）
              if (hasBgm)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.music_note,
                      color: AppColors.accentGold,
                      size: 11,
                    ),
                  ),
                ),

              // 下部グラデーション ＆ タスク情報
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.85),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        pick.taskName,
                        style: GoogleFonts.notoSansJp(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            dateStr,
                            style: GoogleFonts.outfit(
                              color: Colors.white70,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (pick.reactionCount > 0)
                            Text(
                              '🔥${pick.reactionCount}',
                              style: GoogleFonts.outfit(
                                color: AppColors.accentGold,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
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
        ),
      ),
    );
  }

  /// 「＋ 追加」カードスロット
  Widget _buildAddSlot(BuildContext context) {
    final isDark = AppColors.isDark;

    return GestureDetector(
      onTap: () => _addPick(context),
      child: Container(
        width: 115,
        height: 165,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.bgSurface.withValues(alpha: 0.6)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? AppColors.accentGold.withValues(alpha: 0.25)
                : AppColors.accentGold.withValues(alpha: 0.35),
            width: 1,
            style: BorderStyle.solid,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add,
                  color: AppColors.accentGold,
                  size: 20,
                ),
              ),

              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.profileHeroPicksAdd,
                style: GoogleFonts.notoSansJp(
                  color: AppColors.accentGold,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
