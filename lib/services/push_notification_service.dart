import 'dart:math' as math;
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
/// - ストリーク保護アラート: ストリーク切れを防ぐローカル通知をスケジュール
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

  static const int _protectionAlertNotificationId1 = 1002;
  static const int _protectionAlertNotificationId2 = 1003;

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

    // タイムゾーンデータを初期化（zonedSchedule に必須）
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));

    // バックグラウンドハンドラーの登録
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 以前はここで通知権限をリクエストしていましたが、
    // プッシュ通知推奨UI（プレ・モーダル）のタイミングに合わせるため
    // 初期化時の自動リクエストはスキップします。
    // await requestPermission();

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

    // 保護アラートのスケジュールを復元（既ログインユーザー向け）
    await restoreProtectionAlertSchedule();

    // タスク別の毎日リマインダー通知を復元
    await restoreDailyTaskReminders();

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

      // iOS では、通知許可が得られていない状態でバッジを操作しようとすると
      // OS の通知許可ダイアログが自動的に表示されてしまう可能性があるため、ガードする。
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final settings = await FirebaseMessaging.instance.getNotificationSettings();
        if (settings.authorizationStatus != AuthorizationStatus.authorized &&
            settings.authorizationStatus != AuthorizationStatus.provisional) {
          debugPrint('Badgeリセットスキップ: iOSで通知許可が得られていません');
          return;
        }
      }
      
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

  /// 最新の未読通知数をカウントし、アプリアイコンバッジに同期する
  Future<void> syncBadgeCount() async {
    if (kIsWeb) return;
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      // iOS で通知許可が得られていない場合はバッジ操作をガードする
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final settings = await FirebaseMessaging.instance.getNotificationSettings();
        if (settings.authorizationStatus != AuthorizationStatus.authorized &&
            settings.authorizationStatus != AuthorizationStatus.provisional) {
          debugPrint('Badge同期スキップ: iOSで通知許可が得られていません');
          return;
        }
      }

      final myUid = currentUser.uid;
      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));

      // 3日以内の未読通知数を取得（インデックス不要のクエリで取得し、メモリ上で絞り込み）
      final snap = await _db
          .collection('notifications')
          .where('toUid', isEqualTo: myUid)
          .where('isRead', isEqualTo: false)
          .get();

      int unreadCount = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        final createdAtRaw = data['createdAt'];
        final DateTime? createdAt = createdAtRaw is Timestamp
            ? createdAtRaw.toDate()
            : null;
        final String? type = data['type'] as String?;

        final isSeasonPushOnly = type == NotificationType.seasonTaskReceived.name ||
            type == NotificationType.seasonTaskPushOnly.name;
        final isWithinThreeDays = createdAt != null && createdAt.isAfter(threeDaysAgo);

        if (isWithinThreeDays && !isSeasonPushOnly) {
          unreadCount++;
        }
      }

      final bool isSupported = await FlutterAppBadger.isAppBadgeSupported();
      if (isSupported) {
        if (unreadCount > 0) {
          await FlutterAppBadger.updateBadgeCount(unreadCount);
          debugPrint('App Badge 同期完了: 未読 $unreadCount 件');
        } else {
          await FlutterAppBadger.removeBadge();
          debugPrint('App Badge 同期完了: 未読 0 件 (バッジ消去)');
        }
      } else {
        debugPrint('App Badge はこのデバイスでサポートされていません');
      }
    } catch (e) {
      debugPrint('Badge同期エラー: $e');
    }
  }

  /// 通知権限をリクエスト
  Future<void> requestPermission() async {
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

    // 権限が許可された場合、または暫定許可された場合は、
    // 即座に FCM トークンを保存（または更新）し、ローカル通知のスケジュールを復元します。
    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await saveFcmToken();
      await restoreProtectionAlertSchedule();
      await restoreDailyTaskReminders();
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
  }

  /// フォアグラウンドで通知を受信した場合の処理
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    try {
      final notification = message.notification;
      if (notification == null) return;

      final context = VEffectApp.navigatorKey.currentContext;
      if (context == null || !context.mounted) return;

      final typeStr = message.data['type'] as String?;
      final relatedId = message.data['relatedId'] as String?;
      final fromUid = message.data['fromUid'] as String?;

      List<ToastAction>? actions;
      
      // 中略... (actions の設定ロジックは維持)

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
    } catch (e, stack) {
      debugPrint('通知処理エラー（非致命的）: $e');
      debugPrint(stack.toString());
    }
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
      // iOS では、通知許可が得られていない状態で getToken / getAPNSToken を呼ぶと
      // OS の通知許可ダイアログが自動的に表示されてしまうフリクションを防ぐため、
      // 許可ステータスを確認し、許可されていない場合は処理をスキップします。
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final settings = await _messaging.getNotificationSettings();
        if (settings.authorizationStatus != AuthorizationStatus.authorized &&
            settings.authorizationStatus != AuthorizationStatus.provisional) {
          debugPrint('FCMトークン保存スキップ: iOSで通知許可が得られていません');
          return;
        }
      }

      // iOS の場合は APNs トークンの取得状況を確認し、必要に応じて待機する
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        String? apnsToken;
        for (int i = 0; i < 15; i++) {
          apnsToken = await _messaging.getAPNSToken();
          if (apnsToken != null) break;
          await Future.delayed(const Duration(seconds: 1));
        }
        debugPrint('APNs Token: $apnsToken');
        if (apnsToken == null) {
          debugPrint('警告: iOS で APNs トークンが取得できなかったため、FCMトークンの保存をスキップします。実機かつプロビジョニング設定が正しい必要があります。');
          return;
        }
      }

      final token = await _messaging.getToken();
      if (token == null) {
        debugPrint('FCMトークンが取得できませんでした');
        return;
      }

      debugPrint('FCM Token: $token');

      // fcmToken は private subcollection に保存（全認証ユーザーからの読み取りを防ぐ）
      await _db
          .collection('users')
          .doc(user.uid)
          .collection('private')
          .doc('data')
          .set({'fcmToken': token}, SetOptions(merge: true));

      // 旧バージョンが残した public 側の fcmToken を掃除する（移行期間用）
      await _db.collection('users').doc(user.uid).set(
        {'fcmToken': FieldValue.delete()},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('FCMトークン保存エラー: $e');
    }
  }

  /// FCM トークンを削除（ログアウト時に呼び出す）
  Future<void> removeFcmToken() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _db
          .collection('users')
          .doc(user.uid)
          .collection('private')
          .doc('data')
          .set({'fcmToken': FieldValue.delete()}, SetOptions(merge: true));
      // 旧 public 側も念のため削除（移行期間用）
      await _db.collection('users').doc(user.uid).set(
        {'fcmToken': FieldValue.delete()},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('FCMトークン削除エラー: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // V Alert: 毎日スケジュール通知
  // ─────────────────────────────────────────────────────────────────

  /// V Alert（Focus Time リマインダー）を毎日指定時刻にスケジュールする
  /// ストリーク保護プロトコルの作動通知をスケジュールする
  Future<void> scheduleProtectionAlert(int streakProtections, String? lastPostedDateStr) async {
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
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
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



  /// Firestore から必要なデータを取得して保護アラートをスケジュールする
  /// アプリ起動時やログイン後に呼び出す
  Future<void> restoreProtectionAlertSchedule() async {
    if (kIsWeb) return;
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // iOS では、通知許可が得られていない状態でローカル通知をスケジュールすると
      // OS の通知許可ダイアログが自動的に表示されてしまうフリクションを防ぐため、
      // 許可ステータスを確認し、許可されていない場合は処理をスキップします。
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final settings = await FirebaseMessaging.instance.getNotificationSettings();
        if (settings.authorizationStatus != AuthorizationStatus.authorized &&
            settings.authorizationStatus != AuthorizationStatus.provisional) {
          debugPrint('保護アラートスケジュールスキップ: iOSで通知許可が得られていません');
          return;
        }
      }

      final publicSnap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (publicSnap.exists) {
        final data = publicSnap.data()!;

        final protections = (data['streakProtections'] as num?)?.toInt() ?? 0;
        final lastPostedDate = data['lastPostedDate'] as String?;
        final allowProtection = data['protectionNotifications'] ?? false;

        if (allowProtection) {
          await scheduleProtectionAlert(protections, lastPostedDate);
        } else {
          // キャンセル
          await scheduleProtectionAlert(0, null);
        }
      }
    } catch (e) {
      debugPrint('保護アラートスケジュール復元エラー: $e');
    }
  }

  /// すべてのタスクの毎日リマインダー通知を復元（再スケジュール）します。
  /// アプリ起動時や通知権限が変更された際に呼び出します。
  Future<void> restoreDailyTaskReminders() async {
    if (kIsWeb) return;
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // iOS では、通知許可が得られていない状態でローカル通知をスケジュールすると
      // OS の通知許可ダイアログが自動的に表示されてしまうフリクションを防ぐため、
      // 許可ステータスを確認し、許可されていない場合は処理をスキップします。
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final settings = await FirebaseMessaging.instance.getNotificationSettings();
        if (settings.authorizationStatus != AuthorizationStatus.authorized &&
            settings.authorizationStatus != AuthorizationStatus.provisional) {
          debugPrint('タスクリマインダースケジュール復元スキップ: iOSで通知許可が得られていません');
          return;
        }
      }

      final publicSnap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (publicSnap.exists) {
        final data = publicSnap.data();
        if (data != null) {
          final tasksData = data['tasks'] as List<dynamic>?;
          if (tasksData != null) {
            for (final taskMap in tasksData) {
              if (taskMap is Map<String, dynamic>) {
                final taskId = taskMap['id'] as String? ?? '';
                final taskTitle = taskMap['title'] as String? ?? '';
                final reminderTime = taskMap['reminderTime'] as String?;
                
                if (taskId.isNotEmpty && reminderTime != null) {
                  await scheduleDailyTaskReminder(
                    taskId: taskId,
                    taskTitle: taskTitle,
                    reminderTime: reminderTime,
                  );
                }
              }
            }
            debugPrint('タスクリマインダースケジュール復元完了: ${tasksData.length}件のタスクを走査');
          }
        }
      }
    } catch (e) {
      debugPrint('タスクリマインダースケジュール復元エラー: $e');
    }
  }

  /// タスクの毎日リマインダー通知をスケジュールします。
  /// [taskIdHashCode] を ID として使用し、指定された時刻（例: "08:00"）に毎日繰り返し通知します。
  Future<void> scheduleDailyTaskReminder({
    required String taskId,
    required String taskTitle,
    required String reminderTime, // "HH:mm" フォーマット
  }) async {
    if (kIsWeb) return;

    try {
      final parts = reminderTime.split(':');
      if (parts.length != 2) return;
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      // 設定時刻が過去の場合、翌日の設定とする
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      // タスクIDのハッシュコードを通知IDとする（一意でかつ整数）
      final notificationId = taskId.hashCode.abs() % 1000000;

      // 行動心理学に基づいた通知メッセージをランダム（1:1）で決定
      final random = math.Random();
      final isSmallStep = random.nextBool();

      // 端末のシステム言語を取得
      final isJapanese = PlatformDispatcher.instance.locale.languageCode == 'ja';

      final String title;
      final String body;

      if (isJapanese) {
        if (isSmallStep) {
          title = 'まずは1分だけ！';
          body = '「$taskTitle」を少しだけ始めてみよう。最初の一歩が一番大切です！';
        } else {
          title = '約束の時間です ⏱️';
          body = '時間になりました！「$taskTitle」を開始して、今日のクエストを達成しよう！';
        }
      } else {
        if (isSmallStep) {
          title = 'Just 1 minute!';
          body = 'Let\'s start "$taskTitle" for a bit. The first step is the most important!';
        } else {
          title = 'It\'s time! ⏱️';
          body = 'Time is up! Start "$taskTitle" to complete today\'s quest!';
        }
      }

      await _localNotifications.zonedSchedule(
        notificationId,
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
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // 毎日この時刻にマッチさせてリピート
      );
      debugPrint('Daily task reminder scheduled: id=$notificationId at $reminderTime, title="$title"');
    } catch (e) {
      debugPrint('Error scheduling daily task reminder: $e');
    }
  }

  /// 指定したタスクの毎日リマインダー通知をキャンセルします。
  Future<void> cancelDailyTaskReminder(String taskId) async {
    if (kIsWeb) return;
    try {
      final notificationId = taskId.hashCode.abs() % 1000000;
      await _localNotifications.cancel(notificationId);
      debugPrint('Daily task reminder cancelled: id=$notificationId');
    } catch (e) {
      debugPrint('Error cancelling daily task reminder: $e');
    }
  }
}
