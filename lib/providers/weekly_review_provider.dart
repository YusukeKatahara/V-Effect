import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/post.dart';
import '../services/post_service.dart';

/// 今週の振り返り（Weekly Review）画面で表示するデータを読み込み・管理するProvider
class WeeklyReviewData {
  final List<Post> posts;
  final int streak;

  WeeklyReviewData({required this.posts, required this.streak});
}

final weeklyReviewProvider = FutureProvider<WeeklyReviewData>((ref) async {
  final postService = PostService.instance;
  
  // 自分のストリーク数と、直近7日間の投稿を並列で取得
  final results = await Future.wait([
    postService.getWeeklyReviewPosts(),
    postService.getStreak(),
  ]);

  return WeeklyReviewData(
    posts: results[0] as List<Post>,
    streak: results[1] as int,
  );
});
