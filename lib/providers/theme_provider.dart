import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_effect/config/app_colors.dart';

/// アプリ全体のテーマモード（ライト、ダーク、システム設定同期）を管理するプロバイダー
final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(ThemeNotifier.new);

class ThemeNotifier extends Notifier<ThemeMode> {
  Future<void>? _loadFuture;
  bool _hasUserOverride = false;
  Future<void> _writeChain = Future.value();
  bool _isStorageSynced = false;

  Future<void>? get loadFuture => _loadFuture;

  @override
  ThemeMode build() {
    // 初期値はダークモードに設定（起動時のフラッシュ防止）
    _loadFuture = _loadTheme();
    return ThemeMode.dark;
  }

  /// SharedPreferences から保存されたテーマ設定を非同期で読み込みます。
  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (_hasUserOverride) return;

      ThemeMode newMode;
      // 新しい String 型のキー 'theme_mode' を取得
      final savedMode = prefs.getString('theme_mode');
      
      if (savedMode != null) {
        newMode = _parseThemeMode(savedMode);
      } else {
        // 'theme_mode' が存在しない場合、旧 boolean キー 'isDarkMode' を確認
        final isDarkMode = prefs.getBool('isDarkMode');
        if (isDarkMode != null) {
          newMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
          await prefs.setString('theme_mode', isDarkMode ? 'dark' : 'light');
          await prefs.remove('isDarkMode');
        } else {
          newMode = ThemeMode.system;
        }
      }

      if (_hasUserOverride) return;
      
      // AppColors の状態も同期
      AppColors.updateThemeMode(newMode);
      _isStorageSynced = true;
      
      state = newMode;
    } catch (e) {
      debugPrint('テーマの読み込みエラー: $e');
    }
  }

  /// 新しいテーマモードを設定し、SharedPreferences に保存します。
  Future<void> setThemeMode(ThemeMode mode) async {
    _hasUserOverride = true;
    
    // 同じテーマで、かつストレージ同期も完了している場合のみ早期リターン
    if (state == mode && _isStorageSynced) return;
    
    _isStorageSynced = true;
    state = mode;
    
    // AppColors の状態も同期
    AppColors.updateThemeMode(mode);

    _writeChain = _writeChain.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('theme_mode', _themeModeToString(mode));
      } catch (e) {
        debugPrint('テーマの保存エラー: $e');
      }
    });

    await _writeChain;
  }

  /// 文字列から ThemeMode へのパース処理
  ThemeMode _parseThemeMode(String val) {
    switch (val) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  /// ThemeMode から保存用の文字列への変換処理
  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
