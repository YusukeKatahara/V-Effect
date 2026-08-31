import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:v_effect/l10n/app_localizations.dart';

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
  BlogCategory? _selectedCategory; // 選択されたカテゴリ（nullは「すべて」）

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
    final isDeveloperAsync = ref.watch(isDeveloperProvider);
    final isDev = isDeveloperAsync.valueOrNull ?? false;
    final postsAsync = isDev ? ref.watch(blogPostsProvider) : ref.watch(publishedBlogPostsProvider);

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Column(
          children: [
            VEffectHeader(
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              trailing: isDev
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.stars_rounded, color: AppColors.accentGold, size: 22),
                          tooltip: AppLocalizations.of(context)!.vPracticeDistributeBadge,
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => const _AdminBadgeDistributeDialog(),
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.add_rounded, color: AppColors.white, size: 22),
                          tooltip: AppLocalizations.of(context)!.vPracticeCreateBlog,
                          onPressed: () =>
                              Navigator.pushNamed(context, AppRoutes.blogPostEditor),
                        ),
                      ],
                    )
                  : null,
            ),
            _buildCategoryFilter(context), // カテゴリ選択用の横スクロールチップス
            Expanded(
              child: postsAsync.when(
                data: (allPosts) {
                  // 1. 選択中のカテゴリでフィルタリングする
                  var posts = allPosts;
                  if (_selectedCategory != null) {
                    posts = posts.where((p) => p.category == _selectedCategory).toList();
                  }

                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      // フェードと少しのスライド（下から上へ）を組み合わせたアニメーション
                      final slideAnimation = Tween<Offset>(
                        begin: const Offset(0.0, 0.05),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ));
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: slideAnimation,
                          child: child,
                        ),
                      );
                    },
                    child: posts.isEmpty
                        ? _EmptyState(key: ValueKey('empty_${_selectedCategory?.name ?? "all"}'))
                        : ListView.builder(
                            key: ValueKey('list_${_selectedCategory?.name ?? "all"}'),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            itemCount: posts.length,
                            itemBuilder: (context, i) =>
                                _BlogCard(post: posts[i]),
                          ),
                  );
                },
                loading: () => Center(
                  child: CircularProgressIndicator(
                    color: AppColors.white,
                    strokeWidth: 1.5,
                  ),
                ),
                error: (e, _) => Center(
                  child: Text(
                    AppLocalizations.of(context)!.vPracticeError,
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

  /// カテゴリ絞り込み用の横スクロール可能なチップスUIを構築します。
  Widget _buildCategoryFilter(BuildContext context) {
    // 「すべて（null）」と定義済みのカテゴリ一覧を並べます
    final categories = [null, ...BlogCategory.values];
    final l = AppLocalizations.of(context)!;

    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: categories.map((cat) {
            final isSelected = _selectedCategory == cat;
            final String label = cat == null ? l.vPracticeCategoryAll : cat.label(context);

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  if (_selectedCategory != cat) {
                    setState(() {
                      _selectedCategory = cat;
                    });
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.accentGold, AppColors.accentGoldLight],
                          )
                        : null,
                    color: isSelected ? null : AppColors.grey10,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? Colors.transparent : AppColors.grey20,
                      width: 0.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.accentGold.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Text(
                    label,
                    style: GoogleFonts.notoSansJp(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? AppColors.pureBlack : AppColors.grey50,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
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
      child: Opacity(
        opacity: post.isDraft ? 0.7 : 1.0,
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
                      if (post.isDraft) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.error, width: 0.5),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.blogPostEditorStatusDraft,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                      if (post.isPinned) ...[
                        const SizedBox(width: 8),
                        Icon(
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
      decoration: BoxDecoration(gradient: AppColors.bgGradient),
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
      case BlogCategory.howto:
        return Icons.menu_book_rounded;
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
        category.label(context),
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
  const _EmptyState({super.key});

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
            AppLocalizations.of(context)!.vPracticeNoNews,
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
  final _targetUsersController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    _targetUsersController.dispose();
    super.dispose();
  }

  Future<void> _distributeBadge() async {
    final l = AppLocalizations.of(context)!;
    final badgeUrl = _controller.text.trim();
    final targetUsersText = _targetUsersController.text.trim();
    if (badgeUrl.isEmpty) {
      _showError(l.vPracticeBadgeIdRequired);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final db = FirebaseFirestore.instance;
      List<dynamic> targetDocs = [];
      
      if (targetUsersText.isNotEmpty) {
        final targetUserIds = targetUsersText.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        for (var i = 0; i < targetUserIds.length; i += 30) {
          final end = (i + 30 < targetUserIds.length) ? i + 30 : targetUserIds.length;
          final chunk = targetUserIds.sublist(i, end);
          final snap = await db.collection('users').where('userId', whereIn: chunk).get();
          targetDocs.addAll(snap.docs);
        }
      } else {
        final snap = await db.collection('users').get();
        targetDocs = snap.docs;
      }

      if (targetDocs.isEmpty) {
        if (mounted) {
          _showError('対象のユーザーが見つかりませんでした');
          setState(() => _isSaving = false);
        }
        return;
      }

      final batch = db.batch();
      int count = 0;
      
      for (var doc in targetDocs) {
        final data = doc.data() as Map<String, dynamic>;
        final List<String> currentOwned = (data['ownedBadges'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        if (!currentOwned.contains(badgeUrl)) {
          currentOwned.add(badgeUrl);
        }

        batch.update(doc.reference, {
          'ownedBadges': currentOwned,
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
            content: Text(l.vPracticeBadgeDistributed(badgeUrl),
                style: GoogleFonts.notoSansJp(color: AppColors.white)),
            backgroundColor: AppColors.accentGold,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('配布エラー: $e');
      _showError(l.vPracticeBadgeDistributeFailed);
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
          Icon(Icons.stars_rounded, color: AppColors.accentGold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(AppLocalizations.of(context)!.vPracticeDialogTitle,
                style: GoogleFonts.notoSansJp(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.vPracticeDialogDesc,
              style: GoogleFonts.notoSansJp(color: AppColors.grey70, fontSize: 13)),
          const SizedBox(height: 16),
          TextField(
            controller: _targetUsersController,
            style: GoogleFonts.notoSansJp(color: AppColors.white),
            decoration: InputDecoration(
              hintText: '配布先ユーザーID（カンマ区切り。空欄で全員）',
              hintStyle: GoogleFonts.notoSansJp(color: AppColors.grey50),
              filled: true,
              fillColor: AppColors.black.withValues(alpha: 0.3),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.grey30, width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.accentGold, width: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            style: GoogleFonts.notoSansJp(color: AppColors.white),
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.vPracticeBadgeIdHint,
              hintStyle: GoogleFonts.notoSansJp(color: AppColors.grey30),
              filled: true,
              fillColor: AppColors.black.withValues(alpha: 0.3),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.grey30, width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.accentGold, width: 0.5),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.vPracticeCancel, style: GoogleFonts.notoSansJp(color: AppColors.grey50)),
        ),
        _isSaving
            ? SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(color: AppColors.accentGold, strokeWidth: 2),
              )
            : TextButton(
                onPressed: _distributeBadge,
                child: Text(AppLocalizations.of(context)!.vPracticeDistribute, style: GoogleFonts.notoSansJp(color: AppColors.accentGold, fontWeight: FontWeight.bold)),
              ),
      ],
    );
  }
}
