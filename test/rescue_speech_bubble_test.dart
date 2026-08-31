import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_effect/providers/rescue_achieved_provider.dart';
import 'package:v_effect/screens/home/components/rescue_speech_bubble.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('RescueSpeechBubble shows countdown when not achieved (< 150)', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: RescueSpeechBubble(
              postId: 'post_1',
              currentCount: 50,
              targetCount: 150,
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('あと 100VFIREで救済！'), findsOneWidget);
    expect(find.text('救済達成！'), findsNothing);

    // コントローラーを解放するためにアンマウント
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('RescueSpeechBubble shows achievement on first view and marks as seen', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: RescueSpeechBubble(
              postId: 'post_first_achieved',
              currentCount: 150,
              targetCount: 150,
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 初回表示時は「救済達成！」が表示される
    expect(find.text('救済達成！'), findsOneWidget);

    // バックグラウンドで表示済みとしてマークされたことを検証
    expect(container.read(rescueAchievedProvider).contains('post_first_achieved'), isTrue);

    // コントローラーを解放するためにアンマウント
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('RescueSpeechBubble is hidden on second view when already seen', (tester) async {
    // 過去に表示済みとして初期化
    SharedPreferences.setMockInitialValues({
      'seen_rescue_achieved_bubble_post_ids': ['post_already_seen'],
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);

    // 初期ロードを実行
    container.read(rescueAchievedProvider);
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 50));
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: RescueSpeechBubble(
              postId: 'post_already_seen',
              currentCount: 150,
              targetCount: 150,
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    // 2回目の表示時は「救済達成！」が非表示（消えている）
    expect(find.text('救済達成！'), findsNothing);

    // アンマウント
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
