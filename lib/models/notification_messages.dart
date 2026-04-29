import 'dart:math';
import 'app_notification.dart';

/// 通知メッセージのタイトルと本文のペア
class NotificationContent {
  final String title;
  final String body;

  const NotificationContent({required this.title, required this.body});
}

/// NotificationType ごとのメッセージテンプレートを一元管理するクラス
///
/// テンプレート内のプレースホルダー:
///   {username} - ユーザー名
///   {time}     - 時刻 (HH:MM)
///   {streak}   - 現在のストリーク日数
abstract class NotificationMessages {
  static final _random = Random();

  /// テンプレート定義
  static final _templates = {
    // ── ヒーロータスクリマインダー ──
    NotificationType.taskReminder: [
      _Template(
        title: 'V Alert',
        body: '「天才とは努力する凡才のことである」 Albert Einstein',
      ),
      _Template(
        title: 'V Alert',
        body: '「楽観的？悲観的？そんなことは知らん。やる。やり遂げる。必ずやり遂げると神に誓うんだ」 Elon Musk',
      ),
      _Template(
        title: 'V Alert',
        body: '「時間をかけることを恐れてはいけないよ。それは、いちばん洗練されたかたちでの復讐なんだ」 村上春樹',
      ),
      _Template(
        title: 'V Alert',
        body: '「貪欲であれ、愚かであれ」 Steve Jobs',
      ),
    ],

    // ── フレンドのヒーロータスク完了 ──
    NotificationType.friendTaskCompleted: [
      _Template(title: '仲間の一歩', body: '{username}さんも今日の自分に勝ちました'),
      _Template(title: '仲間の一歩', body: '{username}さんが今日も一歩を刻みました。同じ道を歩く仲間がいます'),
      _Template(title: '仲間の一歩', body: '{username}さんが自分との約束を果たしました'),
      _Template(title: '仲間の一歩', body: '{username}さんも戦っています。あなたは一人じゃない'),
      _Template(title: '仲間の一歩', body: '{username}さんが今日の勝利を手にしました'),
    ],

    // ── リアクション受信 ──
    NotificationType.reactionReceived: [
      _Template(
        title: '🔥 激しい炎！',
        body: '{username}さんがあなたの投稿で{count}回、激しい炎を燃やしてます!!',
      ),
    ],

    // ── フレンドリクエスト（機能的通知：単一テンプレート） ──
    NotificationType.friendRequestReceived: [
      _Template(title: 'フォローリクエスト', body: '{username} さんからフォローリクエストが届きました'),
    ],
    NotificationType.friendRequestAccepted: [
      _Template(title: 'リクエスト承認', body: '{username} さんがフォローリクエストを承認しました'),
    ],
  };

  /// 通知タイプ・パラメータからメッセージをランダムに生成します
  static NotificationContent build(
    NotificationType type, [
    Map<String, String> params = const {},
  ]) {
    final templates = _templates[type];
    if (templates == null || templates.isEmpty) {
      return NotificationContent(title: type.name, body: '');
    }

    final template = templates[_random.nextInt(templates.length)];

    return NotificationContent(
      title: _replacePlaceholders(template.title, params),
      body: _replacePlaceholders(template.body, params),
    );
  }

  static String _replacePlaceholders(String text, Map<String, String> params) {
    var result = text;
    for (final entry in params.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value);
    }
    return result;
  }
}

class _Template {
  final String title;
  final String body;

  const _Template({
    required this.title,
    required this.body,
  });
}
