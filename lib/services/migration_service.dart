import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_service.dart';
import '../models/app_user.dart';
import '../models/app_task.dart';

/// 過去データにタスクIDを付与・紐づける移行処理を行うサービス
class MigrationService {
  MigrationService._();
  static final MigrationService instance = MigrationService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// マイグレーション（データ移行）処理を実行します
  Future<void> runTaskIdMigration() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final prefs = await SharedPreferences.getInstance();
    final isMigratedKey = 'migration_task_id_completed_v1_$uid';

    // すでに移行が完了している場合は早期リターン
    if (prefs.getBool(isMigratedKey) == true) {
      return;
    }

    debugPrint('=== START TASK ID MIGRATION FOR USER: $uid ===');

    try {
      // 1. ユーザーのタスク情報（AppUser）を取得
      final userSnap = await _db.collection('users').doc(uid).get();
      if (!userSnap.exists) return;

      final appUser = AppUser.fromFirestore(userSnap);
      final tasks = appUser.tasks;

      // 2. IDがないタスクに新しいIDを割り当てる
      bool tasksUpdated = false;
      final updatedTasks = tasks.map((t) {
        if (t.id.isEmpty) {
          tasksUpdated = true;
          // ランダムIDを生成して付与
          final newId = _db.collection('users').doc().id;
          return t.copyWith(id: newId);
        }
        return t;
      }).toList();

      // タスクのIDが更新された場合、ユーザープロフィールを更新保存する
      if (tasksUpdated) {
        await UserService.instance.updateProfile(tasks: updatedTasks);
        debugPrint('Updated tasks with new IDs: ${updatedTasks.map((t) => "${t.title} -> ${t.id}").join(", ")}');
      }

      // 3. 過去の投稿（posts）をスキャンしてタスクIDを紐づける
      // 自分の過去の全投稿を取得
      final postsSnap = await _db.collection('posts')
          .where('userId', isEqualTo: uid)
          .get();

      if (postsSnap.docs.isNotEmpty) {
        final batch = _db.batch();
        int updateCount = 0;

        for (final doc in postsSnap.docs) {
          final postMap = doc.data();
          final postTaskId = postMap['taskId']?.toString();
          final postTaskName = postMap['taskName']?.toString() ?? '';

          // taskId が未設定の場合のみ紐づけを行う
          if (postTaskId == null || postTaskId.isEmpty) {
            // 現在のユーザーのタスク名と一致するものを探す
            final matchedTask = updatedTasks.firstWhere(
              (t) => t.title == postTaskName,
              orElse: () => const AppTask(id: '', title: ''),
            );

            if (matchedTask.id.isNotEmpty) {
              // 一致するタスクIDが見つかったため、Postドキュメントにセットする
              batch.update(doc.reference, {'taskId': matchedTask.id});
              updateCount++;
            }
          }
        }

        if (updateCount > 0) {
          await batch.commit();
          debugPrint('Associated taskId for $updateCount posts.');
        }
      }

      // マイグレーション完了フラグをローカルに保存
      await prefs.setBool(isMigratedKey, true);
      debugPrint('=== TASK ID MIGRATION COMPLETED SUCCESSFULLY ===');
    } catch (e, stack) {
      debugPrint('ERROR DURING TASK ID MIGRATION: $e\n$stack');
    }
  }
}
