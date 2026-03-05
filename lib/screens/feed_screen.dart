import 'package:flutter/material.dart';

/// 【rennさんへ】
/// ここは友達の「努力（ポスト）」を見るためのフィード（タイムライン）画面です。
/// 自分が今日すでに投稿している場合のみ、友達の投稿をチェックできるという仕組みになります。
class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 画面の一番外側の枠組みです（Scaffold）
    return Scaffold(
      appBar: AppBar(title: const Text('フレンドの投稿 (24h)')),
      // Firebaseからデータをもらうまでは、とりあえず3つのダミー枠を作っておきます
      body: ListView.builder(
        itemCount: 3, // 仮で3件表示させます
        itemBuilder: (context, index) {
          // カード型のデザインで、一人ひとりの投稿をきれいに囲みます
          return Card(
            margin: const EdgeInsets.all(12),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, // 画面幅いっぱいに広げます
              children: [
                // 誰がいつ投稿したかを示す部分（ヘッダー）
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text('User ${index + 1}'),
                  subtitle: const Text('2時間前'), // 本当はFirestoreの時間データから計算します
                  trailing: const Icon(Icons.more_vert), // 「…」ボタン。今は何も起きません。
                ),
                // 投稿された写真を表示するエリア
                Container(
                  height: 300,
                  color: Colors.grey.shade800,
                  // TODO: 後でここに Firebase Storage の画像URL (NetworkImage) を入れます。
                  child: const Center(
                    child: Icon(Icons.image, size: 80, color: Colors.grey),
                  ),
                ),
                // 写真の下にあるテキストとリアクション（🔥）ボタン
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '今日の設定タスク：ランニング',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        // 炎のアイコンです。タップすると友達を応援できます。
                        icon: const Icon(
                          Icons.local_fire_department,
                          color: Colors.amber,
                        ),
                        onPressed: () {
                          // TODO: ここでFirestoreに「リアクションがついたよ！」というデータを送ります
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('リアクションを送りました！🔥')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
