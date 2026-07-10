import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
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

  /// タスクのリストに対し、IDがないものに一意のID（Firestoreの自動生成ID）を割り当てます
  List<AppTask> _ensureTaskIds(List<AppTask> tasks) {
    return tasks.map((t) {
      if (t.id.isEmpty) {
        final newId = _db.collection('users').doc().id;
        return t.copyWith(id: newId);
      }
      return t;
    }).toList();
  }



  /// マイグレーション処理の多重実行を防ぐためのメモリ内ロック
  final Set<String> _migratingUids = {};

  /// 現在ログイン中のユーザーUID（未ログイン時はnull）
  String? get currentUid => _auth.currentUser?.uid;

  /// プロフィール設定を保存します（新規登録フロー Step1）
  /// 公開情報は users/{uid}、非公開情報は users/{uid}/private/data に分離
  Future<void> saveProfile({
    required String username,
    required String userId,
    String? birthDate,
    String? gender,
    required String occupation,
  }) async {
    final uid = _auth.currentUser!.uid;
    final email = _auth.currentUser!.email;

    final batch = _db.batch();

    // 公開情報
    batch.set(
      _db.collection('users').doc(uid),
      {
        AppUser.fieldUsername: username,
        AppUser.fieldUsernameLower: username.toLowerCase(),
        AppUser.fieldUserId: userId,
        AppUser.fieldUserIdLower: userId.toLowerCase(),
        AppUser.fieldStreak: 0,
        AppUser.fieldLastPostedDate: null,
        AppUser.fieldFollowing: [],
        AppUser.fieldFollowers: [],
        AppUser.fieldTasks: [],
        AppUser.fieldPhotoUrl: null,
        AppUser.fieldProfileCompleted: true,
      },
      SetOptions(merge: true),
    );

    // 非公開情報
    batch.set(
      _db.collection('users').doc(uid).collection('private').doc('data'),
      {
        AppUser.fieldEmail: email,
        AppUser.fieldBirthDate: birthDate,
        AppUser.fieldGender: gender,
        AppUser.fieldOccupation: occupation,
      },
      SetOptions(merge: true),
    );

    await batch.commit();

    // 保護スケジュールを更新
    await PushNotificationService().restoreProtectionAlertSchedule();
  }

  /// テンプレートヒーロータスク選択を保存します（新規登録フロー: テンプレート選択ステップ）
  /// 選択されたヒーロータスクをtasksの最初の要素として保存し、templateCompletedをtrueに設定
  Future<void> saveTemplateTask({required String taskName}) async {
    final uid = _auth.currentUser!.uid;
    final taskWithId = _ensureTaskIds([AppTask(title: taskName)]).first;
    await _db.collection('users').doc(uid).set(
      {
        AppUser.fieldTasks: [taskWithId.toFirestore()],
        AppUser.fieldTemplateCompleted: true,
        AppUser.fieldOnboardingCompleted: true,
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
    String? photoUrl,
  }) async {
    final uid = _auth.currentUser!.uid;
    final batch = _db.batch();

    final tasksWithIds = _ensureTaskIds(tasks);

    // 公開情報
    final publicData = <String, dynamic>{
      AppUser.fieldTasks: tasksWithIds.map((t) => t.toFirestore()).toList(),
      AppUser.fieldOnboardingCompleted: true,
    };
    if (photoUrl != null) {
      publicData[AppUser.fieldPhotoUrl] = photoUrl;
    }
    batch.set(
      _db.collection('users').doc(uid),
      publicData,
      SetOptions(merge: true),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingCompleted_$uid', true);

    await batch.commit();

    // 保護スケジュールを更新
    await PushNotificationService().restoreProtectionAlertSchedule();
  }

  /// ユーザーIDが既に使われていないかチェックします
  /// 自分自身のドキュメントは除外します（プロフィール再編集時の対応）
  Future<bool> isUserIdAvailable(String userId) async {
    final uid = _auth.currentUser!.uid;
    final query = await _db
        .collection('users')
        .where(AppUser.fieldUserId, isEqualTo: userId)
        .limit(2)
        .get();
    // 結果が空なら利用可能
    // 結果が自分自身のドキュメントだけなら利用可能（再保存のケース）
    return query.docs.isEmpty ||
        (query.docs.length == 1 && query.docs.first.id == uid);
  }

  /// プロフィール画像をStorageにアップロードし、URLを返します
  /// Web では File が使えないため、XFile から bytes を読み putData でアップロードします
  Future<String> uploadProfileImage(XFile imageFile) async {
    final uid = _auth.currentUser!.uid;
    // Web の path は blob URL で拡張子が取れないため name から判定する
    final name = imageFile.name.isNotEmpty ? imageFile.name : imageFile.path;
    const contentTypes = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
      'gif': 'image/gif',
      'heic': 'image/heic',
    };
    var fileExt = name.contains('.') ? name.split('.').last.toLowerCase() : 'jpg';
    if (!contentTypes.containsKey(fileExt)) fileExt = 'jpg';
    final contentType = imageFile.mimeType ?? contentTypes[fileExt]!;
    final path = 'profiles/$uid/avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

    final bytes = await imageFile.readAsBytes();
    final ref = FirebaseStorage.instance.ref().child(path);
    final taskSnapshot =
        await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return await taskSnapshot.ref.getDownloadURL();
  }

  /// ログイン後のプロフィール編集を保存します
  Future<void> updateProfile({
    String? username,
    String? userId,
    String? birthDate,
    String? gender,
    String? photoUrl,
    List<AppTask>? tasks,
    bool updateEditDate = false,
    String? equippedBadgeUrl,
    String? equippedBadgeAnimation,
    String? instagramId,
  }) async {
    final uid = _auth.currentUser!.uid;
    final batch = _db.batch();

    // 公開情報の更新
    final publicData = <String, dynamic>{};
    if (username != null) {
      publicData[AppUser.fieldUsername] = username;
      publicData[AppUser.fieldUsernameLower] = username.toLowerCase();
    }
    if (userId != null) {
      publicData[AppUser.fieldUserId] = userId;
      publicData[AppUser.fieldUserIdLower] = userId.toLowerCase();
    }
    if (photoUrl != null) publicData[AppUser.fieldPhotoUrl] = photoUrl;
    if (tasks != null) {
      final tasksWithIds = _ensureTaskIds(tasks);
      publicData[AppUser.fieldTasks] = tasksWithIds.map((t) => t.toFirestore()).toList();
    }
    if (updateEditDate) {
      publicData[AppUser.fieldLastProfileEditDate] = DateTime.now().millisecondsSinceEpoch;
    }
    if (equippedBadgeUrl != null) {
      publicData[AppUser.fieldEquippedBadgeUrl] = equippedBadgeUrl.isEmpty ? null : equippedBadgeUrl;
    }
    if (equippedBadgeAnimation != null) {
      publicData[AppUser.fieldEquippedBadgeAnimation] = equippedBadgeAnimation.isEmpty ? null : equippedBadgeAnimation;
    }
    if (instagramId != null) {
      publicData[AppUser.fieldInstagramId] = instagramId.isEmpty ? null : instagramId;
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
    if (birthDate != null) privateData[AppUser.fieldBirthDate] = birthDate;
    if (gender != null) privateData[AppUser.fieldGender] = gender;

    if (privateData.isNotEmpty) {
      batch.set(
        _db.collection('users').doc(uid).collection('private').doc('data'),
        privateData,
        SetOptions(merge: true),
      );
    }

    await batch.commit();

    // 保護スケジュールを更新
    await PushNotificationService().restoreProtectionAlertSchedule();

    // タスクが変更された場合、HeroTasksScreen など購読者に通知
    if (tasks != null) {
      _updateController.add(null);
    }
  }

  /// アプリの設定（通知・プライバシー）を更新します
  Future<void> updateSettings({
    bool? pushNotifications,
    bool? reactionNotifications,
    bool? protectionNotifications,
    bool? vFireNotifications,
    bool? streakWarningNotifications,
    bool? isPrivateAccount,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final data = <String, dynamic>{};
    if (pushNotifications != null) data[AppUser.fieldPushNotifications] = pushNotifications;
    if (reactionNotifications != null) data[AppUser.fieldReactionNotifications] = reactionNotifications;
    if (protectionNotifications != null) data[AppUser.fieldProtectionNotifications] = protectionNotifications;
    if (vFireNotifications != null) data[AppUser.fieldVFireNotifications] = vFireNotifications;
    if (streakWarningNotifications != null) data[AppUser.fieldStreakWarningNotifications] = streakWarningNotifications;
    if (isPrivateAccount != null) data[AppUser.fieldIsPrivateAccount] = isPrivateAccount;

    if (data.isNotEmpty) {
      await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
    }
  }

  /// オンボーディングの進捗ステップを記録します（中断再開用）
  Future<void> saveOnboardingStep(String step) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set(
      {AppUser.fieldOnboardingStep: step},
      SetOptions(merge: true),
    );
  }

  /// 新オンボーディング用プロフィール保存とオンボーディング完了処理
  /// profileCompleted=true, onboardingCompleted=true, onboardingStep='completed' を同一バッチで書き込む
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
        AppUser.fieldUsername: username,
        AppUser.fieldUsernameLower: username.toLowerCase(),
        AppUser.fieldUserId: userId,
        AppUser.fieldUserIdLower: userId.toLowerCase(),
        AppUser.fieldStreak: 0,
        AppUser.fieldLastPostedDate: null,
        AppUser.fieldFollowing: [],
        AppUser.fieldFollowers: [],
        if (photoUrl != null) AppUser.fieldPhotoUrl: photoUrl,
        AppUser.fieldProfileCompleted: true,
        AppUser.fieldOnboardingCompleted: true,
        AppUser.fieldTemplateCompleted: true, // 後方互換
        AppUser.fieldOnboardingStep: 'completed',
      },
      SetOptions(merge: true),
    );

    batch.set(
      _db.collection('users').doc(uid).collection('private').doc('data'),
      {AppUser.fieldEmail: email},
      SetOptions(merge: true),
    );

    // 🚀 【爆速化 1】次回起動時のゼロディレイルーティングのためにローカルキャッシュを保存
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingCompleted_$uid', true);

    await batch.commit();
  }

  /// 最初のV Questを一時保存し、オンボーディングステップを進めます
  Future<void> saveFirstVQuest({String? questTitle, String? questTrigger}) async {
    final uid = _auth.currentUser!.uid;
    final data = <String, dynamic>{
      AppUser.fieldOnboardingStep: 'profile_settings',
    };
    
    final tasks = <AppTask>[];
    // ウェルカムチュートリアルタスクを追加
    tasks.add(AppTask(title: 'Welcome to V EFFECT', isOneTime: true));
    
    if (questTitle != null && questTitle.isNotEmpty) {
      tasks.add(AppTask(title: questTitle, trigger: questTrigger));
    }
    
    final tasksWithIds = _ensureTaskIds(tasks);
    data[AppUser.fieldTasks] = tasksWithIds.map((t) => t.toFirestore()).toList();

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

  /// シーズンタスク通知を処理済み（参加・削除）として記録します
  Future<void> markSeasonTaskAsProcessed(String seasonId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set({
      AppUser.fieldProcessedSeasonTaskIds: FieldValue.arrayUnion([seasonId])
    }, SetOptions(merge: true));
  }

  /// 過去の投稿数を集計し、totalPosts を更新するマイグレーション関数（遅延初期化用）
  Future<void> migrateTotalPosts(String uid) async {
    // 2026ベストプラクティス：多重実行を防ぐメモリロック
    if (_migratingUids.contains(uid)) {
      return;
    }
    _migratingUids.add(uid);

    try {
      // 2026ベストプラクティス：通信不安定時のハングアップを防ぐタイムアウト（6秒）を設定
      final snap = await _db
          .collection('posts')
          .where(AppUser.fieldUserId, isEqualTo: uid)
          .count()
          .get()
          .timeout(const Duration(seconds: 6));
      
      final count = snap.count ?? 0;
      await _db.collection('users').doc(uid).update({
        AppUser.fieldTotalPosts: count,
        AppUser.fieldTotalPostsMigrated: true,
      });
      debugPrint('マイグレーション完了: UID $uid の過去投稿数を $count 件で更新しました');
    } catch (e) {
      debugPrint('totalPostsのマイグレーションエラー: $e');
    } finally {
      // ロックの確実な解放
      _migratingUids.remove(uid);
    }
  }
}
