import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dev_blog_post.dart';
import '../services/dev_blog_service.dart';

final blogPostsProvider = StreamProvider<List<DevBlogPost>>((ref) {
  return DevBlogService.instance.getPosts();
});

final isDeveloperProvider = FutureProvider<bool>((ref) {
  return DevBlogService.instance.isDeveloper();
});

final lastViewedDevBlogAtProvider = FutureProvider<DateTime?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final timestamp = prefs.getInt('lastViewedDevBlogAt');
  if (timestamp != null) {
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }
  return null;
});

final hasUnreadBlogProvider = Provider<bool>((ref) {
  final postsAsync = ref.watch(blogPostsProvider);
  final lastViewedAsync = ref.watch(lastViewedDevBlogAtProvider);

  if (!postsAsync.hasValue || !lastViewedAsync.hasValue) {
    return false;
  }

  final posts = postsAsync.value!;
  if (posts.isEmpty) {
    return false;
  }

  // postsはDevBlogService内で降順にソートされている想定なので最初の要素が最新
  final latestPostDate = posts.first.createdAt;

  final lastViewed = lastViewedAsync.value;
  if (lastViewed == null) {
    return true; // 一度も見たことがない
  }

  return latestPostDate.isAfter(lastViewed);
});

Future<void> markDevBlogAsRead(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('lastViewedDevBlogAt', DateTime.now().millisecondsSinceEpoch);
  ref.invalidate(lastViewedDevBlogAtProvider);
}
