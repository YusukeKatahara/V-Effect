import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// リアクションの種類
enum ReactionType {
  /// 通常の炎 (VFIRE) - 連打可能、Firestore では reactionCount として記録
  flame,
  /// 絵文字リアクション - ユーザーごとに1種類まで
  emoji,
}

/// Firestore の posts コレクションに対応するデータモデル
class Post {
  final String id;
  final String userId;
  final String? taskId; // タスクを識別するID（オプショナル、過去データ対応）
  final String? imageUrl;
  final String? thumbnailUrl;
  final String taskName;
  final String? caption;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int reactionCount;
  final List<String> emojiReactedUserIds; // リアクションしたユーザーID
  final Map<String, String> userReactions; // uid -> 絵文字 (個別リアクション記録)
  final String? bgmUrl; // 30秒プレビューURL
  final String? bgmTitle; // 曲名
  final String? bgmArtist; // アーティスト名
  final String? bgmArtworkUrl; // アートワークURL
  final bool isSecret; // シークレットタスクの投稿かどうか

  // ── フィールド名定数 ──
  static const String fieldUserId = 'userId';
  static const String fieldTaskId = 'taskId';
  static const String fieldImageUrl = 'imageUrl';
  static const String fieldThumbnailUrl = 'thumbnailUrl';
  static const String fieldTaskName = 'taskName';
  static const String fieldCaption = 'caption';
  static const String fieldCreatedAt = 'createdAt';
  static const String fieldExpiresAt = 'expiresAt';
  static const String fieldReactionCount = 'reactionCount';
  static const String fieldEmojiReactedUserIds = 'emojiReactedUserIds';
  static const String fieldUserReactions = 'userReactions';
  static const String fieldBgmUrl = 'bgmUrl';
  static const String fieldBgmTitle = 'bgmTitle';
  static const String fieldBgmArtist = 'bgmArtist';
  static const String fieldBgmArtworkUrl = 'bgmArtworkUrl';
  static const String fieldIsSecret = 'isSecret';

  const Post({
    required this.id,
    required this.userId,
    this.taskId,
    this.imageUrl,
    this.thumbnailUrl,
    required this.taskName,
    this.caption,
    required this.createdAt,
    required this.expiresAt,
    this.reactionCount = 0,
    this.emojiReactedUserIds = const [],
    this.userReactions = const {},
    this.bgmUrl,
    this.bgmTitle,
    this.bgmArtist,
    this.bgmArtworkUrl,
    this.isSecret = false,
  });

  /// Firestore の DocumentSnapshot からモデルを生成します
  factory Post.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return Post.fromMap(doc.id, data ?? {});
  }

  /// `Map<String, dynamic>` からモデルを生成します (withConverter用)
  factory Post.fromMap(String id, Map<String, dynamic> data) {
    Map<String, String> userReactions = {};
    List<String> emojiReactedUserIds = [];

    try {
      // 1. userReactions (Map)
      final rawReactions = data[fieldUserReactions];
      if (rawReactions is Map) {
        rawReactions.forEach((key, value) {
          if (key is String) {
            userReactions[key] = value.toString();
          }
        });
      }
      
      // 2. emojiReactedUserIds (List)
      final rawIds = data[fieldEmojiReactedUserIds];
      if (rawIds is Iterable) {
        emojiReactedUserIds = rawIds.map((id) => id.toString()).toList();
      }

      // 3. Fallback: reactorUids (レガシーフィールド対応)
      final legacyIds = data['reactorUids'];
      if (legacyIds is Iterable) {
        for (final id in legacyIds) {
          final stringId = id.toString();
          if (!emojiReactedUserIds.contains(stringId)) {
            emojiReactedUserIds.add(stringId);
          }
        }
      }
    } catch (e) {
      debugPrint('Error parsing reaction data for post $id: $e');
    }

    return Post(
      id: id,
      userId: data[fieldUserId] ?? '',
      taskId: data[fieldTaskId]?.toString(),
      imageUrl: data[fieldImageUrl],
      thumbnailUrl: data[fieldThumbnailUrl],
      taskName: data[fieldTaskName] ?? '今日のヒーロータスク',
      caption: data[fieldCaption],
      createdAt: (data[fieldCreatedAt] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data[fieldExpiresAt] as Timestamp?)?.toDate() ?? () {
        final now = DateTime.now();
        return DateTime(now.year, now.month, now.day + 1);
      }(),
      reactionCount: (data[fieldReactionCount] as num?)?.toInt() ?? 0,
      emojiReactedUserIds: emojiReactedUserIds,
      userReactions: userReactions,
      bgmUrl: data[fieldBgmUrl],
      bgmTitle: data[fieldBgmTitle],
      bgmArtist: data[fieldBgmArtist],
      bgmArtworkUrl: data[fieldBgmArtworkUrl],
      isSecret: data[fieldIsSecret] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Post &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          taskId == other.taskId &&
          imageUrl == other.imageUrl &&
          thumbnailUrl == other.thumbnailUrl &&
          taskName == other.taskName &&
          caption == other.caption &&
          createdAt == other.createdAt &&
          expiresAt == other.expiresAt &&
          reactionCount == other.reactionCount &&
          _listEquals(emojiReactedUserIds, other.emojiReactedUserIds) &&
          _mapEquals(userReactions, other.userReactions) &&
          bgmUrl == other.bgmUrl &&
          bgmTitle == other.bgmTitle &&
          bgmArtist == other.bgmArtist &&
          bgmArtworkUrl == other.bgmArtworkUrl &&
          isSecret == other.isSecret;

  @override
  int get hashCode =>
      id.hashCode ^
      userId.hashCode ^
      taskId.hashCode ^
      imageUrl.hashCode ^
      thumbnailUrl.hashCode ^
      taskName.hashCode ^
      caption.hashCode ^
      createdAt.hashCode ^
      expiresAt.hashCode ^
      reactionCount.hashCode ^
      emojiReactedUserIds.hashCode ^
      userReactions.hashCode ^
      bgmUrl.hashCode ^
      bgmTitle.hashCode ^
      bgmArtist.hashCode ^
      bgmArtworkUrl.hashCode ^
      isSecret.hashCode;

  bool _listEquals(List? a, List? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _mapEquals(Map? a, Map? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  /// Firestore 保存用の Map を生成します
  Map<String, dynamic> toFirestore() {
    return {
      fieldUserId: userId,
      if (taskId != null) fieldTaskId: taskId,
      fieldImageUrl: imageUrl,
      if (thumbnailUrl != null) fieldThumbnailUrl: thumbnailUrl,
      fieldTaskName: taskName,
      fieldCaption: caption,
      fieldCreatedAt: Timestamp.fromDate(createdAt),
      fieldExpiresAt: Timestamp.fromDate(expiresAt),
      fieldReactionCount: reactionCount,
      fieldEmojiReactedUserIds: emojiReactedUserIds,
      fieldUserReactions: userReactions,
      fieldBgmUrl: bgmUrl,
      fieldBgmTitle: bgmTitle,
      fieldBgmArtist: bgmArtist,
      fieldBgmArtworkUrl: bgmArtworkUrl,
      fieldIsSecret: isSecret,
    };
  }

  /// 指定したユーザーがこの投稿に絵文字リアクション済みかどうかを判定します
  /// (VFIRE '🔥' は含みません)
  bool hasEmojiReacted(String? uid) {
    if (uid == null) return false;
    
    // 冗長化ガード：userReactions マップと emojiReactedUserIds リストの両方を確認
    // 片方が空でももう片方にデータがあれば反応済みとみなす (永続性ハードニング)
    final reaction = userReactions[uid];
    final hasInMap = reaction != null && reaction != '🔥';
    final hasInList = emojiReactedUserIds.contains(uid);
    
    return hasInMap || hasInList;
  }

  /// 別のデータをマージした新しい Post オブジェクトを生成します
  Post copyWith({
    String? id,
    String? userId,
    String? taskId,
    String? imageUrl,
    String? thumbnailUrl,
    String? taskName,
    String? caption,
    DateTime? createdAt,
    DateTime? expiresAt,
    int? reactionCount,
    List<String>? emojiReactedUserIds,
    Map<String, String>? userReactions,
    String? bgmUrl,
    String? bgmTitle,
    String? bgmArtist,
    String? bgmArtworkUrl,
    bool? isSecret,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      taskId: taskId ?? this.taskId,
      imageUrl: imageUrl ?? this.imageUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      taskName: taskName ?? this.taskName,
      caption: caption ?? this.caption,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      reactionCount: reactionCount ?? this.reactionCount,
      emojiReactedUserIds: emojiReactedUserIds ?? this.emojiReactedUserIds,
      userReactions: userReactions ?? this.userReactions,
      bgmUrl: bgmUrl ?? this.bgmUrl,
      bgmTitle: bgmTitle ?? this.bgmTitle,
      bgmArtist: bgmArtist ?? this.bgmArtist,
      bgmArtworkUrl: bgmArtworkUrl ?? this.bgmArtworkUrl,
      isSecret: isSecret ?? this.isSecret,
    );
  }

  /// 期限までの残り時間を日本語テキストで返します
  String get remainingText {
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative) return '期限切れ';
    return remaining.inHours > 0
        ? 'あと${remaining.inHours}時間'
        : 'あと${remaining.inMinutes}分';
  }
}
