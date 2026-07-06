import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

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
    
    // 起動時にログイン済みであればFirestoreへ同期
    await _syncLanguageToFirestore(state);
  }

  Future<void> setLanguage(String langCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, langCode);
    state = langCode;
    await _syncLanguageToFirestore(langCode);
  }

  Future<void> _syncLanguageToFirestore(String langCode) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'language': langCode}, SetOptions(merge: true));
        debugPrint('Language $langCode synced to Firestore for UID: ${user.uid}');
      }
    } catch (e) {
      debugPrint('Failed to sync language to Firestore: $e');
    }
  }
}
