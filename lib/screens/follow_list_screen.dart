import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/app_colors.dart';
import '../models/app_user.dart';
import '../services/friend_service.dart';

/// フォロー中 / フォロワー 一覧画面
///
/// 引数（ModalRoute.settings.arguments）:
///   {'uid': String, 'isFollowing': bool, 'title': String}
class FollowListScreen extends StatefulWidget {
  const FollowListScreen({super.key});

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  final FriendService _friendService = FriendService.instance;
  final String _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  bool _loading = true;
  bool _initialized = false;
  bool _showPendingBanner = false;
  List<AppUser> _users = [];
  String _title = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadUsers();
    }
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);

    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args == null) {
      setState(() => _loading = false);
      return;
    }

    final uid = args['uid'] as String;
    final isFollowing = args['isFollowing'] as bool;
    _title = args['title'] as String? ?? (isFollowing ? 'フォロー中' : 'フォロワー');

    // 自分のフォロワー画面の場合、保留中の申請があるか確認する
    final isMyFollowers = !isFollowing && uid == _myUid;

    try {
      final results = await Future.wait([
        _friendService.getUserByUid(uid),
        if (isMyFollowers)
          _friendService.getReceivedRequests().first,
      ]);

      final userSnap = results[0] as AppUser?;
      final uids = isFollowing
          ? (userSnap?.following ?? [])
          : (userSnap?.followers ?? []);

      final users = await _friendService.getUsersByUids(uids);
      if (!mounted) return;
      setState(() {
        _users = users;
        _loading = false;
        if (isMyFollowers) {
          final pendingList = results[1] as List;
          _showPendingBanner = pendingList.isNotEmpty;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: AppColors.bgBase,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        title: Text(_title, style: const TextStyle(color: AppColors.textPrimary)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_showPendingBanner) _buildPendingBanner(),
                Expanded(
                  child: _users.isEmpty
                      ? Center(
                          child: Text(
                            'ユーザーがいません',
                            style: const TextStyle(
                                color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _users.length,
                          itemBuilder: (context, index) =>
                              _buildUserTile(_users[index]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildPendingBanner() {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/pending-requests'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: AppColors.bgElevated,
          border: Border(
            bottom: BorderSide(color: AppColors.border),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.person_add_rounded,
              color: AppColors.textPrimary,
              size: 20,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'フォロー申請が届いています',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserTile(AppUser user) {
    final isMe = user.uid == _myUid;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: isMe ? null : () {
        Navigator.pushNamed(context, '/user-profile', arguments: user.uid);
      },
      leading: _buildAvatar(user),
      title: Text(
        user.username ?? '',
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        '@${user.userId ?? ''}',
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      trailing: isMe
          ? const Text('自分', style: TextStyle(color: AppColors.textMuted, fontSize: 12))
          : const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
    );
  }

  Widget _buildAvatar(AppUser user) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.bgElevated,
        image: user.photoUrl != null
            ? DecorationImage(
                image: ResizeImage(
                  CachedNetworkImageProvider(user.photoUrl!),
                  width: 100,
                  height: 100,
                ),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: user.photoUrl == null
          ? const Icon(Icons.person, color: AppColors.textMuted, size: 22)
          : null,
    );
  }
}
