import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/date_helper.dart';
import 'notification_service.dart';
import '../models/app_notification.dart';

/// ストリーク（連続記録）に関するロジックを専門に担当するサービス
class StreakService {
  StreakService._();
  static final StreakService instance = StreakService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 自分のストリーク数を取得します
  Future<int> getStreak() async {
    final uid = _auth.currentUser!.uid;
    final snap = await _db.collection('users').doc(uid).get();
    final data = snap.data();
    if (data == null) return 0;

    return calculateEffectiveStreak(
      streak: (data['streak'] as num?)?.toInt() ?? 0,
      protections: (data['streakProtections'] as num?)?.toInt() ?? 0,
      lastPostedDate: data['lastPostedDate'] as String?,
    )['streak']!;
  }

  /// 自分が今日投稿済みかどうかをチェックします
  Future<bool> hasPostedToday() async {
    final uid = _auth.currentUser!.uid;
    final today = DateHelper.toDateString(DateTime.now());
    final userSnap = await _db.collection('users').doc(uid).get();
    if (!userSnap.exists) return false;
    return userSnap.data()?['lastPostedDate'] == today;
  }

  /// ストリーク（連続記録）を更新する処理
  /// 昨日も投稿していれば streak+1、そうでなければ 1 にリセット。
  /// 今日すでに投稿済みなら現在の値を返す。
  /// 戻り値: {'newStreak': int, 'isRecordUpdating': bool}
  Future<Map<String, dynamic>> updateStreak(String uid, DateTime now) async {
    final today = DateHelper.toDateString(now);
    final userRef = _db.collection('users').doc(uid);
    final userSnap = await userRef.get();

    if (!userSnap.exists) {
      await userRef.set({
        'streak': 1,
        'maxStreak': 1,
        'streakProtections': 0,
        'lastPostedDate': today,
        'email': _auth.currentUser!.email,
        'friends': [],
      });
      return {'newStreak': 1, 'isRecordUpdating': true};
    }

    final data = userSnap.data()!;
    final streakCalculation = calculateStreakUpdates(
      userData: data,
      now: now,
      uid: uid,
    );
    final updates = streakCalculation['updates'] as Map<String, dynamic>;
    final result = streakCalculation['result'] as Map<String, dynamic>;

    if (updates.isNotEmpty) {
      await userRef.update(updates);
    }

    // ── ストリーク達成祝いの通知 ──
    final newStreak = result['newStreak'] as int;
    triggerMilestoneNotification(uid: uid, newStreak: newStreak, userData: data);

    return result;
  }

  /// ストリーク（連続記録）の計算を行い、Firestoreの更新用マップと結果を返します（書き込み・読み込みは行いません）
  Map<String, dynamic> calculateStreakUpdates({
    required Map<String, dynamic> userData,
    required DateTime now,
    required String uid,
  }) {
    final today = DateHelper.toDateString(now);
    final rawLastPostedDate = userData['lastPostedDate'];
    final lastPostedDate = rawLastPostedDate is String ? rawLastPostedDate : rawLastPostedDate?.toString();

    final currentStreak = (userData['streak'] as num?)?.toInt() ?? 0;
    final maxStreak = (userData['maxStreak'] as num?)?.toInt() ?? 0;
    int currentProtections = (userData['streakProtections'] as num?)?.toInt() ?? 0;

    if (lastPostedDate == today) {
      return {
        'updates': <String, dynamic>{},
        'result': {'newStreak': currentStreak, 'isRecordUpdating': false},
      };
    }

    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayStr = DateHelper.toDateString(yesterday);
    final dayBeforeYesterday = now.subtract(const Duration(days: 2));
    final dayBeforeYesterdayStr = DateHelper.toDateString(dayBeforeYesterday);

    int newStreak;
    if (lastPostedDate == yesterdayStr) {
      newStreak = currentStreak + 1;
    } else if (lastPostedDate == dayBeforeYesterdayStr && currentProtections > 0) {
      newStreak = currentStreak + 1;
      currentProtections -= 1;
    } else {
      newStreak = 1;
      currentProtections = 0;
    }

    if (newStreak > 1 && newStreak % 3 == 0) {
      if (currentProtections < 1) {
        currentProtections += 1;
      }
    }

    // 最大記録更新チェック
    final isRecordUpdating = newStreak > maxStreak;
    final updates = {
      'streak': newStreak,
      'streakProtections': currentProtections,
      'lastPostedDate': today
    };
    if (isRecordUpdating) {
      updates['maxStreak'] = newStreak;
    }

    return {
      'updates': updates,
      'result': {'newStreak': newStreak, 'isRecordUpdating': isRecordUpdating},
    };
  }

  /// マイルストーン達成時の通知を送信
  void triggerMilestoneNotification({
    required String uid,
    required int newStreak,
    required Map<String, dynamic> userData,
  }) {
    final pushEnabled = userData['pushNotifications'] ?? true;
    final celebrationEnabled = userData['streakCelebrationNotifications'] ?? true;
    
    if (pushEnabled && celebrationEnabled) {
      final milestones = [7, 30, 50, 100, 200, 365];
      if (milestones.contains(newStreak)) {
        NotificationService.instance.createNotification(
          toUid: uid,
          type: NotificationType.streakCelebration,
          params: {'streak': newStreak.toString()},
        ).catchError((e) => debugPrint('Celebration notification error: $e'));
      }
    }
  }

  /// 実際のストリークの更新（下位互換性維持のためのメソッド）
  Future<Map<String, dynamic>> updateStreakLegacy(String uid, DateTime now) async {
    final today = DateHelper.toDateString(now);
    final userRef = _db.collection('users').doc(uid);
    final userSnap = await userRef.get();

    if (!userSnap.exists) {
      await userRef.set({
        'streak': 1,
        'maxStreak': 1,
        'streakProtections': 0,
        'lastPostedDate': today,
        'email': _auth.currentUser!.email,
        'friends': [],
      });
      return {'newStreak': 1, 'isRecordUpdating': true};
    }

    final data = userSnap.data()!;
    final rawLastPostedDate = data['lastPostedDate'];
    final lastPostedDate = rawLastPostedDate is String ? rawLastPostedDate : rawLastPostedDate?.toString();

    final currentStreak = (data['streak'] as num?)?.toInt() ?? 0;
    final maxStreak = (data['maxStreak'] as num?)?.toInt() ?? 0;
    int currentProtections = (data['streakProtections'] as num?)?.toInt() ?? 0;

    if (lastPostedDate == today) {
      return {'newStreak': currentStreak, 'isRecordUpdating': false};
    }

    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayStr = DateHelper.toDateString(yesterday);
    final dayBeforeYesterday = now.subtract(const Duration(days: 2));
    final dayBeforeYesterdayStr = DateHelper.toDateString(dayBeforeYesterday);

    int newStreak;
    if (lastPostedDate == yesterdayStr) {
      newStreak = currentStreak + 1;
    } else if (lastPostedDate == dayBeforeYesterdayStr && currentProtections > 0) {
      newStreak = currentStreak + 1;
      currentProtections -= 1;
    } else {
      newStreak = 1;
      currentProtections = 0;
    }

    if (newStreak > 1 && newStreak % 3 == 0) {
      if (currentProtections < 1) {
        currentProtections += 1;
      }
    }

    // 最大記録更新チェック
    final isRecordUpdating = newStreak > maxStreak;
    final updates = {
      'streak': newStreak,
      'streakProtections': currentProtections,
      'lastPostedDate': today
    };
    if (isRecordUpdating) {
      updates['maxStreak'] = newStreak;
    }

    await userRef.update(updates);

    // ── ストリーク達成祝いの通知 ──
    final pushEnabled = data['pushNotifications'] ?? true;
    final celebrationEnabled = data['streakCelebrationNotifications'] ?? true;
    
    if (pushEnabled && celebrationEnabled) {
      final milestones = [7, 30, 50, 100, 200, 365];
      if (milestones.contains(newStreak)) {
        NotificationService.instance.createNotification(
          toUid: uid,
          type: NotificationType.streakCelebration,
          params: {'streak': newStreak.toString()},
        ).catchError((e) => debugPrint('Celebration notification error: $e'));
      }
    }

    return {'newStreak': newStreak, 'isRecordUpdating': isRecordUpdating};
  }

  /// 最後に投稿した日付に基づいて、現在有効なストリーク数と保護シールド数を計算します。
  /// （UI表示用。Firestoreの更新は行いません）
  static Map<String, int> calculateEffectiveStreak({
    required int streak,
    required int protections,
    required String? lastPostedDate,
  }) {
    if (lastPostedDate == null || streak <= 0) {
      return {'streak': 0, 'streakProtections': 0};
    }

    final now = DateTime.now();
    final todayStr = DateHelper.toDateString(now);
    final yesterdayStr = DateHelper.toDateString(now.subtract(const Duration(days: 1)));
    final dayBeforeYesterdayStr = DateHelper.toDateString(now.subtract(const Duration(days: 2)));

    if (lastPostedDate == todayStr || lastPostedDate == yesterdayStr) {
      // 今日または昨日投稿済みなら有効
      return {'streak': streak, 'streakProtections': protections};
    } else if (lastPostedDate == dayBeforeYesterdayStr && protections > 0) {
      // 一昨日投稿済みでシールドがあるなら、昨日分として1つ消費された状態
      return {'streak': streak, 'streakProtections': protections - 1};
    } else {
      // 2日以上未投稿、またはシールドなしで1日未投稿ならリセット
      return {'streak': 0, 'streakProtections': 0};
    }
  }
}
