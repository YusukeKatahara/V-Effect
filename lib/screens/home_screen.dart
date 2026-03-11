import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/routes.dart';
import '../services/notification_service.dart';
import '../services/post_service.dart';
import 'friend_feed_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PostService _postService           = PostService();
  final NotificationService _notificationService = NotificationService();

  int _streak = 0;
  bool _postedToday         = false;
  bool _loading             = true;
  String _username          = '';
  List<String> _tasks       = [];
  List<Map<String, dynamic>> _friendStatuses = [];
  late final Stream<int> _notificationStream;

  @override
  void initState() {
    super.initState();
    _notificationStream = _notificationService.getNotificationCount();
    _loadData();
    _notificationService.checkAndCreateTimeReminders();
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
        _streak         = results[0] as int;
        _postedToday    = results[1] as bool;
        _username       = results[2] as String;
        _tasks          = results[3] as List<String>;
        _friendStatuses = results[4] as List<Map<String, dynamic>>;
        _loading        = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openFriendFeed(int friendIndex) {
    final friend = _friendStatuses[friendIndex];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FriendFeedScreen(
          friendUid:         friend['uid'] as String,
          friendUsername:    friend['username'] as String,
          allFriends:        _friendStatuses,
          initialFriendIndex: friendIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary,
              backgroundColor: AppColors.bgSurface,
              child: CustomScrollView(
                slivers: [
                  // ── カスタム SliverAppBar ──────────────────
                  _buildSliverAppBar(),

                  // ── Stories Row ────────────────────────────
                  SliverToBoxAdapter(child: _buildStoriesRow()),

                  // ── Streak Card ────────────────────────────
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverToBoxAdapter(child: _buildStreakCard()),
                  ),

                  // ── Tasks Section ──────────────────────────
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverToBoxAdapter(child: _buildTaskSection()),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
    );
  }

  // ════════════════════════════════════════════
  // SliverAppBar
  // ════════════════════════════════════════════
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: AppColors.bgBase,
      surfaceTintColor: Colors.transparent,
      pinned: true,
      expandedHeight: 0,
      title: Row(
        children: [
          // ロゴ
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Icon(Icons.bolt_rounded, size: 18, color: Color(0xFF1A1000)),
          ),
          const SizedBox(width: 10),
          ShaderMask(
            shaderCallback: (bounds) =>
                AppColors.primaryGradient.createShader(bounds),
            child: const Text(
              'V-Effect',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
      actions: [
        StreamBuilder<int>(
          stream: _notificationStream,
          builder: (context, snapshot) {
            final count = snapshot.data ?? 0;
            return IconButton(
              icon: Badge(
                isLabelVisible: count > 0,
                label: Text('$count'),
                child: const Icon(Icons.notifications_outlined,
                    color: AppColors.textPrimary),
              ),
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.notifications),
            );
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ════════════════════════════════════════════
  // Stories Row
  // ════════════════════════════════════════════
  Widget _buildStoriesRow() {
    if (_friendStatuses.isEmpty) {
      return Container(
        height: 110,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_add_outlined, color: AppColors.textMuted, size: 28),
            const SizedBox(height: 6),
            Text('フレンドを追加しましょう',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ロックバナー
        if (!_postedToday)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8, left: 16, right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🔒', style: TextStyle(fontSize: 13)),
                SizedBox(width: 8),
                Text(
                  '投稿するとフレンドの写真が見られます',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),

        // アバターリスト
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            itemCount: _friendStatuses.length,
            itemBuilder: (context, index) {
              final friend           = _friendStatuses[index];
              final username         = friend['username'] as String;
              final friendPostedToday = friend['hasPostedToday'] as bool? ?? false;

              // リングカラー
              final Color ringColor;
              if (!_postedToday) {
                ringColor = AppColors.border;
              } else if (friendPostedToday) {
                ringColor = AppColors.primary;
              } else {
                ringColor = AppColors.border;
              }

              final canTap = _postedToday && friendPostedToday;

              return GestureDetector(
                onTap: canTap ? () => _openFriendFeed(index) : null,
                child: Opacity(
                  opacity: _postedToday ? 1.0 : 0.45,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    child: Column(
                      children: [
                        // アバター
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: friendPostedToday && _postedToday
                                ? AppColors.primaryGradient
                                : null,
                            color: friendPostedToday && _postedToday
                                ? null
                                : AppColors.bgElevated,
                            border: Border.all(color: ringColor, width: 2.5),
                            boxShadow: canTap
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.3),
                                      blurRadius: 10,
                                    ),
                                  ]
                                : [],
                          ),
                          child: CircleAvatar(
                            radius: 27,
                            backgroundColor: Colors.transparent,
                            child: Icon(
                              Icons.person_rounded,
                              size: 30,
                              color: friendPostedToday && _postedToday
                                  ? const Color(0xFF1A1000)
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 68,
                          child: Text(
                            username,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: canTap
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  // ════════════════════════════════════════════
  // Streak Card
  // ════════════════════════════════════════════
  Widget _buildStreakCard() {
    final hasStreak = _streak > 0;
    return Container(
      decoration: BoxDecoration(
        gradient: hasStreak
            ? AppColors.streakActiveGradient
            : AppColors.streakInactiveGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: hasStreak
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          // 炎アイコン
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.15),
            ),
            child: Icon(
              Icons.local_fire_department_rounded,
              size: 36,
              color: hasStreak ? Colors.white : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 16),

          // テキスト部
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _username.isNotEmpty ? _username : 'あなた',
                  style: TextStyle(
                    fontSize: 13,
                    color: hasStreak
                        ? Colors.white.withValues(alpha: 0.8)
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$_streak',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          color: hasStreak ? Colors.white : AppColors.textMuted,
                          height: 1,
                        ),
                      ),
                      TextSpan(
                        text: '  日連続',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: hasStreak
                              ? Colors.white.withValues(alpha: 0.85)
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ステータスバッジ
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _postedToday
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _postedToday
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 15,
                  color: _postedToday ? Colors.white : AppColors.textMuted,
                ),
                const SizedBox(width: 5),
                Text(
                  _postedToday ? '完了' : '未投稿',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _postedToday ? Colors.white : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════
  // Task Section
  // ════════════════════════════════════════════
  Widget _buildTaskSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '今日のタスク',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            if (_tasks.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _postedToday
                      ? AppColors.success.withValues(alpha: 0.15)
                      : AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _postedToday ? AppColors.success : AppColors.border,
                    width: 1,
                  ),
                ),
                child: Text(
                  _postedToday ? '完了 ✓' : '${_tasks.length}件',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _postedToday ? AppColors.success : AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),

        if (_tasks.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: AppColors.textMuted, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('タスクが設定されていません',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text('プロフィールからタスクを設定しましょう',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          ...List.generate(_tasks.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TaskTile(
                title: _tasks[index],
                isDone: _postedToday,
                index: index + 1,
              ),
            );
          }),
      ],
    );
  }
}

// ────────────────────────────────────────────
// 個別タスクタイル
// ────────────────────────────────────────────
class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.title,
    required this.isDone,
    required this.index,
  });

  final String title;
  final bool isDone;
  final int index;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDone
            ? AppColors.success.withValues(alpha: 0.06)
            : AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDone ? AppColors.success.withValues(alpha: 0.3) : AppColors.border,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // チェックアイコン
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Icon(
              isDone
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              key: ValueKey(isDone),
              color: isDone ? AppColors.success : AppColors.textMuted,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDone ? AppColors.textSecondary : AppColors.textPrimary,
                decoration:
                    isDone ? TextDecoration.lineThrough : TextDecoration.none,
                decorationColor: AppColors.textMuted,
              ),
            ),
          ),
          // インデックスバッジ
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone
                  ? AppColors.success.withValues(alpha: 0.15)
                  : AppColors.bgElevated,
            ),
            child: Center(
              child: Text(
                '$index',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDone ? AppColors.success : AppColors.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
