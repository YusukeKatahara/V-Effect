import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post.dart';
import '../models/app_task.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/block_service.dart';
import '../services/post_service.dart';

/// ホーム画面に表示する主要なデータを一括管理・提供するProvider
class HomeData {
  final int streak;
  final bool postedToday;
  final bool isAllTasksCompleted;
  final String username;
  final List<AppTask> tasks;
  final List<String> followingUids;
  final List<Post> feedPosts;
  final List<Map<String, dynamic>> postedFriends; // {uid, username, photoUrl}
  final Map<String, String> userNames; // userId -> username
  final Map<String, String?> userPhotos; // userId -> photoUrl
  final Map<String, int> userStreaks; // userId -> streak
  final Map<String, String?> userBadgeUrls; // userId -> badgeUrl
  final Map<String, String?> userBadgeAnimations; // userId -> badgeAnimation

  HomeData({
    required this.streak,
    required this.postedToday,
    required this.isAllTasksCompleted,
    required this.username,
    required this.tasks,
    required this.followingUids,
    required this.feedPosts,
    required this.postedFriends,
    required this.userNames,
    required this.userPhotos,
    required this.userStreaks,
    required this.userBadgeUrls,
    required this.userBadgeAnimations,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeData &&
          runtimeType == other.runtimeType &&
          streak == other.streak &&
          postedToday == other.postedToday &&
          isAllTasksCompleted == other.isAllTasksCompleted &&
          username == other.username &&
          _listEquals(tasks, other.tasks) &&
          _listEquals(followingUids, other.followingUids) &&
          _listEquals(feedPosts, other.feedPosts) &&
          _listEquals(postedFriends, other.postedFriends) &&
          _mapEquals(userNames, other.userNames) &&
          _mapEquals(userPhotos, other.userPhotos) &&
          _mapEquals(userStreaks, other.userStreaks) &&
          _mapEquals(userBadgeUrls, other.userBadgeUrls) &&
          _mapEquals(userBadgeAnimations, other.userBadgeAnimations);

  @override
  int get hashCode =>
      streak.hashCode ^
      postedToday.hashCode ^
      isAllTasksCompleted.hashCode ^
      username.hashCode ^
      tasks.hashCode ^
      followingUids.hashCode ^
      feedPosts.hashCode ^
      postedFriends.hashCode ^
      userNames.hashCode ^
      userPhotos.hashCode ^
      userStreaks.hashCode ^
      userBadgeUrls.hashCode ^
      userBadgeAnimations.hashCode;

  bool _listEquals(List? a, List? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _mapEquals(Map? a, Map? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  Map<String, dynamic> toJson() {
    return {
      'streak': streak,
      'postedToday': postedToday,
      'isAllTasksCompleted': isAllTasksCompleted,
      'username': username,
      'tasks': tasks.map((t) => {
        'title': t.title,
        'trigger': t.trigger,

        'isOneTime': t.isOneTime,
        'isSeason': t.isSeason,
        'seasonId': t.seasonId,
        'completedAt': t.completedAt?.toIso8601String(),
      }).toList(),
      'followingUids': followingUids,
      'feedPosts': feedPosts.map((p) => {
         'id': p.id,
         'userId': p.userId,
         'imageUrl': p.imageUrl,
         'taskName': p.taskName,
         'caption': p.caption,
         'createdAt': p.createdAt.toIso8601String(),
         'expiresAt': p.expiresAt.toIso8601String(),
         'reactionCount': p.reactionCount,
         'emojiReactedUserIds': p.emojiReactedUserIds,
         'userReactions': p.userReactions,
         'bgmUrl': p.bgmUrl,
         'bgmTitle': p.bgmTitle,
         'bgmArtist': p.bgmArtist,
         'bgmArtworkUrl': p.bgmArtworkUrl,
      }).toList(),
      'postedFriends': postedFriends,
      'userNames': userNames,
      'userPhotos': userPhotos,
      'userStreaks': userStreaks,
      'userBadgeUrls': userBadgeUrls,
      'userBadgeAnimations': userBadgeAnimations,
    };
  }

  factory HomeData.fromJson(Map<String, dynamic> json) {
    return HomeData(
      streak: json['streak'] as int? ?? 0,
      postedToday: json['postedToday'] as bool? ?? false,
      isAllTasksCompleted: json['isAllTasksCompleted'] as bool? ?? false,
      username: json['username'] as String? ?? '',
      tasks: (json['tasks'] as List<dynamic>? ?? []).map((t) => AppTask(
        title: t['title'] as String? ?? '',
        trigger: t['trigger'] as String?,

        isOneTime: t['isOneTime'] as bool? ?? false,
        isSeason: t['isSeason'] as bool? ?? false,
        seasonId: t['seasonId'] as String?,
        completedAt: t['completedAt'] != null ? DateTime.tryParse(t['completedAt']) : null,
      )).toList(),
      followingUids: (json['followingUids'] as List<dynamic>? ?? []).cast<String>(),
      feedPosts: (json['feedPosts'] as List<dynamic>? ?? []).map((p) => Post(
         id: p['id'] as String? ?? '',
         userId: p['userId'] as String? ?? '',
         imageUrl: p['imageUrl'] as String?,
         taskName: p['taskName'] as String? ?? '',
         caption: p['caption'] as String?,
         createdAt: p['createdAt'] != null ? DateTime.tryParse(p['createdAt']) ?? DateTime.now() : DateTime.now(),
         expiresAt: p['expiresAt'] != null ? DateTime.tryParse(p['expiresAt']) ?? DateTime.now() : DateTime.now(),
         reactionCount: p['reactionCount'] as int? ?? 0,
         emojiReactedUserIds: (p['emojiReactedUserIds'] as List<dynamic>? ?? []).cast<String>(),
         userReactions: Map<String, String>.from(p['userReactions'] ?? {}),
         bgmUrl: p['bgmUrl'] as String?,
         bgmTitle: p['bgmTitle'] as String?,
         bgmArtist: p['bgmArtist'] as String?,
         bgmArtworkUrl: p['bgmArtworkUrl'] as String?,
      )).toList(),
      postedFriends: (json['postedFriends'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>(),
      userNames: Map<String, String>.from(json['userNames'] ?? {}),
      userPhotos: Map<String, String?>.from(json['userPhotos'] ?? {}),
      userStreaks: Map<String, int>.from(json['userStreaks'] ?? {}),
      userBadgeUrls: Map<String, String?>.from(json['userBadgeUrls'] ?? {}),
      userBadgeAnimations: Map<String, String?>.from(json['userBadgeAnimations'] ?? {}),
    );
  }
}

final postUpdateProvider = StreamProvider.autoDispose<void>((ref) {
  return PostService.instance.updateStream;
});

/// 初回ロード完了フラグを保持するProvider
final homeDataLoadedProvider = StateProvider.autoDispose<bool>((ref) => false);

final homeDataProvider = StreamProvider.autoDispose<HomeData>((ref) async* {
  // PostService からの更新信号を監視。信号が届くたびにこの Provider は再実行される。
  ref.watch(postUpdateProvider);
  
  final postService = PostService.instance;
  final myUid = FirebaseAuth.instance.currentUser?.uid;
  if (myUid == null) return;

  final prefs = await SharedPreferences.getInstance();
  final cacheKey = 'homeData_$myUid';

  final isLoaded = ref.read(homeDataLoadedProvider);

  // 1. まずローカルキャッシュから即座に表示（ゼロ・ディレイ起動）
  // 2026ベストプラクティス：再フェッチ時はすでに最新データがメモリ上にあるため、古いキャッシュの読み込みをスキップして表示の巻き戻りを防ぐ
  if (!isLoaded) {
    final cachedStr = prefs.getString(cacheKey);
    if (cachedStr != null) {
      try {
        final cachedJson = jsonDecode(cachedStr) as Map<String, dynamic>;
        final cachedData = HomeData.fromJson(cachedJson);
        yield cachedData;
      } catch (e) {
        debugPrint('HomeData cache decode error: $e');
      }
    }
  }
  
  // 2. 裏でFirestoreから最新データを取得
  final Map<String, dynamic> homeDataMap;
  final List<String> blockedUids;
  
  try {
    final initialParallelResults = await Future.wait([
      postService.getHomeData(),
      BlockService.instance.getBlockedUids(),
    ]);
    homeDataMap = initialParallelResults[0] as Map<String, dynamic>;
    blockedUids = initialParallelResults[1] as List<String>;
  } catch (e) {
    throw Exception('Error in initial phase (getHomeData or getBlockedUids): $e');
  }

  final allFriendUids = (homeDataMap['friends'] as List<dynamic>?)?.cast<String>() ?? [];

  // ブロックしたユーザーをフィードから除外
  final friendUids = allFriendUids
      .where((uid) => !blockedUids.contains(uid))
      .toList();

  // 自分のステータスも含めてフレンド情報を取得
  final uidsToFetch = List<String>.from(friendUids);
  if (!uidsToFetch.contains(myUid)) {
    uidsToFetch.add(myUid);
  }

  final List<Post> feedPosts;
  final List<Map<String, dynamic>> friendStatuses;

  try {
    // 2. フィード投稿とフレンドの詳細情報を一括（並列）で取得して高速化
    final parallelResults = await Future.wait([
      postService.getAllFriendsPosts(friendUids, includeMe: false),
      postService.getFriendsListFromUids(uidsToFetch),
    ]);
    feedPosts = parallelResults[0] as List<Post>;
    friendStatuses = parallelResults[1] as List<Map<String, dynamic>>;
  } catch (e) {
    throw Exception('Error in friends phase (getAllFriendsPosts or getFriendsList): $e');
  }
  
  final names = <String, String>{};
  final photos = <String, String?>{};
  final streaks = <String, int>{};
  final badgeUrls = <String, String?>{};
  final badgeAnimations = <String, String?>{};
  for (final f in friendStatuses) {
    final uid = f['uid'] as String;
    names[uid] = f['username'] as String;
    photos[uid] = f['photoUrl'] as String?;
    streaks[uid] = (f['streak'] as num?)?.toInt() ?? 0;
    badgeUrls[uid] = f['equippedBadgeUrl'] as String?;
    badgeAnimations[uid] = f['equippedBadgeAnimation'] as String?;
  }

  // 4. 投稿済みのフレンドを抽出
  final postedFriends = <Map<String, dynamic>>[];
  final seenUids = <String>{};
  // フィード投稿から最新順に、まだ見ていないフレンドをピックアップ
  for (final post in feedPosts) {
    if (!seenUids.contains(post.userId)) {
      seenUids.add(post.userId);
      postedFriends.add({
        'uid': post.userId,
        'username': names[post.userId] ?? 'Unknown',
        'photoUrl': photos[post.userId],
      });
    }
  }

  final latestData = HomeData(
    streak: homeDataMap['streak'] as int,
    postedToday: homeDataMap['postedToday'] as bool,
    isAllTasksCompleted: homeDataMap['isAllTasksCompleted'] as bool,
    username: homeDataMap['username'] as String,
    tasks: (homeDataMap['tasks'] as List<dynamic>).cast<AppTask>(),
    followingUids: friendUids,
    feedPosts: feedPosts,
    postedFriends: postedFriends,
    userNames: names,
    userPhotos: photos,
    userStreaks: streaks,
    userBadgeUrls: badgeUrls,
    userBadgeAnimations: badgeAnimations,
  );

  // 3. 取得した最新データをキャッシュに保存し、UIへ反映
  prefs.setString(cacheKey, jsonEncode(latestData.toJson()));
  ref.read(homeDataLoadedProvider.notifier).state = true; // ロード完了フラグを設定
  yield latestData;
});
