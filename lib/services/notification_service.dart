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

  CollectionReference<AppNotification> get _notificationsRef =>
      _db.collection('notifications').withConverter<AppNotification>(
        fromFirestore: (snapshot, _) => AppNotification.fromFirestore(snapshot),
        toFirestore: (notification, _) => notification.toFirestore(),
      );

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
    String language = 'ja';
    try {
      final userDoc = await _db.collection('users').doc(toUid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null && userData['language'] != null) {
          language = userData['language'].toString();
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch receiver language setting: $e');
    }

    final content = NotificationMessages.build(type, params, language);
    final notification = AppNotification(
      id: '',
      toUid: toUid,
      type: type,
      title: content.title,
      body: content.body,
      fromUid: fromUid,
      relatedId: relatedId,
      isRead: false,
      sendPush: sendPush,
      createdAt: DateTime.now(),
    );
    await _notificationsRef.add(notification);
  }

  Stream<List<AppNotification>> getMyNotifications() {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return Stream.value([]);
    final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));

    return _notificationsRef
        .where(AppNotification.fieldToUid, isEqualTo: myUid)
        .snapshots()
        .asyncMap((snap) async {
      final list = snap.docs
          .map((doc) => doc.data())
          .where((n) {
            // FCMプッシュ通知の配信用として作成された実体レコードは通知画面の二重表示を防ぐために除外
            final isSeasonPushOnly = n.type == NotificationType.seasonTaskReceived || n.type == NotificationType.seasonTaskPushOnly;
            return n.createdAt.isAfter(threeDaysAgo) && !isSeasonPushOnly;
          })
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

      // 🚀 【重複排除 (Deduplication)】
      // 同一ID、同一関連ID(relatedId)、または同一送信元・同一本文・近接日時の重複通知を排除
      final deduplicatedList = <AppNotification>[];
      final seenIds = <String>{};

      for (final notif in list) {
        if (notif.id.isNotEmpty && seenIds.contains(notif.id)) {
          continue;
        }

        final isDuplicate = deduplicatedList.any((existing) {
          final isSameFrom = existing.fromUid != null && existing.fromUid == notif.fromUid;
          final isSameType = existing.type == notif.type;
          final isSameBody = existing.body == notif.body;
          final isSameRelated = existing.relatedId != null &&
              notif.relatedId != null &&
              existing.relatedId == notif.relatedId;
          final isCloseInTime =
              existing.createdAt.difference(notif.createdAt).abs().inMinutes < 5;

          return (isSameRelated && isSameType) ||
              (isSameFrom && isSameType && isSameBody && isCloseInTime);
        });

        if (!isDuplicate) {
          if (notif.id.isNotEmpty) seenIds.add(notif.id);
          deduplicatedList.add(notif);
        }
      }

      return deduplicatedList;
    }).handleError((e) {
      debugPrint('getMyNotifications error: $e');
      return <AppNotification>[];
    });
  }

  /// 未読の通知件数をリアルタイムで取得します
  Stream<int> getNotificationCount() {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return Stream.value(0);
    final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));

    return _notificationsRef
        .where(AppNotification.fieldToUid, isEqualTo: myUid)
        .where(AppNotification.fieldIsRead, isEqualTo: false)
        .snapshots()
        .map((snap) {
      final unreadList = snap.docs
          .map((doc) => doc.data())
          .where((n) {
            final isSeasonPushOnly = n.type == NotificationType.seasonTaskReceived || n.type == NotificationType.seasonTaskPushOnly;
            return n.createdAt.isAfter(threeDaysAgo) && !isSeasonPushOnly;
          })
          .toList();

      final deduplicatedUnread = <AppNotification>[];
      for (final notif in unreadList) {
        final isDuplicate = deduplicatedUnread.any((existing) {
          final isSameFrom = existing.fromUid != null && existing.fromUid == notif.fromUid;
          final isSameType = existing.type == notif.type;
          final isSameBody = existing.body == notif.body;
          final isSameRelated = existing.relatedId != null &&
              notif.relatedId != null &&
              existing.relatedId == notif.relatedId;
          final isCloseInTime =
              existing.createdAt.difference(notif.createdAt).abs().inMinutes < 5;

          return (isSameRelated && isSameType) ||
              (isSameFrom && isSameType && isSameBody && isCloseInTime);
        });

        if (!isDuplicate) {
          deduplicatedUnread.add(notif);
        }
      }

      return deduplicatedUnread.length;
    }).handleError((e) {
      debugPrint('getNotificationCount error: $e');
      return 0;
    });
  }

  /// 全ての未読通知を既読にします
  Future<void> markAllAsRead() async {
    final myUid = _auth.currentUser!.uid;
    final snap = await _notificationsRef
        .where(AppNotification.fieldToUid, isEqualTo: myUid)
        .where(AppNotification.fieldIsRead, isEqualTo: false)
        .get();
    
    if (snap.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {AppNotification.fieldIsRead: true});
    }
    await batch.commit();
  }

  /// 通知を1件削除します
  Future<void> deleteNotification(String notificationId) async {
    await _notificationsRef.doc(notificationId).delete();
  }

  /// 関連ID(relatedId)に基づいて通知を削除します（フレンド申請処理後など）
  Future<void> deleteNotificationByRelatedId(String relatedId, {bool isSender = false}) async {
    final myUid = _auth.currentUser!.uid;
    final query = _notificationsRef.where(AppNotification.fieldRelatedId, isEqualTo: relatedId);
    final snap = await (isSender 
        ? query.where(AppNotification.fieldFromUid, isEqualTo: myUid) 
        : query.where(AppNotification.fieldToUid, isEqualTo: myUid)).get();
    
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
    final snap = await _notificationsRef
        .where(AppNotification.fieldToUid, isEqualTo: myUid)
        .where(AppNotification.fieldRelatedId, isEqualTo: relatedId)
        .get();
    
    if (snap.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {AppNotification.fieldIsProcessed: true});
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
