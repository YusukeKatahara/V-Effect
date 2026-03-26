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
  });

  /// Firestore の DocumentSnapshot からモデルを生成します
  factory Post.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Post(
      id: doc.id,
      userId: data['userId'] ?? '',
      imageUrl: data['imageUrl'],
      taskName: data['taskName'] ?? '今日のヒーロータスク',
      caption: data['caption'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(hours: 24)),
      reactionCount: (data['reactionCount'] as num?)?.toInt() ?? 0,
      showTimestamp: data['showTimestamp'] ?? true,
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
