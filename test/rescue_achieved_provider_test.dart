import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_effect/providers/rescue_achieved_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('RescueAchievedNotifier initializes empty and marks posts as seen', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(rescueAchievedProvider.notifier);

    expect(notifier.isSeen('post_1'), isFalse);

    await notifier.markAsSeen('post_1');

    expect(notifier.isSeen('post_1'), isTrue);
    expect(container.read(rescueAchievedProvider).contains('post_1'), isTrue);

    // SharedPreferences に保存されているか確認
    final prefs = await SharedPreferences.getInstance();
    final savedList = prefs.getStringList('seen_rescue_achieved_bubble_post_ids');
    expect(savedList, contains('post_1'));
  });

  test('RescueAchievedNotifier restores previously seen posts from SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({
      'seen_rescue_achieved_bubble_post_ids': ['post_old_1', 'post_old_2'],
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);

    // プロバイダーを監視して初期化を開始
    container.read(rescueAchievedProvider);

    // 非同期ロード処理の完了を待機
    await pumpEventQueue();

    final state = container.read(rescueAchievedProvider);
    expect(state.contains('post_old_1'), isTrue);
    expect(state.contains('post_old_2'), isTrue);
    expect(state.contains('post_new'), isFalse);
  });
}
