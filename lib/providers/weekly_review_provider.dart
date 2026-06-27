import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/post.dart';
import '../services/post_service.dart';
import '../utils/date_helper.dart';


/// 今週の振り返り（Weekly Review）画面で表示するデータを読み込み・管理するProvider
class WeeklyReviewData {
  final List<Post> posts;
  final int streak;
  final int totalVFire;
  final int totalReactions;

  WeeklyReviewData({
    required this.posts,
    required this.streak,
    required this.totalVFire,
    required this.totalReactions,
  });
}

final weeklyReviewProvider = FutureProvider.autoDispose<WeeklyReviewData>((ref) async {
  final postService = PostService.instance;
  
  // 自分のストリーク数と、今週（月曜〜日曜）の投稿を並列で取得
  final results = await Future.wait([
    postService.getWeeklyReviewPosts(),
    postService.getStreak(),
  ]);

  final posts = results[0] as List<Post>;
  final streak = results[1] as int;

  // 今週（月曜〜日曜）のVFIRE(🔥)の合計とその他の絵文字リアクションの合計を計算
  int totalVFire = 0;
  int totalReactions = 0;
  for (final post in posts) {
    totalVFire += post.reactionCount;
    // 絵文字リアクションは userReactions のエントリ数、または emojiReactedUserIds の数
    // emojiReactedUserIds を基準にする方がユニークユーザー数として確実
    totalReactions += post.emojiReactedUserIds.length;
  }

  return WeeklyReviewData(
    posts: posts,
    streak: streak,
    totalVFire: totalVFire,
    totalReactions: totalReactions,
  );
});

/// 今週の振り返りの既読状態を管理するProvider。
/// 戻り値が true の場合は「既読（一度開いた）」を表す。
final isWeeklyReviewReadProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final mondayStr = DateHelper.getMondayOfWeekString(DateTime.now());
  final isRead = prefs.getBool('weekly_review_read_$mondayStr') ?? false;
  return isRead;
});

/// 今週の振り返りを既読（一度開いた）状態にする関数
Future<void> markWeeklyReviewAsRead(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  final mondayStr = DateHelper.getMondayOfWeekString(DateTime.now());
  await prefs.setBool('weekly_review_read_$mondayStr', true);
  ref.invalidate(isWeeklyReviewReadProvider);
}

