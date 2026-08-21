import 'package:flutter_test/flutter_test.dart';
import 'package:v_effect/models/app_notification.dart';

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
        'body': '諦める気はゼロ！りくさんが本日2つ目のタスクを完遂してストリーク復活へ加速中！熱いVFIREで後押ししましょう⚡️',
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
  });
}
