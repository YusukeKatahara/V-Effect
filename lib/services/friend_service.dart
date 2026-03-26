import 'package:flutter/foundation.dart';
import 'package:kana_kit/kana_kit.dart';
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

  /// 名前（username）で検索します（部分一致・大文字小文字区別なし）
  Future<List<AppUser>> searchByUsername(String queryText) async {
    final kanaKit = const KanaKit();
    final queryLower = queryText.toLowerCase();
    final results = <AppUser>[];

    // 1. 元のクエリ（小文字）で検索
    final originalResults = await _db
        .collection('users')
        .where('usernameLower', isGreaterThanOrEqualTo: queryLower)
        .where('usernameLower', isLessThanOrEqualTo: '$queryLower\uf8ff')
        .limit(20)
        .get();
    results.addAll(originalResults.docs.map((doc) => AppUser.fromFirestore(doc)));

    // 2. もしクエリに日本語が含まれる場合、ローマ字に変換して検索
    if (kanaKit.isRomaji(queryLower) == false) {
      final romajiQuery = kanaKit.toRomaji(queryLower);
      if (romajiQuery != queryLower) {
        final romajiResults = await _db
            .collection('users')
            .where('usernameLower', isGreaterThanOrEqualTo: romajiQuery)
            .where('usernameLower', isLessThanOrEqualTo: '$romajiQuery\uf8ff')
            .limit(10)
            .get();
        for (final doc in romajiResults.docs) {
          final user = AppUser.fromFirestore(doc);
          if (!results.any((u) => u.uid == user.uid)) {
            results.add(user);
          }
        }
      }
    }

    return results;
  }

  /// フォロー申請を送ります
  ///
  /// 相手から既に申請が来ていた場合は自動的に承認します。
  Future<void> sendRequest(String targetUid) async {
    final myUid = _auth.currentUser!.uid;
    if (myUid == targetUid) throw Exception('自分自身にリクエストできません');

    // 既にフォロー中なら何もしない
    if (await isFollowing(targetUid)) return;

    // 相手から既に申請が来ているかチェック（来ていれば自動承認）
    final reverseSnap = await _db
        .collection('friend_requests')
        .where('fromUid', isEqualTo: targetUid)
        .where('toUid', isEqualTo: myUid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (reverseSnap.docs.isNotEmpty) {
      final reverseRequest = FriendRequest.fromFirestore(reverseSnap.docs.first);
      await acceptRequest(reverseRequest);
      return;
    }

    // 既に申請中かチェック
    if (await hasPendingRequest(targetUid)) return;

    // 自分のユーザー情報を取得
    final mySnap = await _db.collection('users').doc(myUid).get();
    final myUsername = mySnap.data()?['username'] ?? '';
    final myUserId = mySnap.data()?['userId'] ?? '';

    // 相手のユーザー情報を取得
    final targetSnap = await _db.collection('users').doc(targetUid).get();
    final targetUsername = targetSnap.data()?['username'] ?? '';
    final targetUserId = targetSnap.data()?['userId'] ?? '';

    // friend_requests に追加
    final docRef = await _db.collection('friend_requests').add({
      'fromUid': myUid,
      'toUid': targetUid,
      'fromUserId': myUserId,
      'fromUsername': myUsername,
      'toUserId': targetUserId,
      'toUsername': targetUsername,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 相手に通知を送る
    await _notificationService.createNotification(
      toUid: targetUid,
      type: NotificationType.friendRequestReceived,
      params: {'username': myUsername},
      fromUid: myUid,
      relatedId: docRef.id,
    );

    _analytics.logFriendRequestSent();
  }

  /// 申請を承認します（followers / following 配列を更新）
  Future<void> acceptRequest(FriendRequest request) async {
    final myUid = _auth.currentUser!.uid;
    final batch = _db.batch();

    // リクエストのステータスを承認に更新
    batch.update(
      _db.collection('friend_requests').doc(request.id),
      {'status': 'accepted'},
    );

    // 承認者（自分）の followers に申請者を追加
    batch.update(
      _db.collection('users').doc(myUid),
      {'followers': FieldValue.arrayUnion([request.fromUid])},
    );

    // 申請者の following に承認者（自分）を追加
    batch.update(
      _db.collection('users').doc(request.fromUid),
      {'following': FieldValue.arrayUnion([myUid])},
    );

    await batch.commit();

    // 申請者に承認通知を送る
    final mySnap = await _db.collection('users').doc(myUid).get();
    final myUsername = mySnap.data()?['username'] ?? '';

    await _notificationService.createNotification(
      toUid: request.fromUid,
      type: NotificationType.friendRequestAccepted,
      params: {'username': myUsername},
      fromUid: myUid,
      relatedId: request.id,
    );
  }

  /// 申請を拒否します
  Future<void> rejectRequest(FriendRequest request) async {
    await _db
        .collection('friend_requests')
        .doc(request.id)
        .update({'status': 'rejected'});
  }

  /// 自分が送った申請をキャンセルします
  Future<void> cancelRequest(String targetUid) async {
    final myUid = _auth.currentUser!.uid;
    final snap = await _db
        .collection('friend_requests')
        .where('fromUid', isEqualTo: myUid)
        .where('toUid', isEqualTo: targetUid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return;
    await snap.docs.first.reference.delete();
  }

  /// ユーザーをフォローします
  Future<void> followUser(String targetUid) async {
    final myUid = _auth.currentUser!.uid;
    if (myUid == targetUid) throw Exception('自分自身はフォローできません');

    final batch = _db.batch();

    // 自分の following に相手を追加
    batch.update(
      _db.collection('users').doc(myUid),
      {'following': FieldValue.arrayUnion([targetUid])},
    );

    // 相手の followers に自分を追加
    batch.update(
      _db.collection('users').doc(targetUid),
      {'followers': FieldValue.arrayUnion([myUid])},
    );

    await batch.commit();

    // 通知を送る
    try {
      final mySnap = await _db.collection('users').doc(myUid).get();
      final myUsername = mySnap.data()?['username'] ?? '誰か';
      await _notificationService.createNotification(
        toUid: targetUid,
        type: NotificationType.friendRequestAccepted,
        params: {'username': myUsername},
        fromUid: myUid,
      );
    } catch (e) {
      debugPrint('Failed to send follow notification: $e');
    }

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

  /// 受信した申請一覧をリアルタイムで取得します（pending のみ）
  Stream<List<FriendRequest>> getReceivedRequests() {
    final myUid = _auth.currentUser!.uid;
    return _db
        .collection('friend_requests')
        .where('toUid', isEqualTo: myUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => FriendRequest.fromFirestore(doc)).toList());
  }

  /// IDで申請を1件取得します
  Future<FriendRequest?> getRequestById(String requestId) async {
    final snap = await _db.collection('friend_requests').doc(requestId).get();
    if (!snap.exists) return null;
    return FriendRequest.fromFirestore(snap);
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

  /// 対象ユーザーが自分のフォロワーかどうか確認します
  Future<bool> isFollower(String targetUid) async {
    final myUid = _auth.currentUser!.uid;
    final snap = await _db.collection('users').doc(myUid).get();
    final followers = List<String>.from(snap.data()?['followers'] ?? []);
    return followers.contains(targetUid);
  }

  /// 自分が対象ユーザーへの申請を送り中かどうか確認します
  Future<bool> hasPendingRequest(String targetUid) async {
    final myUid = _auth.currentUser!.uid;
    final snap = await _db
        .collection('friend_requests')
        .where('fromUid', isEqualTo: myUid)
        .where('toUid', isEqualTo: targetUid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  // ── 既存画面との互換性のためのエイリアス ──

  Stream<List<AppUser>> getFriends() => getFollowing();

  Future<void> removeFriend(String friendUid) => unfollowUser(friendUid);
}
