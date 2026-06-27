import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:v_effect/l10n/app_localizations.dart';

import '../config/app_colors.dart';
import '../config/routes.dart';
import '../models/dev_blog_post.dart';
import '../providers/dev_blog_provider.dart';
import '../providers/language_provider.dart';
import '../services/dev_blog_service.dart';
import '../providers/service_providers.dart';

class BlogPostDetailScreen extends ConsumerStatefulWidget {
  const BlogPostDetailScreen({super.key});

  @override
  ConsumerState<BlogPostDetailScreen> createState() =>
      _BlogPostDetailScreenState();
}

class _BlogPostDetailScreenState extends ConsumerState<BlogPostDetailScreen> {
  DevBlogPost? _initialPost;
  late String _postId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is DevBlogPost) {
      _initialPost = args;
      _postId = args.id;
    } else if (args is String) {
      _postId = args;
    } else {
      // Fallback
      _postId = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDev = ref.watch(isDeveloperProvider).valueOrNull ?? false;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: _postId.isEmpty 
          ? Center(child: Text('Invalid post ID', style: TextStyle(color: AppColors.white)))
          : StreamBuilder<DevBlogPost?>(
        stream: ref.read(devBlogServiceProvider).getPost(_postId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _initialPost == null) {
            return Center(child: CircularProgressIndicator(color: AppColors.accentGold));
          }
          
          final post = snapshot.data ?? _initialPost;
          if (post == null) {
            return Center(child: Text('Post not found', style: TextStyle(color: AppColors.white)));
          }

          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(context, post, isDev),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  child: _buildContent(post),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSliverAppBar(
      BuildContext context, DevBlogPost post, bool isDev) {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      backgroundColor: AppColors.black,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded,
            color: AppColors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      actions: isDev
          ? [
              IconButton(
                icon: Icon(Icons.edit_rounded,
                    color: AppColors.white, size: 20),
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.blogPostEditor,
                  arguments: post,
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded,
                    color: AppColors.grey50, size: 20),
                onPressed: () => _confirmDelete(context, post),
              ),
            ]
          : null,
      flexibleSpace: FlexibleSpaceBar(
        background: post.coverImageUrl != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: post.coverImageUrl!,
                    fit: BoxFit.cover,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppColors.black.withValues(alpha: 0.85),
                        ],
                        stops: const [0.4, 1.0],
                      ),
                    ),
                  ),
                ],
              )
            : Container(
                color: AppColors.grey10,
                child: Center(
                  child: Icon(
                    Icons.article_outlined,
                    size: 48,
                    color: AppColors.grey30,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildContent(DevBlogPost post) {
    final lang = ref.watch(languageProvider);
    final isEnglish = lang == 'en';
    final title = isEnglish && post.titleEn != null && post.titleEn!.isNotEmpty 
        ? post.titleEn! 
        : post.title;
    final body = isEnglish && post.bodyEn != null && post.bodyEn!.isNotEmpty 
        ? post.bodyEn! 
        : post.body;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _CategoryChip(category: post.category),
            if (post.isPinned) ...[
              const SizedBox(width: 8),
              Icon(Icons.push_pin_rounded,
                  size: 13, color: AppColors.accentGold),
            ],
          ],
        ),
        const SizedBox(height: 14),

        Text(
          title,
          style: GoogleFonts.notoSansJp(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.white,
            height: 1.4,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Text(
              post.authorName,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.grey70,
                fontWeight: FontWeight.w600,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Container(
                  width: 3,
                  height: 3,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.grey30,
                  )),
            ),
            Text(
              DateFormat(AppLocalizations.of(context)!.dateFormatFull).format(post.createdAt),
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.grey50,
              ),
            ),
          ],
        ),

        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Divider(
              color: AppColors.grey20, thickness: 0.5, height: 0),
        ),

        MarkdownBody(
          data: body,
          selectable: true,
          styleSheet: MarkdownStyleSheet(
            h1: GoogleFonts.notoSansJp(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.white,
                height: 1.4),
            h2: GoogleFonts.notoSansJp(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.white,
                height: 1.4),
            h3: GoogleFonts.notoSansJp(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.white),
            p: GoogleFonts.notoSansJp(
                fontSize: 15, color: AppColors.grey85, height: 1.8),
            strong: GoogleFonts.notoSansJp(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.white),
            em: GoogleFonts.notoSansJp(
                fontSize: 15,
                color: AppColors.grey85,
                fontStyle: FontStyle.italic),
            listBullet: GoogleFonts.notoSansJp(
                fontSize: 15, color: AppColors.grey85, height: 1.8),
            blockquote: GoogleFonts.notoSansJp(
                fontSize: 15, color: AppColors.grey50, height: 1.8),
            code: GoogleFonts.sourceCodePro(
                fontSize: 13,
                color: AppColors.grey85,
                backgroundColor: Colors.transparent),
            codeblockDecoration: BoxDecoration(
              color: AppColors.grey10,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.grey20, width: 0.5),
            ),
            codeblockPadding: const EdgeInsets.all(12),
            blockquoteDecoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: AppColors.grey30, width: 3),
              ),
            ),
            blockquotePadding:
                const EdgeInsets.only(left: 16, top: 4, bottom: 4),
            horizontalRuleDecoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.grey20, width: 0.5),
              ),
            ),
            blockSpacing: 16,
          ),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, DevBlogPost post) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.grey10,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          AppLocalizations.of(context)!.blogPostDetailDeleteTitle,
          style: GoogleFonts.notoSansJp(
              color: AppColors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          AppLocalizations.of(context)!.blogPostDetailDeleteDesc,
          style: GoogleFonts.notoSansJp(
              color: AppColors.grey50, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.blogPostDetailDeleteCancel,
                style:
                    GoogleFonts.outfit(color: AppColors.grey50)),
          ),
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              nav.pop();
              await ref.read(devBlogServiceProvider).deletePost(post.id);
              if (mounted) nav.pop();
            },
            child: Text(AppLocalizations.of(context)!.blogPostDetailDeleteButton,
                style: GoogleFonts.outfit(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});

  final BlogCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.grey15,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.grey30, width: 0.5),
      ),
      child: Text(
        category.label,
        style: GoogleFonts.outfit(
          fontSize: 12,
          color: AppColors.grey70,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
