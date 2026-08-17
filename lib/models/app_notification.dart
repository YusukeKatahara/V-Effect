import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// 通知の種類
enum NotificationType {
  friendRequestReceived, // フレンドリクエスト受信
  friendRequestAccepted, // フレンドリクエスト承認
  taskReminder,          // ヒーロータスク時間リマインダー
  reactionReceived,      // リアクション受信 (🔥)
  friendTaskCompleted,   // フレンドのヒーロータスク完了
  streakCelebration,     // ストリーク達成祝い
  streakWarning,         // ストリーク危機通知
  badgeAcquired,         // バッジ獲得通知
  seasonTaskDistributed, // シーズンタスク配布通知
  seasonTaskReceived,    // シーズンタスク受信
  seasonTaskPushOnly,    // シーズンタスクPush専用
  rescueRequested,       // 救済SOS通知（救済中の投稿）
  rescueRevived,         // 救済完全復活・感謝通知（150 VFIRE達成）
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
  final bool isProcessed; // 処理済みかどうか
  final bool sendPush; // プッシュ通知を送るかどうかのフラグ
  final DateTime createdAt;

  // ── フィールド名定数 ──
  static const String fieldToUid = 'toUid';
  static const String fieldType = 'type';
  static const String fieldTitle = 'title';
  static const String fieldBody = 'body';
  static const String fieldFromUid = 'fromUid';
  static const String fieldRelatedId = 'relatedId';
  static const String fieldReactionCount = 'reactionCount';
  static const String fieldEmoji = 'emoji';
  static const String fieldIsRead = 'isRead';
  static const String fieldIsProcessed = 'isProcessed';
  static const String fieldSendPush = 'sendPush';
  static const String fieldCreatedAt = 'createdAt';

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
    this.isProcessed = false,
    this.sendPush = true,
    required this.createdAt,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return AppNotification.fromMap(doc.id, data ?? {});
  }

  factory AppNotification.fromMap(String id, Map<String, dynamic> data) {
    try {
      return AppNotification(
        id: id,
        toUid: data[fieldToUid]?.toString() ?? '',
        type: NotificationType.values.firstWhere(
          (e) => e.name == data[fieldType],
          orElse: () => NotificationType.friendRequestReceived,
        ),
        title: data[fieldTitle]?.toString() ?? '',
        body: data[fieldBody]?.toString() ?? '',
        fromUid: data[fieldFromUid]?.toString(),
        relatedId: data[fieldRelatedId]?.toString(),
        emoji: data[fieldEmoji]?.toString(),
        reactionCount: (data[fieldReactionCount] as num?)?.toInt() ?? 0,
        isRead: data[fieldIsRead] == true,
        isProcessed: data[fieldIsProcessed] == true,
        sendPush: data[fieldSendPush] ?? true,
        createdAt: (data[fieldCreatedAt] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error parsing AppNotification $id: $e');
      return AppNotification(
        id: id,
        toUid: '',
        type: NotificationType.friendRequestReceived,
        title: 'Error loading notification',
        body: '',
        createdAt: DateTime.now(),
      );
    }
  }

  Map<String, dynamic> toFirestore() => {
        fieldToUid: toUid,
        fieldType: type.name,
        fieldTitle: title,
        fieldBody: body,
        if (fromUid != null) fieldFromUid: fromUid,
        if (relatedId != null) fieldRelatedId: relatedId,
        if (emoji != null) fieldEmoji: emoji,
        fieldReactionCount: reactionCount,
        fieldIsRead: isRead,
        fieldIsProcessed: isProcessed,
        fieldSendPush: sendPush,
        fieldCreatedAt: FieldValue.serverTimestamp(),
      };
}
