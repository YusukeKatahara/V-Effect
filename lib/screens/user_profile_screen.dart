import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../config/app_colors.dart';
import '../models/app_user.dart';
import '../services/friend_service.dart';

/// 他ユーザーのプロフィール閲覧画面
///
/// 引数（ModalRoute.settings.arguments）: String uid
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final FriendService _friendService = FriendService.instance;
  final String _myUid = FirebaseAuth.instance.currentUser!.uid;

  String? _targetUid;
  String? _initialUsername;
  String? _initialPhotoUrl;

  AppUser? _user;
  bool _loading = true;
  bool _isFollowing = false;
  bool _isMyFollower = false;
  bool _isPending = false;
  bool _isProcessing = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && !_initialized) {
      _initialized = true;
      if (args is String) {
        _targetUid = args;
      } else if (args is Map) {
        _targetUid = args['uid'] as String?;
        _initialUsername = args['username'] as String?;
        _initialPhotoUrl = args['photoUrl'] as String?;
      }
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    // データがある場合はフルスクリーンローディングを出さない
    if (_user == null) {
      setState(() => _loading = true);
    }

    try {
      final results = await Future.wait([
        _friendService.getUserByUid(_targetUid!),
        _friendService.isFollowing(_targetUid!),
      ]);

      // friend_requests コレクションへのアクセスが失敗しても他の処理を妨げない
      bool isPending = false;
      try {
        isPending = await _friendService.hasPendingRequest(_targetUid!);
      } catch (_) {}

      if (!mounted) return;
      final loadedUser = results[0] as AppUser?;
      setState(() {
        _user = loadedUser;
        _isFollowing = results[1] as bool;
        // _user.following にyusukeのUIDが含まれる = renがyusukeをフォローしている = renはyusukeのフォロワー
        _isMyFollower = loadedUser?.following.contains(_myUid) ?? false;
        _isPending = isPending;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (_targetUid == null) return;

    // Optimistic UI Update: サーバーの応答を待たずにUIを切り替える
    final oldFollowing = _isFollowing;
    final oldPending = _isPending;

    setState(() {
      _isProcessing = true;
      if (_isFollowing) {
        _isFollowing = false;
      } else if (_isPending) {
        _isPending = false;
      } else {
        _isPending = true; // とりあえず申請中にする
      }
    });

    try {
      if (oldFollowing) {
        await _friendService.unfollowUser(_targetUid!);
      } else if (oldPending) {
        await _friendService.cancelRequest(_targetUid!);
      } else {
        await _friendService.sendRequest(_targetUid!);
      }
      // 最新の状態を再取得
      await _loadProfile();
    } catch (e) {
      // 失敗した場合は元に戻す
      if (mounted) {
        setState(() {
          _isFollowing = oldFollowing;
          _isPending = oldPending;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _openFollowList({required bool isFollowing}) {
    if (_user == null) return;
    Navigator.pushNamed(
      context,
      '/follow-list',
      arguments: {
        'uid': _targetUid,
        'isFollowing': isFollowing,
        'title': isFollowing ? 'フォロー中' : 'フォロワー',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _user?.username ?? _initialUsername ?? '';

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: AppColors.bgBase,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        title: Text(
          title,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
      ),
      body: _user == null && _loading
          ? _buildSkeleton()
          : _user == null && !_loading
              ? const Center(
                  child: Text(
                    'ユーザーが見つかりません',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadProfile,
                  color: AppColors.primary,
                  backgroundColor: AppColors.bgSurface,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildStats(),
                      if (_targetUid != _myUid) ...[
                        const SizedBox(height: 24),
                        _buildFollowButton(),
                      ],
                      if (_user!.tasks.isNotEmpty) ...[
                        const SizedBox(height: 32),
                        _buildTasksSection(),
                      ],
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // アバターのプレースホルダ（渡されている場合は画像を表示）
              _initialPhotoUrl != null
                  ? CircleAvatar(
                      radius: 40,
                      backgroundImage: ResizeImage(
                        CachedNetworkImageProvider(_initialPhotoUrl!),
                        width: 240,
                        height: 240,
                      ),
                    )
                  : Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.grey10,
                      ),
                    ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _initialUsername != null
                      ? Text(
                          _initialUsername!,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        )
                      : Container(
                          width: 120,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.grey10,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                  const SizedBox(height: 8),
                  Container(
                    width: 80,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.grey10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              3,
              (i) => Column(
                children: [
                  Container(
                    width: 40,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.grey10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 60,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.grey10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final photoUrl = _user?.photoUrl ?? _initialPhotoUrl;
    final username = _user?.username ?? _initialUsername ?? '';

    return Row(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: photoUrl == null ? AppColors.primaryGradient : null,
          ),
          child: photoUrl != null
              ? CircleAvatar(
                  radius: 40,
                  backgroundImage: ResizeImage(
                    CachedNetworkImageProvider(photoUrl),
                    width: 240,
                    height: 240,
                  ),
                )
              : const CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.transparent,
                  child: Icon(
                    Icons.person_rounded,
                    size: 40,
                    color: AppColors.black,
                  ),
                ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                username,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _user != null ? '@${_user!.userId}' : '...',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStats() {
    // フォロー/フォロワーリストは自分自身・自分のフォロワーのみ閲覧可能
    final canViewList = _targetUid == _myUid || _isMyFollower;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem(
          'フォロー',
          _user!.following.length,
          onTap: canViewList ? () => _openFollowList(isFollowing: true) : null,
        ),
        _buildStatItem(
          'フォロワー',
          _user!.followers.length,
          onTap: canViewList ? () => _openFollowList(isFollowing: false) : null,
        ),
        _buildStatItem(
          'ストリーク',
          _user!.streak,
          icon: Icons.local_fire_department_rounded,
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, int count, {IconData? icon, VoidCallback? onTap}) {
    final content = Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: const Color(0xFFD4AF37)),
              const SizedBox(width: 4),
            ],
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        if (onTap != null)
          const SizedBox(height: 2),
        if (onTap != null)
          Container(
            width: 24,
            height: 1,
            color: AppColors.grey20,
          ),
      ],
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: content,
        ),
      );
    }
    return content;
  }

  Widget _buildFollowButton() {
    final String label;
    final Color bgColor;
    final Color fgColor;
    final BorderSide border;

    if (_isFollowing) {
      label = 'フォロー中';
      bgColor = AppColors.bgSurface;
      fgColor = AppColors.textPrimary;
      border = const BorderSide(color: AppColors.border);
    } else if (_isPending) {
      label = '申請中';
      bgColor = AppColors.bgSurface;
      fgColor = AppColors.textSecondary;
      border = const BorderSide(color: AppColors.border);
    } else {
      label = 'フォローをリクエスト';
      bgColor = AppColors.white;
      fgColor = AppColors.black;
      border = BorderSide.none;
    }

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _toggleFollow,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: border,
          ),
        ),
        child: _isProcessing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildTasksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'ヒーロータスク',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: List.generate(_user!.tasks.length, (i) {
              final isLast = i == _user!.tasks.length - 1;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.grey10,
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _user!.tasks[i],
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast) const Divider(height: 1, indent: 52),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}
