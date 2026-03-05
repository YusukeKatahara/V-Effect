import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// 【rennさんへ】
/// ここは「写真を選んで投稿する」ための画面です。
/// パソコンのエミュレーターでも動かしやすいように、ImagePickerという便利なツールを使っています。
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  // 写真を撮影したり選んだりするための専用ツールです。
  final ImagePicker _picker = ImagePicker();

  // 撮影した写真を一時的に保存しておく変数です。
  // まだ撮影していない時は空っぽ（null）なので「XFile?」と「?」がついています。
  XFile? _image;

  // 画像をサーバー（Firebase Storage）に送信中かどうかを判定します。
  bool _isUploading = false;

  /// カメラを起動して写真を撮る処理です
  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    // 写真がちゃんと撮れたら、画面を更新して写真を表示させます。
    if (photo != null) {
      setState(() {
        _image = photo;
      });
    }
  }

  /// 写真をFirebaseへアップロードする処理です
  Future<void> _uploadPost() async {
    // もし写真がない状態なら、何もせず終了します。
    if (_image == null) return;

    // アップロード開始！画面をローディング状態（くるくる）にします。
    setState(() => _isUploading = true);
    try {
      // TODO: yusukeさんへ、ここで Firebase Storage のアップロード処理と
      // Firestore の posts コレクションへのデータ追加を実装します。
      // 現在は仮で2秒待つ処理を入れています。
      await Future.delayed(const Duration(seconds: 2));

      // 無事に終わったらメッセージを出して、ひとつ前の画面（ホーム）に戻ります。
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('投稿が完了しました！ストリークが継続しました🔥')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      // エラーが起きたら赤い文字などで教えてあげましょう。
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('エラーが発生しました: $e')));
    } finally {
      // 必ずローディングを終わらせます。
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('タスクの証明')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // もし写真があったら、画面の真ん中に大きく表示します。
            if (_image != null)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(_image!.path), fit: BoxFit.cover),
                  ),
                ),
              )
            // もし写真がなければ「撮影してね」というメッセージを出します。
            else
              const Expanded(
                child: Center(
                  child: Text(
                    'まだ写真がありません\n下のカメラアイコンを押して撮影してください',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            // 画面の下半分のボタンたちの設定です。
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: _isUploading
                  ? const CircularProgressIndicator() // アップロード中ならくるくる
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        FloatingActionButton(
                          heroTag: 'cam', // 複数のボタンがある時にエラーが出ないためのおまじないです。
                          onPressed: _takePhoto,
                          child: const Icon(Icons.camera_alt),
                        ),
                        // 写真が撮り終わった後だけ「投稿する」ボタンを出します。
                        if (_image != null)
                          FloatingActionButton.extended(
                            heroTag: 'upload',
                            onPressed: _uploadPost,
                            icon: const Icon(Icons.send),
                            label: const Text('投稿する'),
                            backgroundColor: Colors.amber.shade700,
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
