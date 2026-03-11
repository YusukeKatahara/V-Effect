import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../config/app_colors.dart';
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

  // ── リアクションアニメーション用 ──
  int _flameCounter = 0;
  final Map<int, Widget> _activeFlames = {};

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
    
    // ドーパミン誘発：軽いバイブレーションと炎アニメーション
    HapticFeedback.lightImpact();
    _showFloatingFlame();

    final post = _posts[_currentPostIndex];
    // Optimistic UI update (immediately increase count locally)
    setState(() {
      _posts = List.from(_posts)..[_currentPostIndex] = Post(
        id: post.id,
        userId: post.userId,
        imageUrl: post.imageUrl,
        taskName: post.taskName,
        createdAt: post.createdAt,
        expiresAt: post.expiresAt,
        reactionCount: post.reactionCount + 1,
      );
    });

    await _postService.addReaction(post.id);
  }

  void _showFloatingFlame() {
    final id = _flameCounter++;
    final randomX = (Random().nextDouble() - 0.5) * 40; // 左右に少しバラけさせる
    
    setState(() {
      _activeFlames[id] = Positioned(
        bottom: 80,
        right: 20 + randomX, // ボタンの少し上あたり
        child: _FloatingFlameWidget(
          key: ValueKey(id),
          onComplete: () {
            if (mounted) {
              setState(() => _activeFlames.remove(id));
            }
          },
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentFriend = widget.allFriends[_currentFriendIndex];
    final currentUsername = currentFriend['username'] as String;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
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
              size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(
            '$username の投稿はありません',
            style: const TextStyle(fontSize: 16, color: AppColors.textMuted),
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
                        ? AppColors.textPrimary
                        : AppColors.textPrimary.withValues(alpha: 0.24),
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
              // Photo (フィルターなし)
              Stack(
                fit: StackFit.expand,
                children: [
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
                            child: Icon(Icons.broken_image,
                                size: 60, color: AppColors.textMuted),
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.image, size: 80, color: AppColors.textMuted),
                        ),
                ],
              ),

              // タイムスタンプ装飾（シンプルな白色）
              Positioned(
                bottom: 120, // 下のタスク名やリアクションボタンに被らないよう上に配置
                right: 20,
                child: Text(
                  DateFormat('yy/MM/dd\nHH:mm').format(post.createdAt),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: AppColors.bgBase.withValues(alpha: 0.54),
                        offset: const Offset(1, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
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
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [AppColors.bgBase.withValues(alpha: 0.87), Colors.transparent],
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
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              post.remainingText,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textPrimary.withValues(alpha: 0.6),
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
                                color: AppColors.textPrimary.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.local_fire_department,
                                color: AppColors.primary,
                                size: 32,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${post.reactionCount}',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textPrimary.withValues(alpha: 0.7)),
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
                  icon: const Icon(Icons.close, color: AppColors.textPrimary, size: 28),
                  onPressed: _goHome,
                ),
              ),

              // ── Floating Flames Layer ──
              ..._activeFlames.values,
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
                        color: isActive ? AppColors.primary : AppColors.border,
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 19,
                      backgroundColor: isActive
                          ? AppColors.primary
                          : AppColors.bgElevated,
                      child: Icon(
                        Icons.person,
                        size: 20,
                        color: isActive ? AppColors.textPrimary : AppColors.textMuted,
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
                        color: isActive ? AppColors.textPrimary : AppColors.textMuted,
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

/// ── 連打で飛んでいく🔥アニメーションヴィジェット ──
class _FloatingFlameWidget extends StatefulWidget {
  final VoidCallback onComplete;

  const _FloatingFlameWidget({super.key, required this.onComplete});

  @override
  State<_FloatingFlameWidget> createState() => _FloatingFlameWidgetState();
}

class _FloatingFlameWidgetState extends State<_FloatingFlameWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _dy;
  late Animation<double> _opacity;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // 上に昇っていく
    _dy = Tween<double>(begin: 0, end: -250).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    // 途中から消えていく
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.5, 1.0)),
    );
    // 最初だけ少し大きくなる
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 1.5), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.5, end: 1.0), weight: 80),
    ]).animate(_ctrl);

    _ctrl.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _dy.value),
          child: Transform.scale(
            scale: _scale.value,
            child: Opacity(
              opacity: _opacity.value,
              child: child,
            ),
          ),
        );
      },
      child: const Icon(
        Icons.whatshot,
        color: AppColors.primary,
        size: 40,
        shadows: [Shadow(color: Colors.redAccent, blurRadius: 12)],
      ),
    );
  }
}

