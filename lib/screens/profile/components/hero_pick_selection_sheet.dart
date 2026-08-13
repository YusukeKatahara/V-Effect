import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_effect/l10n/app_localizations.dart';

import '../../../config/app_colors.dart';
import '../../../models/hero_pick.dart';
import '../../../models/post.dart';
import '../../../providers/service_providers.dart';
import '../../../widgets/shimmer_container.dart';

/// 過去の投稿からHero Pickに設定する投稿を選択するボトムシート
class HeroPickSelectionSheet extends ConsumerStatefulWidget {
  final List<HeroPick> currentPicks;

  const HeroPickSelectionSheet({
    super.key,
    required this.currentPicks,
  });

  static Future<HeroPick?> show(
    BuildContext context, {
    required List<HeroPick> currentPicks,
  }) {
    return showModalBottomSheet<HeroPick>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HeroPickSelectionSheet(currentPicks: currentPicks),
    );
  }

  @override
  ConsumerState<HeroPickSelectionSheet> createState() => _HeroPickSelectionSheetState();
}

class _HeroPickSelectionSheetState extends ConsumerState<HeroPickSelectionSheet> {
  bool _isLoading = true;
  List<Post> _posts = [];

  @override
  void initState() {
    super.initState();
    _loadPastPosts();
  }

  Future<void> _loadPastPosts() async {
    try {
      final posts = await ref.read(postServiceProvider).getAllMyPastPosts();
      // 画像URLが存在する投稿のみに絞り込む（新しい順にソート）
      final validPosts = posts.where((p) => p.imageUrl != null && p.imageUrl!.isNotEmpty).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (mounted) {
        setState(() {
          _posts = validPosts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading posts for Hero Picks selection: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = AppColors.isDark;
    final currentPickIds = widget.currentPicks.map((p) => p.postId).toSet();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // シートヘッダー
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.profileHeroPicksSelectTitle,
                      style: GoogleFonts.notoSansJp(
                        color: isDark ? Colors.white : AppColors.pureBlack,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.currentPicks.length} / 6',
                      style: GoogleFonts.outfit(
                        color: AppColors.accentGold,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, color: isDark ? Colors.white70 : AppColors.pureBlack),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Divider(color: isDark ? Colors.white12 : Colors.black12, height: 1),


          // グリッドコンテンツ
          Expanded(
            child: _isLoading
                ? _buildLoadingGrid()
                : _posts.isEmpty
                    ? Center(
                        child: Text(
                          l10n.profileHeroPicksSelectEmpty,
                          style: TextStyle(color: AppColors.grey50, fontSize: 14),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: _posts.length,
                        itemBuilder: (context, index) {
                          final post = _posts[index];
                          final isPicked = currentPickIds.contains(post.id);

                          return _buildGridItem(post, isPicked);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(Post post, bool isPicked) {
    final dateStr = DateFormat('M/d').format(post.createdAt);

    return GestureDetector(
      onTap: () {
        if (isPicked) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.profileHeroPicksAlreadyPicked),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }
        final heroPick = HeroPick.fromPost(post);
        Navigator.pop(context, heroPick);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 画像
            CachedNetworkImage(
              imageUrl: post.thumbnailUrl ?? post.imageUrl!,
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


            // 下部グラデーション ＆ タスク名
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      post.taskName,
                      style: GoogleFonts.notoSansJp(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      dateStr,
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // すでにPickされている場合のオーバーレイ
            if (isPicked)
              Container(
                color: Colors.black.withValues(alpha: 0.55),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accentGold,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check, size: 12, color: Colors.black),
                        const SizedBox(width: 2),
                        Text(
                          AppLocalizations.of(context)!.profileHeroPicksPickedBadge,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.8,
      ),
      itemCount: 9,
      itemBuilder: (_, __) => const ShimmerContainer(
        width: double.infinity,
        height: double.infinity,
        borderRadius: 12,
      ),
    );
  }
}
