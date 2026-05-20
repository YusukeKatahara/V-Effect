import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'push_notification_service.dart';
import '../models/app_task.dart';
import '../models/app_user.dart';

/// ユーザープロフィール・ヒーロータスク設定の読み書きを担当するサービス
class UserService {
  UserService._();
  static final UserService instance = UserService._();

  /// タスク変更など、ユーザーデータの更新をアプリ全体に通知するストリーム
  final _updateController = StreamController<void>.broadcast();
  Stream<void> get updateStream => _updateController.stream;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 現在ログイン中のユーザーUID（未ログイン時はnull）
  String? get currentUid => _auth.currentUser?.uid;

  /// プロフィール設定を保存します（新規登録フロー Step1）
  /// 公開情報は users/{uid}、非公開情報は users/{uid}/private/data に分離
  Future<void> saveProfile({
    required String username,
    required String userId,
    String? birthDate,
    String? gender,
    required String taskTime,
    required String occupation,
  }) async {
    final uid = _auth.currentUser!.uid;
    final email = _auth.currentUser!.email;

    final batch = _db.batch();

    // 公開情報
    batch.set(
      _db.collection('users').doc(uid),
      {
        'username': username,
        'usernameLower': username.toLowerCase(),
        'userId': userId,
        'userIdLower': userId.toLowerCase(),
        'streak': 0,
        'lastPostedDate': null,
        'following': [],
        'followers': [],
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
        'taskTime': taskTime,
        'occupation': occupation,
        'showTimestamp': true,
      },
      SetOptions(merge: true),
    );

    await batch.commit();

    // ローカル通知スケジュールを更新
    await PushNotificationService().restoreVAlertSchedule();
  }

  /// テンプレートヒーロータスク選択を保存します（新規登録フロー: テンプレート選択ステップ）
  /// 選択されたヒーロータスクをtasksの最初の要素として保存し、templateCompletedをtrueに設定
  Future<void> saveTemplateTask({required String taskName}) async {
    final uid = _auth.currentUser!.uid;
    await _db.collection('users').doc(uid).set(
      {
        'tasks': [AppTask(title: taskName).toFirestore()],
        'templateCompleted': true,
        'onboardingCompleted': true,
      },
      SetOptions(merge: true),
    );
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingCompleted_$uid', true);
  }

  /// ヒーロータスク設定を保存します（新規登録フロー Step2）
  /// tasks は公開、wakeUpTime/taskTime は非公開
  Future<void> saveTaskSettings({
    required List<AppTask> tasks,
    required String taskTime,
    String? photoUrl,
  }) async {
    final uid = _auth.currentUser!.uid;
    final batch = _db.batch();

    // 公開情報
    final publicData = <String, dynamic>{
      'tasks': tasks.map((t) => t.toFirestore()).toList(),
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

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingCompleted_$uid', true);

    // 非公開情報
    batch.set(
      _db.collection('users').doc(uid).collection('private').doc('data'),
      {
        'taskTime': taskTime,
      },
      SetOptions(merge: true),
    );

    await batch.commit();

    // ローカル通知スケジュールを更新
    await PushNotificationService().restoreVAlertSchedule();
  }

  /// ユーザーIDが既に使われていないかチェックします
  /// 自分自身のドキュメントは除外します（プロフィール再編集時の対応）
  Future<bool> isUserIdAvailable(String userId) async {
    final uid = _auth.currentUser!.uid;
    final query = await _db
        .collection('users')
        .where('userId', isEqualTo: userId)
        .limit(2)
        .get();
    // 結果が空なら利用可能
    // 結果が自分自身のドキュメントだけなら利用可能（再保存のケース）
    return query.docs.isEmpty ||
        (query.docs.length == 1 && query.docs.first.id == uid);
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
    String? taskTime,
    String? photoUrl,
    List<AppTask>? tasks,
    bool? showTimestamp,
    bool updateEditDate = false,
  }) async {
    final uid = _auth.currentUser!.uid;
    final batch = _db.batch();

    // 公開情報の更新
    final publicData = <String, dynamic>{};
    if (username != null) {
      publicData['username'] = username;
      publicData['usernameLower'] = username.toLowerCase();
    }
    if (userId != null) {
      publicData['userId'] = userId;
      publicData['userIdLower'] = userId.toLowerCase();
    }
    if (photoUrl != null) publicData['photoUrl'] = photoUrl;
    if (tasks != null) {
      publicData['tasks'] = tasks.map((t) => t.toFirestore()).toList();
    }
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
    if (taskTime != null) privateData['taskTime'] = taskTime;
    if (showTimestamp != null) privateData['showTimestamp'] = showTimestamp;

    if (privateData.isNotEmpty) {
      batch.set(
        _db.collection('users').doc(uid).collection('private').doc('data'),
        privateData,
        SetOptions(merge: true),
      );
    }

    await batch.commit();

    // ローカル通知スケジュールを更新
    await PushNotificationService().restoreVAlertSchedule();

    // タスクが変更された場合、HeroTasksScreen など購読者に通知
    if (tasks != null) {
      _updateController.add(null);
    }
  }

  /// アプリの設定（通知・プライバシー）を更新します
  Future<void> updateSettings({
    bool? pushNotifications,
    bool? focusTimeNotifications,
    bool? reactionNotifications,
    bool? protectionNotifications,
    bool? vFireNotifications,
    bool? streakCelebrationNotifications,
    bool? streakWarningNotifications,
    bool? isPrivateAccount,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final data = <String, dynamic>{};
    if (pushNotifications != null) data['pushNotifications'] = pushNotifications;
    if (focusTimeNotifications != null) data['focusTimeNotifications'] = focusTimeNotifications;
    if (reactionNotifications != null) data['reactionNotifications'] = reactionNotifications;
    if (protectionNotifications != null) data['protectionNotifications'] = protectionNotifications;
    if (vFireNotifications != null) data['vFireNotifications'] = vFireNotifications;
    if (streakCelebrationNotifications != null) data['streakCelebrationNotifications'] = streakCelebrationNotifications;
    if (streakWarningNotifications != null) data['streakWarningNotifications'] = streakWarningNotifications;
    if (isPrivateAccount != null) data['isPrivateAccount'] = isPrivateAccount;

    if (data.isNotEmpty) {
      await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
      // 通知スケジュールを更新
      // ローカル通知の失敗は設定保存成功とは独立して扱う
      if (focusTimeNotifications != null || protectionNotifications != null) {
        try {
          if (focusTimeNotifications == false) {
            await PushNotificationService().scheduleVAlert(null);
          } else {
            await PushNotificationService().restoreVAlertSchedule();
          }
        } catch (e) {
          debugPrint('V Alert スケジュール更新エラー: $e');
        }
      }
    }
  }

  /// オンボーディングの進捗ステップを記録します（中断再開用）
  Future<void> saveOnboardingStep(String step) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set(
      {'onboardingStep': step},
      SetOptions(merge: true),
    );
  }

  /// 新オンボーディング用プロフィール保存
  /// profileCompleted=true, onboardingStep='first_v_quest' を同一バッチで書き込む
  Future<void> saveOnboardingProfile({
    required String username,
    required String userId,
    String? photoUrl,
  }) async {
    final uid = _auth.currentUser!.uid;
    final email = _auth.currentUser!.email;
    final batch = _db.batch();

    batch.set(
      _db.collection('users').doc(uid),
      {
        'username': username,
        'usernameLower': username.toLowerCase(),
        'userId': userId,
        'userIdLower': userId.toLowerCase(),
        'streak': 0,
        'lastPostedDate': null,
        'following': [],
        'followers': [],
        'tasks': [],
        if (photoUrl != null) 'photoUrl': photoUrl,
        'profileCompleted': true,
        'onboardingStep': 'first_v_quest',
      },
      SetOptions(merge: true),
    );

    batch.set(
      _db.collection('users').doc(uid).collection('private').doc('data'),
      {'email': email},
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  /// 最初のV Questを保存しオンボーディングを完了させます
  Future<void> saveFirstVQuest({String? questTitle, String? questTrigger}) async {
    final uid = _auth.currentUser!.uid;
    final data = <String, dynamic>{
      'onboardingCompleted': true,
      'templateCompleted': true, // 後方互換
      'onboardingStep': 'completed',
    };
    
    final tasks = <Map<String, dynamic>>[];
    // ウェルカムチュートリアルタスクを追加
    tasks.add(AppTask(title: 'Welcome to V EFFECT', isOneTime: true).toFirestore());
    
    if (questTitle != null && questTitle.isNotEmpty) {
      tasks.add(AppTask(title: questTitle, trigger: questTrigger).toFirestore());
    }
    data['tasks'] = tasks;

    // 🚀 【爆速化 1】次回起動時のゼロディレイルーティングのためにローカルキャッシュを保存
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingCompleted_$uid', true);

    await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }

  /// 完了日が昨日以前のワンタイムタスクを自動削除する共通処理
  Future<void> cleanupExpiredTasks(AppUser user) async {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    
    final expiredTasks = user.tasks.where((task) {
      if (!task.isOneTime || task.completedAt == null) return false;
      // 完了日が今日より前（昨日以前）なら期限切れ
      return task.completedAt!.isBefore(startOfToday);
    }).toList();

    if (expiredTasks.isNotEmpty) {
      final updatedTasks = user.tasks.where((task) {
        if (!task.isOneTime || task.completedAt == null) return true;
        return !task.completedAt!.isBefore(startOfToday);
      }).toList();

      await updateProfile(tasks: updatedTasks);
      debugPrint('${expiredTasks.length}個のワンタイムタスクを期限切れ（翌日）のため削除しました');
    }
  }
}
