import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import '../utils/date_helper.dart';

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
      streak: (data[AppUser.fieldStreak] as num?)?.toInt() ?? 0,
      protections: (data[AppUser.fieldStreakProtections] as num?)?.toInt() ?? 0,
      lastPostedDate: data[AppUser.fieldLastPostedDate] as String?,
    )[AppUser.fieldStreak]!;
  }

  /// 自分が今日投稿済みかどうかをチェックします
  Future<bool> hasPostedToday() async {
    final uid = _auth.currentUser!.uid;
    final today = DateHelper.toDateString(DateTime.now());
    final userSnap = await _db.collection('users').doc(uid).get();
    if (!userSnap.exists) return false;
    return userSnap.data()?[AppUser.fieldLastPostedDate] == today;
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
        AppUser.fieldStreak: 1,
        AppUser.fieldMaxStreak: 1,
        AppUser.fieldStreakProtections: 0,
        AppUser.fieldLastPostedDate: today,
        AppUser.fieldEmail: _auth.currentUser!.email,
        AppUser.fieldFriends: [],
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



    return result;
  }

  /// ストリーク（連続記録）の計算を行い、Firestoreの更新用マップと結果を返します（書き込み・読み込みは行いません）
  Map<String, dynamic> calculateStreakUpdates({
    required Map<String, dynamic> userData,
    required DateTime now,
    required String uid,
  }) {
    final today = DateHelper.toDateString(now);
    final rawLastPostedDate = userData[AppUser.fieldLastPostedDate];
    final lastPostedDate = rawLastPostedDate is String ? rawLastPostedDate : rawLastPostedDate?.toString();

    final currentStreak = (userData[AppUser.fieldStreak] as num?)?.toInt() ?? 0;
    final maxStreak = (userData[AppUser.fieldMaxStreak] as num?)?.toInt() ?? 0;
    int currentProtections = (userData[AppUser.fieldStreakProtections] as num?)?.toInt() ?? 0;

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
    bool isRescueTriggered = false;
    if (lastPostedDate == yesterdayStr) {
      newStreak = currentStreak + 1;
    } else if (lastPostedDate == dayBeforeYesterdayStr && currentProtections > 0) {
      newStreak = currentStreak + 1;
      currentProtections -= 1;
    } else {
      // 連続が切れた場合：一気に0にリセットせず、前の記録を保存して救済モードをセット
      newStreak = 1;
      isRescueTriggered = true;
      currentProtections = 0;
    }

    // 7日連続投稿ごとに1シールド付与（最大2個まで保有可能）
    if (newStreak > 1 && newStreak % 7 == 0) {
      if (currentProtections < 2) {
        currentProtections += 1;
      }
    }

    // 最大記録更新チェック
    final isRecordUpdating = newStreak > maxStreak;

    final recentPostDates = (userData[AppUser.fieldRecentPostDates] as List?)?.map((e) => e.toString()).toList() ?? [];
    if (!recentPostDates.contains(today)) {
      recentPostDates.add(today);
      if (recentPostDates.length > 180) {
        recentPostDates.removeAt(0);
      }
    }

    final updates = <String, dynamic>{
      AppUser.fieldStreak: newStreak,
      AppUser.fieldStreakProtections: currentProtections,
      AppUser.fieldLastPostedDate: today,
      AppUser.fieldRecentPostDates: recentPostDates,
      'isRescueActive': isRescueTriggered,
    };
    if (isRescueTriggered) {
      updates['prevStreak'] = currentStreak;
    }
    if (isRecordUpdating) {
      updates[AppUser.fieldMaxStreak] = newStreak;
    }

    return {
      'updates': updates,
      'result': {'newStreak': newStreak, 'isRecordUpdating': isRecordUpdating},
    };
  }



  /// 実際のストリークの更新（下位互換性維持のためのメソッド）
  Future<Map<String, dynamic>> updateStreakLegacy(String uid, DateTime now) async {
    final today = DateHelper.toDateString(now);
    final userRef = _db.collection('users').doc(uid);
    final userSnap = await userRef.get();

    if (!userSnap.exists) {
      await userRef.set({
        AppUser.fieldStreak: 1,
        AppUser.fieldMaxStreak: 1,
        AppUser.fieldStreakProtections: 0,
        AppUser.fieldLastPostedDate: today,
        AppUser.fieldEmail: _auth.currentUser!.email,
        AppUser.fieldFriends: [],
      });
      return {'newStreak': 1, 'isRecordUpdating': true};
    }

    final data = userSnap.data()!;
    final rawLastPostedDate = data[AppUser.fieldLastPostedDate];
    final lastPostedDate = rawLastPostedDate is String ? rawLastPostedDate : rawLastPostedDate?.toString();

    final currentStreak = (data[AppUser.fieldStreak] as num?)?.toInt() ?? 0;
    final maxStreak = (data[AppUser.fieldMaxStreak] as num?)?.toInt() ?? 0;
    int currentProtections = (data[AppUser.fieldStreakProtections] as num?)?.toInt() ?? 0;

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

    final recentPostDates = (data[AppUser.fieldRecentPostDates] as List?)?.map((e) => e.toString()).toList() ?? [];
    if (!recentPostDates.contains(today)) {
      recentPostDates.add(today);
      if (recentPostDates.length > 180) {
        recentPostDates.removeAt(0);
      }
    }

    final updates = {
      AppUser.fieldStreak: newStreak,
      AppUser.fieldStreakProtections: currentProtections,
      AppUser.fieldLastPostedDate: today,
      AppUser.fieldRecentPostDates: recentPostDates,
    };
    if (isRecordUpdating) {
      updates[AppUser.fieldMaxStreak] = newStreak;
    }

    await userRef.update(updates);



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
      return {AppUser.fieldStreak: 0, AppUser.fieldStreakProtections: 0};
    }

    final now = DateTime.now();
    final todayStr = DateHelper.toDateString(now);
    final yesterdayStr = DateHelper.toDateString(now.subtract(const Duration(days: 1)));
    final dayBeforeYesterdayStr = DateHelper.toDateString(now.subtract(const Duration(days: 2)));

    if (lastPostedDate == todayStr || lastPostedDate == yesterdayStr) {
      // 今日または昨日投稿済みなら有効
      return {AppUser.fieldStreak: streak, AppUser.fieldStreakProtections: protections};
    } else if (lastPostedDate == dayBeforeYesterdayStr && protections > 0) {
      // 一昨日投稿済みでシールドがあるなら、昨日分として1つ消費された状態
      return {AppUser.fieldStreak: streak, AppUser.fieldStreakProtections: protections - 1};
    } else {
      // 2日以上未投稿、またはシールドなしで1日未投稿ならリセット
      return {AppUser.fieldStreak: 0, AppUser.fieldStreakProtections: 0};
    }
  }
}
