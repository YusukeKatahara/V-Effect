import 'dart:math';
import 'app_notification.dart';
import 'quote.dart';

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
    if (type == NotificationType.taskReminder) {
      final randomQuote = Quote.getRandomQuote(language);
      final formattedBody = language == 'en'
          ? '“${randomQuote.text}” - ${randomQuote.author}'
          : '「${randomQuote.text}」 - ${randomQuote.author}';
      return NotificationContent(
        title: 'V Alert',
        body: formattedBody,
      );
    }

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
