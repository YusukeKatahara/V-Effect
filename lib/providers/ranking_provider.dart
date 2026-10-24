import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_user.dart';
import 'service_providers.dart';

/// ランキングに表示するための軽量ユーザー情報
class RankingUser {
  final String uid;
  final String username;
  final String? userId;
  final String? photoUrl;
  final int streak;
  final int maxStreak;
  final int totalPosts;

  const RankingUser({
    required this.uid,
    required this.username,
    this.userId,
    this.photoUrl,
    required this.streak,
    required this.maxStreak,
    required this.totalPosts,
  });
}

/// ストリーク数（継続日数）上位のユーザーリストを配信するProvider
final streakRankingProvider = FutureProvider.autoDispose<List<RankingUser>>((ref) async {
  try {
    // ストリーク数降順で上位を取得（複合インデックス不要にするためFirestore側では単一ソート）
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .orderBy('streak', descending: true)
        .limit(15)
        .get();

    return snap.docs
        .map((doc) => AppUser.fromFirestore(doc))
        .where((user) => !user.isPrivateAccount && user.streak > 0)
        .take(5)
        .map((u) => RankingUser(
              uid: u.uid,
              username: u.displayName ?? u.username ?? 'チャレンジャー',
              userId: u.userId,
              photoUrl: u.photoUrl,
              streak: u.streak,
              maxStreak: u.maxStreak,
              totalPosts: u.totalPosts,
            ))
        .toList();
  } catch (e) {
    return [];
  }
});

/// トータルV（累計投稿・勝利数）上位のユーザーリストを配信するProvider
final totalVRankingProvider = FutureProvider.autoDispose<List<RankingUser>>((ref) async {
  try {
    // トータル投稿数（totalPosts）降順で上位を取得
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .orderBy('totalPosts', descending: true)
        .limit(15)
        .get();

    return snap.docs
        .map((doc) => AppUser.fromFirestore(doc))
        .where((user) => !user.isPrivateAccount && user.totalPosts > 0)
        .take(5)
        .map((u) => RankingUser(
              uid: u.uid,
              username: u.displayName ?? u.username ?? 'チャレンジャー',
              userId: u.userId,
              photoUrl: u.photoUrl,
              streak: u.streak,
              maxStreak: u.maxStreak,
              totalPosts: u.totalPosts,
            ))
        .toList();
  } catch (e) {
    return [];
  }
});

/// ログイン中ユーザー自身のステータス（ストリーク数・トータルV）を取得するProvider
final myRankingStatsProvider = FutureProvider.autoDispose<AppUser?>((ref) async {
  final uid = ref.watch(userServiceProvider).currentUid;
  if (uid == null) return null;

  try {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromFirestore(doc);
  } catch (e) {
    return null;
  }
});
