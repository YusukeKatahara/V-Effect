import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_colors.dart';
import '../models/dev_blog_post.dart';
import '../services/dev_blog_service.dart';
import '../widgets/gradient_button.dart';
import '../widgets/v_effect_header.dart';

class BlogPostEditorScreen extends StatefulWidget {
  const BlogPostEditorScreen({super.key});

  @override
  State<BlogPostEditorScreen> createState() => _BlogPostEditorScreenState();
}

class _BlogPostEditorScreenState extends State<BlogPostEditorScreen> {
  DevBlogPost? _editingPost;
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  BlogCategory _category = BlogCategory.progress;
  bool _isPinned = false;
  File? _coverImageFile;
  String? _existingCoverUrl;
  bool _isSaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_editingPost != null) return;
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is DevBlogPost) {
      _editingPost = arg;
      _titleController.text = arg.title;
      _bodyController.text = arg.body;
      _category = arg.category;
      _isPinned = arg.isPinned;
      _existingCoverUrl = arg.coverImageUrl;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() => _coverImageFile = File(picked.path));
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      _showError('タイトルと本文を入力してください');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final now = DateTime.now();

      if (_editingPost == null) {
        final postId = DevBlogService.instance.generatePostId();
        String? coverUrl;
        if (_coverImageFile != null) {
          coverUrl = await DevBlogService.instance
              .uploadCoverImage(postId, _coverImageFile!);
        }
        final post = DevBlogPost(
          id: postId,
          title: title,
          body: body,
          category: _category,
          authorId: user.uid,
          authorName: user.displayName ?? 'Developer',
          coverImageUrl: coverUrl,
          isPinned: _isPinned,
          createdAt: now,
          updatedAt: now,
        );
        await DevBlogService.instance.createPost(post);
      } else {
        String? coverUrl = _existingCoverUrl;
        if (_coverImageFile != null) {
          coverUrl = await DevBlogService.instance
              .uploadCoverImage(_editingPost!.id, _coverImageFile!);
        }
        final updated = _editingPost!.copyWith(
          title: title,
          body: body,
          category: _category,
          coverImageUrl: coverUrl,
          isPinned: _isPinned,
          updatedAt: now,
        );
        await DevBlogService.instance.updatePost(updated);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Save error: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        _showError('保存に失敗しました');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: GoogleFonts.notoSansJp(color: AppColors.white)),
        backgroundColor: AppColors.grey15,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _editingPost != null;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Column(
          children: [
            VEffectHeader(
              leading: IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: AppColors.white, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
              trailing: _isSaving
                  ? const SizedBox(
                      width: 48,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: AppColors.white, strokeWidth: 1.5),
                        ),
                      ),
                    )
                  : TextButton(
                      onPressed: _isSaving ? null : _save,
                      child: Text(
                        isEditing ? '更新' : '投稿',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                    ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCoverPicker(),
                    const SizedBox(height: 24),
                    _buildCategorySelector(),
                    const SizedBox(height: 16),
                    _buildPinToggle(),
                    const SizedBox(height: 24),
                    _buildTitleField(),
                    const SizedBox(height: 16),
                    _buildBodyField(),
                    const SizedBox(height: 32),
                    GradientButton(
                      isLoading: _isSaving,
                      onPressed: _isSaving ? null : _save,
                      child: Text(isEditing ? '記事を更新する' : '記事を投稿する'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverPicker() {
    final hasCover =
        _coverImageFile != null || _existingCoverUrl != null;

    return GestureDetector(
      onTap: _pickImage,
      child: AspectRatio(
        aspectRatio: 3 / 2,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.grey10,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.grey20, width: 0.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_coverImageFile != null)
                  Image.file(_coverImageFile!, fit: BoxFit.cover)
                else if (_existingCoverUrl != null)
                  Image.network(_existingCoverUrl!, fit: BoxFit.cover)
                else
                  const ColoredBox(color: AppColors.grey10),
                Container(
                  decoration: BoxDecoration(
                    color: hasCover
                        ? AppColors.black.withValues(alpha: 0.3)
                        : Colors.transparent,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasCover
                              ? Icons.edit_rounded
                              : Icons.add_photo_alternate_outlined,
                          color: hasCover
                              ? AppColors.white.withValues(alpha: 0.8)
                              : AppColors.grey30,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          hasCover ? 'カバー画像を変更' : 'カバー画像を追加',
                          style: GoogleFonts.notoSansJp(
                            fontSize: 13,
                            color: hasCover
                                ? AppColors.white.withValues(alpha: 0.8)
                                : AppColors.grey50,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'カテゴリ',
          style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.grey50,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: BlogCategory.values.map((cat) {
            final isSelected = _category == cat;
            return GestureDetector(
              onTap: () => setState(() => _category = cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color:
                      isSelected ? AppColors.white : AppColors.grey10,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        isSelected ? AppColors.white : AppColors.grey20,
                    width: 0.5,
                  ),
                ),
                child: Text(
                  cat.label,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? AppColors.black
                        : AppColors.grey50,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPinToggle() {
    return GestureDetector(
      onTap: () => setState(() => _isPinned = !_isPinned),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: _isPinned ? AppColors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color:
                    _isPinned ? AppColors.white : AppColors.grey30,
                width: 1,
              ),
            ),
            child: _isPinned
                ? const Icon(Icons.check_rounded,
                    size: 14, color: AppColors.black)
                : null,
          ),
          const SizedBox(width: 10),
          Text(
            'この記事をピン留めする',
            style: GoogleFonts.notoSansJp(
                fontSize: 14, color: AppColors.grey70),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.push_pin_rounded,
              size: 14, color: AppColors.accentGold),
        ],
      ),
    );
  }

  Widget _buildTitleField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'タイトル',
          style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.grey50,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _titleController,
          style: GoogleFonts.notoSansJp(
              fontSize: 16,
              color: AppColors.white,
              fontWeight: FontWeight.w700),
          maxLines: 2,
          minLines: 1,
          decoration: _inputDecoration('タイトルを入力'),
        ),
      ],
    );
  }

  Widget _buildBodyField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '本文',
          style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.grey50,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _bodyController,
          style: GoogleFonts.notoSansJp(
              fontSize: 15,
              color: AppColors.grey85,
              height: 1.7),
          maxLines: null,
          minLines: 10,
          keyboardType: TextInputType.multiline,
          decoration: _inputDecoration('本文を入力'),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.notoSansJp(
          fontSize: 15, color: AppColors.grey30),
      filled: true,
      fillColor: AppColors.grey10,
      contentPadding: const EdgeInsets.all(16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.grey20, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: AppColors.grey50, width: 0.5),
      ),
    );
  }
}
