import 'package:cloud_firestore/cloud_firestore.dart';

/// 通知の種類
enum NotificationType {
  friendRequestReceived, // フレンドリクエスト受信
  friendRequestAccepted, // フレンドリクエスト承認
  wakeUpReminder,        // 起床時間リマインダー
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
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.toUid,
    required this.type,
    required this.title,
    required this.body,
    this.fromUid,
    this.relatedId,
    this.reactionCount = 0,
    this.isRead = false,
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
      reactionCount: data['reactionCount'] as int? ?? 0,
      isRead: data['isRead'] ?? false,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'toUid': toUid,
        'type': type.name,
        'title': title,
        'body': body,
        'fromUid': fromUid,
        'relatedId': relatedId,
        'reactionCount': reactionCount,
        'isRead': isRead,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
