import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final languageProvider = StateNotifierProvider<LanguageNotifier, String>((ref) {
  return LanguageNotifier();
});

class LanguageNotifier extends StateNotifier<String> {
  LanguageNotifier() : super('ja') {
    _loadLanguage();
  }

  static const _key = 'app_language';

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString(_key);
    
    if (savedLang != null) {
      state = savedLang;
    } else {
      // 保存された言語がない場合はデバイスの言語をデフォルトにする
      final deviceLang = PlatformDispatcher.instance.locale.languageCode;
      state = deviceLang == 'en' ? 'en' : 'ja';
    }
  }

  Future<void> setLanguage(String langCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, langCode);
    state = langCode;
  }
}
