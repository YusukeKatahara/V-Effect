import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/post_service.dart';

/// 【rennさんへ】
/// ホーム画面です。
/// ・今日のストリーク（連続記録）をFirestoreから取得して表示します
/// ・「今日の記録」ボタンでカメラ画面に飛びます
/// ・「フレンドの投稿」ボタンでタイムライン画面に飛びます
class HomeScreen extends StatefulWidget {
  // ストリークを動的に表示するためStatefulにします
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PostService _postService = PostService();
  int _streak = 0;
  bool _postedToday = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData(); // 画面が開いた瞬間にデータを読み込みます
  }

  /// Firestoreからストリークと今日の投稿状況を読み込む処理
  Future<void> _loadData() async {
    try {
      final streak = await _postService.getStreak();
      final posted = await _postService.hasPostedToday();
      setState(() {
        _streak = streak;
        _postedToday = posted;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('V-Effect'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator()) // データ読み込み中はくるくる
          : RefreshIndicator(
              // 画面を下に引っ張ると更新できます
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'ようこそ, ${user?.email?.split('@').first ?? 'ゲスト'} さん',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 20),

                  // ── ストリークカード ──
                  Card(
                    elevation: 4,
                    color: _streak > 0
                        ? Colors.amber.shade800
                        : Colors.grey.shade700,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Text(
                            '現在のストリーク',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$_streak 日連続 🔥',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── 今日の投稿状況バッジ ──
                  Row(
                    children: [
                      Icon(
                        _postedToday
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: _postedToday ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(_postedToday ? '今日の投稿：完了 ✅' : '今日の投稿：まだです'),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // ── カメラ画面へのボタン ──
                  ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: Text(
                      _postedToday ? '今日の記録を見る / 撮り直す' : '今日のタスクを記録する 📸',
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 17),
                    ),
                    onPressed: () async {
                      // カメラ画面から戻ってきたらデータを更新します
                      await Navigator.pushNamed(context, '/camera');
                      _loadData();
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── フィード画面へのボタン ──
                  OutlinedButton.icon(
                    icon: const Icon(Icons.group),
                    label: Text(
                      _postedToday ? 'フレンドの投稿を見る 👥' : 'フレンドの投稿（投稿後に解放）',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 17),
                      // 未投稿なら少し暗くして「使えない感」を出します
                      foregroundColor: _postedToday ? null : Colors.grey,
                    ),
                    onPressed: () {
                      Navigator.pushNamed(context, '/feed');
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
