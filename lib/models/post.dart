import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore の posts コレクションに対応するデータモデル
class Post {
  final String id;
  final String userId;
  final String? imageUrl;
  final String taskName;
  final String? caption;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int reactionCount;
  final bool showTimestamp;
  final List<String> emojiReactedUserIds; // リアクションしたユーザーID
  final Map<String, String> userReactions; // uid -> 絵文字 (個別リアクション記録)

  const Post({
    required this.id,
    required this.userId,
    this.imageUrl,
    required this.taskName,
    this.caption,
    required this.createdAt,
    required this.expiresAt,
    this.reactionCount = 0,
    this.showTimestamp = true,
    this.emojiReactedUserIds = const [],
    this.userReactions = const {},
  });

  /// Firestore の DocumentSnapshot からモデルを生成します
  factory Post.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    // userReactions は {uid: emoji} の形式で保存
    final rawReactions = data['userReactions'] as Map<String, dynamic>?;
    final userReactions = rawReactions?.map(
          (key, value) => MapEntry(key, value.toString()),
        ) ??
        {};
    return Post(
      id: doc.id,
      userId: data['userId'] ?? '',
      imageUrl: data['imageUrl'],
      taskName: data['taskName'] ?? '今日のヒーロータスク',
      caption: data['caption'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(hours: 24)),
      reactionCount: (data['reactionCount'] as num?)?.toInt() ?? 0,
      showTimestamp: data['showTimestamp'] ?? true,
      emojiReactedUserIds: List<String>.from(data['emojiReactedUserIds'] ?? []),
      userReactions: userReactions,
    );
  }

  /// Firestore 保存用の Map を生成します
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'imageUrl': imageUrl,
      'taskName': taskName,
      'caption': caption,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'reactionCount': reactionCount,
      'showTimestamp': showTimestamp,
      'emojiReactedUserIds': emojiReactedUserIds,
      'userReactions': userReactions,
    };
  }

  /// 指定したユーザーがこの投稿に絵文字リアクション済みかどうかを判定します
  /// (VFIRE '🔥' は含みません)
  bool hasUserReacted(String? uid) {
    if (uid == null) return false;
    final reaction = userReactions[uid];
    return reaction != null && reaction != '🔥';
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
