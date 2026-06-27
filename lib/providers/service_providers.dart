import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/analytics_service.dart';
import '../services/app_review_service.dart';
import '../services/auth_service.dart';
import '../services/block_service.dart';
import '../services/dev_blog_service.dart';
import '../services/friend_service.dart';
import '../services/invite_service.dart';
import '../services/music_api_service.dart';
import '../services/notification_service.dart';
import '../services/post_service.dart';
import '../services/push_notification_service.dart';
import '../services/sound_service.dart';
import '../services/streak_service.dart';
import '../services/user_service.dart';
import '../services/widget_service.dart';

/// ──────────────────────────────────────────────
/// サービス層の Riverpod Provider 定義
///
/// 各サービスの既存シングルトン（Service.instance）を Riverpod Provider でラップします。
/// 画面側では `ref.read(xxxServiceProvider)` でサービスを取得してください。
/// テスト時は ProviderScope の overrides でモックに差し替えられます。
/// ──────────────────────────────────────────────

/// ユーザー情報の読み書き（プロフィール・設定など）
final userServiceProvider = Provider<UserService>(
  (ref) => UserService.instance,
);

/// 投稿（ポスト）の作成・取得・削除
final postServiceProvider = Provider<PostService>(
  (ref) => PostService.instance,
);

/// フレンド（フォロー・フォロワー）管理
final friendServiceProvider = Provider<FriendService>(
  (ref) => FriendService.instance,
);

/// アプリ内通知の取得・既読管理
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService.instance,
);

/// ブロック・通報機能
final blockServiceProvider = Provider<BlockService>(
  (ref) => BlockService.instance,
);

/// ストリーク（連続達成）の計算・更新
final streakServiceProvider = Provider<StreakService>(
  (ref) => StreakService.instance,
);

/// Firebase Analytics へのイベント送信
final analyticsServiceProvider = Provider<AnalyticsService>(
  (ref) => AnalyticsService.instance,
);

/// BGM・効果音の再生制御
final soundServiceProvider = Provider<SoundService>(
  (ref) => SoundService.instance,
);

/// Apple Music / Spotify 楽曲検索 API
final musicApiServiceProvider = Provider<MusicApiService>(
  (ref) => MusicApiService.instance,
);

/// 開発チームブログ記事の取得
final devBlogServiceProvider = Provider<DevBlogService>(
  (ref) => DevBlogService.instance,
);

/// メール/Google/Apple 認証（Firebase Auth ラッパー）
/// ※ AuthService はシングルトンではなく通常クラスのため、毎回生成
final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(),
);

/// App Store レビューリクエスト
final appReviewServiceProvider = Provider<AppReviewService>(
  (ref) => AppReviewService.instance,
);

/// 招待リンクの生成・共有
final inviteServiceProvider = Provider<InviteService>(
  (ref) => InviteService.instance,
);

/// FCM プッシュ通知の初期化・受信処理
final pushNotificationServiceProvider = Provider<PushNotificationService>(
  (ref) => PushNotificationService(),
);

/// ホーム画面ウィジェット（iOS/Android ウィジェット）の更新
final widgetServiceProvider = Provider<WidgetService>(
  (ref) => WidgetService.instance,
);
