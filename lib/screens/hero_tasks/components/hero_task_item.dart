import '../../../models/post.dart';
import '../../../models/season.dart';

/// 内部管理用のタスクアイテム
class HeroTaskItem {
  final String name;
  final String? trigger;

  final List<Post> completedPosts;
  final bool isOneTime;
  final bool isSeason;
  final String? seasonId;
  final Season? season;
  final int currentSeasonCount;
  bool get isCompleted => completedPosts.isNotEmpty;

  String get displayName => (trigger != null && trigger!.isNotEmpty) ? '$trigger：$name' : name;

  Post? get latestPost {
    if (completedPosts.isEmpty) return null;
    return completedPosts.reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);
  }

  HeroTaskItem({
    required this.name,
    this.trigger,

    this.completedPosts = const [],
    this.isOneTime = false,
    this.isSeason = false,
    this.seasonId,
    this.season,
    this.currentSeasonCount = 0,
  });
}
