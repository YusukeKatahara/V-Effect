import 'dart:async';
import 'package:flutter/material.dart';
import '../models/post.dart';
import '../services/post_service.dart';

/// Stories風のフルスクリーン投稿ビューアー
///
/// - 上部: フレンドアイコンリスト（現在のフレンドをハイライト）
/// - 中央: 投稿写真（フルスクリーン）
/// - 右下: リアクションボタン
/// - 画面右半分タップ → 次の投稿、左半分 → 前の投稿
/// - 5秒で自動的に次の投稿へ
/// - 最後の投稿の次 → ホーム画面に戻る
class FriendFeedScreen extends StatefulWidget {
  final String friendUid;
  final String friendUsername;
  final List<Map<String, dynamic>> allFriends;
  final int initialFriendIndex;

  const FriendFeedScreen({
    super.key,
    required this.friendUid,
    required this.friendUsername,
    required this.allFriends,
    required this.initialFriendIndex,
  });

  @override
  State<FriendFeedScreen> createState() => _FriendFeedScreenState();
}

class _FriendFeedScreenState extends State<FriendFeedScreen> {
  final PostService _postService = PostService();

  late int _currentFriendIndex;
  List<Post> _posts = [];
  int _currentPostIndex = 0;
  bool _loading = true;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _currentFriendIndex = widget.initialFriendIndex;
    _loadPosts();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    _autoTimer?.cancel();
    setState(() {
      _loading = true;
      _currentPostIndex = 0;
    });

    try {
      final friend = widget.allFriends[_currentFriendIndex];
      final posts = await _postService.getFriendPostsList(
        friend['uid'] as String,
      );
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
      });
      _startAutoTimer();
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startAutoTimer() {
    _autoTimer?.cancel();
    _autoTimer = Timer(const Duration(seconds: 5), _goNext);
  }

  void _resetAutoTimer() {
    _startAutoTimer();
  }

  void _goNext() {
    if (_currentPostIndex < _posts.length - 1) {
      // Next post of same friend
      setState(() => _currentPostIndex++);
      _resetAutoTimer();
    } else {
      // Move to next friend or go home
      if (_currentFriendIndex < widget.allFriends.length - 1) {
        setState(() => _currentFriendIndex++);
        _loadPosts();
      } else {
        _goHome();
      }
    }
  }

  void _goPrev() {
    if (_currentPostIndex > 0) {
      setState(() => _currentPostIndex--);
      _resetAutoTimer();
    } else if (_currentFriendIndex > 0) {
      // Move to previous friend's last post
      setState(() => _currentFriendIndex--);
      _loadPostsAtLast();
    }
    // If first post of first friend, do nothing
  }

  Future<void> _loadPostsAtLast() async {
    _autoTimer?.cancel();
    setState(() => _loading = true);

    try {
      final friend = widget.allFriends[_currentFriendIndex];
      final posts = await _postService.getFriendPostsList(
        friend['uid'] as String,
      );
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _currentPostIndex = posts.isNotEmpty ? posts.length - 1 : 0;
        _loading = false;
      });
      _startAutoTimer();
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goHome() {
    _autoTimer?.cancel();
    Navigator.pop(context);
  }

  void _selectFriend(int index) {
    if (index == _currentFriendIndex) return;
    setState(() => _currentFriendIndex = index);
    _loadPosts();
  }

  Future<void> _sendReaction() async {
    if (_posts.isEmpty) return;
    final post = _posts[_currentPostIndex];
    await _postService.addReaction(post.id);
    // Reload to update reaction count
    final friend = widget.allFriends[_currentFriendIndex];
    final posts = await _postService.getFriendPostsList(
      friend['uid'] as String,
    );
    if (mounted) {
      setState(() => _posts = posts);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentFriend = widget.allFriends[_currentFriendIndex];
    final currentUsername = currentFriend['username'] as String;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _posts.isEmpty
                ? _buildEmpty(currentUsername)
                : _buildStoryView(currentUsername),
      ),
    );
  }

  Widget _buildEmpty(String username) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.photo_library_outlined,
              size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            '$username の投稿はありません',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: _goHome,
            child: const Text('ホームに戻る'),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryView(String username) {
    final post = _posts[_currentPostIndex];

    return Column(
      children: [
        // ── Progress bar ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: List.generate(_posts.length, (i) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: i <= _currentPostIndex
                        ? Colors.white
                        : Colors.white24,
                  ),
                ),
              );
            }),
          ),
        ),

        // ── Friend icon list ──
        _buildFriendIconRow(),

        // ── Main content (photo + tap zones) ──
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Photo
              post.imageUrl != null
                  ? Image.network(
                      post.imageUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (ctx, child, progress) =>
                          progress == null
                              ? child
                              : const Center(
                                  child: CircularProgressIndicator()),
                      errorBuilder: (ctx, e, st) => const Center(
                        child:
                            Icon(Icons.broken_image, size: 60, color: Colors.grey),
                      ),
                    )
                  : const Center(
                      child: Icon(Icons.image, size: 80, color: Colors.grey),
                    ),

              // Tap zones (left half = prev, right half = next)
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _goPrev,
                      behavior: HitTestBehavior.translucent,
                      child: const SizedBox.expand(),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: _goNext,
                      behavior: HitTestBehavior.translucent,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),

              // Bottom overlay: task name + reaction button
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      // Task name + remaining time
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              post.taskName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              post.remainingText,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Reaction button (bottom right)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: _sendReaction,
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.local_fire_department,
                                color: Colors.amber,
                                size: 32,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${post.reactionCount}',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Close button (top right)
              Positioned(
                top: 4,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: _goHome,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Friend icon row at the top ──
  Widget _buildFriendIconRow() {
    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        itemCount: widget.allFriends.length,
        itemBuilder: (context, index) {
          final friend = widget.allFriends[index];
          final username = friend['username'] as String;
          final isActive = index == _currentFriendIndex;

          return GestureDetector(
            onTap: () => _selectFriend(index),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isActive ? Colors.amber : Colors.grey.shade700,
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 19,
                      backgroundColor: isActive
                          ? Colors.deepPurple.shade300
                          : Colors.grey.shade800,
                      child: Icon(
                        Icons.person,
                        size: 20,
                        color: isActive ? Colors.white : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    width: 48,
                    child: Text(
                      username,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            isActive ? FontWeight.bold : FontWeight.normal,
                        color: isActive ? Colors.white : Colors.grey,
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
}
