import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_notification.dart';

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
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 通知を作成します
  Future<void> createNotification({
    required String toUid,
    required NotificationType type,
    required String title,
    required String body,
    String? fromUid,
    String? relatedId,
  }) async {
    await _db.collection('notifications').add({
      'toUid': toUid,
      'type': type.name,
      'title': title,
      'body': body,
      'fromUid': fromUid,
      'relatedId': relatedId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// 自分の通知一覧を取得します（リアルタイム）
  Stream<List<AppNotification>> getMyNotifications() {
    final myUid = _auth.currentUser!.uid;
    return _db
        .collection('notifications')
        .where('toUid', isEqualTo: myUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => AppNotification.fromFirestore(doc))
            .toList());
  }

  /// 通知の件数をリアルタイムで取得します
  Stream<int> getNotificationCount() {
    return getMyNotifications().map((list) => list.length);
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

  /// 起床時間・タスク時間のリマインダー通知を生成します
  /// アプリ起動時やホーム画面表示時に呼び出してください
  Future<void> checkAndCreateTimeReminders() async {
    final myUid = _auth.currentUser!.uid;
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // プライベートデータから時間を取得
    final privateSnap = await _db
        .collection('users')
        .doc(myUid)
        .collection('private')
        .doc('data')
        .get();
    if (!privateSnap.exists) return;
    final data = privateSnap.data()!;
    final wakeUpTime = data['wakeUpTime'] as String?;
    final taskTime = data['taskTime'] as String?;

    if (wakeUpTime != null) {
      await _createTimeReminderIfNeeded(
        uid: myUid,
        timeStr: wakeUpTime,
        todayStr: todayStr,
        now: now,
        type: NotificationType.wakeUpReminder,
        title: '起床時間です',
        body: '$wakeUpTime になりました。今日も頑張りましょう！',
      );
    }

    if (taskTime != null) {
      await _createTimeReminderIfNeeded(
        uid: myUid,
        timeStr: taskTime,
        todayStr: todayStr,
        now: now,
        type: NotificationType.taskReminder,
        title: 'タスクの時間です',
        body: '$taskTime になりました。タスクに取り組みましょう！',
      );
    }
  }

  Future<void> _createTimeReminderIfNeeded({
    required String uid,
    required String timeStr,
    required String todayStr,
    required DateTime now,
    required NotificationType type,
    required String title,
    required String body,
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
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return;

    await createNotification(
      toUid: uid,
      type: type,
      title: title,
      body: body,
    );
  }
}
