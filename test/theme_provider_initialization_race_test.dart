import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_effect/providers/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeProvider Initialization Race Condition Test', () {
    test('Race Condition: setThemeMode immediately after instantiation fails', () async {
      // 初期状態として 'dark' が保存されていると仮定
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      
      // 事前に SharedPreferences インスタンスをロードして、キャッシュが初期化されている状態を作ります
      // (これは実際のアプリ起動時に main() 内で初期化されるなど、キャッシュがすでに存在する状態を再現しています)
      await SharedPreferences.getInstance();
      
      final provider = ThemeProvider();
      
      // _loadTheme (非同期) の完了を待たずに、即座にテーマをライトに設定
      final setFuture = provider.setThemeMode(ThemeMode.light);

      await setFuture;
      // イベントループの残りのマイクロタスクの完了を待機
      await Future.delayed(Duration.zero);

      // 期待値: ユーザーが明示的に選択したライトモードであること
      // 実際: 非同期ロードが完了した際に古い設定 (dark) でメモリ内の状態が上書きされてしまうため、このアサーションは失敗します
      expect(provider.themeMode, ThemeMode.light);
    });
  });
}
