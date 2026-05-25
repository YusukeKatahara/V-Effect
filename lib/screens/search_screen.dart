import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_colors.dart';
import '../models/app_user.dart';
import '../services/friend_service.dart';
import '../providers/following_provider.dart';
import '../widgets/swipe_back_gate.dart';
import 'qr_scanner_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final FriendService _friendService = FriendService.instance;
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  final List<AppUser> _results = [];
  String _query = '';
  String? _errorMessage;
  final Set<String> _pendingUids = {}; // 申請中状態を管理

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _query = query.trim();
      _results.clear();
      _errorMessage = null;
    });

    try {
      final results = await _friendService.searchUsers(_query);
      _results.addAll(results);
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleFollow(AppUser targetUser, bool isFollowing) async {
    // 処理中の連打防止
    if (_pendingUids.contains(targetUser.uid)) return;

    // Optimistic UI Update
    if (!isFollowing) {
      setState(() {
        _pendingUids.add(targetUser.uid);
      });
    }

    try {
      if (isFollowing) {
        await _friendService.unfollowUser(targetUser.uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${targetUser.username}さんのフォローを解除しました')),
          );
        }
      } else {
        // フォローリクエストを送る (直接フォローを廃止)
        await _friendService.sendRequest(targetUser.uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${targetUser.username}さんにフォローリクエストを送りました')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        if (!isFollowing) {
          setState(() {
            _pendingUids.remove(targetUser.uid);
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作に失敗しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Riverpod でフォロー中リストの現在の状態を監視
    final followingAsync = ref.watch(followingProvider);
    final followingUids = followingAsync.value?.map((u) => u.uid).toSet() ?? {};

    return SwipeBackGate(
      child: Scaffold(
        backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: AppColors.bgBase,
        surfaceTintColor: Colors.transparent,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: AppColors.white, fontSize: 15),
          decoration: const InputDecoration(
            hintText: 'IDまたは名前を検索',
            hintStyle: TextStyle(color: AppColors.grey30, fontSize: 15),
            border: InputBorder.none,
          ),
          onSubmitted: _performSearch,
          textInputAction: TextInputAction.search,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: AppColors.grey50),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QrScannerScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '検索エラー:\n$_errorMessage',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ),
                )
              : _query.isEmpty
                  ? const Center(
                      child: Text(
                        '検索キーワードを入力してください',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : _results.isEmpty
                      ? const Center(
                          child: Text(
                            'ユーザーが見つかりませんでした',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final user = _results[index];
                            final isMe = user.uid == _currentUid;
                            final isFollowing = followingUids.contains(user.uid);

                            return ListTile(
                              onTap: () => Navigator.pushNamed(
                                context,
                                '/user-profile',
                                arguments: user.uid,
                              ),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.bgElevated,
                                  image: user.photoUrl != null
                                      ? DecorationImage(
                                          image: NetworkImage(user.photoUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: user.photoUrl == null
                                    ? const Icon(Icons.person, color: AppColors.textMuted)
                                    : null,
                              ),
                              title: Text(
                                user.username ?? '',
                                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '@${user.userId ?? ''}',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                              trailing: isMe
                                  ? const SizedBox.shrink() // 自分自身の場合はボタンを非表示
                                  : ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isFollowing ? AppColors.grey15 : AppColors.primary,
                                        foregroundColor: isFollowing ? AppColors.textPrimary : AppColors.black,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                          side: BorderSide(
                                            color: isFollowing ? AppColors.border : Colors.transparent,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        elevation: isFollowing ? 0 : 2,
                                        minimumSize: Size.zero,
                                      ),
                                      onPressed: () => _toggleFollow(user, isFollowing),
                                      child: Text(
                                        isFollowing 
                                          ? 'フォロー中' 
                                          : (_pendingUids.contains(user.uid) ? '申請中' : 'フォロー'),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                            );
                          },
                        ),
      ),
    );
  }
}
