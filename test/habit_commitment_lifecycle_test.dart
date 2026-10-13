import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:visibility_detector/visibility_detector.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import 'package:v_effect/models/app_task.dart';
import 'package:v_effect/models/app_user.dart';
import 'package:v_effect/models/post.dart';
import 'package:v_effect/providers/home_provider.dart';
import 'package:v_effect/providers/service_providers.dart';
import 'package:v_effect/providers/vfire_provider.dart';
import 'package:v_effect/screens/camera_screen.dart';
import 'package:v_effect/screens/hero_tasks/components/hero_task_item.dart';
import 'package:v_effect/screens/hero_tasks/components/task_card.dart';
import 'package:v_effect/screens/profile/components/habit_planner_sheet.dart';
import 'package:v_effect/services/post_service.dart';
import 'package:v_effect/services/push_notification_service.dart';
import 'package:v_effect/services/user_service.dart';
import 'package:v_effect/utils/date_helper.dart';

// モック用 FlutterLocalNotificationsPlugin 実装
class FakeLocalNotificationsPlugin implements FlutterLocalNotificationsPlugin {
  final List<int> cancelledIds = [];
  final List<Map<String, dynamic>> scheduledNotifications = [];

  @override
  Future<void> cancel(int id, {String? tag}) async {
    cancelledIds.add(id);
  }

  @override
  Future<void> zonedSchedule(
    int id,
    String? title,
    String? body,
    tz.TZDateTime scheduledDate,
    NotificationDetails notificationDetails, {
    required AndroidScheduleMode androidScheduleMode,
    required UILocalNotificationDateInterpretation uiLocalNotificationDateInterpretation,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    scheduledNotifications.add({
      'id': id,
      'title': title,
      'body': body,
      'scheduledDate': scheduledDate,
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// モック用 VFireNotifier 実装
class FakeVFireNotifier extends Notifier<VFireState> implements VFireNotifier {
  @override
  VFireState build() {
    return VFireState(localIncrements: const {}, lastSentCounts: const {});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// モック用 PostService 実装
class MockPostService implements PostService {
  final List<Post> posts;
  MockPostService({this.posts = const []});

  @override
  Future<List<Post>> getAllMyPastPosts({dynamic source}) async => posts;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// モック用 UserService 実装
class MockUserService implements UserService {
  final List<Map<String, dynamic>> updateScheduleCalls = [];

  @override
  Future<void> updateTaskSchedule(String dateStr, List<String> taskIds) async {
    updateScheduleCalls.add({
      'dateStr': dateStr,
      'taskIds': List<String>.from(taskIds),
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));
  });

  group('PushNotificationService Aggregated Notification Tests', () {
    test('getCommittedNotificationId produces unique, consistent IDs within offset 2000000+', () {
      final id1 = PushNotificationService.getCommittedNotificationId('2026-10-15');
      final id2 = PushNotificationService.getCommittedNotificationId('2026-10-15');
      final id3 = PushNotificationService.getCommittedNotificationId('2026-10-16');

      // 同一日付に対して常に一意・同一
      expect(id1, equals(id2));
      // 2000000 〜 3000000 の範囲に収まり、他通知と衝突しない
      expect(id1, greaterThanOrEqualTo(2000000));
      expect(id1, lessThan(3000000));

      // 別日付に対して異なるIDが生成される
      expect(id1, isNot(equals(id3)));
    });

    test('getCommittedNotificationTitle formats single and multiple tasks correctly in Japanese', () {
      // 1件のタスク
      final singleTitle = PushNotificationService.getCommittedNotificationTitle(['Work Out'], isJapanese: true);
      expect(singleTitle, equals('今日は【Work Out】の日です！🔥'));

      // 複数件のタスク（まとめて1つの通知）
      final multiTitle2 = PushNotificationService.getCommittedNotificationTitle(['Work Out', '読書'], isJapanese: true);
      expect(multiTitle2, equals('本日は【Work Out】【読書】の予定日です！🔥'));

      final multiTitle3 = PushNotificationService.getCommittedNotificationTitle(['Work Out', '読書', '瞑想'], isJapanese: true);
      expect(multiTitle3, equals('本日は【Work Out】【読書】【瞑想】の予定日です！🔥'));
    });

    test('getCommittedNotificationBody formats single and multiple tasks correctly in Japanese', () {
      final singleBody = PushNotificationService.getCommittedNotificationBody(['Work Out'], isJapanese: true);
      expect(singleBody, equals('カレンダーで約束した日です。小さな一歩を踏み出して勝利を証明しよう！'));

      final multiBody = PushNotificationService.getCommittedNotificationBody(['Work Out', '読書'], isJapanese: true);
      expect(multiBody, equals('カレンダーで約束した習慣です。今日の勝利を証明しよう！'));
    });

    test('getCommittedNotificationTitle & Body format in English fallback', () {
      final singleTitleEn = PushNotificationService.getCommittedNotificationTitle(['Work Out'], isJapanese: false);
      expect(singleTitleEn, equals('Today is 【Work Out】 day! 🔥'));

      final multiTitleEn = PushNotificationService.getCommittedNotificationTitle(['Work Out', 'Reading'], isJapanese: false);
      expect(multiTitleEn, equals('Today is 【Work Out】【Reading】 scheduled day! 🔥'));

      final singleBodyEn = PushNotificationService.getCommittedNotificationBody(['Work Out'], isJapanese: false);
      expect(singleBodyEn, contains('This is the day you promised on your calendar'));

      final multiBodyEn = PushNotificationService.getCommittedNotificationBody(['Work Out', 'Reading'], isJapanese: false);
      expect(multiBodyEn, contains('These are the habits promised on your calendar'));
    });

    test('getCommittedNotificationTitle & Body handle empty list gracefully', () {
      final emptyTitleJa = PushNotificationService.getCommittedNotificationTitle([], isJapanese: true);
      expect(emptyTitleJa, equals('本日は約束した習慣の予定日です！🔥'));

      final emptyTitleEn = PushNotificationService.getCommittedNotificationTitle([], isJapanese: false);
      expect(emptyTitleEn, equals('Today is your promised habit day! 🔥'));

      final emptyBodyJa = PushNotificationService.getCommittedNotificationBody([], isJapanese: true);
      expect(emptyBodyJa, contains('カレンダーで約束した習慣です'));

      final emptyBodyEn = PushNotificationService.getCommittedNotificationBody([], isJapanese: false);
      expect(emptyBodyEn, contains('These are the habits promised on your calendar'));
    });

    test('syncCommittedDailyReminder schedules aggregated notification for future date', () async {
      final fakePlugin = FakeLocalNotificationsPlugin();
      final pushService = PushNotificationService.instance;
      pushService.setLocalNotificationsPluginForTesting(fakePlugin);

      // 未来の日付（1年後）
      final futureDate = DateTime.now().add(const Duration(days: 365));
      final dateStr = DateHelper.toDateString(futureDate);
      final expectedId = PushNotificationService.getCommittedNotificationId(dateStr);

      await pushService.syncCommittedDailyReminder(
        dateStr: dateStr,
        taskTitles: ['ジムで筋トレ', '読書 30分'],
        reminderTime: '07:30',
        isJapanese: true,
      );

      // 既存同ID通知のキャンセルが呼ばれること
      expect(fakePlugin.cancelledIds, contains(expectedId));

      // 集約された1つの通知がスケジュールされること
      expect(fakePlugin.scheduledNotifications.length, equals(1));
      final scheduled = fakePlugin.scheduledNotifications.first;
      expect(scheduled['id'], equals(expectedId));
      expect(scheduled['title'], equals('本日は【ジムで筋トレ】【読書 30分】の予定日です！🔥'));
      expect(scheduled['body'], contains('今日の勝利を証明しよう！'));

      final scheduledDate = scheduled['scheduledDate'] as tz.TZDateTime;
      expect(scheduledDate.hour, equals(7));
      expect(scheduledDate.minute, equals(30));
    });

    test('syncCommittedDailyReminder schedules aggregated notification for future date in English', () async {
      final fakePlugin = FakeLocalNotificationsPlugin();
      final pushService = PushNotificationService.instance;
      pushService.setLocalNotificationsPluginForTesting(fakePlugin);

      final futureDate = DateTime.now().add(const Duration(days: 365));
      final dateStr = DateHelper.toDateString(futureDate);
      final expectedId = PushNotificationService.getCommittedNotificationId(dateStr);

      await pushService.syncCommittedDailyReminder(
        dateStr: dateStr,
        taskTitles: ['Workout', 'Reading'],
        reminderTime: '08:00',
        isJapanese: false,
      );

      expect(fakePlugin.cancelledIds, contains(expectedId));
      expect(fakePlugin.scheduledNotifications.length, equals(1));
      final scheduled = fakePlugin.scheduledNotifications.first;
      expect(scheduled['title'], equals('Today is 【Workout】【Reading】 scheduled day! 🔥'));
      expect(scheduled['body'], contains('These are the habits promised on your calendar'));
      final scheduledDate = scheduled['scheduledDate'] as tz.TZDateTime;
      expect(scheduledDate.hour, equals(8));
      expect(scheduledDate.minute, equals(0));
    });

    test('syncCommittedDailyReminder cancels notification when taskTitles is empty', () async {
      final fakePlugin = FakeLocalNotificationsPlugin();
      final pushService = PushNotificationService.instance;
      pushService.setLocalNotificationsPluginForTesting(fakePlugin);

      final futureDate = DateTime.now().add(const Duration(days: 30));
      final dateStr = DateHelper.toDateString(futureDate);
      final expectedId = PushNotificationService.getCommittedNotificationId(dateStr);

      await pushService.syncCommittedDailyReminder(
        dateStr: dateStr,
        taskTitles: [],
      );

      expect(fakePlugin.cancelledIds, contains(expectedId));
      expect(fakePlugin.scheduledNotifications, isEmpty);
    });

    test('syncCommittedDailyReminder cancels and skips scheduling for past date', () async {
      final fakePlugin = FakeLocalNotificationsPlugin();
      final pushService = PushNotificationService.instance;
      pushService.setLocalNotificationsPluginForTesting(fakePlugin);

      final pastDate = DateTime.now().subtract(const Duration(days: 5));
      final dateStr = DateHelper.toDateString(pastDate);
      final expectedId = PushNotificationService.getCommittedNotificationId(dateStr);

      await pushService.syncCommittedDailyReminder(
        dateStr: dateStr,
        taskTitles: ['筋トレ'],
        reminderTime: '08:00',
      );

      expect(fakePlugin.cancelledIds, contains(expectedId));
      expect(fakePlugin.scheduledNotifications, isEmpty);
    });

    test('cancelCommittedDailyReminder cancels the specific date notification', () async {
      final fakePlugin = FakeLocalNotificationsPlugin();
      final pushService = PushNotificationService.instance;
      pushService.setLocalNotificationsPluginForTesting(fakePlugin);

      final dateStr = '2026-10-20';
      final expectedId = PushNotificationService.getCommittedNotificationId(dateStr);

      await pushService.cancelCommittedDailyReminder(dateStr);
      expect(fakePlugin.cancelledIds, contains(expectedId));
    });
  });

  group('HeroTaskItem & TaskCard Commitment Badge Tests', () {
    test('HeroTaskItem isCommittedToday defaults to false and can be set to true', () {
      final defaultItem = HeroTaskItem(name: 'Work Out');
      expect(defaultItem.isCommittedToday, isFalse);

      final committedItem = HeroTaskItem(name: 'Work Out', isCommittedToday: true);
      expect(committedItem.isCommittedToday, isTrue);
    });

    testWidgets('TaskCard displays gold [🎯 今日の予約] badge when isCommittedToday && !isCompleted', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final committedUncompletedItem = HeroTaskItem(
        name: 'Work Out',
        isCommittedToday: true,
        completedPosts: const [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vfireProvider.overrideWith(() => FakeVFireNotifier()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TaskCard(
                item: committedUncompletedItem,
                index: 0,
                total: 1,
                depth: 0,
                showCamera: false,
                tierColor: Colors.amber,
                isExpanded: false,
                userPhotos: const {},
                myPhotoUrl: null,
                myUsername: 'Tester',
                myBadgeUrl: null,
                myBadgeAnimation: null,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // [🎯 今日の予約] バッジが表示されること
      expect(find.text('🎯 今日の予約'), findsOneWidget);
    });

    testWidgets('TaskCard does NOT display [🎯 今日の予約] badge when already completed', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final now = DateTime.now();
      final completedItem = HeroTaskItem(
        name: 'Work Out',
        isCommittedToday: true,
        completedPosts: [
          Post(
            id: 'post_1',
            userId: 'user_1',
            taskName: 'Work Out',
            createdAt: now,
            expiresAt: now.add(const Duration(hours: 24)),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vfireProvider.overrideWith(() => FakeVFireNotifier()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TaskCard(
                item: completedItem,
                index: 0,
                total: 1,
                depth: 0,
                showCamera: false,
                tierColor: Colors.amber,
                isExpanded: false,
                userPhotos: const {},
                myPhotoUrl: null,
                myUsername: 'Tester',
                myBadgeUrl: null,
                myBadgeAnimation: null,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 完了している場合は [🎯 今日の予約] バッジが表示されないこと
      expect(find.text('🎯 今日の予約'), findsNothing);
    });
  });

  group('HabitPlannerSheet Today Completion Badge Tests', () {
    testWidgets('displays [達成済 ✨] badge when task is scheduled and posted today', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final now = DateTime.now();
      final todayStr = DateHelper.toDateString(now);

      final todayPost = Post(
        id: 'post_today',
        userId: 'user1',
        taskName: 'ジムで筋トレ',
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 24)),
      );

      final user = AppUser(
        uid: 'user1',
        recentPostDates: [todayStr],
        tasks: const [
          AppTask(
            id: 'task_gym',
            title: 'ジムで筋トレ',
            frequencyType: TaskFrequencyType.daily,
          ),
          AppTask(
            id: 'task_read',
            title: '読書 30分',
            frequencyType: TaskFrequencyType.daily,
          ),
        ],
        taskSchedules: {
          todayStr: ['task_gym', 'task_read'],
        },
      );

      final mockUserService = MockUserService();
      final mockPostService = MockPostService(posts: [todayPost]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            postServiceProvider.overrideWithValue(mockPostService),
            userServiceProvider.overrideWithValue(mockUserService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: HabitPlannerSheet(
                user: user,
                initialDate: now,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 「ジムで筋トレ」は本日達成済みなので [達成済 ✨] が表示されること
      expect(find.text('達成済 ✨'), findsWidgets);
    });
  });

  group('HomeData & Serialization with taskSchedules & user', () {
    test('HomeData stores and serializes user and taskSchedules correctly', () {
      const user = AppUser(
        uid: 'u1',
        taskSchedules: {
          '2026-10-15': ['Work Out', 'Reading'],
        },
      );

      final homeData = HomeData(
        streak: 5,
        postedToday: false,
        isAllTasksCompleted: false,
        username: 'Hero',
        tasks: const [],
        followingUids: const [],
        feedPosts: const [],
        postedFriends: const [],
        userNames: const {},
        userPhotos: const {},
        userStreaks: const {},
        userBadgeUrls: const {},
        userBadgeAnimations: const {},
        isRecommended: true,
        totalPosts: 10,
        user: user,
        taskSchedules: const {
          '2026-10-15': ['Work Out', 'Reading'],
        },
      );

      final json = homeData.toJson();
      expect(json['user'], isNotNull);
      expect(json['taskSchedules'], equals({
        '2026-10-15': ['Work Out', 'Reading'],
      }));

      final restored = HomeData.fromJson(json);
      expect(restored.user?.uid, equals('u1'));
      expect(restored.taskSchedules['2026-10-15'], equals(['Work Out', 'Reading']));
      expect(restored, equals(homeData));
    });
  });

  group('Camera Task Prioritization and Selection Sorting Tests', () {
    test('prioritizes today scheduled quick task over uncompleted non-scheduled userTask', () {
      final now = DateTime.now();
      final todayStr = DateHelper.toDateString(now);

      const registeredTask = AppTask(id: 't_walk', title: '散歩', frequencyType: TaskFrequencyType.daily);

      final homeData = HomeData(
        streak: 1,
        postedToday: false,
        isAllTasksCompleted: false,
        username: 'User',
        tasks: const [registeredTask],
        followingUids: const [],
        feedPosts: const [],
        postedFriends: const [],
        userNames: const {},
        userPhotos: const {},
        userStreaks: const {},
        userBadgeUrls: const {},
        userBadgeAnimations: const {},
        isRecommended: false,
        totalPosts: 1,
        taskSchedules: {
          todayStr: ['英語の勉強'], // 本日クイック予約されたタスク
        },
      );

      final effectiveTask = CameraScreen.computeEffectiveTaskName(homeData: homeData);
      expect(effectiveTask, equals('英語の勉強'));
    });

    test('prioritizes uncompleted scheduled task over completed scheduled task', () {
      final now = DateTime.now();
      final todayStr = DateHelper.toDateString(now);

      final completedGymTask = AppTask(
        id: 't_gym',
        title: 'ジムで筋トレ',
        completedAt: now, // 本日達成済み
      );
      const uncompletedReadingTask = AppTask(
        id: 't_read',
        title: 'プログラミング学習', // 未達成
      );

      final homeData = HomeData(
        streak: 1,
        postedToday: false,
        isAllTasksCompleted: false,
        username: 'User',
        tasks: [completedGymTask, uncompletedReadingTask],
        followingUids: const [],
        feedPosts: const [],
        postedFriends: const [],
        userNames: const {},
        userPhotos: const {},
        userStreaks: const {},
        userBadgeUrls: const {},
        userBadgeAnimations: const {},
        isRecommended: false,
        totalPosts: 1,
        taskSchedules: {
          todayStr: ['t_gym', 't_read'], // 両方予約中
        },
      );

      final effectiveTask = CameraScreen.computeEffectiveTaskName(homeData: homeData);
      expect(effectiveTask, equals('プログラミング学習'));
    });

    test('computeTaskCandidates sorts uncompleted scheduled tasks to the very top', () {
      final now = DateTime.now();
      final todayStr = DateHelper.toDateString(now);

      final completedTask = AppTask(id: 't1', title: '早起き', completedAt: now);
      const uncompletedTask = AppTask(id: 't2', title: '読書');
      const uncommittedTask = AppTask(id: 't3', title: '散歩');

      final homeData = HomeData(
        streak: 1,
        postedToday: false,
        isAllTasksCompleted: false,
        username: 'User',
        tasks: [completedTask, uncompletedTask, uncommittedTask],
        followingUids: const [],
        feedPosts: const [],
        postedFriends: const [],
        userNames: const {},
        userPhotos: const {},
        userStreaks: const {},
        userBadgeUrls: const {},
        userBadgeAnimations: const {},
        isRecommended: false,
        totalPosts: 1,
        taskSchedules: {
          todayStr: ['t1', 't2', 'ヨガ 20分'], // t1(達成), t2(未達成), クイック(未達成)
        },
      );

      final candidates = CameraScreen.computeTaskCandidates(
        homeData: homeData,
        currentTaskName: '読書',
      );

      // 先頭2件は未完了かつ本日予約のタスク（読書 と ヨガ 20分）
      final topTitles = [candidates[0].title, candidates[1].title];
      expect(topTitles, containsAll(['読書', 'ヨガ 20分']));

      // 完了済みタスク（早起き）は未完了タスクより後ろ
      final completedIndex = candidates.indexWhere((t) => t.title == '早起き');
      final uncompletedIndex = candidates.indexWhere((t) => t.title == '読書');
      expect(uncompletedIndex, lessThan(completedIndex));
    });
  });
}
