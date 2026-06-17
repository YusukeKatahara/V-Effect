import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_effect/providers/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/shared_preferences');

  group('ThemeProvider Stress and Race Condition Tests', () {
    test('Race Condition: setThemeMode immediately after instantiation fails', () async {
      print('=== START TEST 1 ===');
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      
      await SharedPreferences.getInstance();
      
      final provider = ThemeProvider();
      final setFuture = provider.setThemeMode(ThemeMode.light);

      await setFuture;
      await Future.delayed(Duration.zero);

      print('Test 1 provider.themeMode = ${provider.themeMode}');
      expect(provider.themeMode, ThemeMode.light);
      print('=== END TEST 1 ===');
    });

    test('Race Condition: Delayed native write causes out-of-order persistence on restart', () async {
      print('=== START TEST 2 ===');
      final Map<String, Object> nativeStorage = {
        'flutter.theme_mode': 'system',
      };

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        print('--- Test 2 Mock handler: ${methodCall.method} with ${methodCall.arguments}');
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

      SharedPreferences.resetStatic();

      final provider = ThemeProvider();
      await Future.delayed(Duration.zero); // Let initialization finish

      final f1 = provider.setThemeMode(ThemeMode.light);
      final f2 = provider.setThemeMode(ThemeMode.dark);

      await Future.wait([f1, f2]);

      expect(provider.themeMode, ThemeMode.dark);

      SharedPreferences.resetStatic();
      
      final newPrefs = await SharedPreferences.getInstance();
      
      print('Native storage state: $nativeStorage');
      print('Restarted SharedPreferences theme_mode: ${newPrefs.getString('theme_mode')}');

      expect(newPrefs.getString('theme_mode'), 'dark');
      print('=== END TEST 2 ===');
    });
  });
}
