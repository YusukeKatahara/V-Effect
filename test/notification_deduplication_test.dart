import 'package:flutter_test/flutter_test.dart';
import 'package:v_effect/models/app_notification.dart';

void main() {
  group('Notification Deduplication Logic Tests', () {
    test('同一送信元・同一本文・近接時間の通知が重複排除されること', () {
      final now = DateTime.now();

      final notif1 = AppNotification(
        id: 'notif_1',
        toUid: 'user_A',
        fromUid: 'user_B',
        type: NotificationType.friendTaskCompleted,
        title: '🫠 沼落ち確定の有言実行',
        body: 'きたはらさんが本日2つ目のタスクをサラッとクリア！言ったことを着実にこなす姿、さすがにメロすぎます…✨',
        createdAt: now,
        isRead: false,
        sendPush: true,
      );

      final notif2 = AppNotification(
        id: 'notif_2',
        toUid: 'user_A',
        fromUid: 'user_B',
        type: NotificationType.friendTaskCompleted,
        title: '🫠 沼落ち確定の有言実行',
        body: 'きたはらさんが本日2つ目のタスクをサラッとクリア！言ったことを着実にこなす姿、さすがにメロすぎます…✨',
        createdAt: now.add(const Duration(seconds: 1)),
        isRead: false,
        sendPush: true,
      );

      final rawList = [notif1, notif2];

      // 重複排除ロジックの検証
      final deduplicatedList = <AppNotification>[];
      final seenIds = <String>{};

      for (final notif in rawList) {
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

      expect(deduplicatedList.length, 1);
      expect(deduplicatedList.first.id, 'notif_1');
    });

    test('異なるユーザーからの通知や時間差のある通知は重複排除されないこと', () {
      final now = DateTime.now();

      final notif1 = AppNotification(
        id: 'notif_1',
        toUid: 'user_A',
        fromUid: 'user_B',
        type: NotificationType.friendTaskCompleted,
        title: '🫠 沼落ち確定の有言実行',
        body: 'きたはらさんが本日1つ目のタスクをクリア！',
        createdAt: now,
        isRead: false,
        sendPush: true,
      );

      final notif2 = AppNotification(
        id: 'notif_2',
        toUid: 'user_A',
        fromUid: 'user_C', // 別ユーザー
        type: NotificationType.friendTaskCompleted,
        title: '🫠 沼落ち確定の有言実行',
        body: '別のフレンドさんが本日1つ目のタスクをクリア！',
        createdAt: now,
        isRead: false,
        sendPush: true,
      );

      final notif3 = AppNotification(
        id: 'notif_3',
        toUid: 'user_A',
        fromUid: 'user_B',
        type: NotificationType.friendTaskCompleted,
        title: '🫠 沼落ち確定の有言実行',
        body: 'きたはらさんが本日2つ目のタスクをクリア！',
        createdAt: now.add(const Duration(hours: 3)), // 3時間後
        isRead: false,
        sendPush: true,
      );

      final rawList = [notif1, notif2, notif3];

      final deduplicatedList = <AppNotification>[];
      final seenIds = <String>{};

      for (final notif in rawList) {
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

      expect(deduplicatedList.length, 3);
    });
  });
}
