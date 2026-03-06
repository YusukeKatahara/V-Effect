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
    required String birthDate,
    required String gender,
  }) async {
    final uid = _auth.currentUser!.uid;
    final email = _auth.currentUser!.email;
    await _db.collection('users').doc(uid).set({
      'username': username,
      'userId': userId,
      'email': email,
      'birthDate': birthDate,
      'gender': gender,
      'streak': 0,
      'lastPostedDate': null,
      'friends': [],
      'tasks': [],
      'wakeUpTime': null,
      'taskTime': null,
      'photoUrl': null,
      'profileCompleted': true,
    }, SetOptions(merge: true));
  }

  /// タスク設定を保存します（新規登録フロー Step2）
  Future<void> saveTaskSettings({
    required List<String> tasks,
    required String wakeUpTime,
    required String taskTime,
    String? photoUrl,
  }) async {
    final uid = _auth.currentUser!.uid;
    final data = <String, dynamic>{
      'tasks': tasks,
      'wakeUpTime': wakeUpTime,
      'taskTime': taskTime,
      'onboardingCompleted': true,
    };
    if (photoUrl != null) {
      data['photoUrl'] = photoUrl;
    }
    // update() だとドキュメントが存在しないとエラーになるため、
    // set(merge: true) を使うことで「あれば更新・なければ新規作成」できます。
    await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
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
