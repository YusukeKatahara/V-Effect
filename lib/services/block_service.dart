import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'analytics_service.dart';

/// ブロック・通報機能を担当するサービス
class BlockService {
  BlockService._();
  static final BlockService instance = BlockService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AnalyticsService _analytics = AnalyticsService.instance;

  /// 対象ユーザーをブロックする
  ///
  /// - users/{myUid}.blockedUsers に targetUid を追加
  /// - フォロー関係（following/followers）を双方から Batch で原子的に解除
  /// - 未処理の friend_requests を削除
  Future<void> blockUser(String targetUid) async {
    final myUid = _auth.currentUser!.uid;
    final batch = _db.batch();

    // 自分側: ブロックリスト追加 + フォロー・フォロワーから削除
    batch.update(_db.collection('users').doc(myUid), {
      'blockedUsers': FieldValue.arrayUnion([targetUid]),
      'following': FieldValue.arrayRemove([targetUid]),
      'followers': FieldValue.arrayRemove([targetUid]),
    });

    // 相手側: フォロー・フォロワーから自分を削除
    batch.update(_db.collection('users').doc(targetUid), {
      'followers': FieldValue.arrayRemove([myUid]),
      'following': FieldValue.arrayRemove([myUid]),
    });

    await batch.commit();

    // 未処理の friend_requests を削除（batch では query-delete 不可のため個別処理）
    await _cancelPendingRequests(myUid, targetUid);

    _analytics.logUserBlocked();
  }

  Future<void> _cancelPendingRequests(String myUid, String targetUid) async {
    final snaps = await Future.wait([
      _db
          .collection('friend_requests')
          .where('fromUid', isEqualTo: myUid)
          .where('toUid', isEqualTo: targetUid)
          .where('status', isEqualTo: 'pending')
          .get(),
      _db
          .collection('friend_requests')
          .where('fromUid', isEqualTo: targetUid)
          .where('toUid', isEqualTo: myUid)
          .where('status', isEqualTo: 'pending')
          .get(),
    ]);
    for (final snap in snaps) {
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    }
  }

  /// ブロックを解除する
  Future<void> unblockUser(String targetUid) async {
    final myUid = _auth.currentUser!.uid;
    await _db.collection('users').doc(myUid).update({
      'blockedUsers': FieldValue.arrayRemove([targetUid]),
    });
  }

  /// 自分が対象ユーザーをブロックしているか確認する
  Future<bool> isBlocked(String targetUid) async {
    final myUid = _auth.currentUser!.uid;
    final snap = await _db.collection('users').doc(myUid).get();
    final blocked = List<String>.from(snap.data()?['blockedUsers'] ?? []);
    return blocked.contains(targetUid);
  }

  /// 対象ユーザーが自分をブロックしているか確認する
  Future<bool> isBlockedBy(String targetUid) async {
    final myUid = _auth.currentUser!.uid;
    final snap = await _db.collection('users').doc(targetUid).get();
    final blocked = List<String>.from(snap.data()?['blockedUsers'] ?? []);
    return blocked.contains(myUid);
  }

  /// 自分がブロックしているUIDの一覧を取得する（フィードフィルタ用）
  Future<List<String>> getBlockedUids() async {
    final myUid = _auth.currentUser!.uid;
    final snap = await _db.collection('users').doc(myUid).get();
    return List<String>.from(snap.data()?['blockedUsers'] ?? []);
  }

  /// ユーザーを通報する（同一ユーザーへの7日以内の重複通報を防止）
  ///
  /// [reason]: "spam" | "harassment" | "inappropriate" | "other"
  ///
  /// 重複通報の場合は Exception('already_reported') をスローする
  Future<void> reportUser(String targetUid, String reason) async {
    final myUid = _auth.currentUser!.uid;

    // 7日以内の重複通報チェック
    final sevenDaysAgo = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(days: 7)),
    );
    final existing = await _db
        .collection('reports')
        .where('reporterUid', isEqualTo: myUid)
        .where('reportedUid', isEqualTo: targetUid)
        .where('createdAt', isGreaterThan: sevenDaysAgo)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('already_reported');
    }

    await _db.collection('reports').add({
      'reporterUid': myUid,
      'reportedUid': targetUid,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }
}
