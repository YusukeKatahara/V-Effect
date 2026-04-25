import 'package:cloud_firestore/cloud_firestore.dart';

/// 通知の種類
enum NotificationType {
  friendRequestReceived, // フレンドリクエスト受信
  friendRequestAccepted, // フレンドリクエスト承認
  taskReminder,          // ヒーロータスク時間リマインダー
  reactionReceived,      // リアクション受信 (🔥)
  friendTaskCompleted,   // フレンドのヒーロータスク完了
}

/// Firestore の notifications コレクションに対応するデータモデル
class AppNotification {
  final String id;
  final String toUid;
  final NotificationType type;
  final String title;
  final String body;
  final String? fromUid;
  final String? relatedId;
  final int reactionCount;
  final String? emoji; // 絵文字リアクション用
  final bool isRead;
  final bool sendPush; // プッシュ通知を送るかどうかのフラグ
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.toUid,
    required this.type,
    required this.title,
    required this.body,
    this.fromUid,
    this.relatedId,
    this.emoji,
    this.reactionCount = 0,
    this.isRead = false,
    this.sendPush = true,
    required this.createdAt,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      toUid: data['toUid'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => NotificationType.friendRequestReceived,
      ),
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      fromUid: data['fromUid'],
      relatedId: data['relatedId'],
      emoji: data['emoji'],
      reactionCount: data['reactionCount'] as int? ?? 0,
      isRead: data['isRead'] ?? false,
      sendPush: data['sendPush'] ?? true,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'toUid': toUid,
        'type': type.name,
        'title': title,
        'body': body,
        'fromUid': fromUid,
        'relatedId': relatedId,
        'emoji': emoji,
        'reactionCount': reactionCount,
        'isRead': isRead,
        'sendPush': sendPush,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
