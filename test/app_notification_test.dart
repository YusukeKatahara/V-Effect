import 'package:flutter_test/flutter_test.dart';
import 'package:v_effect/models/app_notification.dart';
import 'package:v_effect/models/app_user.dart';

void main() {
  group('AppNotification parsing tests', () {
    test('rescueRequested is parsed correctly when type matches', () {
      final notif = AppNotification.fromMap('id1', {
        'toUid': 'userA',
        'fromUid': 'userB',
        'type': 'rescueRequested',
        'title': '🤝 りくが立ち上がった！',
        'body': 'りくが諦めずに投稿！合計150VFIREでりくさんのストリークが復活します（まるで不死鳥のように！）',
      });

      expect(notif.type, NotificationType.rescueRequested);
    });

    test('rescueRequested is parsed via safety net when type is missing or unknown', () {
      final notif = AppNotification.fromMap('id2', {
        'toUid': 'userA',
        'fromUid': 'userB',
        'type': 'unknownType',
        'title': '🤝 りくが立ち上がった！',
        'body': 'りくが諦めずに投稿！合計150VFIREでりくさんのストリークが復活します（まるで不死鳥のように！）',
      });

      expect(notif.type, NotificationType.rescueRequested);
    });

    test('rescueRevived is parsed correctly', () {
      final notif = AppNotification.fromMap('id3', {
        'toUid': 'userA',
        'fromUid': 'userB',
        'type': 'rescueRevived',
        'title': '🎉 りくさんのストリークが復活しました！',
        'body': 'あなたの熱いVFIREのおかげで、りくさんの連続記録が息を吹き返しました！「応援ありがとう！🔥」',
      });

      expect(notif.type, NotificationType.rescueRevived);
    });

    test('unknown type falls back to friendTaskCompleted instead of friendRequestReceived', () {
      final notif = AppNotification.fromMap('id4', {
        'toUid': 'userA',
        'fromUid': 'userB',
        'type': 'nonExistentType',
        'title': 'Some Title',
        'body': 'Some generic message',
      });

      expect(notif.type, NotificationType.friendTaskCompleted);
      expect(notif.type, isNot(NotificationType.friendRequestReceived));
    });

    test('multiple rescue notifications are parsed correctly via safety net', () {
      final notif = AppNotification.fromMap('id6', {
        'toUid': 'userA',
        'fromUid': 'userB',
        'type': 'unknownType',
        'title': '🔥 りくの猛追！本日2つ目の達成',
        'body': '不屈の闘志で本日2回目の投稿！あと100VFIREで完全覚醒へ',
      });

      expect(notif.type, NotificationType.rescueRequested);
    });

    test('friendRequestReceived is only parsed when explicit', () {
      final notif = AppNotification.fromMap('id5', {
        'toUid': 'userA',
        'fromUid': 'userB',
        'type': 'friendRequestReceived',
        'title': 'フレンド申請',
        'body': 'フレンド申請が届きました',
      });

      expect(notif.type, NotificationType.friendRequestReceived);
    });

    test('directMessage is parsed correctly when type matches', () {
      final notif = AppNotification.fromMap('id7', {
        'toUid': 'userA',
        'fromUid': 'userB',
        'type': 'directMessage',
        'title': 'りく',
        'body': 'こんにちは！',
        'relatedId': 'chat_123',
        'reactionCount': 3,
      });

      expect(notif.type, NotificationType.directMessage);
      expect(notif.reactionCount, 3);
      expect(notif.relatedId, 'chat_123');
    });

    test('directMessage aliases (dm, direct_message) are parsed correctly', () {
      final notifDm = AppNotification.fromMap('id8', {
        'toUid': 'userA',
        'fromUid': 'userB',
        'type': 'dm',
        'title': 'りく',
        'body': 'テストメッセージ',
      });
      expect(notifDm.type, NotificationType.directMessage);

      final notifSnake = AppNotification.fromMap('id9', {
        'toUid': 'userA',
        'fromUid': 'userB',
        'type': 'direct_message',
        'title': 'りく',
        'body': 'テストメッセージ2',
      });
      expect(notifSnake.type, NotificationType.directMessage);
    });

    test('reactionReceived notification correctly parses sendPush false for in-app-only alerts', () {
      final notif = AppNotification.fromMap('reaction_1', {
        'toUid': 'userA',
        'fromUid': 'userB',
        'relatedId': 'post_123',
        'type': 'reactionReceived',
        'emoji': '🔥',
        'reactionCount': 10,
        'title': '⚡️ V EFFECT 発動！',
        'body': 'あなたの「タスク」が、userBさんのモチベーションに火をつけました！10回のV FIRE🔥',
        'sendPush': false,
        'isRead': false,
      });

      expect(notif.type, NotificationType.reactionReceived);
      expect(notif.sendPush, isFalse);
      expect(notif.isRead, isFalse);
      expect(notif.reactionCount, 10);
      expect(notif.emoji, '🔥');
    });

    test('reactionReceived notification toFirestore preserves sendPush false', () {
      final notif = AppNotification(
        id: 'reaction_1',
        toUid: 'userA',
        fromUid: 'userB',
        relatedId: 'post_123',
        type: NotificationType.reactionReceived,
        emoji: '🔥',
        reactionCount: 15,
        title: '⚡️ V EFFECT 発動！',
        body: 'あなたの「タスク」が、userBさんのモチベーションに火をつけました！',
        sendPush: false,
        isRead: false,
        createdAt: DateTime.now(),
      );

      final map = notif.toFirestore();
      expect(map[AppNotification.fieldSendPush], isFalse);
      expect(map[AppNotification.fieldType], 'reactionReceived');
      expect(map[AppNotification.fieldIsRead], isFalse);
      expect(map[AppNotification.fieldReactionCount], 15);
    });

    test('legacy reactionReceived notification without sendPush defaults to true in client parser', () {
      final notif = AppNotification.fromMap('legacy_reaction', {
        'toUid': 'userA',
        'fromUid': 'userB',
        'relatedId': 'post_123',
        'type': 'reactionReceived',
        'reactionCount': 1,
        'title': 'リアクション',
        'body': 'リアクションが届きました',
      });

      expect(notif.type, NotificationType.reactionReceived);
      expect(notif.sendPush, isTrue); // レガシーデータはクライアントパーサでデフォルトtrue
    });
  });

  group('AppUser DM notification settings tests', () {
    test('default values are true when omitted', () {
      const user = AppUser(uid: 'user_123');
      expect(user.dmNotifications, isTrue);
      expect(user.dmMessagePreview, isTrue);

      final parsed = AppUser.fromMap('user_123', {});
      expect(parsed.dmNotifications, isTrue);
      expect(parsed.dmMessagePreview, isTrue);
    });

    test('parses dmNotifications and dmMessagePreview correctly from map', () {
      final user = AppUser.fromMap('user_123', {
        AppUser.fieldDmNotifications: false,
        AppUser.fieldDmMessagePreview: false,
      });
      expect(user.dmNotifications, isFalse);
      expect(user.dmMessagePreview, isFalse);

      final firestoreMap = user.toFirestore();
      expect(firestoreMap[AppUser.fieldDmNotifications], isFalse);
      expect(firestoreMap[AppUser.fieldDmMessagePreview], isFalse);
    });

    test('copyWith updates dmNotifications and dmMessagePreview', () {
      const user = AppUser(uid: 'user_123');
      final updated = user.copyWith(
        dmNotifications: false,
        dmMessagePreview: false,
      );
      expect(updated.dmNotifications, isFalse);
      expect(updated.dmMessagePreview, isFalse);
    });
  });
}
