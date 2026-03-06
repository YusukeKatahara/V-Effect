import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ユーザープロフィール・タスク設定の読み書きを担当するサービス
class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// プロフィール設定を保存します（新規登録フロー Step1）
  Future<void> saveProfile({
    required String username,
    required String userId,
    required String email,
  }) async {
    final uid = _auth.currentUser!.uid;
    await _db.collection('users').doc(uid).set({
      'username': username,
      'userId': userId,
      'email': email,
      'streak': 0,
      'lastPostedDate': null,
      'friends': [],
      'tasks': [],
      'wakeUpTime': null,
      'taskTime': null,
      'profileCompleted': true,
    }, SetOptions(merge: true));
  }

  /// タスク設定を保存します（新規登録フロー Step2）
  Future<void> saveTaskSettings({
    required List<String> tasks,
    required String wakeUpTime,
    required String taskTime,
  }) async {
    final uid = _auth.currentUser!.uid;
    await _db.collection('users').doc(uid).update({
      'tasks': tasks,
      'wakeUpTime': wakeUpTime,
      'taskTime': taskTime,
      'onboardingCompleted': true,
    });
  }

  /// ユーザーIDが既に使われていないかチェックします
  Future<bool> isUserIdAvailable(String userId) async {
    final query = await _db
        .collection('users')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    return query.docs.isEmpty;
  }
}
