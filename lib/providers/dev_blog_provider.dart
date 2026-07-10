import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dev_blog_post.dart';
import '../services/dev_blog_service.dart';

final blogPostsProvider = StreamProvider<List<DevBlogPost>>((ref) {
  return DevBlogService.instance.getPosts();
});

/// 公開済みのお知らせのみをフィルタリングして提供するプロバイダー
final publishedBlogPostsProvider = Provider<AsyncValue<List<DevBlogPost>>>((ref) {
  final postsAsync = ref.watch(blogPostsProvider);
  return postsAsync.when(
    data: (posts) {
      final now = DateTime.now();
      return AsyncValue.data(
        posts.where((p) {
          if (p.isDraft) return false;
          if (p.publishAt != null && p.publishAt!.isAfter(now)) return false;
          return true;
        }).toList(),
      );
    },
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
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
  final postsAsync = ref.watch(publishedBlogPostsProvider);
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
