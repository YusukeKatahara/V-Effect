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

  /// 通知タイプを安全にパースするヘルパーメソッド
  static NotificationType _parseType(
    dynamic rawType, {
    String? title,
    String? body,
  }) {
    final typeStr = rawType?.toString();
    final b = body ?? '';
    final t = title ?? '';

    // 1. 本文やタイトルから救済通知を判定するセーフティネット
    // （過去データや表記揺れで type が不一致の場合でも救済通知として正しく解釈）
    if (b.contains('150VFIRE') ||
        b.contains('不死鳥') ||
        b.contains('ストリーク復活へ') ||
        b.contains('不屈の闘志') ||
        b.contains('完全覚醒') ||
        t.contains('立ち上がった') ||
        t.contains('has risen') ||
        t.contains('猛追') ||
        t.contains('完全覚醒') ||
        t.contains('不屈の闘志') ||
        t.contains('不死鳥') ||
        t.contains('on the Chase') ||
        t.contains('Wings of the Phoenix') ||
        t.contains('Fully Awakened') ||
        t.contains('Unyielding Spirit')) {
      return NotificationType.rescueRequested;
    }
    if (b.contains('ストリークが復活') ||
        b.contains('streak has been revived') ||
        t.contains('ストリークが復活') ||
        t.contains('Streak Revived')) {
      return NotificationType.rescueRevived;
    }

    // 2. 表記揺れ・エイリアスのマッピング
    if (typeStr != null) {
      if (typeStr == 'rescueRequested' ||
          typeStr == 'rescue_requested' ||
          typeStr == 'rescue' ||
          typeStr == 'streak_relief' ||
          typeStr == 'streakRelief') {
        return NotificationType.rescueRequested;
      }
      if (typeStr == 'rescueRevived' ||
          typeStr == 'rescue_revived' ||
          typeStr == 'streak_revived') {
        return NotificationType.rescueRevived;
      }

      for (final val in NotificationType.values) {
        if (val.name == typeStr) {
          return val;
        }
      }
    }

    // 3. 不明なタイプの場合、安全な汎用タイプ（friendTaskCompleted）にフォールバック
    // ※ 承認・削除ボタンが出る friendRequestReceived にフォールバックさせてはならない
    return NotificationType.friendTaskCompleted;
  }

  factory AppNotification.fromMap(String id, Map<String, dynamic> data) {
    try {
      final title = data[fieldTitle]?.toString() ?? '';
      final body = data[fieldBody]?.toString() ?? '';
      final type = _parseType(
        data[fieldType],
        title: title,
        body: body,
      );

      return AppNotification(
        id: id,
        toUid: data[fieldToUid]?.toString() ?? '',
        type: type,
        title: title,
        body: body,
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
        type: NotificationType.friendTaskCompleted,
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
