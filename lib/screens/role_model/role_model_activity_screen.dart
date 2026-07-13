import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../config/app_colors.dart';
import '../../models/app_user.dart';
import '../../models/post.dart';
import '../../providers/service_providers.dart';
import '../../widgets/swipe_back_gate.dart';

/// ロールモデルの活動詳細（達成率・過去投稿一覧）画面
class RoleModelActivityScreen extends ConsumerStatefulWidget {
  const RoleModelActivityScreen({super.key});

  @override
  ConsumerState<RoleModelActivityScreen> createState() => _RoleModelActivityScreenState();
}

class _RoleModelActivityScreenState extends ConsumerState<RoleModelActivityScreen> {
  String? _targetUid;
  bool _initialized = false;
  bool _loading = true;
  AppUser? _user;
  Map<DateTime, double> _weeklyRates = {};
  bool _isRoleModel = false;
  bool _isProcessing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String) {
        _targetUid = args;
        _initialized = true;
        _loadData();
      }
    }
  }

  Future<void> _loadData() async {
    if (_targetUid == null) return;
    setState(() => _loading = true);

    try {
      final user = await ref.read(friendServiceProvider).getUserByUid(_targetUid!);
      final weeklyRates = await ref.read(roleModelServiceProvider).getWeeklyCompletionRate(_targetUid!);
      final isRoleModel = await ref.read(roleModelServiceProvider).isRoleModel(_targetUid!);

      setState(() {
        _user = user;
        _weeklyRates = weeklyRates;
        _isRoleModel = isRoleModel;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading role model activity details: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleRoleModel() async {
    if (_user == null || _isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final service = ref.read(roleModelServiceProvider);
      if (_isRoleModel) {
        await service.removeRoleModel(_user!.uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${_user!.displayName ?? 'ユーザー'}さんをロールモデルから解除しました')),
          );
        }
      } else {
        await service.registerRoleModel(_user!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${_user!.displayName ?? 'ユーザー'}さんをロールモデルに登録しました')),
          );
        }
      }

      // 状態を反転
      setState(() {
        _isRoleModel = !_isRoleModel;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('処理に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  String _getDayLabel(DateTime date) {
    final today = DateTime.now();
    if (date.year == today.year && date.month == today.month && date.day == today.day) {
      return '今日';
    }
    const weekDays = ['日', '月', '火', '水', '木', '金', '土'];
    return weekDays[date.weekday % 7];
  }

  Stream<List<Post>> _getPastPostsStream() {
    if (_targetUid == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('posts')
        .where('userId', isEqualTo: _targetUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => Post.fromFirestore(doc)).toList());
  }

  @override
  Widget build(BuildContext context) {
    if (_targetUid == null) {
      return Scaffold(
        backgroundColor: AppColors.bgBase,
        body: Center(
          child: Text(
            'ユーザーIDが見つかりません',
            style: GoogleFonts.notoSansJp(color: AppColors.error),
          ),
        ),
      );
    }

    return SwipeBackGate(
      child: Scaffold(
        backgroundColor: AppColors.bgBase,
        appBar: AppBar(
          backgroundColor: AppColors.bgBase,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'ロールモデル詳細',
            style: GoogleFonts.notoSansJp(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : _user == null
                ? Center(
                    child: Text(
                      'ユーザー情報の取得に失敗しました',
                      style: GoogleFonts.notoSansJp(color: AppColors.textSecondary),
                    ),
                  )
                : StreamBuilder<List<Post>>(
                    stream: _getPastPostsStream(),
                    builder: (context, snapshot) {
                      final posts = snapshot.data ?? [];
                      final hasPosts = snapshot.hasData && posts.isNotEmpty;

                      return CustomScrollView(
                        slivers: [
                          // 1. プロフィールヘッダー & 登録ボタン
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              child: Column(
                                children: [
                                  _buildProfileHeader(_user!),
                                  const SizedBox(height: 16),
                                  _buildRoleModelButton(),
                                ],
                              ),
                            ),
                          ),

                          // 2. 週間タスク達成率セクション
                          SliverToBoxAdapter(
                            child: _buildWeeklyCompletionSection(),
                          ),

                          // 3. 過去の投稿履歴タイトル
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 12),
                              child: Text(
                                '過去の投稿履歴',
                                style: GoogleFonts.notoSansJp(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),

                          // 4. 過去の投稿履歴グリッド
                          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData)
                            const SliverToBoxAdapter(
                              child: Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32),
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                              ),
                            )
                          else if (!hasPosts)
                            SliverToBoxAdapter(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(48),
                                  child: Text(
                                    '投稿履歴はありません',
                                    style: GoogleFonts.notoSansJp(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              sliver: SliverGrid(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: 1.0,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    return _buildPostGridItem(context, posts[index]);
                                  },
                                  childCount: posts.length,
                                ),
                              ),
                            ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 40),
                          ),
                        ],
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildProfileHeader(AppUser user) {
    final photoUrl = user.photoUrl;
    return Row(
      children: [
        // アバター画像
        if (photoUrl == null || photoUrl.isEmpty)
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.bgElevated,
            child: Icon(Icons.person_rounded, color: AppColors.textSecondary, size: 40),
          )
        else
          ClipOval(
            child: CachedNetworkImage(
              imageUrl: photoUrl,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 72,
                height: 72,
                color: AppColors.bgElevated,
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.bgElevated,
                child: Icon(Icons.person_rounded, color: AppColors.textSecondary, size: 40),
              ),
            ),
          ),
        const SizedBox(width: 20),
        // 表示名とユーザーID
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.displayName ?? '名無しユーザー',
                style: GoogleFonts.notoSansJp(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '@${user.username ?? ''}',
                style: GoogleFonts.notoSansJp(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoleModelButton() {
    if (_isRoleModel) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: _isProcessing ? null : _toggleRoleModel,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: _isProcessing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  'ロールモデルから解除',
                  style: GoogleFonts.notoSansJp(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
        ),
      );
    } else {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isProcessing ? null : _toggleRoleModel,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentGold,
            foregroundColor: AppColors.pureBlack,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            elevation: 0,
          ),
          child: _isProcessing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              : Text(
                  'ロールモデルに登録',
                  style: GoogleFonts.notoSansJp(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
        ),
      );
    }
  }

  Widget _buildWeeklyCompletionSection() {
    if (_weeklyRates.isEmpty) return const SizedBox.shrink();

    final sortedDays = _weeklyRates.keys.toList()..sort();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '週間達成率',
            style: GoogleFonts.notoSansJp(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(sortedDays.length, (index) {
              final day = sortedDays[index];
              final rate = _weeklyRates[day] ?? 0.0;
              final isToday = _getDayLabel(day) == '今日';

              return Column(
                children: [
                  Text(
                    '${(rate * 100).toInt()}%',
                    style: GoogleFonts.notoSansJp(
                      color: rate > 0 ? AppColors.accentGold : AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 80,
                    width: 12,
                    decoration: BoxDecoration(
                      color: AppColors.bgElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.bottomCenter,
                      heightFactor: rate,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.accentGold,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getDayLabel(day),
                    style: GoogleFonts.notoSansJp(
                      color: isToday ? AppColors.accentGold : AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildPostGridItem(BuildContext context, Post post) {
    final imageUrl = post.thumbnailUrl ?? post.imageUrl;
    return GestureDetector(
      onTap: () => _showPostDetailDialog(context, post),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 1.0),
        ),
        clipBehavior: Clip.antiAlias,
        child: imageUrl != null && imageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: AppColors.bgElevated,
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => _buildPostFallback(post),
              )
            : _buildPostFallback(post),
      ),
    );
  }

  Widget _buildPostFallback(Post post) {
    return Container(
      padding: const EdgeInsets.all(8),
      alignment: Alignment.center,
      child: Text(
        post.taskName,
        style: GoogleFonts.notoSansJp(
          color: AppColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  void _showPostDetailDialog(BuildContext context, Post post) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(
                  height: 300,
                  child: CachedNetworkImage(
                    imageUrl: post.imageUrl!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.taskName,
                    style: GoogleFonts.notoSansJp(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (post.caption != null && post.caption!.isNotEmpty) ...[
                    Text(
                      post.caption!,
                      style: GoogleFonts.notoSansJp(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    '投稿日時: ${post.createdAt.year}/${post.createdAt.month}/${post.createdAt.day} ${post.createdAt.hour}:${post.createdAt.minute.toString().padLeft(2, '0')}',
                    style: GoogleFonts.notoSansJp(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                '閉じる',
                style: GoogleFonts.notoSansJp(
                  color: AppColors.accentGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
