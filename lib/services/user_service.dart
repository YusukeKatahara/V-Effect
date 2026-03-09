import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// ユーザープロフィール・タスク設定の読み書きを担当するサービス
class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// プロフィール設定を保存します（新規登録フロー Step1）
  /// 公開情報は users/{uid}、非公開情報は users/{uid}/private/data に分離
  Future<void> saveProfile({
    required String username,
    required String userId,
    required String birthDate,
    required String gender,
  }) async {
    final uid = _auth.currentUser!.uid;
    final email = _auth.currentUser!.email;

    final batch = _db.batch();

    // 公開情報
    batch.set(
      _db.collection('users').doc(uid),
      {
        'username': username,
        'userId': userId,
        'streak': 0,
        'lastPostedDate': null,
        'friends': [],
        'tasks': [],
        'photoUrl': null,
        'profileCompleted': true,
      },
      SetOptions(merge: true),
    );

    // 非公開情報
    batch.set(
      _db.collection('users').doc(uid).collection('private').doc('data'),
      {
        'email': email,
        'birthDate': birthDate,
        'gender': gender,
        'wakeUpTime': null,
        'taskTime': null,
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  /// タスク設定を保存します（新規登録フロー Step2）
  /// tasks は公開、wakeUpTime/taskTime は非公開
  Future<void> saveTaskSettings({
    required List<String> tasks,
    required String wakeUpTime,
    required String taskTime,
    String? photoUrl,
  }) async {
    final uid = _auth.currentUser!.uid;
    final batch = _db.batch();

    // 公開情報
    final publicData = <String, dynamic>{
      'tasks': tasks,
      'onboardingCompleted': true,
    };
    if (photoUrl != null) {
      publicData['photoUrl'] = photoUrl;
    }
    batch.set(
      _db.collection('users').doc(uid),
      publicData,
      SetOptions(merge: true),
    );

    // 非公開情報
    batch.set(
      _db.collection('users').doc(uid).collection('private').doc('data'),
      {
        'wakeUpTime': wakeUpTime,
        'taskTime': taskTime,
      },
      SetOptions(merge: true),
    );

    await batch.commit();
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

  /// プロフィール画像をStorageにアップロードし、URLを返します
  Future<String> uploadProfileImage(File imageFile) async {
    final uid = _auth.currentUser!.uid;
    final fileExt = imageFile.path.split('.').last;
    final path = 'profiles/$uid/avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    
    final ref = FirebaseStorage.instance.ref().child(path);
    final taskSnapshot = await ref.putFile(imageFile);
    return await taskSnapshot.ref.getDownloadURL();
  }

  /// ログイン後のプロフィール編集を保存します
  Future<void> updateProfile({
    String? username,
    String? userId,
    String? birthDate,
    String? wakeUpTime,
    String? taskTime,
    String? photoUrl,
    List<String>? tasks,
    bool updateEditDate = false,
  }) async {
    final uid = _auth.currentUser!.uid;
    final batch = _db.batch();

    // 公開情報の更新
    final publicData = <String, dynamic>{};
    if (username != null) publicData['username'] = username;
    if (userId != null) publicData['userId'] = userId;
    if (photoUrl != null) publicData['photoUrl'] = photoUrl;
    if (tasks != null) publicData['tasks'] = tasks;
    if (updateEditDate) {
      publicData['lastProfileEditDate'] = DateTime.now().millisecondsSinceEpoch;
    }

    if (publicData.isNotEmpty) {
      batch.set(
        _db.collection('users').doc(uid),
        publicData,
        SetOptions(merge: true),
      );
    }

    // 非公開情報の更新
    final privateData = <String, dynamic>{};
    if (birthDate != null) privateData['birthDate'] = birthDate;
    if (wakeUpTime != null) privateData['wakeUpTime'] = wakeUpTime;
    if (taskTime != null) privateData['taskTime'] = taskTime;

    if (privateData.isNotEmpty) {
      batch.set(
        _db.collection('users').doc(uid).collection('private').doc('data'),
        privateData,
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }
}
