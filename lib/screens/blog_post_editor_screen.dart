import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_colors.dart';
import '../models/dev_blog_post.dart';
import '../models/season.dart';
import '../services/dev_blog_service.dart';
import '../widgets/gradient_button.dart';
import '../widgets/v_effect_header.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BlogPostEditorScreen extends StatefulWidget {
  const BlogPostEditorScreen({super.key});

  @override
  State<BlogPostEditorScreen> createState() => _BlogPostEditorScreenState();
}

class _BlogPostEditorScreenState extends State<BlogPostEditorScreen> {
  DevBlogPost? _editingPost;
  final _titleController = TextEditingController();
  final _titleEnController = TextEditingController();
  final _bodyController = TextEditingController();
  final _bodyEnController = TextEditingController();
  final _bodyFocusNode = FocusNode();
  BlogCategory _category = BlogCategory.progress;
  bool _isPinned = false;
  File? _coverImageFile;
  String? _existingCoverUrl;
  bool _isSaving = false;
  bool _previewMode = false;

  bool _isSeasonTask = false;
  final _seasonTaskNameController = TextEditingController();
  final _seasonDurationController = TextEditingController(text: '7');
  final _seasonHintTitleController = TextEditingController();
  final _seasonHintBodyController = TextEditingController();
  final _seasonBadgeImageUrlController = TextEditingController();
  String _seasonBadgeAnimation = 'none';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_editingPost != null) return;
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is DevBlogPost) {
      _editingPost = arg;
      _titleController.text = arg.title;
      _titleEnController.text = arg.titleEn ?? '';
      _bodyController.text = arg.body;
      _bodyEnController.text = arg.bodyEn ?? '';
      _category = arg.category;
      _isPinned = arg.isPinned;
      _existingCoverUrl = arg.coverImageUrl;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleEnController.dispose();
    _bodyController.dispose();
    _bodyEnController.dispose();
    _bodyFocusNode.dispose();
    _seasonTaskNameController.dispose();
    _seasonDurationController.dispose();
    _seasonHintTitleController.dispose();
    _seasonHintBodyController.dispose();
    _seasonBadgeImageUrlController.dispose();
    super.dispose();
  }

  // ── テキスト操作 ──────────────────────────────────────

  void _insertLinePrefix(String prefix) {
    final ctrl = _bodyController;
    final sel = ctrl.selection;
    if (!sel.isValid) return;
    _bodyFocusNode.requestFocus();

    final text = ctrl.text;
    final lineStart =
        text.lastIndexOf('\n', sel.baseOffset > 0 ? sel.baseOffset - 1 : 0) + 1;
    final afterStart = text.substring(lineStart);

    final String newText;
    final int newOffset;
    if (afterStart.startsWith(prefix)) {
      newText = text.replaceRange(lineStart, lineStart + prefix.length, '');
      newOffset =
          (sel.baseOffset - prefix.length).clamp(lineStart, newText.length);
    } else {
      newText = text.replaceRange(lineStart, lineStart, prefix);
      newOffset = sel.baseOffset + prefix.length;
    }

    ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }

  void _wrapText(String before, String after) {
    final ctrl = _bodyController;
    final sel = ctrl.selection;
    if (!sel.isValid) return;
    _bodyFocusNode.requestFocus();

    final text = ctrl.text;
    final String newText;
    final TextSelection newSel;

    if (sel.isCollapsed) {
      const placeholder = 'テキスト';
      newText =
          text.replaceRange(sel.start, sel.end, '$before$placeholder$after');
      newSel = TextSelection(
        baseOffset: sel.start + before.length,
        extentOffset: sel.start + before.length + placeholder.length,
      );
    } else {
      final selected = sel.textInside(text);
      newText = text.replaceRange(
          sel.start, sel.end, '$before$selected$after');
      newSel = TextSelection.collapsed(
        offset: sel.start + before.length + selected.length + after.length,
      );
    }

    ctrl.value = TextEditingValue(text: newText, selection: newSel);
  }

  void _insertDivider() {
    final ctrl = _bodyController;
    final sel = ctrl.selection;
    if (!sel.isValid) return;
    _bodyFocusNode.requestFocus();

    final text = ctrl.text;
    const divider = '\n\n---\n\n';
    final newText = text.replaceRange(sel.start, sel.end, divider);
    ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: sel.start + divider.length),
    );
  }

  void _insertCodeBlock() {
    final ctrl = _bodyController;
    final sel = ctrl.selection;
    if (!sel.isValid) return;
    _bodyFocusNode.requestFocus();

    final text = ctrl.text;
    const placeholder = 'コードをここに入力';

    if (sel.isCollapsed) {
      final block = '\n```\n$placeholder\n```\n';
      final newText = text.replaceRange(sel.start, sel.end, block);
      ctrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: sel.start + 5,
          extentOffset: sel.start + 5 + placeholder.length,
        ),
      );
    } else {
      final selected = sel.textInside(text);
      final block = '\n```\n$selected\n```\n';
      final newText = text.replaceRange(sel.start, sel.end, block);
      ctrl.value = TextEditingValue(
        text: newText,
        selection:
            TextSelection.collapsed(offset: sel.start + block.length),
      );
    }
  }

  // ── 画像・保存 ────────────────────────────────────────

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
    final titleEn = _titleEnController.text.trim();
    final body = _bodyController.text.trim();
    final bodyEn = _bodyEnController.text.trim();
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
          titleEn: titleEn.isNotEmpty ? titleEn : null,
          bodyEn: bodyEn.isNotEmpty ? bodyEn : null,
        );
        await DevBlogService.instance.createPost(post);

        // シーズンタスクの設定があれば保存
        if (_isSeasonTask) {
          final durationDays = int.tryParse(_seasonDurationController.text) ?? 7;
          final season = Season(
            id: postId,
            taskName: _seasonTaskNameController.text.trim(),
            startDate: now,
            endDate: now.add(Duration(days: durationDays)),
            hintTitle: _seasonHintTitleController.text.trim().isEmpty ? null : _seasonHintTitleController.text.trim(),
            hintBody: _seasonHintBodyController.text.trim().isEmpty ? null : _seasonHintBodyController.text.trim(),
            relatedBlogId: postId,
            badgeImageUrl: _seasonBadgeImageUrlController.text.trim().isEmpty ? null : _seasonBadgeImageUrlController.text.trim(),
            badgeAnimation: _seasonBadgeImageUrlController.text.trim() == 'tester' ? 'shimmer' : 'none',
          );
          await FirebaseFirestore.instance.collection('seasons').doc(postId).set(season.toFirestore());
        }
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
          titleEn: titleEn.isNotEmpty ? titleEn : null,
          bodyEn: bodyEn.isNotEmpty ? bodyEn : null,
        );
        await DevBlogService.instance.updatePost(updated);

        if (_isSeasonTask) {
          final durationDays = int.tryParse(_seasonDurationController.text) ?? 7;
          final season = Season(
            id: _editingPost!.id,
            taskName: _seasonTaskNameController.text.trim(),
            startDate: now, // 既存開始日を保持すべきだが簡易的に現在時刻とするか、今回は新規作成メインで考慮
            endDate: now.add(Duration(days: durationDays)),
            hintTitle: _seasonHintTitleController.text.trim().isEmpty ? null : _seasonHintTitleController.text.trim(),
            hintBody: _seasonHintBodyController.text.trim().isEmpty ? null : _seasonHintBodyController.text.trim(),
            relatedBlogId: _editingPost!.id,
            badgeImageUrl: _seasonBadgeImageUrlController.text.trim().isEmpty ? null : _seasonBadgeImageUrlController.text.trim(),
            badgeAnimation: _seasonBadgeImageUrlController.text.trim() == 'tester' ? 'shimmer' : 'none',
          );
          await FirebaseFirestore.instance.collection('seasons').doc(_editingPost!.id).set(season.toFirestore());
        }
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Save error: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        _showError('エラー: $e');
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

  // ── Build ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEditing = _editingPost != null;

    return Scaffold(
      backgroundColor: AppColors.black,
      resizeToAvoidBottomInset: true,
      bottomNavigationBar: _previewMode ? null : _buildFormatToolbar(),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isEditing),
            Expanded(
              child: _previewMode
                  ? _buildPreview()
                  : _buildEditor(isEditing),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isEditing) {
    return VEffectHeader(
      leading: IconButton(
        icon: const Icon(Icons.close_rounded, color: AppColors.white, size: 22),
        onPressed: () => Navigator.pop(context),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              _previewMode ? Icons.edit_outlined : Icons.visibility_outlined,
              color: _previewMode ? AppColors.white : AppColors.grey50,
              size: 20,
            ),
            onPressed: () {
              setState(() => _previewMode = !_previewMode);
              if (!_previewMode) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _bodyFocusNode.requestFocus();
                });
              } else {
                FocusScope.of(context).unfocus();
              }
            },
          ),
          if (_isSaving)
            const SizedBox(
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
          else
            TextButton(
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
        ],
      ),
    );
  }

  Widget _buildEditor(bool isEditing) {
    return SingleChildScrollView(
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
          _buildTitleEnField(),
          const SizedBox(height: 16),
          _buildBodyField(),
          const SizedBox(height: 16),
          _buildBodyEnField(),
          const SizedBox(height: 24),
          _buildSeasonTaskToggle(),
          const SizedBox(height: 32),
          GradientButton(
            isLoading: _isSaving,
            onPressed: _isSaving ? null : _save,
            child: Text(isEditing ? '記事を更新する' : '記事を投稿する'),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final title = _titleController.text;
    final body = _bodyController.text;
    final hasCover = _coverImageFile != null || _existingCoverUrl != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasCover)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 3 / 2,
                child: _coverImageFile != null
                    ? Image.file(_coverImageFile!, fit: BoxFit.cover)
                    : Image.network(_existingCoverUrl!, fit: BoxFit.cover),
              ),
            ),
          if (hasCover) const SizedBox(height: 20),
          if (title.isNotEmpty)
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
          if (title.isNotEmpty && body.isNotEmpty)
            const SizedBox(height: 20),
          if (body.isNotEmpty)
            MarkdownBody(
              data: body,
              styleSheet: _markdownStyleSheet(),
              selectable: true,
            ),
          if (title.isEmpty && body.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Text(
                  'タイトルと本文を入力してください',
                  style: GoogleFonts.notoSansJp(color: AppColors.grey30),
                ),
              ),
            ),
        ],
      ),
    );
  }

  MarkdownStyleSheet _markdownStyleSheet() {
    return MarkdownStyleSheet(
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
      blockquoteDecoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: AppColors.grey30, width: 3),
        ),
      ),
      blockquotePadding:
          const EdgeInsets.only(left: 16, top: 4, bottom: 4),
      horizontalRuleDecoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.grey20, width: 0.5),
        ),
      ),
      blockSpacing: 16,
    );
  }

  // ── フォーマットツールバー ────────────────────────────

  Widget _buildFormatToolbar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.grey10,
        border: Border(
          top: BorderSide(color: AppColors.grey20, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 44,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                _toolbarTextBtn('H1', () => _insertLinePrefix('## ')),
                _toolbarTextBtn('H2', () => _insertLinePrefix('### ')),
                _toolbarSep(),
                _toolbarIconBtn(Icons.format_bold_rounded,
                    () => _wrapText('**', '**')),
                _toolbarIconBtn(Icons.format_italic_rounded,
                    () => _wrapText('*', '*')),
                _toolbarSep(),
                _toolbarIconBtn(Icons.format_list_bulleted_rounded,
                    () => _insertLinePrefix('- ')),
                _toolbarIconBtn(Icons.format_list_numbered_rounded,
                    () => _insertLinePrefix('1. ')),
                _toolbarSep(),
                _toolbarIconBtn(Icons.format_quote_rounded,
                    () => _insertLinePrefix('> ')),
                _toolbarIconBtn(
                    Icons.code_rounded, () => _wrapText('`', '`')),
                _toolbarTextBtn('</>', _insertCodeBlock),
                _toolbarSep(),
                _toolbarIconBtn(Icons.horizontal_rule_rounded, _insertDivider),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolbarIconBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Icon(icon, size: 19, color: AppColors.grey70),
      ),
    );
  }

  Widget _toolbarTextBtn(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.grey70,
          ),
        ),
      ),
    );
  }

  Widget _toolbarSep() {
    return Container(
      width: 0.5,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      color: AppColors.grey20,
    );
  }

  // ── フォームパーツ ────────────────────────────────────

  Future<void> _pickBadgeImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() => _isSaving = true);
      try {
        final url = await DevBlogService.instance.uploadBadgeImage(File(picked.path));
        setState(() {
          _seasonBadgeImageUrlController.text = url;
        });
        _showError('バッジ画像をアップロードしました'); // Use _showError to show success as snackbar
      } catch (e) {
        _showError('アップロードに失敗しました');
      } finally {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildCoverPicker() {

    final hasCover = _coverImageFile != null || _existingCoverUrl != null;

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
                  color: isSelected ? AppColors.white : AppColors.grey10,
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
                color: _isPinned ? AppColors.white : AppColors.grey30,
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

  Widget _buildTitleEnField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'タイトル (ENGLISH)',
          style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.grey50,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _titleEnController,
          style: GoogleFonts.notoSansJp(
              fontSize: 16,
              color: AppColors.white,
              fontWeight: FontWeight.w700),
          maxLines: 2,
          minLines: 1,
          decoration: _inputDecoration('Enter title in English'),
        ),
      ],
    );
  }

  Widget _buildBodyField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '本文',
              style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AppColors.grey50,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Text(
              '— Markdownが使えます',
              style: GoogleFonts.outfit(
                  fontSize: 11, color: AppColors.grey30),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _bodyController,
          focusNode: _bodyFocusNode,
          style: GoogleFonts.notoSansJp(
              fontSize: 15, color: AppColors.grey85, height: 1.7),
          maxLines: null,
          minLines: 10,
          keyboardType: TextInputType.multiline,
          decoration: _inputDecoration('本文を入力\n\n## 見出し\n**太字** *斜体*\n- 箇条書き'),
        ),
      ],
    );
  }

  Widget _buildBodyEnField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '本文 (ENGLISH)',
              style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AppColors.grey50,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Text(
              '— Markdownが使えます',
              style: GoogleFonts.outfit(
                  fontSize: 11, color: AppColors.grey30),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _bodyEnController,
          style: GoogleFonts.notoSansJp(
              fontSize: 15, color: AppColors.grey85, height: 1.7),
          maxLines: null,
          minLines: 10,
          keyboardType: TextInputType.multiline,
          decoration: _inputDecoration('Enter body in English\n\n## Heading\n**Bold** *Italic*\n- List'),
        ),
      ],
    );
  }

  Widget _buildSeasonTaskToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.grey10,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _isSeasonTask ? AppColors.accentGold : AppColors.grey20, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showSeasonTaskConfigModal(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _isSeasonTask ? AppColors.accentGold.withValues(alpha: 0.15) : AppColors.grey15,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isSeasonTask ? Icons.star_rounded : Icons.star_border_rounded,
                    color: _isSeasonTask ? AppColors.accentGold : AppColors.grey50,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isSeasonTask ? 'シーズンタスク設定済み' : 'シーズンタスクを設定する',
                        style: GoogleFonts.notoSansJp(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _isSeasonTask ? AppColors.accentGold : AppColors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isSeasonTask
                            ? '${_seasonTaskNameController.text} (${_seasonDurationController.text}日間)'
                            : 'このお知らせと一緒にシーズンタスクを配布・通知します。',
                        style: GoogleFonts.notoSansJp(
                          fontSize: 12,
                          color: AppColors.grey50,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.grey50,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSeasonTaskConfigModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
          return Container(
            margin: EdgeInsets.only(bottom: bottomInset),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            decoration: const BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'シーズンタスクの設定',
                        style: GoogleFonts.notoSansJp(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white,
                        ),
                      ),
                      Switch(
                        value: _isSeasonTask,
                        activeColor: AppColors.accentGold,
                        onChanged: (val) {
                          setStateModal(() => _isSeasonTask = val);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_isSeasonTask) ...[
                    Text('タスク名 (必須)', style: GoogleFonts.notoSansJp(fontSize: 13, color: AppColors.grey50)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _seasonTaskNameController,
                      style: GoogleFonts.notoSansJp(color: AppColors.white),
                      decoration: _inputDecoration('例: 感謝を伝える'),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    Text('実施期間(日数)', style: GoogleFonts.notoSansJp(fontSize: 13, color: AppColors.grey50)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _seasonDurationController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.notoSansJp(color: AppColors.white),
                      decoration: _inputDecoration('例: 7'),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    Text('ヒントタイトル', style: GoogleFonts.notoSansJp(fontSize: 13, color: AppColors.grey50)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _seasonHintTitleController,
                      style: GoogleFonts.notoSansJp(color: AppColors.white),
                      decoration: _inputDecoration('例: 📸 何を撮ればいいの？（撮影のヒント）'),
                    ),
                    const SizedBox(height: 16),
                    Text('ヒント本文', style: GoogleFonts.notoSansJp(fontSize: 13, color: AppColors.grey50)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _seasonHintBodyController,
                      maxLines: 4,
                      style: GoogleFonts.notoSansJp(color: AppColors.white),
                      decoration: _inputDecoration('ユーザーが写真を撮る際のヒントを入力してください'),
                    ),
                    const SizedBox(height: 16),
                    Text('バッジ画像URL', style: GoogleFonts.notoSansJp(fontSize: 13, color: AppColors.grey50)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _seasonBadgeImageUrlController,
                            style: GoogleFonts.notoSansJp(color: AppColors.white),
                            decoration: _inputDecoration('例: tester (またはFirebase URL)'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.add_photo_alternate, color: AppColors.accentGold),
                          onPressed: () async {
                            await _pickBadgeImage();
                            setStateModal(() {});
                          },
                          tooltip: '画像を選択してアップロード',
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.white,
                      foregroundColor: AppColors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text(
                      '完了',
                      style: GoogleFonts.notoSansJp(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
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
        borderSide:
            const BorderSide(color: AppColors.grey20, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: AppColors.grey50, width: 0.5),
      ),
    );
  }
}
