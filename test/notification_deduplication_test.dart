import 'package:flutter_test/flutter_test.dart';
import 'package:v_effect/models/app_notification.dart';
import 'package:v_effect/services/notification_service.dart';

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

      expect(NotificationService.isDuplicateNotification(notif1, notif2), isTrue);
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

      expect(NotificationService.isDuplicateNotification(notif1, notif2), isFalse);
      expect(NotificationService.isDuplicateNotification(notif1, notif3), isFalse);
    });

    test('同一投稿に対する異なるユーザーからのリアクション（絵文字・V FIRE）が重複排除されないこと', () {
      final now = DateTime.now();

      // ユーザーBからのV FIRE (emoji: null)
      final vfireFromB = AppNotification(
        id: 'vfire_B',
        toUid: 'user_A',
        fromUid: 'user_B',
        relatedId: 'post_100', // 同一投稿
        type: NotificationType.reactionReceived,
        title: 'V FIRE',
        body: 'user_BさんからV FIREが届きました',
        createdAt: now,
        isRead: false,
        sendPush: false,
      );

      // ユーザーCからの絵文字リアクション (emoji: 🎉)
      final emojiFromC = AppNotification(
        id: 'emoji_C',
        toUid: 'user_A',
        fromUid: 'user_C',
        relatedId: 'post_100', // 同一投稿
        type: NotificationType.reactionReceived,
        emoji: '🎉',
        title: '✨ リアクション',
        body: 'user_Cさんが「🎉」を贈りました！',
        createdAt: now.add(const Duration(seconds: 10)),
        isRead: false,
        sendPush: false,
      );

      // 送信者が異なるため重複と判定されないこと（以前のバグではここで消去されていた）
      expect(NotificationService.isDuplicateNotification(vfireFromB, emojiFromC), isFalse);
    });

    test('同一ユーザーからの同一投稿への「V FIRE」と「絵文字」が重複排除されないこと', () {
      final now = DateTime.now();

      final vfireFromB = AppNotification(
        id: 'vfire_B',
        toUid: 'user_A',
        fromUid: 'user_B',
        relatedId: 'post_100',
        type: NotificationType.reactionReceived,
        title: 'V FIRE',
        body: 'user_BさんからV FIREが届きました',
        createdAt: now,
        isRead: false,
        sendPush: false,
      );

      final emojiFromB = AppNotification(
        id: 'emoji_B',
        toUid: 'user_A',
        fromUid: 'user_B',
        relatedId: 'post_100',
        type: NotificationType.reactionReceived,
        emoji: '👏',
        title: '✨ リアクション',
        body: 'user_Bさんが「👏」を贈りました！',
        createdAt: now.add(const Duration(seconds: 5)),
        isRead: false,
        sendPush: false,
      );

      // V FIREと絵文字は種類が異なるため重複と判定されないこと
      expect(NotificationService.isDuplicateNotification(vfireFromB, emojiFromB), isFalse);
    });

    test('同一ユーザー・同一投稿・同一絵文字の通知は重複排除されること', () {
      final now = DateTime.now();

      final emoji1 = AppNotification(
        id: 'emoji_1',
        toUid: 'user_A',
        fromUid: 'user_B',
        relatedId: 'post_100',
        type: NotificationType.reactionReceived,
        emoji: '🔥',
        title: '✨ リアクション',
        body: 'user_Bさんが「🔥」を贈りました！',
        createdAt: now,
        isRead: false,
        sendPush: false,
      );

      final emoji2 = AppNotification(
        id: 'emoji_2',
        toUid: 'user_A',
        fromUid: 'user_B',
        relatedId: 'post_100',
        type: NotificationType.reactionReceived,
        emoji: '🔥',
        title: '✨ リアクション',
        body: 'user_Bさんが「🔥」を贈りました！',
        createdAt: now.add(const Duration(seconds: 2)),
        isRead: false,
        sendPush: false,
      );

      // 送信者・投稿・絵文字がすべて一致するため重複と判定されること
      expect(NotificationService.isDuplicateNotification(emoji1, emoji2), isTrue);
    });
  });
}
