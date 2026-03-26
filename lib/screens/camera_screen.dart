import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_colors.dart';
import '../services/post_service.dart';
import '../widgets/post_success_dialog.dart';

/// Hero Task 撮影画面
///
/// [heroTaskName] が渡された場合、ヒーロータスク名は固定表示されます。
/// 投稿成功時は `Navigator.pop(context, true)` で結果を返します。
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, this.heroTaskName});

  final String? heroTaskName;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImagePicker _picker = ImagePicker();
  final PostService _postService = PostService.instance;
  XFile? _image;
  DateTime? _captureTime;
  bool _isUploading = false;
  bool _showTimestamp = true;
  final TextEditingController _captionController = TextEditingController();

  String? get _taskName {
    // ルート引数 or コンストラクタ引数
    final args = ModalRoute.of(context)?.settings.arguments;
    if (widget.heroTaskName != null) return widget.heroTaskName;
    if (args is String) return args;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
    // 画面を開いたら即選択メニューを表示
    WidgetsBinding.instance.addPostFrameCallback((_) => _showPickerMenu());
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('private')
        .doc('data')
        .get();
    if (mounted) {
      setState(() {
        _showTimestamp = snap.data()?['showTimestamp'] ?? true;
      });
    }
  }

  Future<void> _showPickerMenu() async {
    // インスタ風に下からメニューを出す
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.grey10,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.white),
                title: const Text('カメラで撮影', style: TextStyle(color: AppColors.white)),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.white),
                title: const Text('アルバムから選択', style: TextStyle(color: AppColors.white)),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source != null) {
      _pickImage(source);
    } else if (_image == null && mounted) {
      // メニューを閉じた時に写真が未選択なら戻る
      Navigator.pop(context, false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? photo = await _picker.pickImage(
      source: source,
      maxWidth: 1080,
      maxHeight: 1920,
      imageQuality: 70,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (photo != null && mounted) {
      setState(() {
        _image = photo;
        _captureTime = DateTime.now(); // ギャラリーからの場合も現在時刻とする
      });
    } else if (_image == null && mounted) {
      // キャンセルした場合は再度メニューを出すか戻る
      _showPickerMenu();
    }
  }

  Future<void> _uploadPost() async {
    if (_image == null) return;
    final taskName = _taskName ?? '今日のヒーロータスク';

    HapticFeedback.mediumImpact();
    setState(() => _isUploading = true);

    try {
      final bytes = await _image!.readAsBytes();
      final captionText = _captionController.text.trim();

      final result = await _postService.createPost(
        imageBytes: bytes,
        taskName: taskName,
        caption: captionText.isNotEmpty ? captionText : null,
      );

      if (mounted) {
        await PostSuccessDialog.show(
          context,
          streakDays: result['newStreak'] as int,
          isRecordUpdating: result['isRecordUpdating'] as bool,
        );
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e, st) {
      debugPrint('POST UPLOAD ERROR: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('投稿に失敗しました。もう一度お試しください。')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskName = _taskName;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.white),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                  const Spacer(),
                  if (taskName != null)
                    Expanded(
                      flex: 3,
                      child: Text(
                        taskName,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSansJp(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  const Spacer(),
                  const SizedBox(width: 48), // balance close button
                ],
              ),
            ),

            // ── Photo area ──
            Expanded(
              child: _image != null
                  ? _buildPreview()
                  : _buildPlaceholder(),
            ),

            // ── Bottom actions ──
            if (_image != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: TextField(
                  controller: _captionController,
                  style: const TextStyle(color: AppColors.white),
                  decoration: InputDecoration(
                    hintText: '一言を添える (任意)',
                    hintStyle: const TextStyle(color: AppColors.grey50),
                    filled: true,
                    fillColor: AppColors.white.withValues(alpha: 0.1),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              _buildBottomBar(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.white.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.white.withValues(alpha: 0.03),
            blurRadius: 40,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            kIsWeb
                ? Image.network(_image!.path, fit: BoxFit.cover)
                : Image.file(File(_image!.path), fit: BoxFit.cover),

            // Timestamp
            if (_captureTime != null && _showTimestamp)
              Positioned(
                bottom: 20,
                right: 20,
                child: Text(
                  DateFormat('yy/MM/dd\nHH:mm').format(_captureTime!),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: AppColors.black.withValues(alpha: 0.6),
                        offset: const Offset(1, 1),
                        blurRadius: 2,
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

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.grey15,
              border: Border.all(color: AppColors.grey20),
            ),
            child: const Icon(Icons.camera_alt,
                size: 40, color: AppColors.grey50),
          ),
          const SizedBox(height: 20),
          Text('カメラを起動中...',
              style: TextStyle(color: AppColors.grey30, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.black.withValues(alpha: 0.0),
                AppColors.black.withValues(alpha: 0.8),
              ],
            ),
          ),
          child: Row(
            children: [
              // Retake
              GestureDetector(
                onTap: _isUploading ? null : _showPickerMenu,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.grey15,
                    border: Border.all(color: AppColors.grey20),
                  ),
                  child: const Icon(Icons.refresh_rounded,
                      color: AppColors.grey70, size: 22),
                ),
              ),
              const Spacer(),

              // Post button
              GestureDetector(
                onTap: _isUploading ? null : _uploadPost,
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: BoxDecoration(
                    color: _isUploading ? AppColors.grey15 : AppColors.white,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: _isUploading
                        ? []
                        : [
                            BoxShadow(
                              color: AppColors.white.withValues(alpha: 0.15),
                              blurRadius: 24,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: Center(
                    child: _isUploading
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.grey50))
                        : Text(
                            '投稿する',
                            style: GoogleFonts.notoSansJp(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.black,
                            ),
                          ),
                  ),
                ),
              ),
              const Spacer(),
              const SizedBox(width: 48), // balance retake button
            ],
          ),
        ),
      ),
    );
  }
}
