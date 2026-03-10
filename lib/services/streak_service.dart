import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/date_helper.dart';

/// ストリーク（連続記録）に関するロジックを専門に担当するサービス
class StreakService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 自分のストリーク数を取得します
  Future<int> getStreak() async {
    final uid = _auth.currentUser!.uid;
    final snap = await _db.collection('users').doc(uid).get();
    return (snap.data()?['streak'] as num?)?.toInt() ?? 0;
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
        'lastPostedDate': today,
        'email': _auth.currentUser!.email,
        'friends': [],
      });
      return {'newStreak': 1, 'isRecordUpdating': true};
    }

    final data = userSnap.data()!;
    final lastPostedDate = data['lastPostedDate'] as String?;
    final currentStreak = (data['streak'] as num?)?.toInt() ?? 0;
    final maxStreak = (data['maxStreak'] as num?)?.toInt() ?? 0;

    if (lastPostedDate == today) {
      return {'newStreak': currentStreak, 'isRecordUpdating': false};
    }

    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayStr = DateHelper.toDateString(yesterday);
    final newStreak = (lastPostedDate == yesterdayStr) ? currentStreak + 1 : 1;

    // 最大記録更新チェック
    final isRecordUpdating = newStreak > maxStreak;
    final updates = {'streak': newStreak, 'lastPostedDate': today};
    if (isRecordUpdating) {
      updates['maxStreak'] = newStreak;
    }

    await userRef.update(updates);

    return {'newStreak': newStreak, 'isRecordUpdating': isRecordUpdating};
  }
}
