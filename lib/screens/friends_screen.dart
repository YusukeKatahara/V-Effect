import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/friend_request.dart';
import '../services/friend_service.dart';

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
        title: const Text('フレンド解除'),
        content: Text('${friend.username} をフレンドから外しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('解除する', style: TextStyle(color: Colors.red)),
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
      appBar: AppBar(title: const Text('フレンド')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ══════════════════════════════
          // フレンド検索セクション
          // ══════════════════════════════
          const Text(
            'フレンドを追加',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'ユーザーIDで検索',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (_) => _searchUser(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isSearching ? null : _searchUser,
                child: _isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('検索'),
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
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          if (_searchResult != null)
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(_searchResult!.username ?? ''),
                subtitle: Text('@${_searchResult!.userId ?? ''}'),
                trailing: _requestSent
                    ? const Icon(Icons.check, color: Colors.green)
                    : IconButton(
                        icon: const Icon(Icons.person_add),
                        onPressed: () => _sendRequest(_searchResult!),
                      ),
              ),
            ),
          const SizedBox(height: 24),

          // ══════════════════════════════
          // 受信リクエストセクション
          // ══════════════════════════════
          const Text(
            '受信リクエスト',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<FriendRequest>>(
            stream: _friendService.getReceivedRequests(),
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
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              return Column(
                children: requests.map((req) {
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.mail)),
                      title: Text(req.fromUsername),
                      subtitle: Text('@${req.fromUserId}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check_circle,
                                color: Colors.green),
                            onPressed: () => _acceptRequest(req),
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel,
                                color: Colors.redAccent),
                            onPressed: () => _rejectRequest(req),
                          ),
                        ],
                      ),
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
          const Text(
            'フレンドリスト',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<AppUser>>(
            stream: _friendService.getFriends(),
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
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              return Column(
                children: friends.map((friend) {
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(friend.username ?? ''),
                      subtitle: Text('@${friend.userId ?? ''}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.person_remove,
                            color: Colors.grey),
                        onPressed: () => _removeFriend(friend),
                      ),
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
