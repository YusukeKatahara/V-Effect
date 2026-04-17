import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'analytics_service.dart';

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

  /// Android のフォアグラウンド通知チャンネル
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'veffect_notifications',
    'V EFFECT 通知',
    description: 'V EFFECT アプリからの通知',
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

    // タイムゾーンの初期化
    tz.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));

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

    // 初期化時にスケジュールを同期
    await syncScheduledReminders();

    _initialized = true;
  }

  /// Firestore から設定を取得してローカル通知スケジュールを同期する
  Future<void> syncScheduledReminders() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Fetch public settings
      final publicSnap = await _db.collection('users').doc(user.uid).get();
      bool focusTimeEnabled = true;
      if (publicSnap.exists) {
        focusTimeEnabled = publicSnap.data()?['focusTimeNotifications'] ?? true;
      }

      // Fetch private details (times)
      final privateSnap = await _db
          .collection('users')
          .doc(user.uid)
          .collection('private')
          .doc('data')
          .get();

      if (privateSnap.exists) {
        final data = privateSnap.data()!;
        final wakeUpTime = data['wakeUpTime'] as String?;
        final taskTime = data['taskTime'] as String?;

        await updateScheduledReminders(
          wakeUpTime: wakeUpTime,
          taskTime: taskTime,
          focusTimeEnabled: focusTimeEnabled,
        );
      }
    } catch (e) {
      debugPrint('スケジュール同期エラー: $e');
    }
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
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
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
      // iOS の場合は APNs トークンの取得状況を確認（デバッグ用）
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final apnsToken = await _messaging.getAPNSToken();
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

  /// 毎日決まった時刻に通知をスケジュールする
  /// [id] 通知を識別する一意のID
  /// [timeStr] "HH:MM" 形式
  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required String timeStr,
  }) async {
    if (kIsWeb) return;

    final parts = timeStr.split(':');
    if (parts.length != 2) return;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return;

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    // 既に今日の設定時刻を過ぎている場合は明日にスケジュール
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    debugPrint('通知スケジュール完了: $id ($timeStr)');
  }

  /// 特定のIDのスケジュール通知を解除する
  Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;
    await _localNotifications.cancel(id);
  }

  /// 起床時間とヒーロータスク時間のローカル通知スケジュールを更新する
  Future<void> updateScheduledReminders({
    String? wakeUpTime,
    String? taskTime,
    bool focusTimeEnabled = true,
  }) async {
    if (kIsWeb) return;

    // 起床時間 (ID: 1001)
    if (wakeUpTime != null && wakeUpTime.isNotEmpty) {
      await scheduleDailyNotification(
        id: 1001,
        title: '起床時間です',
        body: '新しい一日。昨日の自分を超えるチャンスです',
        timeStr: wakeUpTime,
      );
    } else {
      await cancelNotification(1001);
    }

    // フォーカス時間 (ID: 1002)
    if (focusTimeEnabled && taskTime != null && taskTime.isNotEmpty) {
      await scheduleDailyNotification(
        id: 1002,
        title: 'Focus Time',
        body: '自分で決めたことをやる。それが一番の自信になります',
        timeStr: taskTime,
      );
    } else {
      await cancelNotification(1002);
    }
  }
}
