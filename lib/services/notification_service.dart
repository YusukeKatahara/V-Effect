import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  // 重複実行防止フラグ
  bool _isCheckingReminders = false;

  /// 通知を作成します（テンプレートからメッセージを自動生成）
  ///
  /// [params] はプレースホルダーの置換に使用されます。
  /// [context] は条件付きテンプレートの選択に使用されます。
  Future<void> createNotification({
    required String toUid,
    required NotificationType type,
    Map<String, String> params = const {},
    NotificationContext context = const NotificationContext(),
    String? fromUid,
    String? relatedId,
  }) async {
    final content = NotificationMessages.build(type, params, context);
    await _db.collection('notifications').add({
      'toUid': toUid,
      'type': type.name,
      'title': content.title,
      'body': content.body,
      'fromUid': fromUid,
      'relatedId': relatedId,
      'isRead': false,
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
        .map((snap) {
      final list = snap.docs
          .map((doc) => AppNotification.fromFirestore(doc))
          .where((n) => n.createdAt.isAfter(threeDaysAgo)) // 3日以内のみ
          .toList();
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

  Future<void> checkAndCreateTimeReminders({int? streak}) async {
    if (_isCheckingReminders) return;
    _isCheckingReminders = true;

    try {
      final myUid = _auth.currentUser?.uid;
      if (myUid == null) return;
      
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      int streakNum;
      if (streak != null) {
        streakNum = streak;
      } else {
        final userSnap = await _db.collection('users').doc(myUid).get();
        streakNum = ((userSnap.data()?['streak'] as num?) ?? 0).toInt();
      }
      final streakStr = streakNum.toString();

      final privateSnap = await _db
          .collection('users')
          .doc(myUid)
          .collection('private')
          .doc('data')
          .get();
      if (!privateSnap.exists) return;
      final data = privateSnap.data()!;
      final taskTime = data['taskTime'] as String?;

      final ctx = NotificationContext(streak: streakNum);

      if (taskTime != null) {
        await _createTimeReminderIfNeeded(
          uid: myUid,
          timeStr: taskTime,
          todayStr: todayStr,
          now: now,
          type: NotificationType.taskReminder,
          params: {'time': taskTime, 'streak': streakStr},
          context: ctx,
        );
      }
    } finally {
      _isCheckingReminders = false;
    }
  }

  Future<void> _createTimeReminderIfNeeded({
    required String uid,
    required String timeStr,
    required String todayStr,
    required DateTime now,
    required NotificationType type,
    required Map<String, String> params,
    NotificationContext context = const NotificationContext(),
  }) async {
    // timeStr は "HH:MM" 形式を想定
    final parts = timeStr.split(':');
    if (parts.length != 2) return;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return;

    // まだ設定時刻を過ぎていなければ通知しない
    if (now.hour < hour || (now.hour == hour && now.minute < minute)) return;

    // 今日既に同じ種類の通知を作成済みかチェック
    final todayStart = DateTime(now.year, now.month, now.day);
    final existing = await _db
        .collection('notifications')
        .where('toUid', isEqualTo: uid)
        .where('type', isEqualTo: type.name)
        .get();

    final alreadyCreated = existing.docs.any((doc) {
      final createdAt = doc.data()['createdAt'];
      if (createdAt is Timestamp) {
        return createdAt.toDate().isAfter(todayStart);
      }
      return false; // null などの場合（ローカルの書き込み待ちなど）
    });

    if (alreadyCreated) return;

    await createNotification(
      toUid: uid,
      type: type,
      params: params,
      context: context,
    );
  }
}
