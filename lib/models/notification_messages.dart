import 'dart:math';
import 'app_notification.dart';

/// 通知メッセージのタイトルと本文のペア
class NotificationContent {
  final String title;
  final String body;

  const NotificationContent({required this.title, required this.body});
}

/// テンプレート選択時に参照されるコンテキスト情報
class NotificationContext {
  final int streak;
  final bool earlyWake; // 起床時間の1時間前までにアプリを開いたか

  const NotificationContext({this.streak = 0, this.earlyWake = false});
}

/// テンプレートが選ばれるための条件
enum _Condition {
  none,           // 常に候補
  streakAtLeast1, // streak >= 1
  streakAtLeast5, // streak >= 5
  streakZero,     // streak == 0
  earlyWake,      // 起床時間の1時間前までにアプリを開いている
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
  static const Map<NotificationType, List<_Template>> _templates = {
    // ── 起床リマインダー ──
    NotificationType.wakeUpReminder: [
      _Template(
        title: '起床時間です',
        body: '新しい一日。昨日の自分を超えるチャンスです',
      ),
      _Template(
        title: '起床時間です',
        body: '{streak}日間、自分との約束を守り続けています',
        condition: _Condition.streakAtLeast5,
      ),
      _Template(
        title: '起床時間です',
        body: '今日もあなたが決めた時間に目覚めた。それだけで一歩前進です',
        condition: _Condition.earlyWake,
      ),
      _Template(
        title: '起床時間です',
        body: '今日の自分は、まだ何も描かれていないキャンバス。どんな一日にしますか？',
      ),
      _Template(
        title: '起床時間です',
        body: '毎朝起きると決めたのはあなた自身。その決意が力になります',
      ),
    ],

    // ── ヒーロータスクリマインダー ──
    NotificationType.taskReminder: [
      _Template(
        title: 'ヒーロータスクの時間です',
        body: '自分で決めたことをやる。それが一番の自信になります',
      ),
      _Template(
        title: 'ヒーロータスクの時間です',
        body: '完璧じゃなくていい。今日も「やった」という事実を積み上げよう',
        condition: _Condition.streakAtLeast1,
      ),
      _Template(
        title: 'ヒーロータスクの時間です',
        body: '{streak}日目の挑戦。続けている自分を誇ろう',
        condition: _Condition.streakAtLeast5,
      ),
      _Template(
        title: 'ヒーロータスクの時間です',
        body: 'まずは始めるだけ。やると決めたのはあなたです',
      ),
      _Template(
        title: 'ヒーロータスクの時間です',
        body: '昨日の自分にできなかったことが、今日はできるかもしれない',
        condition: _Condition.streakZero,
      ),
    ],

    // ── フレンドのヒーロータスク完了 ──
    NotificationType.friendTaskCompleted: [
      _Template(
        title: '仲間の一歩',
        body: '{username}さんも今日の自分に勝ちました',
      ),
      _Template(
        title: '仲間の一歩',
        body: '{username}さんが今日も一歩を刻みました。同じ道を歩く仲間がいます',
      ),
      _Template(
        title: '仲間の一歩',
        body: '{username}さんが自分との約束を果たしました',
      ),
      _Template(
        title: '仲間の一歩',
        body: '{username}さんも戦っています。あなたは一人じゃない',
      ),
      _Template(
        title: '仲間の一歩',
        body: '{username}さんが今日の勝利を手にしました',
      ),
    ],

    // ── リアクション受信 ──
    NotificationType.reactionReceived: [
      _Template(
        title: '🔥リアクション',
        body: 'あなたの一歩に{username}さんから🔥が届きました',
      ),
      _Template(
        title: '🔥リアクション',
        body: '{username}さんがあなたの努力を見ています🔥',
      ),
      _Template(
        title: '🔥リアクション',
        body: '{username}さんから🔥！あなたの積み重ねが誰かの力になっています',
      ),
      _Template(
        title: '🔥リアクション',
        body: '{username}さんがあなたの挑戦に🔥を送りました',
      ),
      _Template(
        title: '🔥リアクション',
        body: '🔥{username}さんがあなたの一歩を称えています',
      ),
    ],

    // ── フレンドリクエスト（機能的通知：単一テンプレート） ──
    NotificationType.friendRequestReceived: [
      _Template(
        title: 'フレンドリクエスト',
        body: '{username} さんからフレンドリクエストが届きました',
      ),
    ],
    NotificationType.friendRequestAccepted: [
      _Template(
        title: 'リクエスト承認',
        body: '{username} さんがフレンドリクエストを承認しました',
      ),
    ],
  };

  /// 通知タイプ・パラメータ・コンテキストからメッセージを生成します
  ///
  /// 条件付きテンプレートは [context] の値で候補がフィルタリングされます。
  /// 候補が複数ある場合はランダムに1つ選択されます。
  static NotificationContent build(
    NotificationType type, [
    Map<String, String> params = const {},
    NotificationContext context = const NotificationContext(),
  ]) {
    final allTemplates = _templates[type];
    if (allTemplates == null || allTemplates.isEmpty) {
      return NotificationContent(title: type.name, body: '');
    }

    // 条件を満たすテンプレートだけに絞り込む
    final eligible = allTemplates.where((t) => _meetsCondition(t, context)).toList();

    // 条件付きがすべて外れた場合は無条件のもののみにフォールバック
    final candidates = eligible.isNotEmpty
        ? eligible
        : allTemplates.where((t) => t.condition == _Condition.none).toList();

    if (candidates.isEmpty) {
      return NotificationContent(title: type.name, body: '');
    }

    final template = candidates[_random.nextInt(candidates.length)];

    return NotificationContent(
      title: _replacePlaceholders(template.title, params),
      body: _replacePlaceholders(template.body, params),
    );
  }

  static bool _meetsCondition(_Template template, NotificationContext ctx) {
    switch (template.condition) {
      case _Condition.none:
        return true;
      case _Condition.streakAtLeast1:
        return ctx.streak >= 1;
      case _Condition.streakAtLeast5:
        return ctx.streak >= 5;
      case _Condition.streakZero:
        return ctx.streak == 0;
      case _Condition.earlyWake:
        return ctx.earlyWake;
    }
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
  final _Condition condition;

  const _Template({
    required this.title,
    required this.body,
    this.condition = _Condition.none,
  });
}
