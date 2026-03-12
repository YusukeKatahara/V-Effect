import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../models/app_user.dart';
import '../models/friend_request.dart';
import '../services/friend_service.dart';
import '../widgets/section_title.dart';

/// フレンドリスト + フレンド検索・リクエスト画面
/// 上部にフレンド検索、中部に受信リクエスト、下部にフレンドリストを表示します
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final FriendService _friendService = FriendService();
  final _searchCtrl = TextEditingController();

  bool _isSearching = false;
  AppUser? _searchResult;
  String? _searchError;
  bool _requestSent = false;

  late final Stream<List<FriendRequest>> _requestsStream;
  late final Stream<List<AppUser>> _friendsStream;

  @override
  void initState() {
    super.initState();
    _requestsStream = _friendService.getReceivedRequests();
    _friendsStream = _friendService.getFriends();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchUser() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResult = null;
      _searchError = null;
      _requestSent = false;
    });

    try {
      final user = await _friendService.searchByUserId(query);
      setState(() {
        _searchResult = user;
        _searchError = user == null ? 'ユーザーが見つかりません' : null;
      });
    } catch (e) {
      setState(() => _searchError = '検索に失敗しました');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _sendRequest(AppUser target) async {
    try {
      await _friendService.sendRequest(target.uid);
      setState(() => _requestSent = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${target.username} にリクエストを送りました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  Future<void> _acceptRequest(FriendRequest request) async {
    try {
      await _friendService.acceptRequest(request);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${request.fromUsername} とフレンドになりました'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('承認に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _rejectRequest(FriendRequest request) async {
    try {
      await _friendService.rejectRequest(request);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拒否に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _removeFriend(AppUser friend) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('フレンド解除', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('${friend.username} をフレンドから外しますか？',
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('解除する', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _friendService.removeFriend(friend.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${friend.username} をフレンドから外しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('解除に失敗しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        title: const Text('フレンド'),
        backgroundColor: AppColors.bgBase,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ══════════════════════════════
          // フレンド検索セクション
          // ══════════════════════════════
          const SectionTitle(title: 'フレンドを追加'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'ユーザーIDで検索',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (_) => _searchUser(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 50,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton(
                    onPressed: _isSearching ? null : _searchUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: const Color(0xFF1A1000),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isSearching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('検索',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 検索結果
          if (_searchError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _searchError!,
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
          if (_searchResult != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppColors.bgElevated,
                    child: Icon(Icons.person, color: AppColors.textMuted),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_searchResult!.username ?? '',
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600)),
                        Text('@${_searchResult!.userId ?? ''}',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                  _requestSent
                      ? const Icon(Icons.check, color: AppColors.success)
                      : IconButton(
                          icon: const Icon(Icons.person_add,
                              color: AppColors.primary),
                          onPressed: () => _sendRequest(_searchResult!),
                        ),
                ],
              ),
            ),
          const SizedBox(height: 24),

          // ══════════════════════════════
          // 受信リクエストセクション
          // ══════════════════════════════
          const SectionTitle(title: '受信リクエスト'),
          const SizedBox(height: 12),
          StreamBuilder<List<FriendRequest>>(
            stream: _requestsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final requests = snapshot.data ?? [];
              if (requests.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'リクエストはありません',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                );
              }

              return Column(
                children: requests.map((req) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: AppColors.bgElevated,
                          child:
                              Icon(Icons.mail, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(req.fromUsername,
                                  style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600)),
                              Text('@${req.fromUserId}',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                        // Gold accept button
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.primaryGradient,
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.check,
                                  color: Color(0xFF1A1000), size: 20),
                              onPressed: () => _acceptRequest(req),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Muted reject button
                        IconButton(
                          icon: const Icon(Icons.close,
                              color: AppColors.textMuted, size: 20),
                          onPressed: () => _rejectRequest(req),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 24),

          // ══════════════════════════════
          // フレンドリストセクション
          // ══════════════════════════════
          const SectionTitle(title: 'フレンドリスト'),
          const SizedBox(height: 12),
          StreamBuilder<List<AppUser>>(
            stream: _friendsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final friends = snapshot.data ?? [];
              if (friends.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'まだフレンドがいません\nユーザーIDで検索して追加しましょう',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                );
              }

              return Column(
                children: friends.map((friend) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: AppColors.bgElevated,
                          child: Icon(Icons.person,
                              color: AppColors.textMuted),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(friend.username ?? '',
                                  style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600)),
                              Text('@${friend.userId ?? ''}',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.person_remove,
                              color: AppColors.textMuted),
                          onPressed: () => _removeFriend(friend),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
