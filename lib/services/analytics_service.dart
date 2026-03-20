import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Firebase Analytics / Crashlytics を一元管理するサービス
///
/// 各種ユーザー行動をカスタムイベントとして記録し、
/// Firebase Console からデータを取得・分析できるようにします。
///
/// データの活用方法:
///   - Firebase Console > Analytics > イベント / ユーザー
///   - BigQuery Export で SQL による詳細分析
///   - Google Analytics 4 との連携でコホート分析・ファネル分析
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// セッション開始時刻（セッション時間計測用）
  DateTime? _sessionStart;

  /// NavigatorObserver（自動画面遷移トラッキング用）
  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  // ════════════════════════════════════════════
  // セッション・リテンション
  // ════════════════════════════════════════════

  /// アプリがフォアグラウンドに来た時に呼ぶ
  void onAppResumed() {
    _sessionStart = DateTime.now();
    _analytics.logEvent(
      name: 'app_open_custom',
      parameters: {
        'hour_of_day': DateTime.now().hour,
        'day_of_week': DateTime.now().weekday, // 1=月 ... 7=日
      },
    );
  }

  /// アプリがバックグラウンドに移行した時に呼ぶ
  void onAppPaused() {
    if (_sessionStart != null) {
      final duration = DateTime.now().difference(_sessionStart!).inSeconds;
      _analytics.logEvent(
        name: 'session_end',
        parameters: {'duration_seconds': duration},
      );
      _sessionStart = null;
    }
  }

  /// 初回起動を記録（registeredAt がない場合のみ発火）
  Future<void> logFirstOpen() async {
    await _analytics.logEvent(name: 'first_open_custom');
  }

  // ════════════════════════════════════════════
  // 認証イベント
  // ════════════════════════════════════════════

  /// ログイン成功
  Future<void> logLogin(String method) async {
    await _analytics.logLogin(loginMethod: method);
  }

  /// 新規登録完了
  Future<void> logSignUp(String method) async {
    await _analytics.logSignUp(signUpMethod: method);
  }

  /// ユーザーIDを設定（Analytics上でユーザーを識別）
  Future<void> setUserId(String uid) async {
    await _analytics.setUserId(id: uid);
    // Crashlytics にも同じIDを設定
    if (!kIsWeb) {
      await FirebaseCrashlytics.instance.setUserIdentifier(uid);
    }
  }

  // ════════════════════════════════════════════
  // オンボーディングイベント
  // ════════════════════════════════════════════

  /// プロフィール設定完了
  Future<void> logProfileSetupComplete() async {
    await _analytics.logEvent(name: 'profile_setup_complete');
  }

  /// タスク設定完了
  Future<void> logTaskSetupComplete({required int taskCount}) async {
    await _analytics.logEvent(
      name: 'task_setup_complete',
      parameters: {'task_count': taskCount},
    );
  }

  /// オンボーディング完了
  Future<void> logOnboardingComplete() async {
    await _analytics.logEvent(name: 'onboarding_complete');
  }

  /// テンプレートタスク選択を記録
  Future<void> logTemplateSelected({
    required String templateName,
    required bool isCustom,
  }) async {
    await _analytics.logEvent(
      name: 'template_selected',
      parameters: {
        'template_name': templateName,
        'is_custom': isCustom ? 1 : 0,
      },
    );
  }

  // ════════════════════════════════════════════
  // 投稿イベント（タスクカテゴリ + 時間帯付き）
  // ════════════════════════════════════════════

  /// 投稿作成（タスクカテゴリと時間帯を自動分類して付与）
  Future<void> logPostCreated({required String taskName}) async {
    final now = DateTime.now();
    await _analytics.logEvent(
      name: 'post_created',
      parameters: {
        'task_name': taskName,
        'task_category': classifyTask(taskName),
        'hour_of_day': now.hour,
        'time_slot': _timeSlot(now.hour),
        'day_of_week': now.weekday,
      },
    );
  }

  /// リアクション送信
  Future<void> logReactionSent() async {
    await _analytics.logEvent(name: 'reaction_sent');
  }

  // ════════════════════════════════════════════
  // ストリークイベント
  // ════════════════════════════════════════════

  /// ストリーク更新
  Future<void> logStreakUpdate({
    required int streak,
    required bool isRecord,
  }) async {
    await _analytics.logEvent(
      name: 'streak_update',
      parameters: {
        'streak': streak,
        'is_record': isRecord ? 1 : 0,
      },
    );
  }

  /// ストリークマイルストーン達成（7日、30日、100日 等）
  Future<void> logStreakMilestone({required int streak}) async {
    await _analytics.logEvent(
      name: 'streak_milestone',
      parameters: {'streak': streak},
    );
  }

  // ════════════════════════════════════════════
  // ソーシャルイベント
  // ════════════════════════════════════════════

  /// フレンドリクエスト送信
  Future<void> logFriendRequestSent() async {
    await _analytics.logEvent(name: 'friend_request_sent');
  }

  /// フレンドリクエスト承認
  Future<void> logFriendRequestAccepted() async {
    await _analytics.logEvent(name: 'friend_request_accepted');
  }

  /// フレンドリクエスト拒否
  Future<void> logFriendRequestRejected() async {
    await _analytics.logEvent(name: 'friend_request_rejected');
  }

  /// フレンド削除
  Future<void> logFriendRemoved() async {
    await _analytics.logEvent(name: 'friend_removed');
  }

  /// フレンドフィード閲覧
  Future<void> logFriendFeedViewed() async {
    await _analytics.logEvent(name: 'friend_feed_viewed');
  }

  // ════════════════════════════════════════════
  // 流入元トラッキング
  // ════════════════════════════════════════════

  /// 初期フレンド画面での招待元を記録
  /// （「誰に誘われましたか？」の選択結果）
  Future<void> logReferralSource({
    required List<String> referrers,
    required bool skipped,
  }) async {
    await _analytics.logEvent(
      name: 'referral_source',
      parameters: {
        'referrers': referrers.join(','),
        'referrer_count': referrers.length,
        'skipped': skipped ? 1 : 0,
      },
    );

    // 最初の招待元をユーザープロパティにも設定（セグメント分析用）
    if (referrers.isNotEmpty) {
      await _analytics.setUserProperty(
        name: 'referral_source',
        value: referrers.first,
      );
    } else {
      await _analytics.setUserProperty(
        name: 'referral_source',
        value: 'organic',
      );
    }
  }

  /// 通知経由のアプリ起動を記録
  Future<void> logOpenFromNotification({required String type}) async {
    await _analytics.logEvent(
      name: 'open_from_notification',
      parameters: {'notification_type': type},
    );
  }

  // ════════════════════════════════════════════
  // ユーザープロパティ
  // ════════════════════════════════════════════

  /// ストリーク帯をユーザープロパティとして設定
  /// Firebase Console の「ユーザー」セグメントで利用可能
  Future<void> setStreakTier(int streak) async {
    final String tier;
    if (streak == 0) {
      tier = 'inactive';
    } else if (streak < 7) {
      tier = 'beginner';
    } else if (streak < 30) {
      tier = 'active';
    } else if (streak < 100) {
      tier = 'dedicated';
    } else {
      tier = 'master';
    }
    await _analytics.setUserProperty(name: 'streak_tier', value: tier);
  }

  /// タスク数をユーザープロパティとして設定
  Future<void> setTaskCount(int count) async {
    await _analytics.setUserProperty(
      name: 'task_count',
      value: count.toString(),
    );
  }

  /// フレンド数をユーザープロパティとして設定
  Future<void> setFriendCount(int count) async {
    await _analytics.setUserProperty(
      name: 'friend_count',
      value: count.toString(),
    );
  }

  /// 主要タスクカテゴリをユーザープロパティとして設定
  /// 複数タスクのうち最も多いカテゴリを代表値とする
  Future<void> setTaskCategories(List<String> tasks) async {
    if (tasks.isEmpty) return;

    final counts = <String, int>{};
    for (final task in tasks) {
      final cat = classifyTask(task);
      counts[cat] = (counts[cat] ?? 0) + 1;
    }
    // 最も多いカテゴリを代表値に
    final primary = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    await _analytics.setUserProperty(
      name: 'primary_task_category',
      value: primary.key,
    );
  }

  /// 投稿時間帯の傾向をユーザープロパティとして設定
  Future<void> setPostingTimeSlot(int hour) async {
    await _analytics.setUserProperty(
      name: 'posting_time_slot',
      value: _timeSlot(hour),
    );
  }

  // ════════════════════════════════════════════
  // タスクカテゴリ自動分類（内部ロジック）
  // ════════════════════════════════════════════

  /// タスク名からカテゴリを自動推定する
  /// ユーザーには見えない裏側のロジック
  static String classifyTask(String taskName) {
    final t = taskName.toLowerCase();

    // 運動・フィットネス
    if (_matchesAny(t, [
      'ランニング', 'ジョギング', '走', '筋トレ', '腕立て', '腹筋', 'スクワット',
      'ストレッチ', 'ヨガ', '散歩', 'ウォーキング', '水泳', 'ジム',
      '運動', 'トレーニング', 'プランク', '懸垂', 'サイクリング', '自転車',
      'running', 'workout', 'gym', 'exercise', 'yoga', 'walk',
    ])) {
      return 'exercise';
    }

    // 学習・勉強
    if (_matchesAny(t, [
      '勉強', '学習', '読書', '本', '英語', '単語', 'プログラミング', 'コーディング',
      '問題集', '暗記', '資格', '講義', '授業', 'レポート', '宿題', '復習', '予習',
      'study', 'reading', 'learn', 'code', 'programming',
    ])) {
      return 'study';
    }

    // 生活習慣・健康
    if (_matchesAny(t, [
      '早起き', '起床', '瞑想', '日記', '水', '食事', '自炊', '料理', '掃除',
      '片付け', '洗濯', 'スキンケア', '歯磨き', '睡眠', '寝る', '禁煙', '禁酒',
      'meditation', 'journal', 'clean', 'cook', 'diet', 'sleep',
    ])) {
      return 'lifestyle';
    }

    // クリエイティブ・趣味
    if (_matchesAny(t, [
      '絵', 'イラスト', '描', '写真', '撮影', '音楽', '楽器', 'ピアノ', 'ギター',
      '作曲', 'ブログ', '記事', 'デザイン', 'ハンドメイド', 'DIY',
      'draw', 'art', 'music', 'photo', 'write', 'blog', 'design',
    ])) {
      return 'creative';
    }

    // 仕事・副業
    if (_matchesAny(t, [
      '仕事', 'タスク', '案件', '副業', '作業', 'メール', 'ミーティング',
      '企画', '営業', 'プレゼン', '資料',
      'work', 'task', 'meeting', 'email', 'project',
    ])) {
      return 'work';
    }

    return 'other';
  }

  static bool _matchesAny(String text, List<String> keywords) {
    return keywords.any((kw) => text.contains(kw));
  }

  /// 時刻から時間帯ラベルを返す
  static String _timeSlot(int hour) {
    if (hour < 6) return 'night';       // 深夜 0-5
    if (hour < 10) return 'morning';    // 朝 6-9
    if (hour < 14) return 'midday';     // 昼 10-13
    if (hour < 18) return 'afternoon';  // 午後 14-17
    if (hour < 22) return 'evening';    // 夜 18-21
    return 'night';                     // 深夜 22-23
  }
}
