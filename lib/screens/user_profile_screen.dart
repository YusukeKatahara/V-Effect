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
  AppUser? _user;
  bool _loading = true;
  bool _isFollowing = false;
  bool _isProcessing = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = ModalRoute.of(context)?.settings.arguments as String?;
    if (uid != null && !_initialized) {
      _initialized = true;
      _targetUid = uid;
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _friendService.getUserByUid(_targetUid!),
        _friendService.isFollowing(_targetUid!),
      ]);
      if (!mounted) return;
      setState(() {
        _user = results[0] as AppUser?;
        _isFollowing = results[1] as bool;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (_targetUid == null) return;
    setState(() => _isProcessing = true);
    try {
      if (_isFollowing) {
        await _friendService.unfollowUser(_targetUid!);
      } else {
        await _friendService.followUser(_targetUid!);
      }
      await _loadProfile();
    } catch (e) {
      if (mounted) {
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
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: AppColors.bgBase,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        title: Text(
          _user?.username ?? '',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _user == null
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

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: _user!.photoUrl == null ? AppColors.primaryGradient : null,
          ),
          child: _user!.photoUrl != null
              ? CircleAvatar(
                  radius: 40,
                  backgroundImage: ResizeImage(
                    CachedNetworkImageProvider(_user!.photoUrl!),
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
                _user!.username ?? '',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '@${_user!.userId ?? ''}',
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem(
          'フォロー',
          _user!.following.length,
          onTap: () => _openFollowList(isFollowing: true),
        ),
        _buildStatItem(
          'フォロワー',
          _user!.followers.length,
          onTap: () => _openFollowList(isFollowing: false),
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
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _toggleFollow,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isFollowing ? AppColors.bgSurface : AppColors.white,
          foregroundColor: _isFollowing ? AppColors.textPrimary : AppColors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: _isFollowing
                ? const BorderSide(color: AppColors.border)
                : BorderSide.none,
          ),
        ),
        child: _isProcessing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                _isFollowing ? 'フォロー中' : 'フォローする',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
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
