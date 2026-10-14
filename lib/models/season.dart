import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Season {
  final String id;
  final String taskName;
  final DateTime startDate;
  final DateTime endDate;
  final int requiredPostsCount;
  final String? hintTitle;
  final String? hintBody;
  final String? relatedBlogId;
  final String? badgeImageUrl;
  final String? badgeAnimation;

  // ── フィールド名定数 ──
  static const String fieldTaskName = 'taskName';
  static const String fieldStartDate = 'startDate';
  static const String fieldEndDate = 'endDate';
  static const String fieldRequiredPostsCount = 'requiredPostsCount';
  static const String fieldHintTitle = 'hintTitle';
  static const String fieldHintBody = 'hintBody';
  static const String fieldRelatedBlogId = 'relatedBlogId';
  static const String fieldBadgeImageUrl = 'badgeImageUrl';
  static const String fieldBadgeAnimation = 'badgeAnimation';

  const Season({
    required this.id,
    required this.taskName,
    required this.startDate,
    required this.endDate,
    this.requiredPostsCount = 12,
    this.hintTitle,
    this.hintBody,
    this.relatedBlogId,
    this.badgeImageUrl,
    this.badgeAnimation = 'none',
  });

  Map<String, dynamic> toFirestore() {
    return {
      fieldTaskName: taskName,
      fieldStartDate: Timestamp.fromDate(startDate),
      fieldEndDate: Timestamp.fromDate(endDate),
      fieldRequiredPostsCount: requiredPostsCount,
      if (hintTitle != null) fieldHintTitle: hintTitle,
      if (hintBody != null) fieldHintBody: hintBody,
      if (relatedBlogId != null) fieldRelatedBlogId: relatedBlogId,
      if (badgeImageUrl != null) fieldBadgeImageUrl: badgeImageUrl,
      if (badgeAnimation != null) fieldBadgeAnimation: badgeAnimation,
    };
  }

  factory Season.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Season.fromMap(doc.id, data);
  }

  factory Season.fromMap(String id, Map<String, dynamic> data) {
    // 💡 キーの揺れ（末尾スペースや大文字小文字）を許容して値を取得するヘルパー関数
    T? getValue<T>(String key) {
      if (data.containsKey(key)) {
        try {
          return data[key] as T?;
        } catch (_) {}
      }
      for (final k in data.keys) {
        if (k.trim().toLowerCase() == key.toLowerCase()) {
          try {
            return data[k] as T?;
          } catch (_) {}
        }
      }
      return null;
    }

    try {
      final taskNameVal = getValue<dynamic>(fieldTaskName)?.toString() ?? '';
      final startDateVal = getValue<Timestamp>(fieldStartDate);
      final endDateVal = getValue<Timestamp>(fieldEndDate);

      return Season(
        id: id,
        taskName: taskNameVal,
        // 💡 取得・パース失敗時、DateTime.now() ではなく過去の確定日を設定（自動復活バグの根本防止）
        startDate: startDateVal?.toDate() ?? DateTime(1970, 1, 1),
        endDate: endDateVal?.toDate() ?? DateTime(1970, 1, 1),
        requiredPostsCount: (getValue<num>(fieldRequiredPostsCount))?.toInt() ?? 12,
        hintTitle: getValue<dynamic>(fieldHintTitle)?.toString(),
        hintBody: getValue<dynamic>(fieldHintBody)?.toString(),
        relatedBlogId: getValue<dynamic>(fieldRelatedBlogId)?.toString(),
        badgeImageUrl: getValue<dynamic>(fieldBadgeImageUrl)?.toString(),
        badgeAnimation: getValue<dynamic>(fieldBadgeAnimation)?.toString() ?? 'none',
      );
    } catch (e) {
      debugPrint('Error parsing Season $id: $e');
      return Season(
        id: id,
        taskName: 'Error loading season',
        startDate: DateTime.now(),
        endDate: DateTime.now(),
      );
    }
  }

  static Season createFallback(String taskName, {String? seasonId}) {
    final cleanName = taskName.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    final isWinterArc = cleanName.contains('WINTERARC') ||
        (seasonId != null && seasonId.toLowerCase().contains('winter_arc'));

    Map<String, String>? localHint;
    for (final entry in _localSeasonHints.entries) {
      final entryClean = entry.key.replaceAll(RegExp(r'\s+'), '').toUpperCase();
      if (cleanName.contains(entryClean) || entryClean.contains(cleanName)) {
        localHint = entry.value;
        break;
      }
    }
    localHint ??= {};

    return Season(
      id: seasonId ?? (isWinterArc ? 'winter_arc_2026' : 'debug_season'),
      taskName: taskName,
      startDate: isWinterArc ? DateTime(2026, 10, 15) : DateTime(2024, 1, 1),
      endDate: isWinterArc ? DateTime(2026, 12, 31, 23, 59, 59) : DateTime.now().add(const Duration(days: 365)),
      requiredPostsCount: isWinterArc ? 40 : 12,
      hintTitle: localHint['hintTitle'] ?? (isWinterArc ? '冬の3ヶ月で覚醒する5大規律' : 'シーズンタスクのヒント💡'),
      hintBody: localHint['hintBody'] ?? (isWinterArc
          ? '迷ったらここから3つ選ぼう：\n1. 🏋️ ワークアウト（筋トレ / ランニング / 自宅トレ15分）\n2. 🌅 自己規律（決めた時間に起床 / 朝日を浴びる）\n3. 🥷 スマホ断ち（起床後・就寝前のデジタルデトックス）\n4. 📖 読書・学習（読書10ページ / 勉強30分）\n5. 💧 食事・水（水2L / クリーンな食事）\n\n📷 撮るのが億劫にならない証明写真（1秒でOK！）：\n画面の明るさを下げて映画風に暗め撮影。ダンベル、スニーカー、コーヒーの湯気、閉じたPC、時計などをパシャリ！'
          : 'このシーズンタスクを習慣にするためのアドバイスです。'),
      badgeImageUrl: isWinterArc ? 'https://veffect.web.app/assets/badges/winter_arc_2026.png' : null,
      relatedBlogId: isWinterArc ? 'winter-arc-2026' : null,
    );
  }

  static const Map<String, Map<String, String>> _localSeasonHints = {
    'WINTER ARC 2026': {
      'hintTitle': '冬の3ヶ月で覚醒する5大規律',
      'hintBody': '''迷ったらここから3つ選ぼう：
1. 🏋️ ワークアウト（筋トレ / ランニング / 自宅トレ15分）
2. 🌅 自己規律（決めた時間に起床 / 朝日を浴びる）
3. 🥷 スマホ断ち（起床後・就寝前のデジタルデトックス）
4. 📖 読書・学習（読書10ページ / 勉強30分）
5. 💧 食事・水（水2L / クリーンな食事）

📷 撮るのが億劫にならない証明写真（1秒でOK！）：
画面の明るさを下げて映画風に暗め撮影。ダンベル、スニーカー、コーヒーの湯気、閉じたPC、時計などをパシャリ！''',
    },
    'WINTER ARC': {
      'hintTitle': '冬の3ヶ月で覚醒する5大規律',
      'hintBody': '''迷ったらここから3つ選ぼう：
1. 🏋️ ワークアウト（筋トレ / ランニング / 自宅トレ15分）
2. 🌅 自己規律（決めた時間に起床 / 朝日を浴びる）
3. 🥷 スマホ断ち（起床後・就寝前のデジタルデトックス）
4. 📖 読書・学習（読書10ページ / 勉強30分）
5. 💧 食事・水（水2L / クリーンな食事）

📷 撮るのが億劫にならない証明写真（1秒でOK！）：
画面の明るさを下げて映画風に暗め撮影。ダンベル、スニーカー、コーヒーの湯気、閉じたPC、時計などをパシャリ！''',
    },
    '感謝を伝える（または記録する）': {
      'hintTitle': '感謝を伝えるヒント💡',
      'hintBody': '''「感謝」は幸福度を最も高める習慣の一つです。一日一回、身近な人（家族、友人、同僚）に小さな「ありがとう」を言葉やメッセージで伝えましょう。言葉にするのが恥ずかしい時は、ノートやアプリに「今日感謝したこと」を3つ記録するだけでも同様の効果が得られます。まずは朝起きた時や、一日の終わりに振り返る習慣から始めましょう！

何に感謝すればいいか迷ったら、こんなものを撮ってみよう。

📷 「もらいもの」をパシャリ
「差し入れでもらったお菓子」や「同僚からの励ましのメモ」など、感謝のきっかけになったものをそのまま撮る。

📷 「いつもお世話になっている相棒」をパシャリ
「毎日がんばってくれているパソコン」や「雨の日に守ってくれた傘」など、身の回りの道具への感謝を込めて撮る。

📷 「誰かがやってくれたこと」をパシャリ
「綺麗に掃除されたリビング」や「作ってもらったご飯」など、誰かの気遣いが感じられる場所やモノを撮る。

📷 「感謝のメッセージ」をパシャリ
直接伝えるのが少し恥ずかしいときは、LINEなどのメッセージアプリで「ありがとう！」と伝えた画面をスクリーンショットで撮る。''',
    },
    '感謝を伝える': {
      'hintTitle': '感謝を伝えるヒント💡',
      'hintBody': '''「感謝」は幸福度を最も高める習慣の一つです。一日一回、身近な人（家族、友人、同僚）に小さな「ありがとう」を言葉やメッセージで伝えましょう。言葉にするのが恥ずかしい時は、ノートやアプリに「今日感謝したこと」を3つ記録するだけでも同様の効果が得られます。まずは朝起きた時や、一日の終わりに振り返る習慣から始めましょう！

何に感謝すればいいか迷ったら、こんなものを撮ってみよう。

📷 「もらいもの」をパシャリ
「差し入れでもらったお菓子」や「同僚からの励ましのメモ」など、感謝のきっかけになったものをそのまま撮る。

📷 「いつもお世話になっている相棒」をパシャリ
「毎日がんばってくれているパソコン」や「雨の日に守ってくれた傘」など、身の回りの道具への感謝を込めて撮る。

📷 「誰かがやってくれたこと」をパシャリ
「綺麗に掃除されたリビング」や「作ってもらったご飯」など、誰かの気遣いが感じられる場所やモノを撮る。

📷 「感謝のメッセージ」をパシャリ
直接伝えるのが少し恥ずかしいときは、LINEなどのメッセージアプリで「ありがとう！」と伝えた画面をスクリーンショットで撮る。''',
    },
    'Welcome to V EFFECT': {
      'hintTitle': 'V EFFECTへようこそ！💡',
      'hintBody': 'このアプリは、あなたが新しい習慣を身につけるのをサポートします。まずは今日達成したい小さなアクション（トリガーとセットになったもの）を登録し、完了したらカメラで証拠写真を撮影してみましょう！',
    }
  };
}
