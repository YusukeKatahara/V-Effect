import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'analytics_service.dart';
import '../models/app_notification.dart';
import '../models/notification_messages.dart';

/// バックグラウンドメッセージハンドラー（トップレベル関数である必要がある）
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // バックグラウンドではシステムが自動的に通知を表示するため、
  // 追加のUI処理は不要
  debugPrint('バックグラウンド通知受信: ${message.messageId}');
}

/// Firebase Cloud Messaging によるプッシュ通知を管理するサービス
///
/// - FCM トークンの取得・Firestore への保存
/// - フォアグラウンド通知の表示（flutter_local_notifications）
/// - バックグラウンド/終了状態の通知はシステムが自動処理
/// - V Alert（タスクリマインダー）: 毎日設定時刻にローカル通知をスケジュール
class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // V Alert 通知ID
  static const int _vAlertNotificationId = 1001;

  /// Android のフォアグラウンド通知チャンネル
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'veffect_notifications',
    'V EFFECT 通知',
    description: 'V EFFECT アプリからの通知',
    importance: Importance.high,
  );

  static const AndroidNotificationChannel _alertChannel =
      AndroidNotificationChannel(
    'veffect_alert',
    'V Alert',
    description: 'V EFFECT の毎日リマインダー通知',
    importance: Importance.high,
  );

  /// 初期化（アプリ起動時に1回呼び出す）
  Future<void> initialize() async {
    if (_initialized) return;

    // Web ではプッシュ通知をスキップ
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    // タイムゾーンデータを初期化（zonedSchedule に必須）
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));

    // バックグラウンドハンドラーの登録
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 通知権限のリクエスト
    await _requestPermission();

    // ローカル通知の初期化（フォアグラウンド表示用）
    await _initializeLocalNotifications();

    // フォアグラウンドでの通知受信リスナー
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 通知タップによるアプリ起動を計測
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);
    // アプリ終了状態から通知タップで起動した場合
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationOpen(initialMessage);
    }

    // FCM トークンを保存
    await saveFcmToken();

    // トークン更新時にも保存
    _messaging.onTokenRefresh.listen((_) => saveFcmToken());

    _initialized = true;
  }

  /// 通知権限をリクエスト
  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('通知権限の状態: ${settings.authorizationStatus}');

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // iOS でフォアグラウンド通知を表示するための設定
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  /// ローカル通知プラグインの初期化
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          'valert',
          actions: [],
        ),
      ],
    );
    final settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(settings);

    // Android の通知チャンネルを作成
    final androidPlugin =
        _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    await androidPlugin?.createNotificationChannel(_channel);
    await androidPlugin?.createNotificationChannel(_alertChannel);
  }

  /// フォアグラウンドで通知を受信した場合の処理
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    // ローカル通知として表示
    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  /// 通知タップによるアプリ起動を Analytics に記録
  void _handleNotificationOpen(RemoteMessage message) {
    final type = message.data['type'] as String? ?? 'unknown';
    AnalyticsService.instance.logOpenFromNotification(type: type);
  }

  /// FCM トークンを Firestore に保存
  Future<void> saveFcmToken() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // iOS の場合は APNs トークンの取得状況を確認し、必要に応じて待機する
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        String? apnsToken;
        for (int i = 0; i < 5; i++) {
          apnsToken = await _messaging.getAPNSToken();
          if (apnsToken != null) break;
          await Future.delayed(const Duration(seconds: 1));
        }
        debugPrint('APNs Token: $apnsToken');
        if (apnsToken == null) {
          debugPrint('警告: iOS で APNs トークンが取得できていません。実機かつ正しく設定されている必要があります。');
        }
      }

      final token = await _messaging.getToken();
      if (token == null) {
        debugPrint('FCMトークンが取得できませんでした');
        return;
      }

      debugPrint('FCM Token: $token');

      await _db.collection('users').doc(user.uid).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('FCMトークン保存エラー: $e');
    }
  }

  /// FCM トークンを削除（ログアウト時に呼び出す）
  Future<void> removeFcmToken() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _db.collection('users').doc(user.uid).update({
        'fcmToken': FieldValue.delete(),
      });
    } catch (e) {
      debugPrint('FCMトークン削除エラー: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // V Alert: 毎日スケジュール通知
  // ─────────────────────────────────────────────────────────────────

  /// V Alert（Focus Time リマインダー）を毎日指定時刻にスケジュールする
  ///
  /// [taskTimeStr] は "HH:MM" 形式の文字列。null の場合はキャンセルのみ行う。
  /// - アプリが閉じていても OS が通知を表示する
  /// - 既存スケジュールはキャンセルして再登録する（時刻変更対応）
  Future<void> scheduleVAlert(String? taskTimeStr) async {
    if (kIsWeb) return;

    // 既存スケジュール（最大7日分）を先にキャンセル
    for (int i = 0; i < 7; i++) {
      await _localNotifications.cancel(_vAlertNotificationId + i);
    }

    if (taskTimeStr == null || taskTimeStr.isEmpty) {
      debugPrint('V Alert: taskTime が未設定のためキャンセルのみ実行');
      return;
    }

    final parts = taskTimeStr.split(':');
    if (parts.length != 2) return;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return;

    final now = tz.TZDateTime.now(tz.local);

    // 次に通知する日時を計算（今日の設定時刻が過ぎていれば明日）
    var baseDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (baseDate.isBefore(now)) {
      baseDate = baseDate.add(const Duration(days: 1));
    }

    // 今後 7 日間分の通知をそれぞれランダムなメッセージでスケジュール
    for (int i = 0; i < 7; i++) {
      final scheduledDate = baseDate.add(Duration(days: i));
      final notificationId = _vAlertNotificationId + i;

      // ランダムにメッセージを選択
      final content = NotificationMessages.build(NotificationType.taskReminder);

      try {
        await _localNotifications.zonedSchedule(
          notificationId,
          content.title,
          content.body,
          scheduledDate,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _alertChannel.id,
              _alertChannel.name,
              channelDescription: _alertChannel.description,
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
              styleInformation: const BigTextStyleInformation(''),
            ),
            iOS: const DarwinNotificationDetails(
              categoryIdentifier: 'valert',
              presentAlert: true,
              presentSound: true,
              presentBadge: true,
              sound: 'default',
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        debugPrint(
          'V Alert スケジュール登録完了 [Day ${i + 1}]: $scheduledDate - ${content.body.replaceAll('\n', ' ')}',
        );
      } catch (e) {
        debugPrint('V Alert スケジュール登録エラー [Day ${i + 1}]: $e');
      }
    }
  }

  /// Firestore から taskTime を取得して V Alert をスケジュールする
  /// アプリ起動時やログイン後に呼び出す
  Future<void> restoreVAlertSchedule() async {
    if (kIsWeb) return;
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('private')
          .doc('data')
          .get();
      if (!snap.exists) return;

      final taskTime = snap.data()?['taskTime'] as String?;
      await scheduleVAlert(taskTime);
    } catch (e) {
      debugPrint('V Alert スケジュール復元エラー: $e');
    }
  }
}
