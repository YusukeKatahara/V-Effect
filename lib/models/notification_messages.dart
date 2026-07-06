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

  /// テンプレート定義 (日本語)
  static final _templatesJa = {
    // ── ヒーロータスクリマインダー ──
    NotificationType.taskReminder: [
      _Template(
        title: 'V Alert',
        body: '「天才とは努力する凡才のことである」 - Albert Einstein',
      ),
      _Template(
        title: 'V Alert',
        body: '「楽観的？悲観的？そんなことは知らん。やる。やり遂げる。必ずやり遂げると神に誓うんだ」 - Elon Musk',
      ),
      _Template(
        title: 'V Alert',
        body: '「時間をかけることを恐れてはいけないよ。それは、いちばん洗練されたかたちでの復讐んだ」 - 村上春樹',
      ),
      _Template(
        title: 'V Alert',
        body: '「貪欲であれ、愚かであれ」 - Steve Jobs',
      ),
    ],

    // ── リアクション受信 ──
    NotificationType.reactionReceived: [
      _Template(
        title: '🔥 激しい炎！',
        body: '{username}さんがあなたの投稿で{count}回、激しい炎を燃やしてます!!',
      ),
    ],
  };

  /// テンプレート定義 (英語)
  static final _templatesEn = {
    // ── ヒーロータスクリマインダー ──
    NotificationType.taskReminder: [
      _Template(
        title: 'V Alert',
        body: '“Genius is one percent inspiration and ninety-nine percent perspiration.” - Albert Einstein',
      ),
      _Template(
        title: 'V Alert',
        body: '“I don\'t give up. I\'d have to be dead or completely incapacitated.” - Elon Musk',
      ),
      _Template(
        title: 'V Alert',
        body: '“Don\'t look at me, I\'m just a novelist.” - Haruki Murakami',
      ),
      _Template(
        title: 'V Alert',
        body: '“Stay hungry. Stay foolish.” - Steve Jobs',
      ),
    ],

    // ── リアクション受信 ──
    NotificationType.reactionReceived: [
      _Template(
        title: '🔥 Blazing Fire!',
        body: '{username} set your post ablaze with {count} fire reactions!!',
      ),
    ],
  };


  /// 通知タイプ・パラメータからメッセージをランダムに生成します
  static NotificationContent build(
    NotificationType type, [
    Map<String, String> params = const {},
    String language = 'ja',
  ]) {
    final templatesMap = (language == 'en') ? _templatesEn : _templatesJa;
    final templates = templatesMap[type];
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
