import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/app_task.dart';
import '../models/app_user.dart';
import '../models/post.dart';
import '../models/season.dart';
import '../services/post_service.dart';
import '../services/user_service.dart';
import '../screens/hero_tasks/components/hero_task_item.dart';

/// 炎画面（HeroTasksScreen）で表示する主要なデータを一括管理するデータクラス
class HeroTasksData {
  final int streak;
  final int streakProtections;
  final List<HeroTaskItem> taskItems;
  final Map<String, String?> userPhotos; // userId -> photoUrl
  final Map<String, String> userNames;   // userId -> username
  final String? myPhotoUrl;
  final String myUsername;
  final String? myBadgeUrl;
  final String? myBadgeAnimation;

  HeroTasksData({
    required this.streak,
    required this.streakProtections,
    required this.taskItems,
    required this.userPhotos,
    required this.userNames,
    this.myPhotoUrl,
    required this.myUsername,
    this.myBadgeUrl,
    this.myBadgeAnimation,
  });
}

/// データの更新通知ストリームを監視し、イベントが流れてきたらこのプロバイダーをトリガーする
final heroTasksUpdateProvider = StreamProvider.autoDispose<void>((ref) async* {
  // PostService と UserService の更新イベントストリームを統合して監視
  final postStream = PostService.instance.updateStream;
  final userStream = UserService.instance.updateStream;

  yield* postStream;
  yield* userStream;
});

/// 炎画面のデータを非同期でロードし、メモリ上にキャッシュするプロバイダー
final heroTasksDataProvider = FutureProvider.autoDispose<HeroTasksData>((ref) async {
  // データ更新イベントが流れてきたら再ロードを走らせるために watch する
  ref.watch(heroTasksUpdateProvider);

  final postService = PostService.instance;
  final userService = UserService.instance;
  final uid = userService.currentUid;
  
  if (uid == null) {
    throw Exception('ユーザーがログインしていません。');
  }

  // 1. ホームデータと自分自身のユーザープロファイルを並列（同時）にフェッチして高速化
  final parallelResults = await Future.wait([
    postService.getHomeData(),
    FirebaseFirestore.instance.collection('users').doc(uid).get(),
  ]);

  final homeData = parallelResults[0] as Map<String, dynamic>;
  final userSnap = parallelResults[1] as DocumentSnapshot;

  final allTasks = (homeData['tasks'] as List<dynamic>?)?.cast<AppTask>() ?? [];
  
  // ワンタイムタスクのクリーンアップ（期限切れのものを削除）
  AppUser? appUser;
  if (userSnap.exists) {
    appUser = AppUser.fromFirestore(userSnap);
    await userService.cleanupExpiredTasks(appUser);
    
    // クリーンアップされた可能性があるので、取得済みの allTasks からフィルタリングして即時反映する
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    allTasks.removeWhere((t) => t.isOneTime && t.completedAt != null && t.completedAt!.isBefore(startOfToday));
  }

  final postedPosts = (homeData['postedTasksToday'] as List<dynamic>?)?.cast<Post>() ?? [];

  // 2. シーズンタスクの進行状況を取得
  final seasonTasks = allTasks.where((t) => t.isSeason).toList();
  Map<String, Season> seasonsMap = {};
  Map<String, int> seasonPostsCountMap = {};
  if (seasonTasks.isNotEmpty) {
    try {
      final progressData = await postService.getSeasonProgressMap(uid, seasonTasks);
      seasonsMap = Map<String, Season>.from(progressData['seasonsMap'] ?? {});
      seasonPostsCountMap = Map<String, int>.from(progressData['seasonPostsCountMap'] ?? {});
    } catch (e) {
      debugPrint('Season progress load error: $e');
    }
  }

  // 3. 各タスクの進捗状況（HeroTaskItem）をビルド
  final List<HeroTaskItem> items = [];
  final Set<String> uidsToFetch = {};
  
  for (final task in allTasks) {
    final taskPosts = postedPosts.where((p) => p.taskName == task.title).toList();
    final sId = task.seasonId ?? 'debug_season_test';
    
    // リアクションをしたユーザーのIDを収集する
    for (final post in taskPosts) {
      uidsToFetch.addAll(post.emojiReactedUserIds);
      uidsToFetch.addAll(post.userReactions.keys);
    }
    
    items.add(HeroTaskItem(
      name: task.title,
      trigger: task.trigger,
      completedPosts: taskPosts,
      isOneTime: task.isOneTime,
      isSeason: task.isSeason,
      seasonId: task.seasonId,
      season: task.isSeason
          ? (seasonsMap[sId] ?? seasonsMap['debug_season'] ?? seasonsMap['debug_season_test'])
          : null,
      currentSeasonCount: task.isSeason ? (seasonPostsCountMap[sId] ?? 0) : 0,
    ));
  }

  // 4. リアクションしたユーザーのプロフィール情報を並列に取得
  final Map<String, String?> photoMap = {};
  final Map<String, String> nameMap = {};

  if (uidsToFetch.isNotEmpty) {
    try {
      final profiles = await postService.getFriendsListFromUids(uidsToFetch.toList());
      for (final p in profiles) {
        final friendUid = p['uid'] as String;
        photoMap[friendUid] = p['photoUrl'] as String?;
        nameMap[friendUid] = p['username'] as String? ?? 'Unknown';
      }
    } catch (e) {
      debugPrint('Friends profiles load error: $e');
    }
  }

  // 5. 自分自身の最新のプロフィール情報（アバター、バッジ情報）をバインド
  String? myPhotoUrl;
  String myUsername = 'V';
  String? myBadgeUrl;
  String? myBadgeAnimation;

  if (appUser != null) {
    myPhotoUrl = appUser.photoUrl;
    myUsername = appUser.displayName ?? appUser.username ?? 'V';
    myBadgeUrl = appUser.equippedBadgeUrl;
    myBadgeAnimation = appUser.equippedBadgeAnimation;
  }

  return HeroTasksData(
    streak: (homeData['streak'] as num?)?.toInt() ?? 0,
    streakProtections: (homeData['streakProtections'] as num?)?.toInt() ?? 0,
    taskItems: items,
    userPhotos: photoMap,
    userNames: nameMap,
    myPhotoUrl: myPhotoUrl,
    myUsername: myUsername,
    myBadgeUrl: myBadgeUrl,
    myBadgeAnimation: myBadgeAnimation,
  );
});
