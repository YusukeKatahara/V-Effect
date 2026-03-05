import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 【rennさんへ】
/// ここはログイン後に表示されるホーム画面です。
/// 現時点での連続達成記録（ストリーク🔥）や、カメラ画面へのボタンを配置しています。
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 現在ログインしているユーザーの情報を取得します。
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ホーム'),
        actions: [
          // ログアウトボタンです。右上に配置されます。
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              // ログアウトが終わったらログイン画面に戻ります。
              if (context.mounted)
                Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ユーザー名を画面に表示します。メールアドレスがない場合は「ゲスト」と表示します。
            Text(
              'ようこそ, ${user?.email ?? 'ゲスト'} さん',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            // ストリーク（連続記録）を目立たせるためのカードです。
            Card(
              elevation: 4,
              color: Colors.amber.shade800,
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      '現在のストリーク🔥',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '3 日連続',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            // その日の努力を写真で証明するためのボタンです。
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('今日のタスクを記録する (写真)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                textStyle: const TextStyle(fontSize: 18),
              ),
              onPressed: () {
                // カメラ画面（CameraScreen）へ移動します。
                Navigator.pushNamed(context, '/camera');
              },
            ),
            const SizedBox(height: 16),
            // 友達の投稿を見るためのボタンです。
            OutlinedButton.icon(
              icon: const Icon(Icons.group),
              label: const Text('フレンドの進捗を見る'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                textStyle: const TextStyle(fontSize: 18),
              ),
              onPressed: () {
                // タイムライン画面（FeedScreen）へ移動します。
                Navigator.pushNamed(context, '/feed');
              },
            ),
          ],
        ),
      ),
    );
  }
}
