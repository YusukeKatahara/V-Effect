import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/post_service.dart';
import '../models/post.dart';
import 'home_provider.dart';

class VFireState {
  final Map<String, int> localIncrements;

  VFireState({
    required this.localIncrements,
  });

  VFireState copyWith({
    Map<String, int>? localIncrements,
  }) {
    return VFireState(
      localIncrements: localIncrements ?? this.localIncrements,
    );
  }
}

class VFireNotifier extends Notifier<VFireState> {
  final Map<String, int> _pendingCounts = {};
  final Map<String, Timer> _debounceTimers = {};
  final PostService _postService = PostService.instance;

  @override
  VFireState build() {
    // 画面遷移などで破棄された際にタイマーをクリアする
    ref.onDispose(() {
      for (var timer in _debounceTimers.values) {
        timer.cancel();
      }
      _debounceTimers.clear();
      _pendingCounts.clear();
    });
    return VFireState(localIncrements: {});
  }

  /// 投稿のVFIREボタンをタップしたときに呼ばれます。
  void increment(Post post) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    // 1. UI用に即座にローカルStateをインクリメント
    final currentLocalInc = state.localIncrements[post.id] ?? 0;
    state = state.copyWith(
      localIncrements: {
        ...state.localIncrements,
        post.id: currentLocalInc + 1,
      },
    );

    // 2. 送信用のデバウンス処理
    _pendingCounts[post.id] = (_pendingCounts[post.id] ?? 0) + 1;
    _debounceTimers[post.id]?.cancel();

    _debounceTimers[post.id] = Timer(const Duration(milliseconds: 500), () async {
      final countToSend = _pendingCounts[post.id] ?? 0;
      _pendingCounts.remove(post.id);
      _debounceTimers.remove(post.id);

      if (countToSend > 0) {
        try {
          await _postService.incrementFlameCount(
            post.id,
            countToSend,
            targetUid: post.userId,
            targetTaskName: post.taskName,
            triggerUpdateStream: false,
          );

          // ローカルキャッシュ（SharedPreferences）も更新
          await updateHomeDataCacheWithReaction(
            myUid,
            post.id,
            flameIncrement: countToSend,
          );

          // 送信成功後、メモリ上のローカルインクリメント分を差し引く
          // (サーバーの値が増えるため、二重加算にならないようにする)
          if (state.localIncrements.containsKey(post.id)) {
            final latestLocalInc = state.localIncrements[post.id] ?? 0;
            final newInc = (latestLocalInc - countToSend).clamp(0, 100000);
            
            state = state.copyWith(
              localIncrements: {
                ...state.localIncrements,
                post.id: newInc,
              },
            );
          }
        } catch (e) {
          debugPrint('VFIRE sync error: $e');
        }
      }
    });
  }
}

final vfireProvider = NotifierProvider<VFireNotifier, VFireState>(() {
  return VFireNotifier();
});
