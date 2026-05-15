import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'analytics_service.dart';
import '../models/app_notification.dart';
import '../models/notification_messages.dart';
import '../main.dart';
import '../widgets/premium_notification_toast.dart';
import 'friend_service.dart';
import 'notification_service.dart';

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
  static const int _protectionAlertNotificationId1 = 1002;
  static const int _protectionAlertNotificationId2 = 1003;

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

    // 起動時にバッジをリセット
    await resetBadge();

    // V Alert のスケジュールを復元（既ログインユーザー向け）
    await restoreVAlertSchedule();

    _initialized = true;
  }

  /// 通知センターから全通知を消去する
  Future<void> resetBadge() async {
    if (kIsWeb) return;
    try {
      // cancelAll() は未来のスケジュールも消してしまうため、
      // バッジのみをリセットするように変更。
      // iOS の場合、バッジリセットで通知センターの通知も一部消えるが、
      // スケジュールを維持するために cancelAll は避ける。
      
      // アプリバッジをリセット
      final bool isSupported = await FlutterAppBadger.isAppBadgeSupported();
      if (isSupported) {
        await FlutterAppBadger.removeBadge();
        debugPrint('App Badge & Notification Center リセット完了');
      } else {
        debugPrint('App Badge はこのデバイスでサポートされていません');
      }
    } catch (e) {
      debugPrint('Notification Center リセットエラー: $e');
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
      // alert: false にすることで OS 標準の自動表示を抑制し、
      // _handleForegroundMessage での手動表示（LocalNotifications）と重複するのを防ぐ
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: false,
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

    final context = VEffectApp.navigatorKey.currentContext;
    if (context == null) return;

    final typeStr = message.data['type'] as String?;
    final relatedId = message.data['relatedId'] as String?;
    final fromUid = message.data['fromUid'] as String?;

    List<ToastAction>? actions;

    // フォローリクエストの場合は承認ボタンを出す
    if (typeStr == NotificationType.friendRequestReceived.name &&
        relatedId != null) {
      actions = [
        ToastAction(
          label: '承認',
          isPrimary: true,
          onPressed: () async {
            try {
              final friendService = FriendService.instance;
              final request = await friendService.getRequestById(relatedId);
              if (request != null) {
                await friendService.acceptRequest(request);
                // 通知を既読にする
                final notifSnap = await FirebaseFirestore.instance
                    .collection('notifications')
                    .where('relatedId', isEqualTo: relatedId)
                    .where('type', isEqualTo: typeStr)
                    .limit(1)
                    .get();
                if (notifSnap.docs.isNotEmpty) {
                  await NotificationService.instance
                      .deleteNotification(notifSnap.docs.first.id);
                }
              }
            } catch (e) {
              debugPrint('Toast accept error: $e');
            }
          },
        ),
        ToastAction(
          label: 'あとで',
          onPressed: () {},
        ),
      ];
    }

    PremiumNotificationToast.show(
      context,
      title: notification.title ?? '',
      body: notification.body ?? '',
      icon: _iconForType(typeStr),
      actions: actions,
      onTap: () {
        if (fromUid != null) {
          VEffectApp.navigatorKey.currentState?.pushNamed(
            '/user-profile',
            arguments: fromUid,
          );
        }
      },
    );
  }

  IconData _iconForType(String? typeStr) {
    if (typeStr == NotificationType.friendRequestReceived.name) {
      return Icons.person_add;
    } else if (typeStr == NotificationType.friendRequestAccepted.name) {
      return Icons.how_to_reg;
    } else if (typeStr == NotificationType.reactionReceived.name) {
      return Icons.whatshot;
    } else if (typeStr == NotificationType.friendTaskCompleted.name) {
      return Icons.emoji_events;
    } else if (typeStr == NotificationType.streakCelebration.name) {
      return Icons.workspace_premium;
    } else if (typeStr == NotificationType.streakWarning.name) {
      return Icons.warning_amber_rounded;
    }
    return Icons.notifications;
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

    // 既存の特定ID（V Alert）をキャンセル
    try {
      await _localNotifications.cancel(_vAlertNotificationId);
    } catch (e) {
      debugPrint('V Alert キャンセルエラー: $e');
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

    // 初回の通知日時を計算
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final content = NotificationMessages.build(NotificationType.taskReminder);

    try {
      // matchDateTimeComponents: DateTimeComponents.time を使うことで、
      // 1回の登録で毎日同じ時刻に通知を繰り返す（リピート設定）
      await _localNotifications.zonedSchedule(
        _vAlertNotificationId,
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
        matchDateTimeComponents: DateTimeComponents.time, // 毎日リピート！
      );
      debugPrint(
        'V Alert スケジュール登録（毎日リピート設定）: $scheduledDate - ${content.body.replaceAll('\n', ' ')}',
      );
    } catch (e) {
      debugPrint('V Alert スケジュール登録エラー: $e');
    }
  }

  /// ストリーク保護プロトコルの作動通知をスケジュールする
  Future<void> scheduleProtectionAlert(String? taskTimeStr, int streakProtections, String? lastPostedDateStr) async {
    if (kIsWeb) return;

    // 既存のスケジュールをキャンセル
    await _localNotifications.cancel(_protectionAlertNotificationId1);
    await _localNotifications.cancel(_protectionAlertNotificationId2);

    if (streakProtections <= 0 || lastPostedDateStr == null) {
      return;
    }

    final partsDate = lastPostedDateStr.split('-');
    if (partsDate.length != 3) return;
    final year = int.tryParse(partsDate[0]);
    final month = int.tryParse(partsDate[1]);
    final day = int.tryParse(partsDate[2]);
    if (year == null || month == null || day == null) return;

    final now = tz.TZDateTime.now(tz.local);
    // 日付を超えた瞬間（00:00）に通知を送るように設定
    final baseDate = tz.TZDateTime(tz.local, year, month, day, 0, 0);

    const bodyText = 'ストリーク保護プロトコル、作動中！';

    // 1回目の保護発動 (2日後)
    final targetDate1 = baseDate.add(const Duration(days: 2));
    if (targetDate1.isAfter(now)) {
      final title1 = streakProtections == 2 ? '🛡️ 報告' : '🛡️ 警告';
      await _scheduleOneOffLocalNotification(
        _protectionAlertNotificationId1,
        title1,
        bodyText,
        targetDate1,
      );
      debugPrint('Protection Alert 1 スケジュール登録: $targetDate1');
    }

    // 2回目の保護発動 (3日後)
    if (streakProtections >= 2) {
      final targetDate2 = baseDate.add(const Duration(days: 3));
      if (targetDate2.isAfter(now)) {
        const title2 = '🛡️ 警告'; // 最後の1つ
        await _scheduleOneOffLocalNotification(
          _protectionAlertNotificationId2,
          title2,
          bodyText,
          targetDate2,
        );
        debugPrint('Protection Alert 2 スケジュール登録: $targetDate2');
      }
    }
  }

  Future<void> _scheduleOneOffLocalNotification(int id, String title, String body, tz.TZDateTime scheduledDate) async {
    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
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
          presentAlert: true,
          presentSound: true,
          presentBadge: true,
          sound: 'default',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// スケジュールされたリマインダーを更新する
  Future<void> updateScheduledReminders({
    String? wakeUpTime,
    String? taskTime,
    bool focusTimeEnabled = true,
  }) async {
    if (kIsWeb) return;

    if (focusTimeEnabled) {
      await scheduleVAlert(taskTime);
    } else {
      for (int i = 0; i < 7; i++) {
        await _localNotifications.cancel(_vAlertNotificationId + i);
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
      final privateSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('private')
          .doc('data')
          .get();
      if (!privateSnap.exists) return;

      final taskTime = privateSnap.data()?['taskTime'] as String? ?? '08:00';
      await scheduleVAlert(taskTime);

      final publicSnap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (publicSnap.exists) {
        final data = publicSnap.data()!;
        final protections = (data['streakProtections'] as num?)?.toInt() ?? 0;
        final lastPostedDate = data['lastPostedDate'] as String?;
        final allowProtection = data['protectionNotifications'] ?? true;

        if (allowProtection) {
          await scheduleProtectionAlert(taskTime, protections, lastPostedDate);
        } else {
          // キャンセル
          await scheduleProtectionAlert(null, 0, null);
        }
      }
    } catch (e) {
      debugPrint('V Alert スケジュール復元エラー: $e');
    }
  }
}
