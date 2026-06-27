import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import '../config/app_colors.dart';
import '../models/app_user.dart';
import '../services/friend_service.dart';
import '../providers/service_providers.dart';
import '../providers/following_provider.dart';
import '../widgets/swipe_back_gate.dart';
import 'qr_scanner_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final FriendService _friendService;
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  final List<AppUser> _results = [];
  String _query = '';
  String? _errorMessage;
  final Set<String> _pendingUids = {}; // 申請中状態を管理

  Timer? _debounce;
  List<SearchHistoryItem> _historyItems = [];
  static const String _recentSearchesKey = 'recent_search_history_v2'; // バージョン2に変更して互換性を担保

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _friendService = ref.read(friendServiceProvider);
    _loadRecentSearches();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final historyStrings = prefs.getStringList(_recentSearchesKey) ?? [];
    if (mounted) {
      setState(() {
        _historyItems = historyStrings.map((s) {
          try {
            return SearchHistoryItem.fromJson(jsonDecode(s) as Map<String, dynamic>);
          } catch (e) {
            // 万が一のデコードエラー対策
            return SearchHistoryItem(type: 'keyword', value: s);
          }
        }).toList();
      });
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final strings = _historyItems.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList(_recentSearchesKey, strings);
  }

  Future<void> _addKeywordToHistory(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    
    setState(() {
      _historyItems.removeWhere((item) => item.type == 'keyword' && item.value == trimmed);
      _historyItems.insert(0, SearchHistoryItem(type: 'keyword', value: trimmed));
      if (_historyItems.length > 15) {
        _historyItems.removeLast();
      }
    });
    await _saveHistory();
  }

  Future<void> _addUserToHistory(AppUser user) async {
    setState(() {
      _historyItems.removeWhere((item) => item.type == 'user' && item.uid == user.uid);
      _historyItems.insert(
        0,
        SearchHistoryItem(
          type: 'user',
          uid: user.uid,
          username: user.username,
          userId: user.userId,
          photoUrl: user.photoUrl,
        ),
      );
      if (_historyItems.length > 15) {
        _historyItems.removeLast();
      }
    });
    await _saveHistory();
  }

  Future<void> _removeFromHistory(SearchHistoryItem item) async {
    setState(() {
      _historyItems.remove(item);
    });
    await _saveHistory();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final searchTarget = query.trim();
    if (searchTarget.isEmpty) {
      if (mounted) {
        setState(() {
          _query = '';
          _results.clear();
          _errorMessage = null;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _query = searchTarget;
      _results.clear();
      _errorMessage = null;
    });

    try {
      final results = await _friendService.searchUsers(searchTarget);
      
      // 非同期処理中に別の検索が開始されていないかチェック
      if (mounted && _query == searchTarget) {
        setState(() {
          _results.clear(); // 念のためクリアして最新の結果で上書き
          _results.addAll(results);
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted && _query == searchTarget) {
        setState(() => _errorMessage = e.toString());
      }
    } finally {
      if (mounted && _query == searchTarget) {
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
            SnackBar(content: Text(AppLocalizations.of(context)!.searchUnfollowed(targetUser.username ?? ''))),
          );
        }
      } else {
        // フォローリクエストを送る (直接フォローを廃止)
        await _friendService.sendRequest(targetUser.uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.searchFollowRequestSent(targetUser.username ?? ''))),
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
          SnackBar(content: Text(AppLocalizations.of(context)!.searchActionFailed(e))),
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
          style: TextStyle(color: AppColors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.searchHint,
            hintStyle: TextStyle(color: AppColors.grey30, fontSize: 15),
            border: InputBorder.none,
          ),
          onChanged: _onSearchChanged,
          onSubmitted: (query) {
            _addKeywordToHistory(query);
            _performSearch(query);
          },
          textInputAction: TextInputAction.search,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: Icon(Icons.qr_code_scanner, color: AppColors.grey50),
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
          ? ListView.builder(
              itemCount: 8,
              itemBuilder: (context, index) => Shimmer.fromColors(
                baseColor: AppColors.bgElevated,
                highlightColor: AppColors.grey15,
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                  title: Container(
                    height: 14,
                    width: 150,
                    color: Colors.white,
                  ),
                  subtitle: Container(
                    height: 12,
                    width: 80,
                    color: Colors.white,
                    margin: const EdgeInsets.only(top: 4),
                  ),
                ),
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      AppLocalizations.of(context)!.searchError(_errorMessage ?? ''),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ),
                )
              : _query.isEmpty
                  ? _historyItems.isEmpty
                      ? Center(
                          child: Text(
                            AppLocalizations.of(context)!.searchKeywordPrompt,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _historyItems.length,
                          itemBuilder: (context, index) {
                            final item = _historyItems[index];
                            if (item.type == 'keyword') {
                              final keyword = item.value ?? '';
                              return ListTile(
                                leading: Icon(Icons.history, color: AppColors.textSecondary),
                                title: Text(keyword, style: TextStyle(color: AppColors.textPrimary)),
                                trailing: IconButton(
                                  icon: Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                                  onPressed: () => _removeFromHistory(item),
                                ),
                                onTap: () {
                                  _searchController.text = keyword;
                                  _searchController.selection = TextSelection.fromPosition(TextPosition(offset: keyword.length));
                                  _addKeywordToHistory(keyword);
                                  _performSearch(keyword);
                                },
                              );
                            } else {
                              return ListTile(
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.bgElevated,
                                    image: item.photoUrl != null
                                        ? DecorationImage(
                                            image: NetworkImage(item.photoUrl!),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: item.photoUrl == null
                                      ? Icon(Icons.person, color: AppColors.textMuted)
                                      : null,
                                ),
                                title: Text(
                                  item.username ?? '',
                                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  '@${item.userId ?? ''}',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                                trailing: IconButton(
                                  icon: Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                                  onPressed: () => _removeFromHistory(item),
                                ),
                                onTap: () {
                                  final appUser = AppUser(
                                    uid: item.uid ?? '',
                                    username: item.username,
                                    userId: item.userId,
                                    photoUrl: item.photoUrl,
                                  );
                                  _addUserToHistory(appUser);
                                  Navigator.pushNamed(
                                    context,
                                    '/user-profile',
                                    arguments: item.uid,
                                  );
                                },
                              );
                            }
                          },
                        )
                  : _results.isEmpty
                      ? Center(
                          child: Text(
                            AppLocalizations.of(context)!.searchNoResults,
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
                              onTap: () {
                                _addUserToHistory(user);
                                Navigator.pushNamed(
                                  context,
                                  '/user-profile',
                                  arguments: user.uid,
                                );
                              },
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
                                    ? Icon(Icons.person, color: AppColors.textMuted)
                                    : null,
                              ),
                              title: Text(
                                user.username ?? '',
                                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '@${user.userId ?? ''}',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
                                          ? AppLocalizations.of(context)!.searchFollowing
                                          : (_pendingUids.contains(user.uid) ? AppLocalizations.of(context)!.searchPending : AppLocalizations.of(context)!.searchFollow),
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

class SearchHistoryItem {
  final String type; // 'keyword' or 'user'
  final String? value; // For keyword
  final String? uid; // For user
  final String? username; // For user
  final String? userId; // For user
  final String? photoUrl; // For user

  SearchHistoryItem({
    required this.type,
    this.value,
    this.uid,
    this.username,
    this.userId,
    this.photoUrl,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    if (value != null) 'value': value,
    if (uid != null) 'uid': uid,
    if (username != null) 'username': username,
    if (userId != null) 'userId': userId,
    if (photoUrl != null) 'photoUrl': photoUrl,
  };

  factory SearchHistoryItem.fromJson(Map<String, dynamic> json) => SearchHistoryItem(
    type: json['type'] as String,
    value: json['value'] as String?,
    uid: json['uid'] as String?,
    username: json['username'] as String?,
    userId: json['userId'] as String?,
    photoUrl: json['photoUrl'] as String?,
  );
}
