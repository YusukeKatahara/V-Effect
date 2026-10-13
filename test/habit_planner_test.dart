import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:v_effect/models/app_user.dart';
import 'package:v_effect/models/app_task.dart';
import 'package:v_effect/models/post.dart';
import 'package:v_effect/screens/profile/components/habit_planner_sheet.dart';
import 'package:v_effect/screens/profile_screen.dart';
import 'package:v_effect/providers/service_providers.dart';
import 'package:v_effect/services/post_service.dart';
import 'package:v_effect/services/push_notification_service.dart';
import 'package:v_effect/services/user_service.dart';
import 'package:v_effect/utils/date_helper.dart';

// モック用の PostService 実装
class MockPostService implements PostService {
  final List<Post> posts;
  MockPostService({this.posts = const []});

  @override
  Future<List<Post>> getAllMyPastPosts({dynamic source}) async {
    if (posts.isNotEmpty) return posts;
    return [
      Post(
        id: 'post_1',
        userId: 'user_123',
        taskName: 'ジムで筋トレ',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        expiresAt: DateTime.now().add(const Duration(hours: 12)),
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// モック用の UserService 実装
class MockUserService implements UserService {
  final List<Map<String, dynamic>> updateScheduleCalls = [];
  bool shouldThrowOnUpdate = false;

  @override
  Future<void> updateTaskSchedule(String dateStr, List<String> taskIds) async {
    if (shouldThrowOnUpdate) {
      throw Exception('Firestore network error');
    }
    updateScheduleCalls.add({
      'dateStr': dateStr,
      'taskIds': List<String>.from(taskIds),
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// モック用の PushNotificationService 実装
class MockPushNotificationService implements PushNotificationService {
  final List<Map<String, dynamic>> syncCalls = [];

  @override
  Future<void> syncCommittedDailyReminder({
    required String dateStr,
    required List<String> taskTitles,
    String? reminderTime,
    bool? isJapanese,
  }) async {
    syncCalls.add({
      'dateStr': dateStr,
      'taskTitles': List<String>.from(taskTitles),
      'reminderTime': reminderTime,
      'isJapanese': isJapanese,
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  group('AppUser taskSchedules serialization tests', () {
    test('defaults to empty map when missing in fromMap', () {
      final user = AppUser.fromMap('user1', {
        'username': 'test_user',
      });

      expect(user.taskSchedules, isEmpty);
    });

    test('extracts taskSchedules map correctly from fromMap', () {
      final user = AppUser.fromMap('user1', {
        'username': 'test_user',
        'taskSchedules': {
          '2026-10-15': ['task_gym', 'task_read'],
          '2026-10-16': ['task_run'],
        },
      });

      expect(user.taskSchedules.length, 2);
      expect(user.taskSchedules['2026-10-15'], equals(['task_gym', 'task_read']));
      expect(user.taskSchedules['2026-10-16'], equals(['task_run']));
    });

    test('gracefully handles non-map or corrupted taskSchedules', () {
      final user1 = AppUser.fromMap('user1', {
        'taskSchedules': 'invalid_string',
      });
      expect(user1.taskSchedules, isEmpty);

      final user2 = AppUser.fromMap('user2', {
        'taskSchedules': 12345,
      });
      expect(user2.taskSchedules, isEmpty);
    });

    test('toFirestore includes fieldTaskSchedules', () {
      const user = AppUser(
        uid: 'user1',
        taskSchedules: {
          '2026-10-20': ['task_a', 'task_b'],
        },
      );

      final map = user.toFirestore();
      expect(map[AppUser.fieldTaskSchedules], equals({
        '2026-10-20': ['task_a', 'task_b'],
      }));
    });

    test('copyWith updates taskSchedules or retains existing', () {
      const user = AppUser(
        uid: 'user1',
        taskSchedules: {
          '2026-10-20': ['task_a'],
        },
      );

      final userWithNew = user.copyWith(taskSchedules: {
        '2026-10-21': ['task_c'],
      });
      expect(userWithNew.taskSchedules.containsKey('2026-10-21'), isTrue);
      expect(userWithNew.taskSchedules.containsKey('2026-10-20'), isFalse);

      final userRetained = user.copyWith(displayName: 'New Name');
      expect(userRetained.taskSchedules, equals(user.taskSchedules));
    });
  });

  group('StreakMonthCalendarWidget widget tests', () {
    testWidgets('renders month calendar, scheduled dots, and handles taps', (tester) async {
      final now = DateTime.now();
      // 10日はどの月でも必ず存在する日付
      final targetDay = 10;
      final targetDateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${targetDay.toString().padLeft(2, '0')}';

      DateTime? tappedDate;
      bool generalTapCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreakMonthCalendarWidget(
              recentPostDates: const [],
              activeColor: Colors.amber,
              taskSchedules: {
                targetDateStr: ['task_1'],
              },
              onDateTap: (date) {
                tappedDate = date;
              },
              onTap: () {
                generalTapCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 月のヘッダーが表示されていること
      expect(find.text('${now.month}月'), findsOneWidget);
      // 「予定」アフォーダンスが表示されていること
      expect(find.text('予定'), findsOneWidget);

      // 「予定」ボタンをタップ
      await tester.tap(find.text('予定'));
      expect(generalTapCalled, isTrue);

      // 日付セル（10日）をタップ
      final dayFinder = find.text('$targetDay');
      expect(dayFinder, findsOneWidget);
      await tester.tap(dayFinder);
      expect(tappedDate, isNotNull);
      expect(tappedDate!.day, targetDay);
      expect(tappedDate!.month, now.month);
    });
  });

  group('HabitPlannerSheet widget tests', () {
    testWidgets('renders month calendar, weekly & monthly goal commitment badges', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayStr = DateHelper.toDateString(yesterday);

      final user = AppUser(
        uid: 'user1',
        recentPostDates: [yesterdayStr],
        tasks: const [
          AppTask(
            id: 'task_gym',
            title: 'ジムで筋トレ',
            frequencyType: TaskFrequencyType.weeklyTarget,
            targetCount: 3,
          ),
          AppTask(
            id: 'task_book',
            title: '読書 30分',
            frequencyType: TaskFrequencyType.monthlyTarget,
            targetCount: 10,
          ),
          AppTask(
            id: 'task_meditation',
            title: '朝の瞑想 10分',
            frequencyType: TaskFrequencyType.daily,
          ),
        ],
        taskSchedules: {
          DateHelper.toDateString(now): ['task_gym', 'task_book'],
        },
      );

      final mockUserService = MockUserService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            postServiceProvider.overrideWithValue(MockPostService()),
            userServiceProvider.overrideWithValue(mockUserService),
            pushNotificationServiceProvider.overrideWithValue(MockPushNotificationService()),
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

      // シートタイトル
      expect(find.text('習慣プランナー & 達成記録'), findsOneWidget);
      // 登録タスク名が表示されること
      expect(find.text('ジムで筋トレ'), findsWidgets);
      expect(find.text('読書 30分'), findsWidgets);
      expect(find.text('朝の瞑想 10分'), findsOneWidget);
      // 週次タスクの目標情報（週3回目標）が表示されること
      expect(find.textContaining('週3回'), findsWidgets);
      // 月次タスクの目標情報（月10回目標）が表示されること
      expect(find.textContaining('月10回'), findsWidgets);
      // 予約中バッジ
      expect(find.text('予約中のタスク (2件):'), findsOneWidget);
    });

    testWidgets('toggles task schedule on tap and calls UserService', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final now = DateTime.now();
      final todayStr = DateHelper.toDateString(now);

      final user = const AppUser(
        uid: 'user1',
        tasks: [
          AppTask(
            id: 'task_run',
            title: 'ランニング 5km',
            frequencyType: TaskFrequencyType.daily,
          ),
        ],
        taskSchedules: {},
      );

      final mockUserService = MockUserService();
      final mockPushService = MockPushNotificationService();
      bool onScheduleUpdatedCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            postServiceProvider.overrideWithValue(MockPostService()),
            userServiceProvider.overrideWithValue(mockUserService),
            pushNotificationServiceProvider.overrideWithValue(mockPushService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: HabitPlannerSheet(
                user: user,
                initialDate: now,
                onScheduleUpdated: () {
                  onScheduleUpdatedCalled = true;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 初期状態では未予約
      expect(find.text('予約中のタスク (1件):'), findsNothing);

      // タスク行をタップして予定を追加
      await tester.tap(find.text('ランニング 5km'));
      await tester.pumpAndSettle();

      // mockUserService が呼び出されたこと
      expect(mockUserService.updateScheduleCalls.length, 1);
      expect(mockUserService.updateScheduleCalls.first['dateStr'], todayStr);
      expect(mockUserService.updateScheduleCalls.first['taskIds'], contains('task_run'));
      expect(onScheduleUpdatedCalled, isTrue);

      // プッシュ通知の同期が呼び出されたこと
      expect(mockPushService.syncCalls.length, 1);
      expect(mockPushService.syncCalls.first['dateStr'], todayStr);
      expect(mockPushService.syncCalls.first['taskTitles'], contains('ランニング 5km'));

      // UI上に予約中タスクとして表示されること
      expect(find.text('予約中のタスク (1件):'), findsOneWidget);

      // もう一度タップしてトグル解除
      await tester.tap(find.text('ランニング 5km').first);
      await tester.pumpAndSettle();

      expect(mockUserService.updateScheduleCalls.length, 2);
      expect(mockUserService.updateScheduleCalls.last['taskIds'], isEmpty);
      expect(find.text('予約中のタスク (1件):'), findsNothing);

      // トグル解除時も通知同期が呼び出されたこと
      expect(mockPushService.syncCalls.length, 2);
      expect(mockPushService.syncCalls.last['taskTitles'], isEmpty);
    });

    testWidgets('adds quick task via text field and button', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final now = DateTime.now();
      final todayStr = DateHelper.toDateString(now);

      final user = const AppUser(
        uid: 'user1',
        tasks: [],
        taskSchedules: {},
      );

      final mockUserService = MockUserService();
      final mockPushService = MockPushNotificationService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            postServiceProvider.overrideWithValue(MockPostService()),
            userServiceProvider.overrideWithValue(mockUserService),
            pushNotificationServiceProvider.overrideWithValue(mockPushService),
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

      // クイック予定入力
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);
      await tester.enterText(textFieldFinder, 'ヨガ 20分');

      // 追加ボタンをタップ
      await tester.tap(find.text('追加'));
      await tester.pumpAndSettle();

      expect(mockUserService.updateScheduleCalls.length, 1);
      expect(mockUserService.updateScheduleCalls.first['dateStr'], todayStr);
      expect(mockUserService.updateScheduleCalls.first['taskIds'], contains('ヨガ 20分'));
      expect(find.text('ヨガ 20分'), findsOneWidget);
      expect(find.text('予約中のタスク (1件):'), findsOneWidget);
    });

    testWidgets('removes scheduled task via cancel icon button', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final now = DateTime.now();
      final todayStr = DateHelper.toDateString(now);

      final user = AppUser(
        uid: 'user1',
        tasks: const [],
        taskSchedules: {
          todayStr: ['散歩 30分'],
        },
      );

      final mockUserService = MockUserService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            postServiceProvider.overrideWithValue(MockPostService()),
            userServiceProvider.overrideWithValue(mockUserService),
            pushNotificationServiceProvider.overrideWithValue(MockPushNotificationService()),
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

      expect(find.text('散歩 30分'), findsOneWidget);
      expect(find.text('予約中のタスク (1件):'), findsOneWidget);

      // 削除ボタン (Icons.cancel_rounded) をタップ
      final cancelIconFinder = find.byIcon(Icons.cancel_rounded);
      expect(cancelIconFinder, findsOneWidget);
      await tester.tap(cancelIconFinder);
      await tester.pumpAndSettle();

      expect(mockUserService.updateScheduleCalls.length, 1);
      expect(mockUserService.updateScheduleCalls.first['taskIds'], isEmpty);
      expect(find.text('予約中のタスク (1件):'), findsNothing);
    });

    testWidgets('viewing past date displays past schedule history in read-only mode', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final now = DateTime.now();
      final pastDate = now.subtract(const Duration(days: 3));
      final pastDateStr = DateHelper.toDateString(pastDate);

      final user = AppUser(
        uid: 'user1',
        tasks: const [
          AppTask(
            id: 'task_guitar',
            title: 'ギター練習',
          ),
        ],
        taskSchedules: {
          pastDateStr: ['ギター練習'],
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            postServiceProvider.overrideWithValue(MockPostService()),
            userServiceProvider.overrideWithValue(MockUserService()),
            pushNotificationServiceProvider.overrideWithValue(MockPushNotificationService()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: HabitPlannerSheet(
                user: user,
                initialDate: pastDate,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 過去日の場合は「この日の予定履歴」が表示されること
      expect(find.text('この日の予定履歴'), findsOneWidget);
      expect(find.text('ギター練習'), findsOneWidget);

      // 過去日の場合は予定追加入力フィールドやチェックボックス等のコミットUIが表示されないこと
      expect(find.text('習慣コミットメント（予定）'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('追加'), findsNothing);
    });

    testWidgets('rolls back and displays snackbar if updateTaskSchedule throws', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final now = DateTime.now();

      final user = const AppUser(
        uid: 'user1',
        tasks: [
          AppTask(
            id: 'task_run',
            title: 'ランニング',
          ),
        ],
        taskSchedules: {},
      );

      final mockUserService = MockUserService()..shouldThrowOnUpdate = true;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            postServiceProvider.overrideWithValue(MockPostService()),
            userServiceProvider.overrideWithValue(mockUserService),
            pushNotificationServiceProvider.overrideWithValue(MockPushNotificationService()),
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

      // タスク行をタップ
      await tester.tap(find.text('ランニング'));
      await tester.pumpAndSettle();

      // エラーのスナックバーが表示されること
      expect(find.text('予定の保存に失敗しました'), findsOneWidget);
      // ローカル状態がロールバックされ、予約中リストに残っていないこと
      expect(find.text('予約中のタスク (1件):'), findsNothing);
    });
  });
}
