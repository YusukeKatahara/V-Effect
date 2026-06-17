import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_effect/providers/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/shared_preferences');

  group('ThemeProvider Write Race Condition Test', () {
    test('Race Condition: Delayed native write causes out-of-order persistence on restart', () async {
      final Map<String, Object> nativeStorage = {
        'flutter.theme_mode': 'system',
      };

      // ネイティブ側（ディスク書き込みなど）での非同期な遅延を再現するカスタムハンドラー
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        try {
          if (methodCall.method == 'getAll') {
            return nativeStorage;
          }
          if (methodCall.method == 'setString') {
            final args = methodCall.arguments;
            if (args is Map) {
              final key = args['key'] as String;
              final value = args['value'] as String;
              if (value == 'light') {
                // ライトモードへの変更書き込みを意図的に50ミリ秒遅延させて、I/O遅延を再現
                await Future.delayed(const Duration(milliseconds: 50));
              }
              nativeStorage[key] = value;
              return true;
            }
          }
        } catch (e, stack) {
          print('Mock MethodCallHandler error: $e\n$stack');
        }
        return null;
      });

      // 静的キャッシュをクリアしてカスタムハンドラーを反映させます
      SharedPreferences.resetStatic();

      final provider = ThemeProvider();
      await Future.delayed(Duration.zero); // 初期ロード完了を待機

      // ライトモード -> ダークモードへと高速でテーマを切り替える
      final f1 = provider.setThemeMode(ThemeMode.light);
      final f2 = provider.setThemeMode(ThemeMode.dark);

      await Future.wait([f1, f2]);

      // 現在のメモリ上では最後の操作であるダークモードになっているべき
      expect(provider.themeMode, ThemeMode.dark);

      // アプリが再起動した状況を再現するため、静的キャッシュをリセット
      SharedPreferences.resetStatic();
      
      // 再起動後の SharedPreferences インスタンスを取得（ネイティブストレージから再ロード）
      final newPrefs = await SharedPreferences.getInstance();
      
      print('ネイティブストレージの最終状態: $nativeStorage');
      print('再起動後の保存されているテーマモード: ${newPrefs.getString('theme_mode')}');

      // 期待値: 最後に設定したダークモード ('dark') が永続化されていること
      // 実際: 遅延したライトモードの書き込みが後から完了したため、'light' に上書きされてしまっており、このアサーションは失敗します
      expect(newPrefs.getString('theme_mode'), 'dark');
    });
  });
}
