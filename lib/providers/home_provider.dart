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

  HomeData({
    required this.streak,
    required this.postedToday,
    required this.isAllTasksCompleted,
    required this.username,
    required this.tasks,
    required this.followingUids,
    required this.feedPosts,
    required this.postedFriends,
  });
}

final homeDataProvider = FutureProvider<HomeData>((ref) async {
  final postService = PostService.instance;
  
  // 1. 基本的なホームデータ（自分のステータス、タスク、フレンドUID）を取得
  final homeDataMap = await postService.getHomeData();
  final friendUids = (homeDataMap['friends'] as List<dynamic>?)?.cast<String>() ?? [];
  
  // 2. フィード投稿を取得
  final feedPosts = await postService.getAllFriendsPosts(friendUids, includeMe: false);
  
  // 3. フレンドの詳細情報（名前や写真）を取得
  final friendStatuses = await postService.getFriendsListFromUids(friendUids);
  
  final names = <String, String>{};
  final photos = <String, String?>{};
  for (final f in friendStatuses) {
    names[f['uid']] = f['username'] as String;
    photos[f['uid']] = f['photoUrl'] as String?;
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
  );
});
