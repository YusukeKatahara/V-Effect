import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/dev_blog_provider.dart';
import '../../providers/weekly_review_provider.dart';
import '../../widgets/weekly_review_banner.dart';

import 'dev_blog_banner.dart';

class AnnouncementArea extends ConsumerWidget {
  final VoidCallback onOpenWeeklyReview;

  const AnnouncementArea({
    super.key,
    required this.onOpenWeeklyReview,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWeeklyReviewReadAsync = ref.watch(isWeeklyReviewReadProvider);
    final isWeeklyReviewRead = isWeeklyReviewReadAsync.value ?? false;
    final hasUnreadBlog = ref.watch(hasUnreadBlogProvider);
    final isWeekend = DateTime.now().weekday == DateTime.saturday || DateTime.now().weekday == DateTime.sunday;


    final List<Widget> banners = [];
    
    if (hasUnreadBlog) {
      banners.add(const DevBlogBanner());
    }
    
    if (isWeekend && !isWeeklyReviewRead) {
      banners.add(
        SizedBox(
          height: 76,
          child: Center(
            child: WeeklyReviewBanner(onTap: onOpenWeeklyReview),
          ),
        ),
      );
    }


    if (banners.isEmpty) {
      return const SizedBox(height: 76);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < banners.length; i++) ...[
          if (i > 0) const SizedBox(height: 4),
          banners[i],
        ],
        if (banners.length == 1 && hasUnreadBlog) const SizedBox(height: 12),
      ],
    );
  }
}
