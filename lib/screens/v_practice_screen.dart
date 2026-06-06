import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../config/app_colors.dart';
import '../config/routes.dart';
import '../models/dev_blog_post.dart';
import '../providers/dev_blog_provider.dart';
import '../providers/language_provider.dart';
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
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.stars_rounded, color: AppColors.accentGold, size: 22),
                          tooltip: '全ユーザーへバッジ配布',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => const _AdminBadgeDistributeDialog(),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_rounded, color: AppColors.white, size: 22),
                          tooltip: 'ブログ記事を作成',
                          onPressed: () =>
                              Navigator.pushNamed(context, AppRoutes.blogPostEditor),
                        ),
                      ],
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

class _BlogCard extends ConsumerWidget {
  const _BlogCard({required this.post});

  final DevBlogPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final isEnglish = lang == 'en';
    final title = isEnglish && post.titleEn != null && post.titleEn!.isNotEmpty 
        ? post.titleEn! 
        : post.title;

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
                    title,
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

class _AdminBadgeDistributeDialog extends StatefulWidget {
  const _AdminBadgeDistributeDialog();

  @override
  State<_AdminBadgeDistributeDialog> createState() => _AdminBadgeDistributeDialogState();
}

class _AdminBadgeDistributeDialogState extends State<_AdminBadgeDistributeDialog> {
  final _controller = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _distributeBadge() async {
    final badgeUrl = _controller.text.trim();
    if (badgeUrl.isEmpty) {
      _showError('バッジID（または tester など）を入力してください');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final db = FirebaseFirestore.instance;
      final snapshot = await db.collection('users').get();
      final batch = db.batch();
      int count = 0;
      final anim = badgeUrl == 'tester' ? 'shimmer' : 'none';
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'equippedBadgeUrl': badgeUrl,
          'equippedBadgeAnimation': anim,
        });
        count++;
        if (count >= 490) {
          await batch.commit();
          count = 0;
        }
      }
      if (count > 0) {
        await batch.commit();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('全ユーザーにバッジ「$badgeUrl」を配布・装備させました！',
                style: GoogleFonts.notoSansJp(color: AppColors.white)),
            backgroundColor: AppColors.accentGold,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('配布エラー: $e');
      _showError('バッジの配布に失敗しました');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.notoSansJp(color: AppColors.white)),
        backgroundColor: AppColors.grey15,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.grey15,
      title: Row(
        children: [
          const Icon(Icons.stars_rounded, color: AppColors.accentGold),
          const SizedBox(width: 8),
          Expanded(
            child: Text('全ユーザーへバッジ配布',
                style: GoogleFonts.notoSansJp(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('現在登録されている全てのユーザーに、指定したバッジを強制的に装備させます。通知は飛びません。',
              style: GoogleFonts.notoSansJp(color: AppColors.grey70, fontSize: 13)),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            style: GoogleFonts.notoSansJp(color: AppColors.white),
            decoration: InputDecoration(
              hintText: 'バッジID (例: tester)',
              hintStyle: GoogleFonts.notoSansJp(color: AppColors.grey30),
              filled: true,
              fillColor: AppColors.black.withValues(alpha: 0.3),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.grey30, width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.accentGold, width: 0.5),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text('キャンセル', style: GoogleFonts.notoSansJp(color: AppColors.grey50)),
        ),
        _isSaving
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(color: AppColors.accentGold, strokeWidth: 2),
              )
            : TextButton(
                onPressed: _distributeBadge,
                child: Text('配布する', style: GoogleFonts.notoSansJp(color: AppColors.accentGold, fontWeight: FontWeight.bold)),
              ),
      ],
    );
  }
}
