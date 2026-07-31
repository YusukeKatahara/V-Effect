import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/post.dart';
import '../services/post_service.dart';
import '../utils/date_helper.dart';

class AiInsightItem {
  final String icon;
  final String title;
  final String detail;

  AiInsightItem({required this.icon, required this.title, required this.detail});

  factory AiInsightItem.fromMap(Map<String, dynamic> map) {
    return AiInsightItem(
      icon: map['icon'] as String? ?? '💡',
      title: map['title'] as String? ?? '【データ分析】',
      detail: map['detail'] as String? ?? '過去のデータから継続のチャンスを発見しました。',
    );
  }
}

class WeeklyReviewAiAdvice {
  final String badgeText;
  final String headline;
  final List<AiInsightItem> insights;
  final String actionType; // 'slide_time', 'two_minute_rule', 'send_thanks'
  final String actionLabel;

  WeeklyReviewAiAdvice({
    required this.badgeText,
    required this.headline,
    required this.insights,
    required this.actionType,
    required this.actionLabel,
  });

  factory WeeklyReviewAiAdvice.fromMap(Map<String, dynamic> map) {
    final rawInsights = map['insights'] as List?;
    final list = <AiInsightItem>[];
    if (rawInsights != null) {
      for (final item in rawInsights) {
        if (item is Map) {
          list.add(AiInsightItem.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    return WeeklyReviewAiAdvice(
      badgeText: map['badgeText'] as String? ?? '分析完了',
      headline: map['headline'] as String? ?? '💡 今週のデータ多角分析結果 (PDCA)',
      insights: list.isNotEmpty ? list : [
        AiInsightItem(
          icon: '⏰',
          title: '1. 【時間の傾向】',
          detail: 'アクティブな時間帯に合わせたタスク実行を意識することで、継続率を高められます！',
        ),
        AiInsightItem(
          icon: '🔑',
          title: '2. 【ドミノ習慣】',
          detail: '中心となるタスクを優先的に達成することが、日々の成功リズムを作ります！',
        ),
        AiInsightItem(
          icon: '🔮',
          title: '3. 【来週のポイント】',
          detail: '小さなアプローチからスタートし、無理のないペースでストリークを伸ばしましょう！',
        ),
      ],
      actionType: map['actionType'] as String? ?? 'slide_time',
      actionLabel: map['actionLabel'] as String? ?? '⚡️ タスク設定を確認',
    );
  }
}

/// 今週の振り返り（Weekly Review）画面で表示するデータを読み込み・管理するProvider
class WeeklyReviewData {
  final List<Post> posts;
  final int streak;
  final int totalVFire;
  final int totalReactions;

  // パーソナライズ統計
  final String? mostSentToUid;
  final String? mostSentToName;
  final int mostSentToCount;
  final String? mostReceivedFromUid;
  final String? mostReceivedFromName;
  final int mostReceivedFromCount;
  final int mostActiveDayOfWeek; // 1 (月) 〜 7 (日)、0 はなし
  final int mostActiveDayCount;
  final String? goldenTimeRange; // 'morning', 'afternoon', 'evening', 'lateNight'
  final String? buddyTaskName;
  final int buddyTaskCount;

  // AIデータアナリティクス (PDCA)
  final WeeklyReviewAiAdvice? aiAdvice;

  WeeklyReviewData({
    required this.posts,
    required this.streak,
    required this.totalVFire,
    required this.totalReactions,
    this.mostSentToUid,
    this.mostSentToName,
    this.mostSentToCount = 0,
    this.mostReceivedFromUid,
    this.mostReceivedFromName,
    this.mostReceivedFromCount = 0,
    this.mostActiveDayOfWeek = 0,
    this.mostActiveDayCount = 0,
    this.goldenTimeRange,
    this.buddyTaskName,
    this.buddyTaskCount = 0,
    this.aiAdvice,
  });
}

final weeklyReviewProvider = FutureProvider.autoDispose<WeeklyReviewData>((ref) async {
  final postService = PostService.instance;
  
  // 自分のストリーク数と、今週（月曜〜日曜）の投稿を並列で取得
  final results = await Future.wait([
    postService.getWeeklyReviewPosts(),
    postService.getStreak(),
  ]);

  final posts = results[0] as List<Post>;
  final streak = results[1] as int;

  // 今週（月曜〜日曜）のVFIRE(🔥)の合計とその他の絵文字リアクションの合計を計算
  int totalVFire = 0;
  int totalReactions = 0;
  for (final post in posts) {
    totalVFire += post.reactionCount;
    // emojiReactedUserIds (単なるユニーク人数) ではなく userReactions (送られた絵文字マップ全件) を集計
    final emojiCount = post.userReactions.isNotEmpty
        ? post.userReactions.length
        : post.emojiReactedUserIds.length;
    totalReactions += emojiCount;
  }

  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    return WeeklyReviewData(
      posts: posts,
      streak: streak,
      totalVFire: totalVFire,
      totalReactions: totalReactions,
    );
  }

  // 今週の開始（月曜日0:00）を計算
  final now = DateTime.now();
  final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
  final startTimestamp = Timestamp.fromDate(startOfWeek);

  // ── 1. 最もV FIREを送った相手の集計 ──
  final sentQuery = await FirebaseFirestore.instance
      .collection('notifications')
      .where('fromUid', isEqualTo: uid)
      .where('type', isEqualTo: 'reactionReceived')
      .get();

  final sentMap = <String, int>{};
  for (final doc in sentQuery.docs) {
    final data = doc.data();
    if (data['emoji'] != null) continue;
    final createdAt = data['createdAt'] as Timestamp?;
    if (createdAt == null || createdAt.compareTo(startTimestamp) < 0) continue;
    
    final toUid = data['toUid'] as String?;
    final count = data['reactionCount'] as int? ?? 0;
    if (toUid != null && count > 0) {
      sentMap[toUid] = (sentMap[toUid] ?? 0) + count;
    }
  }

  String? mostSentToUid;
  int mostSentToCount = 0;
  sentMap.forEach((key, val) {
    if (val > mostSentToCount) {
      mostSentToCount = val;
      mostSentToUid = key;
    }
  });

  // ── 2. 最もV FIREを受け取った相手の集計 ──
  final receivedQuery = await FirebaseFirestore.instance
      .collection('notifications')
      .where('toUid', isEqualTo: uid)
      .where('type', isEqualTo: 'reactionReceived')
      .get();

  final receivedMap = <String, int>{};
  for (final doc in receivedQuery.docs) {
    final data = doc.data();
    if (data['emoji'] != null) continue;
    final createdAt = data['createdAt'] as Timestamp?;
    if (createdAt == null || createdAt.compareTo(startTimestamp) < 0) continue;

    final fromUid = data['fromUid'] as String?;
    final count = data['reactionCount'] as int? ?? 0;
    if (fromUid != null && count > 0) {
      receivedMap[fromUid] = (receivedMap[fromUid] ?? 0) + count;
    }
  }

  String? mostReceivedFromUid;
  int mostReceivedFromCount = 0;
  receivedMap.forEach((key, val) {
    if (val > mostReceivedFromCount) {
      mostReceivedFromCount = val;
      mostReceivedFromUid = key;
    }
  });

  // 名前を非同期で取得
  String? mostSentToName;
  if (mostSentToUid != null) {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(mostSentToUid).get();
      mostSentToName = userDoc.data()?['displayName'] ?? userDoc.data()?['username'] ?? 'フレンド';
    } catch (_) {}
  }

  String? mostReceivedFromName;
  if (mostReceivedFromUid != null) {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(mostReceivedFromUid).get();
      mostReceivedFromName = userDoc.data()?['displayName'] ?? userDoc.data()?['username'] ?? 'フレンド';
    } catch (_) {}
  }

  // ── 3. 最もモチベーションの高かった（タスクを完了した）曜日の集計 ──
  final dayMap = <int, int>{};
  for (final post in posts) {
    final day = post.createdAt.weekday;
    dayMap[day] = (dayMap[day] ?? 0) + 1;
  }
  int mostActiveDayOfWeek = 0;
  int mostActiveDayCount = 0;
  dayMap.forEach((key, val) {
    if (val > mostActiveDayCount) {
      mostActiveDayCount = val;
      mostActiveDayOfWeek = key;
    }
  });

  // ── 4. 集中ゴールデンタイム（時間帯）の集計 ──
  final hourMap = <String, int>{
    'morning': 0,
    'afternoon': 0,
    'evening': 0,
    'lateNight': 0,
  };
  for (final post in posts) {
    final hour = post.createdAt.hour;
    if (hour >= 5 && hour < 12) {
      hourMap['morning'] = hourMap['morning']! + 1;
    } else if (hour >= 12 && hour < 18) {
      hourMap['afternoon'] = hourMap['afternoon']! + 1;
    } else if (hour >= 18 && hour < 24) {
      hourMap['evening'] = hourMap['evening']! + 1;
    } else {
      hourMap['lateNight'] = hourMap['lateNight']! + 1;
    }
  }
  String? goldenTimeRange;
  int maxHourCount = 0;
  hourMap.forEach((key, val) {
    if (val > maxHourCount) {
      maxHourCount = val;
      goldenTimeRange = key;
    }
  });
  if (maxHourCount == 0) goldenTimeRange = null;

  // ── 5. 今週の相棒タスクの集計 ──
  final taskMap = <String, int>{};
  for (final post in posts) {
    final title = post.taskName;
    if (title.isNotEmpty) {
      taskMap[title] = (taskMap[title] ?? 0) + 1;
    }
  }
  String? buddyTaskName;
  int buddyTaskCount = 0;
  taskMap.forEach((key, val) {
    if (val > buddyTaskCount) {
      buddyTaskCount = val;
      buddyTaskName = key;
    }
  });

  // ── 6. AIデータアナリティクス (PDCA) アドバイスの取得／生成 ──
  WeeklyReviewAiAdvice? aiAdvice;
  try {
    final mondayStr = DateHelper.getMondayOfWeekString(DateTime.now());
    final cacheDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('weekly_advices')
        .doc(mondayStr)
        .get();

    if (cacheDoc.exists && cacheDoc.data() != null) {
      aiAdvice = WeeklyReviewAiAdvice.fromMap(cacheDoc.data()!);
    } else {
      // Functions を呼び出してオンデマンド生成
      final dayNames = ['', '月曜日', '火曜日', '水曜日', '木曜日', '金曜日', '土曜日', '日曜日'];
      final timeNames = {
        'morning': '朝 (5:00〜12:00)',
        'afternoon': '昼 (12:00〜18:00)',
        'evening': '夜 (18:00〜24:00)',
        'lateNight': '深夜',
      };
      
      final callable = FirebaseFunctions.instance.httpsCallable('getWeeklyAiAdvice');
      final res = await callable.call({
        'streak': streak,
        'totalPostsCount': posts.length,
        'mostActiveDayName': (mostActiveDayOfWeek >= 1 && mostActiveDayOfWeek <= 7) ? dayNames[mostActiveDayOfWeek] : '月曜日',
        'goldenTimeName': goldenTimeRange != null ? (timeNames[goldenTimeRange] ?? '朝') : '朝',
        'buddyTaskName': buddyTaskName ?? 'タスク',
      });

      if (res.data != null && res.data is Map) {
        final map = Map<String, dynamic>.from(res.data as Map);
        aiAdvice = WeeklyReviewAiAdvice.fromMap(map);
      }
    }
  } catch (e) {
    // エラー時のフォールバックデータ
    final taskName = buddyTaskName ?? '相棒タスク';
    aiAdvice = WeeklyReviewAiAdvice(
      badgeText: '分析完了',
      headline: '💡 今週のデータ多角分析結果 (PDCA)',
      insights: [
        AiInsightItem(
          icon: '⏰',
          title: '1. 【時間の傾向】',
          detail: 'ご自身の生活リズムに合わせた時間設定が、習慣化の最大の鍵となります！',
        ),
        AiInsightItem(
          icon: '🔑',
          title: '2. 【ドミノ習慣】',
          detail: '『$taskName』を中心に、一つずつのクリアを積み重ねていきましょう！',
        ),
        AiInsightItem(
          icon: '🔮',
          title: '3. 【来週のポイント】',
          detail: '来週も集中しやすい時間帯を活用し、ストリークを更新していきましょう！',
        ),
      ],
      actionType: 'slide_time',
      actionLabel: '⚡️『$taskName』の設定を確認',
    );
  }

  return WeeklyReviewData(
    posts: posts,
    streak: streak,
    totalVFire: totalVFire,
    totalReactions: totalReactions,
    mostSentToUid: mostSentToUid,
    mostSentToName: mostSentToName,
    mostSentToCount: mostSentToCount,
    mostReceivedFromUid: mostReceivedFromUid,
    mostReceivedFromName: mostReceivedFromName,
    mostReceivedFromCount: mostReceivedFromCount,
    mostActiveDayOfWeek: mostActiveDayOfWeek,
    mostActiveDayCount: mostActiveDayCount,
    goldenTimeRange: goldenTimeRange,
    buddyTaskName: buddyTaskName,
    buddyTaskCount: buddyTaskCount,
    aiAdvice: aiAdvice,
  );
});

/// 今週の振り返りの既読状態を管理するProvider。
/// 戻り値が true の場合は「既読（一度開いた）」を表す。
final isWeeklyReviewReadProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final mondayStr = DateHelper.getMondayOfWeekString(DateTime.now());
  final isRead = prefs.getBool('weekly_review_read_$mondayStr') ?? false;
  return isRead;
});

/// 今週の振り返りを既読（一度開いた）状態にする関数
Future<void> markWeeklyReviewAsRead(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  final mondayStr = DateHelper.getMondayOfWeekString(DateTime.now());
  await prefs.setBool('weekly_review_read_$mondayStr', true);
  ref.invalidate(isWeeklyReviewReadProvider);
}


