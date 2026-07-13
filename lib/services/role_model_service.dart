import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/post.dart';
import '../models/app_user.dart';
import '../models/role_model.dart';

/// ロールモデルの登録・解除・データ取得を担当するサービス
class RoleModelService {
  RoleModelService._();
  static final RoleModelService instance = RoleModelService._();

  FirebaseFirestore? _customDb;
  FirebaseAuth? _customAuth;

  FirebaseFirestore get _db => _customDb ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;

  /// テスト時にMockを注入するためのメソッド
  @visibleForTesting
  void configure({FirebaseFirestore? db, FirebaseAuth? auth}) {
    _customDb = db;
    _customAuth = auth;
  }

  /// サブコレクション `users/{myUid}/role_models` への型安全な参照を返します
  CollectionReference<RoleModel> _roleModelsRef(String myUid) {
    return _db
        .collection('users')
        .doc(myUid)
        .collection('role_models')
        .withConverter<RoleModel>(
          fromFirestore: (snapshot, _) => RoleModel.fromFirestore(snapshot),
          toFirestore: (roleModel, _) => roleModel.toFirestore(),
        );
  }

  /// 対象ユーザーをロールモデルに登録します
  ///
  /// `users/{myUid}/role_models/{targetUid}` にドキュメントを保存します。
  Future<void> registerRoleModel(AppUser targetUser) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) throw Exception('User not authenticated');

    final roleModel = RoleModel(
      targetUid: targetUser.uid,
      displayName: targetUser.displayName ?? '',
      username: targetUser.username ?? '',
      photoUrl: targetUser.photoUrl,
      createdAt: DateTime.now(),
    );

    await _roleModelsRef(myUid).doc(targetUser.uid).set(roleModel);
  }

  /// 対象ユーザーのロールモデル登録を解除します
  ///
  /// `users/{myUid}/role_models/{targetUid}` のドキュメントを削除します。
  Future<void> removeRoleModel(String targetUid) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) throw Exception('User not authenticated');

    await _roleModelsRef(myUid).doc(targetUid).delete();
  }

  /// 指定したユーザーが既にロールモデルに登録されているか確認します
  Future<bool> isRoleModel(String targetUid) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return false;

    final doc = await _roleModelsRef(myUid).doc(targetUid).get();
    return doc.exists;
  }

  /// 登録しているロールモデルの一覧をリアルタイムに取得するストリーム
  Stream<List<RoleModel>> getRoleModelsStream() {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return Stream.value([]);

    return _roleModelsRef(myUid)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// 対象ユーザーの1週間のタスク達成率を取得します
  Future<Map<DateTime, double>> getWeeklyCompletionRate(String targetUid) async {
    // 1. users/{targetUid} から AppUser ドキュメントを取得。存在しない場合は空の Map を返す
    final userDoc = await _db.collection('users').doc(targetUid).get();
    if (!userDoc.exists) {
      return {};
    }
    final user = AppUser.fromFirestore(userDoc);

    // 2. ユーザーのタスク数を確認。タスク数が 0 の場合は、過去 7 日間の値を 0.0 で埋めて返す
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final startOfWeek = todayStart.subtract(const Duration(days: 6));

    if (user.tasks.isEmpty) {
      final Map<DateTime, double> emptyResult = {};
      for (int i = 0; i < 7; i++) {
        final day = startOfWeek.add(Duration(days: i));
        emptyResult[day] = 0.0;
      }
      return emptyResult;
    }

    // 3. posts コレクションから、対象ユーザーかつ過去 7 日間（本日含め）の投稿をクエリする
    final postsSnap = await _db
        .collection('posts')
        .withConverter<Post>(
          fromFirestore: (snapshot, _) => Post.fromFirestore(snapshot),
          toFirestore: (post, _) => post.toFirestore(),
        )
        .where('userId', isEqualTo: targetUid)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
        .get();

    final posts = postsSnap.docs.map((doc) => doc.data()).toList();

    // 4. 投稿を日（DateTime）ごとにグループ化し、各日のユニークなタスク名をカウントする
    final Map<DateTime, Set<String>> dailyTaskNames = {};
    for (final post in posts) {
      final day = DateTime(post.createdAt.year, post.createdAt.month, post.createdAt.day);
      dailyTaskNames.putIfAbsent(day, () => {}).add(post.taskName);
    }

    // 5. 達成率を計算して Map を作成（0.0 〜 1.0 にクランプする）
    final Map<DateTime, double> result = {};
    for (int i = 0; i < 7; i++) {
      final day = startOfWeek.add(Duration(days: i));
      final uniqueTaskNames = dailyTaskNames[day] ?? {};
      final double rate = (uniqueTaskNames.length / user.tasks.length).clamp(0.0, 1.0);
      result[day] = rate;
    }

    return result;
  }
}
