import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../config/app_colors.dart';
import '../config/routes.dart';
import '../models/dev_blog_post.dart';
import '../providers/dev_blog_provider.dart';
import '../widgets/v_effect_header.dart';

class VPracticeScreen extends ConsumerStatefulWidget {
  const VPracticeScreen({super.key});

  @override
  ConsumerState<VPracticeScreen> createState() => _VPracticeScreenState();
}

class _VPracticeScreenState extends ConsumerState<VPracticeScreen> {
  @override
  void initState() {
    super.initState();
    // 画面を開いたタイミングで既読にする
    WidgetsBinding.instance.addPostFrameCallback((_) {
      markDevBlogAsRead(ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(blogPostsProvider);
    final isDeveloperAsync = ref.watch(isDeveloperProvider);
    final isDev = isDeveloperAsync.valueOrNull ?? false;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Column(
          children: [
            VEffectHeader(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              trailing: isDev
                  ? IconButton(
                      icon: const Icon(Icons.add_rounded, color: AppColors.white),
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.blogPostEditor),
                    )
                  : null,
            ),
            Expanded(
              child: postsAsync.when(
                data: (posts) => posts.isEmpty
                    ? const _EmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: posts.length,
                        itemBuilder: (context, i) =>
                            _BlogCard(post: posts[i]),
                      ),
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.white,
                    strokeWidth: 1.5,
                  ),
                ),
                error: (e, _) => Center(
                  child: Text(
                    'エラーが発生しました',
                    style: TextStyle(color: AppColors.grey50, fontSize: 14),
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

class _BlogCard extends StatelessWidget {
  const _BlogCard({required this.post});

  final DevBlogPost post;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.blogPostDetail,
        arguments: post,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.grey10,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.grey20, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 3 / 2,
                child: post.coverImageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: post.coverImageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const _CoverPlaceholder(
                            category: BlogCategory.progress),
                        errorWidget: (_, __, ___) =>
                            _CoverPlaceholder(category: post.category),
                      )
                    : _CoverPlaceholder(category: post.category),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _CategoryBadge(category: post.category),
                      if (post.isPinned) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.push_pin_rounded,
                          size: 13,
                          color: AppColors.accentGold,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    post.title,
                    style: GoogleFonts.notoSansJp(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${post.authorName}  ·  ${DateFormat('yyyy.MM.dd').format(post.createdAt)}',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.grey50,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.category});

  final BlogCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.bgGradient),
      child: Center(
        child: Icon(
          _iconForCategory(category),
          size: 36,
          color: AppColors.grey30,
        ),
      ),
    );
  }

  IconData _iconForCategory(BlogCategory cat) {
    switch (cat) {
      case BlogCategory.progress:
        return Icons.code_rounded;
      case BlogCategory.concept:
        return Icons.lightbulb_outline_rounded;
      case BlogCategory.howto:
        return Icons.menu_book_rounded;
      case BlogCategory.thanks:
        return Icons.favorite_outline_rounded;
      case BlogCategory.seasonTask:
        return Icons.star_border_rounded;
    }
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});

  final BlogCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.grey15,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.grey30, width: 0.5),
      ),
      child: Text(
        category.label,
        style: GoogleFonts.outfit(
          fontSize: 11,
          color: AppColors.grey70,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.campaign_outlined, // Changed icon to match 'notice'
            size: 48,
            color: AppColors.white.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 16),
          Text(
            'お知らせはまだありません',
            style: GoogleFonts.notoSansJp(
              fontSize: 14,
              color: AppColors.grey50,
            ),
          ),
        ],
      ),
    );
  }
}
