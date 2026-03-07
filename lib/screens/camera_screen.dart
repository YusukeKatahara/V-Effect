import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/post_service.dart';

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
  bool _isUploading = false;

  // ── タスク名を入力するためのコントローラー ──
  final _taskCtrl = TextEditingController();

  /// カメラで写真を撮影する処理
  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80, // 画質を80%に圧縮してデータ量を減らします
    );
    if (photo != null) {
      setState(() => _image = photo);
    }
  }

  /// Firebase に写真を投稿する処理
  Future<void> _uploadPost() async {
    if (_image == null) return;

    // タスク名が空なら汎用メッセージを使います
    final taskName = _taskCtrl.text.trim().isEmpty
        ? '今日のタスク'
        : _taskCtrl.text.trim();

    setState(() => _isUploading = true);
    try {
      // PostServiceの createPost を呼び出すだけでOKです！
      // 中でStorageへのアップロードとFirestoreへの保存の両方をやってくれます。
      await _postService.createPost(
        imageFile: File(_image!.path),
        taskName: taskName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('投稿が完了しました！ストリークが継続しました🔥')),
        );
        Navigator.pop(context); // ホーム画面に戻ります
      }
    } catch (e) {
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
            child: _image != null
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(_image!.path),
                        fit: BoxFit.cover,
                        width: double.infinity,
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
                          color: Colors.grey,
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
                    child: _isUploading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton.icon(
                            icon: const Icon(Icons.send),
                            label: const Text(
                              '投稿する',
                              style: TextStyle(fontSize: 18),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.amber.shade700,
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
