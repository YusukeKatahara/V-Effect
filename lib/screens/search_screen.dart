import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../models/app_user.dart';
import '../services/friend_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final FriendService _friendService = FriendService.instance;
  bool _isLoading = true;
  List<AppUser> _results = [];
  String _query = '';
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && _query != args) {
      _query = args;
      _performSearch(_query);
    } else if (args == null) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
      _results.clear();
      _errorMessage = null;
    });

    try {
      // 1. IDで検索 (完全一致)
      final idResult = await _friendService.searchByUserId(query);
      if (idResult != null) {
        _results.add(idResult);
      }

      // 2. 名前で検索 (部分一致)
      final nameResults = await _friendService.searchByUsername(query);
      for (final user in nameResults) {
        // 重複を除外
        if (!_results.any((u) => u.uid == user.uid)) {
          _results.add(user);
        }
      }
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

  void _toggleFollow(AppUser targetUser) async {
    try {
      await _friendService.followUser(targetUser.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${targetUser.username}さんをフォローしました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('フォローに失敗しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: AppColors.bgBase,
        surfaceTintColor: Colors.transparent,
        title: Text('検索結果: $_query', style: const TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
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
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          minimumSize: Size.zero,
                        ),
                        onPressed: () => _toggleFollow(user),
                        child: const Text('フォロー', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    );
                  },
                ),
    );
  }
}
