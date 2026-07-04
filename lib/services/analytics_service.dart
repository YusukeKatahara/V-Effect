import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

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

  // ════════════════════════════════════════════
  // action_logs（ローカルバッチ型の生データ収集基盤）
  // FirebaseAnalytics と共存。LLM/Python 等での仮説検証用に
  // uid + 可変パラメータのみを正規化して Firestore に保存する。
  // ════════════════════════════════════════════

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// 送信前にローカルへ溜めるイベントキュー
  final List<Map<String, dynamic>> _actionLogQueue = [];

  /// 自動 flush するキュー件数のしきい値
  static const int _batchThreshold = 10;

  /// 1 回の WriteBatch で送る最大件数（Firestore のハード制限 500 に対する安全マージン）
  static const int _maxBatchOps = 400;

  /// キューの最大保持件数（リトライ蓄積によるメモリ暴走を防ぐ）
  static const int _maxQueueSize = 500;

  /// アプリバージョン（PackageInfo を一度だけ解決してキャッシュ）
  String? _cachedAppVersion;

  /// NavigatorObserver（自動画面遷移トラッキング用）
  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  /// イベントを action_logs キューに積む（内部用）
  ///
  /// 既存の FirebaseAnalytics 送信とは独立して動作し、
  /// 例外は全て握り潰して本体機能を絶対に止めない。
  /// 静的データ（年齢・性別等）は含めず、uid と可変パラメータのみを保存する。
  Future<void> _logToActionLogs(
    String eventName, [
    Map<String, dynamic> parameters = const {},
  ]) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return; // 未ログイン時は記録しない

      _cachedAppVersion ??= (await PackageInfo.fromPlatform()).version;
      final platform = kIsWeb ? 'web' : Platform.operatingSystem;

      _actionLogQueue.add({
        'uid': uid,
        'eventName': eventName,
        'parameters': parameters,
        'appVersion': _cachedAppVersion,
        'platform': platform,
        // イベント発生時刻（バッチ遅延の影響を受けない正確な時刻）
        'clientTimestamp': Timestamp.now(),
        // 仕様準拠：サーバー側の書き込み時刻
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (_actionLogQueue.length >= _batchThreshold) {
        unawaited(flushBatch());
      }
    } catch (_) {
      // 分析ログ起因で本体機能を絶対に止めない
    }
  }

  /// 溜まった action_logs を WriteBatch で一括送信する
  ///
  /// アプリのバックグラウンド移行時（main.dart のライフサイクル監視）や
  /// キューがしきい値に達した時に呼ばれる。失敗時はキューに戻して次回リトライ。
  Future<void> flushBatch() async {
    if (_actionLogQueue.isEmpty) return;

    // 送信対象を取り出し、キューは即座にクリア（送信中の追加分を失わない）
    final pending = List<Map<String, dynamic>>.from(_actionLogQueue);
    _actionLogQueue.clear();

    var committed = 0;
    try {
      // 500 件制限を超えないよう分割してコミットする
      for (var i = 0; i < pending.length; i += _maxBatchOps) {
        final end =
            (i + _maxBatchOps < pending.length) ? i + _maxBatchOps : pending.length;
        final batch = _db.batch();
        for (final log in pending.sublist(i, end)) {
          batch.set(_db.collection('action_logs').doc(), log);
        }
        await batch.commit();
        committed = end;
      }
    } catch (_) {
      // 未コミット分のみキュー先頭へ戻す（コミット済みチャンクの重複送信を避ける）。
      // メモリ暴走防止のため上限を超えた古い分は捨てる。
      _actionLogQueue.insertAll(0, pending.sublist(committed));
      if (_actionLogQueue.length > _maxQueueSize) {
        _actionLogQueue.removeRange(_maxQueueSize, _actionLogQueue.length);
      }
    }
  }

  // ════════════════════════════════════════════
  // セッション・リテンション
  // ════════════════════════════════════════════

  /// アプリがフォアグラウンドに来た時に呼ぶ
  void onAppResumed() {
    _sessionStart = DateTime.now();
    final now = DateTime.now();
    _analytics.logEvent(
      name: 'app_open_custom',
      parameters: {
        'hour_of_day': now.hour,
        'day_of_week': now.weekday, // 1=月 ... 7=日
      },
    );
    _logToActionLogs('app_open', {
      'hour_of_day': now.hour,
      'day_of_week': now.weekday,
    });
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
    _logToActionLogs('profile_setup_complete');
  }

  /// ヒーロータスク設定完了
  Future<void> logTaskSetupComplete({required int taskCount}) async {
    await _analytics.logEvent(
      name: 'task_setup_complete',
      parameters: {'task_count': taskCount},
    );
    _logToActionLogs('task_setup_complete', {'task_count': taskCount});
  }

  /// オンボーディング完了
  Future<void> logOnboardingComplete() async {
    await _analytics.logEvent(name: 'onboarding_complete');
    _logToActionLogs('onboarding_complete');
  }

  /// テンプレートヒーロータスク選択を記録
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
    _logToActionLogs('template_selected', {
      'template_name': templateName,
      'is_custom': isCustom ? 1 : 0,
    });
  }

  // ════════════════════════════════════════════
  // 投稿イベント（ヒーロータスクカテゴリ + 時間帯付き）
  // ════════════════════════════════════════════

  /// 投稿作成（ヒーロータスクカテゴリと時間帯を自動分類して付与）
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
    // action_logs には生のタスク名を含めず、正規化したカテゴリ等のみ保存
    _logToActionLogs('post_created', {
      'task_category': classifyTask(taskName),
      'hour_of_day': now.hour,
      'time_slot': _timeSlot(now.hour),
      'day_of_week': now.weekday,
    });
  }

  /// リアクション送信
  ///
  /// [reactionType] は 'flame'（VFIRE）または 'emoji'。
  /// [targetUid]/[targetTaskName] は対象投稿の情報（呼び出し元が保持する値を渡す。
  /// 追加の Firestore Read は行わない）。targetUid は他者UIDのため
  /// FirebaseAnalytics には送らず、JOIN 用に action_logs のみへ保存する。
  Future<void> logReactionSent({
    required String targetUid,
    required String targetTaskName,
    required String reactionType,
    int? flameCount,
    String? emoji,
  }) async {
    await _analytics.logEvent(
      name: 'reaction_sent',
      parameters: {
        'reaction_type': reactionType,
        'target_task_category': classifyTask(targetTaskName),
        if (flameCount != null) 'flame_count': flameCount,
        if (emoji != null) 'emoji': emoji,
      },
    );
    _logToActionLogs('reaction_sent', {
      'target_uid': targetUid,
      'target_task_category': classifyTask(targetTaskName),
      'reaction_type': reactionType,
      if (flameCount != null) 'flame_count': flameCount,
      if (emoji != null) 'emoji': emoji,
    });
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
    _logToActionLogs('streak_update', {
      'streak': streak,
      'is_record': isRecord ? 1 : 0,
    });
  }

  /// ストリークマイルストーン達成（7日、30日、100日 等）
  Future<void> logStreakMilestone({required int streak}) async {
    await _analytics.logEvent(
      name: 'streak_milestone',
      parameters: {'streak': streak},
    );
    _logToActionLogs('streak_milestone', {'streak': streak});
  }

  // ════════════════════════════════════════════
  // ソーシャルイベント
  // ════════════════════════════════════════════

  /// フレンドリクエスト送信
  Future<void> logFriendRequestSent() async {
    await _analytics.logEvent(name: 'friend_request_sent');
    _logToActionLogs('friend_request_sent');
  }

  /// フレンドリクエスト承認
  Future<void> logFriendRequestAccepted() async {
    await _analytics.logEvent(name: 'friend_request_accepted');
    _logToActionLogs('friend_request_accepted');
  }

  /// フレンドリクエスト拒否
  Future<void> logFriendRequestRejected() async {
    await _analytics.logEvent(name: 'friend_request_rejected');
    _logToActionLogs('friend_request_rejected');
  }

  /// フレンド削除
  Future<void> logFriendRemoved() async {
    await _analytics.logEvent(name: 'friend_removed');
    _logToActionLogs('friend_removed');
  }

  /// ユーザーをブロック
  Future<void> logUserBlocked() async {
    await _analytics.logEvent(name: 'user_blocked');
    _logToActionLogs('user_blocked');
  }

  /// フレンドフィード閲覧
  ///
  /// [todayFriendPostsCount] はフィードに表示されている「今日の友達投稿数」。
  /// コミュニティの活発度と翌日の継続率の相関分析に用いる。
  Future<void> logFriendFeedViewed({required int todayFriendPostsCount}) async {
    await _analytics.logEvent(
      name: 'friend_feed_viewed',
      parameters: {'today_friend_posts_count': todayFriendPostsCount},
    );
    _logToActionLogs('friend_feed_viewed', {
      'today_friend_posts_count': todayFriendPostsCount,
    });
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

    _logToActionLogs('referral_source', {
      'referrers': referrers.join(','),
      'referrer_count': referrers.length,
      'skipped': skipped ? 1 : 0,
    });
  }

  /// 通知経由のアプリ起動を記録
  Future<void> logOpenFromNotification({required String type}) async {
    await _analytics.logEvent(
      name: 'open_from_notification',
      parameters: {'notification_type': type},
    );
    _logToActionLogs('open_from_notification', {'notification_type': type});
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

  /// ヒーロータスク数をユーザープロパティとして設定
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

  /// 主要ヒーロータスクカテゴリをユーザープロパティとして設定
  /// 複数ヒーロータスクのうち最も多いカテゴリを代表値とする
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
  // ヒーロータスクカテゴリ自動分類（内部ロジック）
  // ════════════════════════════════════════════

  /// ヒーロータスク名からカテゴリを自動推定する
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
      '仕事', 'ヒーロータスク', '案件', '副業', '作業', 'メール', 'ミーティング',
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

  // ════════════════════════════════════════════
  // 閲覧・拡散・広告・作成フローの新規イベント
  // ════════════════════════════════════════════

  /// 友達の投稿を詳細表示/閲覧した時
  Future<void> logFriendPostViewed({
    required String friendUid,
    required String taskName,
  }) async {
    final category = classifyTask(taskName);
    await _analytics.logEvent(
      name: 'friend_post_viewed',
      parameters: {
        'friend_uid_hash': friendUid.hashCode.toString(),
        'task_category': category,
      },
    );
    _logToActionLogs('friend_post_viewed', {
      'friend_uid': friendUid,
      'task_category': category,
    });
  }

  /// 投稿を外部SNS等にシェアした時
  Future<void> logPostShared({required String platform}) async {
    await _analytics.logEvent(
      name: 'post_shared',
      parameters: {
        'platform': platform,
      },
    );
    _logToActionLogs('post_shared', {
      'platform': platform,
    });
  }

  /// 投稿（撮影）フローを開始した時
  Future<void> logPostFlowStart() async {
    await _analytics.logEvent(name: 'post_flow_start');
    _logToActionLogs('post_flow_start');
  }

  /// 投稿（撮影）フローを途中で離脱した時
  Future<void> logPostFlowCancel({required String reason}) async {
    await _analytics.logEvent(
      name: 'post_flow_cancel',
      parameters: {
        'reason': reason,
      },
    );
    _logToActionLogs('post_flow_cancel', {
      'reason': reason,
    });
  }

  /// 広告が表示された時（インプレッション）
  Future<void> logAdImpression({required String adUnitId}) async {
    await _analytics.logEvent(
      name: 'ad_impression_custom',
      parameters: {
        'ad_unit_id': adUnitId,
      },
    );
    _logToActionLogs('ad_impression', {
      'ad_unit_id': adUnitId,
    });
  }

  /// 広告がクリックされた時
  Future<void> logAdClicked({required String adUnitId}) async {
    await _analytics.logEvent(
      name: 'ad_clicked_custom',
      parameters: {
        'ad_unit_id': adUnitId,
      },
    );
    _logToActionLogs('ad_clicked', {
      'ad_unit_id': adUnitId,
    });
  }
}

