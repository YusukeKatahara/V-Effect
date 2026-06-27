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
    try {
      return Season(
        id: id,
        taskName: data[fieldTaskName]?.toString() ?? '',
        startDate: (data[fieldStartDate] as Timestamp?)?.toDate() ?? DateTime.now(),
        endDate: (data[fieldEndDate] as Timestamp?)?.toDate() ?? DateTime.now(),
        requiredPostsCount: (data[fieldRequiredPostsCount] as num?)?.toInt() ?? 12,
        hintTitle: data[fieldHintTitle]?.toString(),
        hintBody: data[fieldHintBody]?.toString(),
        relatedBlogId: data[fieldRelatedBlogId]?.toString(),
        badgeImageUrl: data[fieldBadgeImageUrl]?.toString(),
        badgeAnimation: data[fieldBadgeAnimation]?.toString() ?? 'none',
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
    final cleanName = taskName.replaceAll(RegExp(r'\s+'), '');
    Map<String, String>? localHint;
    for (final entry in _localSeasonHints.entries) {
      if (cleanName.contains(entry.key) || entry.key.contains(cleanName)) {
        localHint = entry.value;
        break;
      }
    }
    localHint ??= {};

    return Season(
      id: seasonId ?? 'debug_season',
      taskName: taskName,
      startDate: DateTime(2024, 1, 1), // フォールバックは過去の日付にしてこれまでの投稿を含める
      endDate: DateTime.now().add(const Duration(days: 365)),
      hintTitle: localHint['hintTitle'] ?? 'シーズンタスクのヒント💡',
      hintBody: localHint['hintBody'] ?? 'このシーズンタスクを習慣にするためのアドバイスです。',
    );
  }

  static const Map<String, Map<String, String>> _localSeasonHints = {
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
