import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/post.dart';
import '../models/app_task.dart';
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
          _mapEquals(userStreaks, other.userStreaks);

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
      userStreaks.hashCode;

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
}

final postUpdateProvider = StreamProvider<void>((ref) {
  return PostService.instance.updateStream;
});

final homeDataProvider = FutureProvider<HomeData>((ref) async {
  // PostService からの更新信号を監視。信号が届くたびにこの Provider は再実行される。
  ref.watch(postUpdateProvider);
  
  final postService = PostService.instance;
  final myUid = FirebaseAuth.instance.currentUser?.uid;
  
  // 1. 基本的なホームデータ（自分のステータス、タスク、フレンドUID）を取得
  final homeDataMap = await postService.getHomeData();
  final friendUids = (homeDataMap['friends'] as List<dynamic>?)?.cast<String>() ?? [];
  final uidsToFetch = List<String>.from(friendUids);
  if (myUid != null && !uidsToFetch.contains(myUid)) {
    uidsToFetch.add(myUid);
  }
  
  // 2. フィード投稿を取得
  final feedPosts = await postService.getAllFriendsPosts(friendUids, includeMe: false);
  
  // 3. フレンドの詳細情報（名前や写真）を取得
  final friendStatuses = await postService.getFriendsListFromUids(uidsToFetch);
  
  final names = <String, String>{};
  final photos = <String, String?>{};
  final streaks = <String, int>{};
  for (final f in friendStatuses) {
    final uid = f['uid'] as String;
    names[uid] = f['username'] as String;
    photos[uid] = f['photoUrl'] as String?;
    streaks[uid] = (f['streak'] as num?)?.toInt() ?? 0;
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

  return HomeData(
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
  );
});
