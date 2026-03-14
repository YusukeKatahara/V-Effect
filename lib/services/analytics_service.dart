import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Firebase Analytics / Crashlytics を一元管理するサービス
///
/// 各種ユーザー行動をカスタムイベントとして記録し、
/// Firebase Console からデータを取得・分析できるようにします。
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// NavigatorObserver（自動画面遷移トラッキング用）
  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

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

  // ════════════════════════════════════════════
  // 投稿イベント
  // ════════════════════════════════════════════

  /// 投稿作成
  Future<void> logPostCreated({required String taskName}) async {
    await _analytics.logEvent(
      name: 'post_created',
      parameters: {'task_name': taskName},
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
}
