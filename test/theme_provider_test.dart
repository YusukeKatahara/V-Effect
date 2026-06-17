import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_effect/providers/theme_provider.dart';

void main() {
  // SharedPreferences のモックを設定するために必要なテストバインディング初期化
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeProvider Tests', () {
    test('Initial theme mode is dark to prevent splash screen white flash', () {
      SharedPreferences.setMockInitialValues({});
      final provider = ThemeProvider();
      // 初期値がダークであることを確認
      expect(provider.themeMode, ThemeMode.dark);
    });

    test('Loads saved theme mode light from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
      final provider = ThemeProvider();
      
      // コンストラクタ内の非同期ロードが完了するのを待機
      await Future.delayed(Duration.zero);
      expect(provider.themeMode, ThemeMode.light);
    });

    test('Loads saved theme mode dark from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      final provider = ThemeProvider();
      
      await Future.delayed(Duration.zero);
      expect(provider.themeMode, ThemeMode.dark);
    });

    test('Loads saved theme mode system from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'system'});
      final provider = ThemeProvider();
      
      await Future.delayed(Duration.zero);
      expect(provider.themeMode, ThemeMode.system);
    });

    test('Handles migration from old isDarkMode = false to light mode and persists', () async {
      SharedPreferences.setMockInitialValues({'isDarkMode': false});
      final provider = ThemeProvider();
      
      await Future.delayed(Duration.zero);
      expect(provider.themeMode, ThemeMode.light);
      
      // マイグレーション後に新キー 'theme_mode' に書き出されていることを確認
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'light');
    });

    test('Handles migration from old isDarkMode = true to dark mode and persists', () async {
      SharedPreferences.setMockInitialValues({'isDarkMode': true});
      final provider = ThemeProvider();
      
      await Future.delayed(Duration.zero);
      expect(provider.themeMode, ThemeMode.dark);
      
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'dark');
    });

    test('Fallbacks to system theme mode when no keys exist', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ThemeProvider();
      
      await Future.delayed(Duration.zero);
      expect(provider.themeMode, ThemeMode.system);
    });

    test('setThemeMode updates state, notifies listeners, and persists selection', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ThemeProvider();
      
      await Future.delayed(Duration.zero);
      expect(provider.themeMode, ThemeMode.system);
      
      var listenerCalled = false;
      provider.addListener(() {
        listenerCalled = true;
      });
      
      await provider.setThemeMode(ThemeMode.light);
      
      expect(provider.themeMode, ThemeMode.light);
      expect(listenerCalled, isTrue);
      
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'light');
    });
  });
}
