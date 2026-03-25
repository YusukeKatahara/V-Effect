import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/friend_request.dart';
import '../models/app_notification.dart';
import '../models/app_user.dart';
import 'analytics_service.dart';
import 'notification_service.dart';

/// フォロー・フォロワー・検索を担当するサービス
class FriendService {
  FriendService._();
  static final FriendService instance = FriendService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService.instance;
  final AnalyticsService _analytics = AnalyticsService.instance;

  /// ユーザーIDで検索します（完全一致）
  Future<AppUser?> searchByUserId(String userId) async {
    final query = await _db
        .collection('users')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return AppUser.fromFirestore(query.docs.first);
  }

  /// 名前（username）で検索します（部分一致）
  Future<List<AppUser>> searchByUsername(String queryText) async {
    final query = await _db
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: queryText)
        .where('username', isLessThanOrEqualTo: '$queryText\uf8ff')
        .limit(20)
        .get();
    return query.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
  }

  /// ユーザーをフォローします
  Future<void> followUser(String targetUid) async {
    final myUid = _auth.currentUser!.uid;
    if (myUid == targetUid) throw Exception('自分自身はフォローできません');

    final batch = _db.batch();

    // 自分の following に追加
    batch.update(
      _db.collection('users').doc(myUid),
      {'following': FieldValue.arrayUnion([targetUid])},
    );

    // 相手の followers に追加
    batch.update(
      _db.collection('users').doc(targetUid),
      {'followers': FieldValue.arrayUnion([myUid])},
    );

    await batch.commit();

    // 相手に通知を送る
    final mySnap = await _db.collection('users').doc(myUid).get();
    final myUsername = mySnap.data()?['username'] ?? '誰か';

    await _notificationService.createNotification(
      toUid: targetUid,
      type: NotificationType.friendRequestAccepted, // 型を再利用
      params: {'username': myUsername},
      fromUid: myUid,
    );

    _analytics.logFriendRequestSent();
  }

  /// フォローを解除します
  Future<void> unfollowUser(String targetUid) async {
    final myUid = _auth.currentUser!.uid;
    final batch = _db.batch();

    batch.update(
      _db.collection('users').doc(myUid),
      {'following': FieldValue.arrayRemove([targetUid])},
    );

    batch.update(
      _db.collection('users').doc(targetUid),
      {'followers': FieldValue.arrayRemove([myUid])},
    );

    await batch.commit();
    _analytics.logFriendRemoved();
  }

  /// フォロー中リストを取得します（リアルタイム）
  Stream<List<AppUser>> getFollowing() {
    final myUid = _auth.currentUser!.uid;
    return _db.collection('users').doc(myUid).snapshots().asyncMap((snap) async {
      if (!snap.exists) return [];
      final uids = List<String>.from(snap.data()?['following'] ?? snap.data()?['friends'] ?? []);
      if (uids.isEmpty) return [];

      final usersSnap = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: uids.take(30).toList())
          .get();
      return usersSnap.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
    });
  }

  /// フォロワーリストを取得します（リアルタイム）
  Stream<List<AppUser>> getFollowers() {
    final myUid = _auth.currentUser!.uid;
    return _db.collection('users').doc(myUid).snapshots().asyncMap((snap) async {
      if (!snap.exists) return [];
      final uids = List<String>.from(snap.data()?['followers'] ?? []);
      if (uids.isEmpty) return [];

      final usersSnap = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: uids.take(30).toList())
          .get();
      return usersSnap.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
    });
  }

  /// UIDでユーザーを1件取得します
  Future<AppUser?> getUserByUid(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    if (!snap.exists) return null;
    return AppUser.fromFirestore(snap);
  }

  /// 複数UIDのユーザーを一括取得します（最大30件/チャンク）
  Future<List<AppUser>> getUsersByUids(List<String> uids) async {
    if (uids.isEmpty) return [];
    final results = <AppUser>[];
    for (var i = 0; i < uids.length; i += 30) {
      final chunk = uids.sublist(i, (i + 30).clamp(0, uids.length));
      final snap = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      results.addAll(snap.docs.map((doc) => AppUser.fromFirestore(doc)));
    }
    return results;
  }

  /// 現在のユーザーが対象ユーザーをフォローしているか確認します
  Future<bool> isFollowing(String targetUid) async {
    final myUid = _auth.currentUser!.uid;
    final snap = await _db.collection('users').doc(myUid).get();
    final following = List<String>.from(
      snap.data()?['following'] ?? snap.data()?['friends'] ?? [],
    );
    return following.contains(targetUid);
  }

  // ── 以下、既存画面との互換性のためのエイリアス ──

  Future<void> sendRequest(String targetUid) => followUser(targetUid);
  
  Stream<List<FriendRequest>> getReceivedRequests() => const Stream.empty();
  
  Future<FriendRequest?> getRequestById(String requestId) async => null;
  
  Future<void> acceptRequest(dynamic request) async {}
  
  Future<void> rejectRequest(dynamic request) async {}
  
  Stream<List<AppUser>> getFriends() => getFollowing();
  
  Future<void> removeFriend(String friendUid) => unfollowUser(friendUid);
}
