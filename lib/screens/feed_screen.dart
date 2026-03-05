import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/post_service.dart';

/// 【rennさんへ】
/// タイムライン（フィード）画面です。
/// ポイントは2つです：
/// 1. 「自分が今日投稿していないと見れない」というBeRealのルールをチェックします
/// 2. Firestoreのデータをリアルタイムで受け取って（Stream）、動的に表示します
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final PostService _postService = PostService();
  bool _loading = true;
  bool _canView = false; // 自分が今日投稿済みかどうか

  @override
  void initState() {
    super.initState();
    _checkAccess(); // 画面を開いた瞬間に「見れるかどうか」をチェックします
  }

  /// 今日投稿しているかどうかを確認する処理
  Future<void> _checkAccess() async {
    final posted = await _postService.hasPostedToday();
    setState(() {
      _canView = posted;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('フレンドの投稿 (24h)')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _canView
          ? _buildFeed() // 投稿済み → フィードを表示
          : _buildGate(), // 未投稿 → 「先に投稿してね」の壁を表示
    );
  }

  /// 未投稿の場合に表示する「ゲート」画面
  Widget _buildGate() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 80, color: Colors.grey),
            const SizedBox(height: 24),
            const Text(
              '今日まだ投稿していません！\n先に自分のタスクを記録してから\nフレンドの投稿を見ましょう 💪',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('今日のタスクを記録する'),
              onPressed: () async {
                await Navigator.pushNamed(context, '/camera');
                _checkAccess(); // カメラから戻ったら再チェック
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 投稿済みの場合に表示するリアルタイムフィード
  Widget _buildFeed() {
    return StreamBuilder<QuerySnapshot>(
      // getFriendsFeedはFirestoreから「フレンドの24時間以内の投稿」を取ってくるStreamです
      stream: _postService.getFriendsFeed(),
      builder: (context, snapshot) {
        // ── データ読み込み中 ──
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        // ── エラーが起きた場合 ──
        if (snapshot.hasError) {
          return Center(child: Text('データの取得に失敗しました: ${snapshot.error}'));
        }
        // ── フレンドがいないか投稿がない場合 ──
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'フレンドの投稿はまだありません\n一緒に頑張ろう！',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          );
        }

        final posts = snapshot.data!.docs;

        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) {
            // Firestoreの1件のドキュメント（投稿データ）を取り出します
            final post = posts[index].data() as Map<String, dynamic>;
            final postId = posts[index].id;

            // 期限までの残り時間を計算します
            final expiresAt = (post['expiresAt'] as Timestamp).toDate();
            final remaining = expiresAt.difference(DateTime.now());
            final remainingText = remaining.inHours > 0
                ? 'あと${remaining.inHours}時間'
                : 'あと${remaining.inMinutes}分';

            return Card(
              margin: const EdgeInsets.all(12),
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── ヘッダー：投稿者と残り時間 ──
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(post['userId'] ?? '誰か'), // TODO: ユーザー名に変更する
                    subtitle: Text('🕐 $remainingText で消えます'),
                  ),
                  // ── 写真 ──
                  // 【rennさんへ】Image.networkはURLから画像をダウンロードして表示します
                  SizedBox(
                    height: 300,
                    child: post['imageUrl'] != null
                        ? Image.network(
                            post['imageUrl'],
                            fit: BoxFit.cover,
                            // 読み込み中の表示を設定します
                            loadingBuilder: (ctx, child, progress) =>
                                progress == null
                                ? child
                                : const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                            errorBuilder: (ctx, e, st) => const Center(
                              child: Icon(Icons.broken_image, size: 60),
                            ),
                          )
                        : const Center(
                            child: Icon(
                              Icons.image,
                              size: 80,
                              color: Colors.grey,
                            ),
                          ),
                  ),
                  // ── フッター：タスク名とリアクション🔥 ──
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '📌 ${post['taskName'] ?? '今日のタスク'}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '${post['reactionCount'] ?? 0}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.local_fire_department,
                                color: Colors.amber,
                                size: 28,
                              ),
                              onPressed: () async {
                                // 🔥ボタンを押したらFirestoreのカウントを増やします
                                await _postService.addReaction(postId);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
