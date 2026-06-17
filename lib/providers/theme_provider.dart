import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_effect/config/app_colors.dart';

/// アプリ全体のテーマモード（ライト、ダーク、システム設定同期）を管理するプロバイダー
///
/// 起動時の白飛び（White Flash）を防ぐため、初期値は `ThemeMode.dark` に設定しています。
/// SharedPreferences から非同期で設定を読み込み、変更時は永続化を行います。
class ThemeProvider extends ChangeNotifier {
  // 初期値はダークモードに設定（起動時のフラッシュ防止）
  ThemeMode _themeMode = ThemeMode.dark;
  Future<void>? _loadFuture;
  bool _hasUserOverride = false;
  Future<void> _writeChain = Future.value();

  // ストレージとの同期が完了したかを示すフラグ（起動時のデータ競合/boot-raceを防ぐため）
  bool _isStorageSynced = false;

  ThemeMode get themeMode => _themeMode;
  Future<void>? get loadFuture => _loadFuture;

  ThemeProvider() {
    _loadFuture = _loadTheme();
  }

  /// SharedPreferences から保存されたテーマ設定を非同期で読み込みます。
  /// 旧バージョンの 'isDarkMode' (bool) からの移行処理も含んでいます。
  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (_hasUserOverride) return;

      // 新しい String 型のキー 'theme_mode' を取得
      final savedMode = prefs.getString('theme_mode');
      
      if (savedMode != null) {
        _themeMode = _parseThemeMode(savedMode);
      } else {
        // 'theme_mode' が存在しない場合、旧 boolean キー 'isDarkMode' を確認
        final isDarkMode = prefs.getBool('isDarkMode');
        if (isDarkMode != null) {
          // 'isDarkMode' の値を新フォーマットに変換して設定
          _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
          // 新しいキー 'theme_mode' で保存して移行完了とする
          await prefs.setString('theme_mode', isDarkMode ? 'dark' : 'light');
          // 旧キー 'isDarkMode' を削除
          await prefs.remove('isDarkMode');
        } else {
          // どちらも存在しない場合のデフォルトはシステム設定
          _themeMode = ThemeMode.system;
        }
      }

      if (_hasUserOverride) return;
      
      // AppColors の状態も同期
      AppColors.updateThemeMode(_themeMode);

      // 同期が完了したことをマーク
      _isStorageSynced = true;
      
      // 状態が変化したため、リスナー（UIなど）に通知して再描画を促します
      notifyListeners();
    } catch (e) {
      debugPrint('テーマの読み込みエラー: $e');
    }
  }

  /// 新しいテーマモードを設定し、SharedPreferences に保存します。
  Future<void> setThemeMode(ThemeMode mode) async {
    _hasUserOverride = true;
    
    // 同じテーマで、かつストレージ同期も完了している場合のみ早期リターン
    if (_themeMode == mode && _isStorageSynced) return;
    _isStorageSynced = true;
    _themeMode = mode;
    
    // AppColors の状態も同期
    AppColors.updateThemeMode(mode);
    notifyListeners();

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

