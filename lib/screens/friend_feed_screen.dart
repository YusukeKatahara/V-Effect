import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/app_colors.dart';
import '../models/post.dart';
import '../services/analytics_service.dart';
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
  final PostService _postService = PostService.instance;

  late int _currentFriendIndex;
  List<Post> _posts = [];
  int _currentPostIndex = 0;
  bool _loading = true;
  Timer? _autoTimer;

  // ── フレンドアイコン行のスクロール制御 ──
  final ScrollController _iconScrollController = ScrollController();
  static const double _iconItemWidth = 52.0; // 44px avatar + 4px padding × 2
  static const double _iconListPadding = 8.0;

  // ── リアクションアニメーション制御用 ──
  final GlobalKey<_FloatingFlamesLayerState> _flamesKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _currentFriendIndex = widget.initialFriendIndex;
    _loadPosts();
    AnalyticsService.instance.logFriendFeedViewed();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _iconScrollController.dispose();
    super.dispose();
  }

  /// アクティブなフレンドアイコンが中央に来るようスクロールする
  void _scrollToCurrentFriend() {
    if (!_iconScrollController.hasClients) return;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final targetOffset = _iconListPadding
        + _currentFriendIndex * _iconItemWidth
        + _iconItemWidth / 2
        - screenWidth / 2;
    _iconScrollController.animateTo(
      targetOffset.clamp(0.0, _iconScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _loadPosts() async {
    _autoTimer?.cancel();
    setState(() {
      _loading = true;
      _currentPostIndex = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentFriend());

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
      debugPrint('LoadPosts error: $e');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('投稿の読み込みに失敗しました: $e')),
        );
      }
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
    _scrollToCurrentFriend();
    _loadPosts();
  }

  Future<void> _sendReaction() async {
    if (_posts.isEmpty) return;
    
    // ドーパミン誘発：軽いバイブレーションと炎アニメーション
    HapticFeedback.lightImpact();
    _flamesKey.currentState?.addFlame();

    final post = _posts[_currentPostIndex];
    // Optimistic UI update (immediately increase count locally)
    setState(() {
      _posts = List.from(_posts)..[_currentPostIndex] = Post(
        id: post.id,
        userId: post.userId,
        imageUrl: post.imageUrl,
        taskName: post.taskName,
        caption: post.caption,
        createdAt: post.createdAt,
        expiresAt: post.expiresAt,
        reactionCount: post.reactionCount + 1,
      );
    });

    await _postService.addReaction(post.id);
  }


  @override
  Widget build(BuildContext context) {
    final currentFriend = widget.allFriends[_currentFriendIndex];
    final currentUsername = currentFriend['username'] as String;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            // ── Progress bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: List.generate(
                    _posts.isEmpty ? 3 : _posts.length, (i) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      height: 3,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: _loading
                            ? AppColors.textPrimary.withValues(alpha: 0.1)
                            : (i <= _currentPostIndex
                                ? AppColors.textPrimary
                                : AppColors.textPrimary.withValues(alpha: 0.24)),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // ── Friend icon list (常に表示) ──
            _buildFriendIconRow(),

            // ── Main content ──
            Expanded(
              child: _loading
                  ? _buildPhotoSkeleton()
                  : _posts.isEmpty
                      ? _buildEmpty(currentUsername)
                      : _buildStoryView(currentUsername),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSkeleton() {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildEmpty(String username) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.sentiment_dissatisfied_rounded,
            size: 64,
            color: AppColors.textPrimary.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 24),
          Text(
            '$username さんの投稿が\nまだありません',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _goHome,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.bgElevated,
              foregroundColor: AppColors.textPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
                side: const BorderSide(color: AppColors.border),
              ),
              elevation: 0,
            ),
            child: const Text('戻る'),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryView(String username) {
    final post = _posts[_currentPostIndex];

    return Stack(
      fit: StackFit.expand,
      children: [
        // Photo (RepaintBoundaryで囲んで無駄な再描画を抑制)
        RepaintBoundary(
          child: post.imageUrl != null
              ? CachedNetworkImage(
                  imageUrl: post.imageUrl!,
                  fit: BoxFit.cover,
                  memCacheWidth: 1080, // メモリ上のデコードサイズを制限
                  placeholder: (ctx, url) => _buildPhotoSkeleton(),
                  errorWidget: (ctx, url, error) => const Center(
                    child: Icon(Icons.broken_image,
                        size: 60, color: AppColors.textMuted),
                  ),
                )
              : const Center(
                  child: Icon(Icons.image,
                      size: 80, color: AppColors.textMuted),
                ),
        ),

        // タイムスタンプ装飾（シンプルな白色）
        if (post.showTimestamp)
          Positioned(
            bottom: 120, // 下のヒーロータスク名やリアクションボタンに被らないよう上に配置
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
                colors: [
                  AppColors.bgBase.withValues(alpha: 0.87),
                  Colors.transparent
                ],
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Task name + remaining time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (post.caption != null &&
                          post.caption!.isNotEmpty) ...[
                        Text(
                          post.caption!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        post.taskName,
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
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.textPrimary
                                .withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.local_fire_department,
                            color: AppColors.primary,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      '${post.reactionCount}',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary.withValues(alpha: 0.7)),
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
            icon: const Icon(Icons.close,
                color: AppColors.textPrimary, size: 28),
            onPressed: _goHome,
          ),
        ),

        // ── Floating Flames Layer (setStateの影響をここだけに留める) ──
        _FloatingFlamesLayer(key: _flamesKey),
      ],
    );
  }

  // ── Friend icon row at the top ──
  Widget _buildFriendIconRow() {
    return SizedBox(
      height: 72,
      child: ListView.builder(
        controller: _iconScrollController,
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
                      backgroundImage: friend['photoUrl'] != null
                          ? ResizeImage(CachedNetworkImageProvider(friend['photoUrl'] as String), width: 120, height: 120)
                          : null,
                      child: friend['photoUrl'] == null
                          ? Icon(
                              Icons.person,
                              size: 20,
                              color: isActive ? AppColors.textPrimary : AppColors.textMuted,
                            )
                          : null,
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

/// ── リアクションの火の粉を管理する専用レイヤー ──
class _FloatingFlamesLayer extends StatefulWidget {
  const _FloatingFlamesLayer({super.key});

  @override
  State<_FloatingFlamesLayer> createState() => _FloatingFlamesLayerState();
}

class _FloatingFlamesLayerState extends State<_FloatingFlamesLayer> {
  int _counter = 0;
  final Map<int, Widget> _flames = {};

  void addFlame() {
    final id = _counter++;
    final randomX = (Random().nextDouble() - 0.5) * 40;

    setState(() {
      _flames[id] = Positioned(
        key: ValueKey(id),
        bottom: 80,
        right: 20 + randomX,
        child: _FloatingFlameWidget(
          key: ValueKey('flame_$id'),
          onComplete: () {
            if (mounted) {
              setState(() => _flames.remove(id));
            }
          },
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: _flames.values.toList(),
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

    _dy = Tween<double>(begin: 0, end: -250).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.5, 1.0)),
    );
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
      child: Icon(
        Icons.whatshot,
        color: AppColors.primary,
        size: 40,
        shadows: [Shadow(color: AppColors.white.withValues(alpha: 0.5), blurRadius: 12)],
      ),
    );
  }
}

