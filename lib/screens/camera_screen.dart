import 'dart:io';
import 'package:flutter/foundation.dart'; // kIsWeb を使うため
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../config/app_colors.dart';
import '../services/post_service.dart';
import '../widgets/post_success_dialog.dart';

/// 【rennさんへ】
/// カメラ画面です。写真を撮影して「投稿する」ボタンを押すと、
/// PostServiceを通じてFirebaseへ写真とデータが送られます。
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImagePicker _picker = ImagePicker();
  final PostService _postService = PostService(); // サービスを呼び出す準備です
  XFile? _image;
  DateTime? _captureTime;
  bool _isUploading = false;

  // ── タスク名を入力するためのコントローラー ──
  final _taskCtrl = TextEditingController();

  @override
  void dispose() {
    _taskCtrl.dispose();
    super.dispose();
  }

  /// カメラで写真を撮影する処理
  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80, // 画質を80%に戻してデータ量を節約
      preferredCameraDevice: CameraDevice.rear,
    );
    if (photo != null) {
      setState(() {
        _image = photo;
        _captureTime = DateTime.now();
      });
    }
  }

  /// Firebase に写真を投稿する処理
  Future<void> _uploadPost() async {
    if (_image == null) return;

    // タスク名が空なら汎用メッセージを使います
    final taskName =
        _taskCtrl.text.trim().isEmpty ? '今日のタスク' : _taskCtrl.text.trim();

    // ドーパミン誘発：ボタンを押した瞬間の心地よい振動
    HapticFeedback.mediumImpact();

    setState(() => _isUploading = true);
    try {
      // Webとモバイルの両方でアップロードできるように、XFileのbytesを読み込みます
      final bytes = await _image!.readAsBytes();

      // PostServiceの createPost を呼び出すだけでOKです！
      final result = await _postService.createPost(
        imageBytes: bytes,
        taskName: taskName,
      );

      if (mounted) {
        // お祝いダイアログを表示
        await PostSuccessDialog.show(
          context,
          streakDays: result['newStreak'] as int,
          isRecordUpdating: result['isRecordUpdating'] as bool,
        );

        // ダイアログが閉じられたら、ホーム画面に戻る
        if (mounted) {
          Navigator.pop(context); // カメラ画面を閉じる
        }
      }
    } catch (e, st) {
      print('=== POST UPLOAD ERROR ===');
      print(e);
      print(st);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('投稿に失敗しました: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('タスクの証明')),
      body: Column(
        children: [
          // ── 写真エリア ──
          Expanded(
            child:
                _image != null
                    ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // 写真プレビュー（フィルターなし）
                            kIsWeb
                                ? Image.network(_image!.path, fit: BoxFit.cover)
                                : Image.file(
                                  File(_image!.path),
                                  fit: BoxFit.cover,
                                ),

                            // タイムスタンプ（シンプルな白色）
                            if (_captureTime != null)
                              Positioned(
                                bottom: 16,
                                right: 20,
                                child: Text(
                                  DateFormat(
                                    'yy/MM/dd\nHH:mm',
                                  ).format(_captureTime!),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black54,
                                        offset: Offset(1, 1),
                                        blurRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                    : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.camera_alt,
                            size: 80,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('写真を撮る'),
                            onPressed: _takePhoto,
                          ),
                        ],
                      ),
                    ),
          ),

          // ── タスク名入力と投稿ボタンエリア ──
          if (_image != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 写真の撮り直し or タスク名の入力ができます
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _takePhoto,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _taskCtrl,
                          decoration: const InputDecoration(
                            labelText: '今日のタスク（例：ランニング3km）',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child:
                        _isUploading
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton.icon(
                              icon: const Icon(Icons.send),
                              label: const Text(
                                '投稿する',
                                style: TextStyle(fontSize: 18),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                backgroundColor: AppColors.primary,
                              ),
                              onPressed: _uploadPost,
                            ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
