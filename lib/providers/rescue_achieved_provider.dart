import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 救済達成（150 VFIRE以上）の吹き出しバッジを表示済み（seen）にした投稿IDを管理するNotifier
class RescueAchievedNotifier extends Notifier<Set<String>> {
  static const String _prefKey = 'seen_rescue_achieved_bubble_post_ids';

  @override
  Set<String> build() {
    _loadFromPrefs();
    return {};
  }

  /// SharedPreferences から表示済みの投稿ID一覧を非同期で読み込みます。
  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefKey) ?? [];
      if (list.isNotEmpty) {
        state = list.toSet();
      }
    } catch (e) {
      debugPrint('Error loading seen rescue achieved post ids: $e');
    }
  }

  /// 指定の投稿IDが救済達成バッジ表示済み（2回目以降）かどうかを判定します。
  bool isSeen(String postId) => state.contains(postId);

  /// 投稿IDを救済達成バッジ表示済みとして永続化（ローカル保存）します。
  Future<void> markAsSeen(String postId) async {
    if (state.contains(postId)) return;
    final updated = {...state, postId};
    state = updated;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefKey, updated.toList());
    } catch (e) {
      debugPrint('Error saving seen rescue achieved post id: $e');
    }
  }
}

/// 救済達成バッジの表示済み状態を提供するグローバルProvider
final rescueAchievedProvider = NotifierProvider<RescueAchievedNotifier, Set<String>>(() {
  return RescueAchievedNotifier();
});
