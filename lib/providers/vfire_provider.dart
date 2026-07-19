import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/post_service.dart';
import '../models/post.dart';
import 'home_provider.dart';

class VFireState {
  final Map<String, int> localIncrements;
  // 各投稿の最後に送信された情報の記録: baseCount (送信前のサーバー値), sentCount (送信した数)
  // これにより、非同期通信中やFirestoreからのライブ同期のタイムラグが発生している間も
  // 数値の「巻き戻り（チラつき）」を防止します。
  final Map<String, ({int baseCount, int sentCount})> lastSentCounts;

  VFireState({
    required this.localIncrements,
    required this.lastSentCounts,
  });

  VFireState copyWith({
    Map<String, int>? localIncrements,
    Map<String, ({int baseCount, int sentCount})>? lastSentCounts,
  }) {
    return VFireState(
      localIncrements: localIncrements ?? this.localIncrements,
      lastSentCounts: lastSentCounts ?? this.lastSentCounts,
    );
  }
}

extension VFireStateExtension on VFireState {
  /// サーバーから取得した reactionCount とローカルの送信待ち/送信成功履歴を足し合わせ、
  /// 同期遅れ（タイムラグ）を考慮した正しい表示用カウントを計算します。
  int getAdjustedReactionCount(Post post) {
    final localInc = localIncrements[post.id] ?? 0;
    final lastSent = lastSentCounts[post.id];
    
    if (lastSent != null) {
      // 期待される確定値 = 送信前のサーバー値 + 送信した数
      final expectedCount = lastSent.baseCount + lastSent.sentCount;
      if (post.reactionCount < expectedCount) {
        // サーバーの値がまだ期待値に達していない場合、差分を補正値として加算
        final syncLag = expectedCount - post.reactionCount;
        return post.reactionCount + localInc + syncLag;
      }
    }
    return post.reactionCount + localInc;
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
    return VFireState(localIncrements: {}, lastSentCounts: {});
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
            
            // タップ開始時点（送信前）のサーバーの値を基準値とする
            final baseCount = post.reactionCount;

            state = state.copyWith(
              localIncrements: {
                ...state.localIncrements,
                post.id: newInc,
              },
              lastSentCounts: {
                ...state.lastSentCounts,
                post.id: (baseCount: baseCount, sentCount: countToSend),
              },
            );
          }
        } catch (e) {
          debugPrint('VFIRE sync error: $e');
        }
      }
    });
  }

  /// 手動リフレッシュやアプリ復帰時など、Firestoreのデータが強制的に最新化された際に、
  /// メモリ上の送信履歴をクリアして最新データに一本化します。
  void clearSynced() {
    state = state.copyWith(lastSentCounts: {});
  }
}

final vfireProvider = NotifierProvider<VFireNotifier, VFireState>(() {
  return VFireNotifier();
});
