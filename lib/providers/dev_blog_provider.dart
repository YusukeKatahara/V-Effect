import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dev_blog_post.dart';
import '../services/dev_blog_service.dart';

final blogPostsProvider = StreamProvider<List<DevBlogPost>>((ref) {
  return DevBlogService.instance.getPosts();
});

final isDeveloperProvider = FutureProvider<bool>((ref) {
  return DevBlogService.instance.isDeveloper();
});
