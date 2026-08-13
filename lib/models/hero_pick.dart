import 'package:cloud_firestore/cloud_firestore.dart';
import 'post.dart';

/// プロフィールに固定表示（Pin）するベストショット・過去投稿モデル
class HeroPick {
  final String postId;
  final String imageUrl;
  final String? thumbnailUrl;
  final String taskName;
  final DateTime createdAt;
  final String? caption;
  final String? bgmUrl;
  final String? bgmTitle;
  final String? bgmArtist;
  final String? bgmArtworkUrl;
  final int reactionCount;

  // ── フィールド名定数 ──
  static const String fieldPostId = 'postId';
  static const String fieldImageUrl = 'imageUrl';
  static const String fieldThumbnailUrl = 'thumbnailUrl';
  static const String fieldTaskName = 'taskName';
  static const String fieldCreatedAt = 'createdAt';
  static const String fieldCaption = 'caption';
  static const String fieldBgmUrl = 'bgmUrl';
  static const String fieldBgmTitle = 'bgmTitle';
  static const String fieldBgmArtist = 'bgmArtist';
  static const String fieldBgmArtworkUrl = 'bgmArtworkUrl';
  static const String fieldReactionCount = 'reactionCount';

  const HeroPick({
    required this.postId,
    required this.imageUrl,
    this.thumbnailUrl,
    required this.taskName,
    required this.createdAt,
    this.caption,
    this.bgmUrl,
    this.bgmTitle,
    this.bgmArtist,
    this.bgmArtworkUrl,
    this.reactionCount = 0,
  });

  /// `Map<String, dynamic>` から生成 (Firestore 読み込み用)
  factory HeroPick.fromMap(Map<String, dynamic> data) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    return HeroPick(
      postId: data[fieldPostId]?.toString() ?? '',
      imageUrl: data[fieldImageUrl]?.toString() ?? '',
      thumbnailUrl: data[fieldThumbnailUrl]?.toString(),
      taskName: data[fieldTaskName]?.toString() ?? 'Hero Task',
      createdAt: parseDate(data[fieldCreatedAt]),
      caption: data[fieldCaption]?.toString(),
      bgmUrl: data[fieldBgmUrl]?.toString(),
      bgmTitle: data[fieldBgmTitle]?.toString(),
      bgmArtist: data[fieldBgmArtist]?.toString(),
      bgmArtworkUrl: data[fieldBgmArtworkUrl]?.toString(),
      reactionCount: (data[fieldReactionCount] as num?)?.toInt() ?? 0,
    );
  }

  /// `Post` インスタンスから生成
  factory HeroPick.fromPost(Post post) {
    return HeroPick(
      postId: post.id,
      imageUrl: post.imageUrl ?? '',
      thumbnailUrl: post.thumbnailUrl,
      taskName: post.taskName,
      createdAt: post.createdAt,
      caption: post.caption,
      bgmUrl: post.bgmUrl,
      bgmTitle: post.bgmTitle,
      bgmArtist: post.bgmArtist,
      bgmArtworkUrl: post.bgmArtworkUrl,
      reactionCount: post.reactionCount,
    );
  }

  /// Firestore 保存用の Map を生成
  Map<String, dynamic> toMap() {
    return {
      fieldPostId: postId,
      fieldImageUrl: imageUrl,
      if (thumbnailUrl != null) fieldThumbnailUrl: thumbnailUrl,
      fieldTaskName: taskName,
      fieldCreatedAt: Timestamp.fromDate(createdAt),
      if (caption != null) fieldCaption: caption,
      if (bgmUrl != null) fieldBgmUrl: bgmUrl,
      if (bgmTitle != null) fieldBgmTitle: bgmTitle,
      if (bgmArtist != null) fieldBgmArtist: bgmArtist,
      if (bgmArtworkUrl != null) fieldBgmArtworkUrl: bgmArtworkUrl,
      fieldReactionCount: reactionCount,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeroPick &&
          runtimeType == other.runtimeType &&
          postId == other.postId;

  @override
  int get hashCode => postId.hashCode;
}
