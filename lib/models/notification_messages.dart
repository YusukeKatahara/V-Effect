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
        body: '「天才とは努力する凡才のことである」 - Albert Einstein',
      ),
      _Template(
        title: 'V Alert',
        body: '「楽観的？悲観的？そんなことは知らん。やる。やり遂げる。必ずやり遂げると神に誓うんだ」 - Elon Musk',
      ),
      _Template(
        title: 'V Alert',
        body: '「時間をかけることを恐れてはいけないよ。それは、いちばん洗練されたかたちでの復讐なんだ」 - 村上春樹',
      ),
      _Template(
        title: 'V Alert',
        body: '「貪欲であれ、愚かであれ」 - Steve Jobs',
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
      _Template(
        title: '🔥 仲間の予感',
        body: '{username} さんがあなたの努力に惹かれています！仲間リクエストが届きました',
      ),
      _Template(
        title: '👀 注目されています',
        body: '{username} さんがあなたに注目しています。共に成長する仲間に加えますか？',
      ),
    ],
    NotificationType.friendRequestAccepted: [
      _Template(
        title: '🤝 仲間が誕生しました',
        body: '{username} さんと仲間になりました！お互いのV Questを高め合いましょう！',
      ),
      _Template(
        title: '⚔️ 戦友の合流',
        body: '{username} さんがリクエストを承認しました！共に高みを目指しましょう',
      ),
    ],
    // ── ストリーク達成祝い ──
    NotificationType.streakCelebration: [
      _Template(
        title: '🎉 伝説の始まり',
        body: '素晴らしい！{streak}日連続で自分に勝ち続けています。この調子で伝説を刻みましょう！',
      ),
      _Template(
        title: '🏆 圧倒的な継続力',
        body: '{streak}日間の継続達成！あなたの意志の強さは本物です。',
      ),
    ],
    // ── ストリーク危機通知 ──
    NotificationType.streakWarning: [
      _Template(
        title: '⚠️ 危機が迫っています',
        body: '今日のV Questがまだ完了していません！このままでは{streak}日間のストリークが途切れてしまいます！',
      ),
      _Template(
        title: '🔥 最後の踏ん張り',
        body: 'ストリークを維持する時間は残りわずかです。自分との約束を果たしましょう！',
      ),
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
