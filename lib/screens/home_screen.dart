import 'package:flutter/material.dart';
import '../services/post_service.dart';
import 'friend_feed_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PostService _postService = PostService();

  int _streak = 0;
  bool _postedToday = false;
  bool _loading = true;
  String _username = '';
  List<String> _tasks = [];
  List<Map<String, dynamic>> _friendStatuses = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _postService.getStreak(),
        _postService.hasPostedToday(),
        _postService.getMyUsername(),
        _postService.getMyTasks(),
        _postService.getFriendsList(),
      ]);
      if (!mounted) return;
      setState(() {
        _streak = results[0] as int;
        _postedToday = results[1] as bool;
        _username = results[2] as String;
        _tasks = results[3] as List<String>;
        _friendStatuses = results[4] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openFriendFeed(int friendIndex) {
    final friend = _friendStatuses[friendIndex];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FriendFeedScreen(
          friendUid: friend['uid'] as String,
          friendUsername: friend['username'] as String,
          allFriends: _friendStatuses,
          initialFriendIndex: friendIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('V-Effect'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                children: [
                  // ════════════════════════════════
                  // Stories row (Instagram-style)
                  // ════════════════════════════════
                  _buildStoriesRow(),
                  const Divider(height: 1),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ════════════════════════════════
                        // Streak card
                        // ════════════════════════════════
                        _buildStreakCard(),
                        const SizedBox(height: 24),

                        // ════════════════════════════════
                        // Today's tasks
                        // ════════════════════════════════
                        _buildTaskSection(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ──────────────────────────────────────────
  // Stories row
  // ──────────────────────────────────────────
  Widget _buildStoriesRow() {
    if (_friendStatuses.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: Text('フレンドを追加しましょう',
              style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: _friendStatuses.length,
        itemBuilder: (context, index) {
          final friend = _friendStatuses[index];
          final username = friend['username'] as String;

          return GestureDetector(
            onTap: _postedToday ? () => _openFriendFeed(index) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                children: [
                  // Avatar with ring
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _postedToday
                            ? Colors.amber
                            : Colors.grey.shade700,
                        width: 3,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: _postedToday
                          ? Colors.deepPurple.shade300
                          : Colors.grey.shade800,
                      child: Icon(
                        Icons.person,
                        size: 28,
                        color: _postedToday
                            ? Colors.white
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Username label
                  SizedBox(
                    width: 64,
                    child: Text(
                      username,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: _postedToday ? Colors.white : Colors.grey,
                      ),
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

  // ──────────────────────────────────────────
  // Streak card
  // ──────────────────────────────────────────
  Widget _buildStreakCard() {
    return Card(
      elevation: 4,
      color: _streak > 0 ? Colors.amber.shade800 : Colors.grey.shade700,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Row(
          children: [
            // Left: flame icon
            Icon(
              Icons.local_fire_department,
              size: 48,
              color: _streak > 0 ? Colors.white : Colors.grey.shade400,
            ),
            const SizedBox(width: 16),
            // Right: text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _username.isNotEmpty ? _username : 'あなた',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_streak 日連続',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            // Right side: status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _postedToday
                    ? Colors.green.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _postedToday
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 16,
                    color: _postedToday ? Colors.greenAccent : Colors.white54,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _postedToday ? '完了' : '未投稿',
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          _postedToday ? Colors.greenAccent : Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  // Task section
  // ──────────────────────────────────────────
  Widget _buildTaskSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '今日のタスク',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_tasks.isEmpty)
          Card(
            child: ListTile(
              leading:
                  const Icon(Icons.info_outline, color: Colors.grey),
              title: const Text('タスクが設定されていません'),
              subtitle: const Text('プロフィールからタスクを設定しましょう'),
            ),
          )
        else
          ...List.generate(_tasks.length, (index) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  _postedToday
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  color: _postedToday ? Colors.green : Colors.grey,
                  size: 28,
                ),
                title: Text(
                  _tasks[index],
                  style: TextStyle(
                    fontSize: 16,
                    decoration: _postedToday
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    color: _postedToday ? Colors.grey : Colors.white,
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}
