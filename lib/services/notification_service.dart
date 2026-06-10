import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/app_notification.dart';
import '../models/notification_messages.dart';

/// 通知の作成・取得・削除を担当するサービス
///
/// Firestore データ構造:
///   notifications/{notificationId}
///     - toUid: string          通知先ユーザーの Auth UID
///     - type: string           通知種別 (NotificationType.name)
///     - title: string          通知タイトル
///     - body: string           通知本文
///     - fromUid: string?       送信元ユーザーの UID（フレンド系通知用）
///     - relatedId: string?     関連ドキュメント ID
///     - createdAt: Timestamp
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 通知を作成します（テンプレートからメッセージを自動生成）
  ///
  /// [params] はプレースホルダーの置換に使用されます。
  Future<void> createNotification({
    required String toUid,
    required NotificationType type,
    Map<String, String> params = const {},
    String? fromUid,
    String? relatedId,
    bool sendPush = true,
  }) async {
    final content = NotificationMessages.build(type, params);
    await _db.collection('notifications').add({
      'toUid': toUid,
      'type': type.name,
      'title': content.title,
      'body': content.body,
      'fromUid': fromUid,
      'relatedId': relatedId,
      'isRead': false,
      'sendPush': sendPush,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<AppNotification>> getMyNotifications() {
    final myUid = _auth.currentUser!.uid;
    final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));

    return _db
        .collection('notifications')
        .where('toUid', isEqualTo: myUid)
        .snapshots()
        .asyncMap((snap) async {
      final list = snap.docs
          .map((doc) => AppNotification.fromFirestore(doc))
          .where((n) => n.createdAt.isAfter(threeDaysAgo)) // 3日以内のみ
          .toList();

      // --- ここからシーズンタスク動的マージ処理 ---
      try {
        final userDoc = await _db.collection('users').doc(myUid).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final processedSeasonTaskIds = (userData['processedSeasonTaskIds'] as List?)?.map((e) => e.toString()).toList() ?? [];
          final now = DateTime.now();

          // 開催中のシーズンを取得
          final seasonsSnap = await _db
              .collection('seasons')
              .where('startDate', isLessThanOrEqualTo: now)
              .get();

          for (final seasonDoc in seasonsSnap.docs) {
            final seasonData = seasonDoc.data();
            final endDate = (seasonData['endDate'] as Timestamp?)?.toDate();
            
            // まだ処理されておらず、期間内（または endDate がない）のもの
            if (!processedSeasonTaskIds.contains(seasonDoc.id) && 
                (endDate == null || now.isBefore(endDate))) {
              final taskName = seasonData['taskName'] as String? ?? 'シーズンタスク';
              
              list.add(AppNotification(
                id: 'season_${seasonDoc.id}', // 疑似的なID
                toUid: myUid,
                type: NotificationType.seasonTaskDistributed,
                title: '期間限定タスク',
                body: '期間限定タスク「$taskName」が追加されました。',
                relatedId: seasonDoc.id, // seasonIdを持たせる
                isRead: false,
                isProcessed: false,
                sendPush: false,
                createdAt: (seasonData['startDate'] as Timestamp).toDate(),
              ));
            }
          }
        }
      } catch (e) {
        debugPrint('シーズンタスクマージエラー: $e');
      }
      // --- マージ処理終了 ---

      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// 未読の通知件数をリアルタイムで取得します
  Stream<int> getNotificationCount() {
    final myUid = _auth.currentUser!.uid;
    final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));

    return _db
        .collection('notifications')
        .where('toUid', isEqualTo: myUid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((doc) => AppNotification.fromFirestore(doc))
          .where((n) => n.createdAt.isAfter(threeDaysAgo))
          .length;
    });
  }

  /// 全ての未読通知を既読にします
  Future<void> markAllAsRead() async {
    final myUid = _auth.currentUser!.uid;
    final snap = await _db
        .collection('notifications')
        .where('toUid', isEqualTo: myUid)
        .where('isRead', isEqualTo: false)
        .get();
    
    if (snap.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  /// 通知を1件削除します
  Future<void> deleteNotification(String notificationId) async {
    await _db.collection('notifications').doc(notificationId).delete();
  }

  /// 関連ID(relatedId)に基づいて通知を削除します（フレンド申請処理後など）
  Future<void> deleteNotificationByRelatedId(String relatedId, {bool isSender = false}) async {
    final myUid = _auth.currentUser!.uid;
    final query = _db.collection('notifications').where('relatedId', isEqualTo: relatedId);
    final snap = await (isSender 
        ? query.where('fromUid', isEqualTo: myUid) 
        : query.where('toUid', isEqualTo: myUid)).get();
    
    if (snap.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// 特定の関連ID(フレンド申請IDなど)に紐づく通知を処理済みにします
  Future<void> markNotificationAsProcessedByRelatedId(String relatedId) async {
    final myUid = _auth.currentUser!.uid;
    final snap = await _db
        .collection('notifications')
        .where('toUid', isEqualTo: myUid)
        .where('relatedId', isEqualTo: relatedId)
        .get();
    
    if (snap.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isProcessed': true});
    }
    await batch.commit();
  }

  /// 全通知を削除します
  Future<void> deleteAllNotifications() async {
    final myUid = _auth.currentUser!.uid;
    final snap = await _db
        .collection('notifications')
        .where('toUid', isEqualTo: myUid)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }


}
