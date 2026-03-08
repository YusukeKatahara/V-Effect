import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/friend_request.dart';
import '../models/app_notification.dart';
import '../models/app_user.dart';
import 'notification_service.dart';

/// フレンド検索・リクエスト送受信・フレンドリストを担当するサービス
///
/// Firestore データ構造:
///   friend_requests/{requestId}
///     - fromUid: string       送信者の Auth UID
///     - toUid: string         受信者の Auth UID
///     - fromUserId: string    送信者のユーザーID（表示用）
///     - fromUsername: string   送信者のユーザー名（表示用）
///     - toUserId: string      受信者のユーザーID
///     - toUsername: string     受信者のユーザー名
///     - status: string        "pending" | "accepted" | "rejected"
///     - createdAt: Timestamp
class FriendService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  /// ユーザーIDで検索します（部分一致ではなく完全一致）
  Future<AppUser?> searchByUserId(String userId) async {
    final query = await _db
        .collection('users')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return AppUser.fromFirestore(query.docs.first);
  }

  /// フレンドリクエストを送信します
  Future<void> sendRequest(String targetUid) async {
    final myUid = _auth.currentUser!.uid;
    if (myUid == targetUid) throw Exception('自分自身には送れません');

    // 既にリクエスト済み or 既にフレンドかチェック
    final existing = await _db
        .collection('friend_requests')
        .where('fromUid', isEqualTo: myUid)
        .where('toUid', isEqualTo: targetUid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) throw Exception('既にリクエスト送信済みです');

    // 自分のプロフィール情報を取得
    final mySnap = await _db.collection('users').doc(myUid).get();
    final myData = mySnap.data() ?? {};

    // 相手のプロフィール情報を取得
    final targetSnap = await _db.collection('users').doc(targetUid).get();
    final targetData = targetSnap.data() ?? {};

    // 既にフレンドかチェック
    final myFriends = List<String>.from(myData['friends'] ?? []);
    if (myFriends.contains(targetUid)) throw Exception('既にフレンドです');

    await _db.collection('friend_requests').add({
      'fromUid': myUid,
      'toUid': targetUid,
      'fromUserId': myData['userId'] ?? '',
      'fromUsername': myData['username'] ?? '',
      'toUserId': targetData['userId'] ?? '',
      'toUsername': targetData['username'] ?? '',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 相手に通知を送る
    await _notificationService.createNotification(
      toUid: targetUid,
      type: NotificationType.friendRequestReceived,
      params: {'username': myData['username'] ?? ''},
      fromUid: myUid,
    );
  }

  /// 受信したフレンドリクエスト一覧を取得します（リアルタイム）
  Stream<List<FriendRequest>> getReceivedRequests() {
    final myUid = _auth.currentUser!.uid;
    return _db
        .collection('friend_requests')
        .where('toUid', isEqualTo: myUid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => FriendRequest.fromFirestore(doc)).toList());
  }

  /// フレンドリクエストを承認します（双方の friends リストに追加）
  Future<void> acceptRequest(FriendRequest request) async {
    final batch = _db.batch();

    // リクエストのステータスを accepted に更新
    batch.update(
      _db.collection('friend_requests').doc(request.id),
      {'status': 'accepted'},
    );

    // 双方の friends 配列に相手の UID を追加
    batch.update(
      _db.collection('users').doc(request.toUid),
      {'friends': FieldValue.arrayUnion([request.fromUid])},
    );
    batch.update(
      _db.collection('users').doc(request.fromUid),
      {'friends': FieldValue.arrayUnion([request.toUid])},
    );

    await batch.commit();

    // リクエスト送信者に承認通知を送る
    await _notificationService.createNotification(
      toUid: request.fromUid,
      type: NotificationType.friendRequestAccepted,
      params: {'username': request.toUsername},
      fromUid: request.toUid,
    );
  }

  /// フレンドリクエストを拒否します
  Future<void> rejectRequest(FriendRequest request) async {
    await _db.collection('friend_requests').doc(request.id).update({
      'status': 'rejected',
    });
  }

  /// フレンドリストを取得します（リアルタイム）
  Stream<List<AppUser>> getFriends() {
    final myUid = _auth.currentUser!.uid;
    return _db
        .collection('users')
        .doc(myUid)
        .snapshots()
        .asyncMap((mySnap) async {
      final friendUids = List<String>.from(mySnap.data()?['friends'] ?? []);
      if (friendUids.isEmpty) return <AppUser>[];

      // Firestore の in クエリは最大30件
      final limitedUids = friendUids.take(30).toList();
      final friendsSnap = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: limitedUids)
          .get();

      return friendsSnap.docs
          .map((doc) => AppUser.fromFirestore(doc))
          .toList();
    });
  }

  /// フレンドを削除します
  Future<void> removeFriend(String friendUid) async {
    final myUid = _auth.currentUser!.uid;
    final batch = _db.batch();

    batch.update(
      _db.collection('users').doc(myUid),
      {'friends': FieldValue.arrayRemove([friendUid])},
    );
    batch.update(
      _db.collection('users').doc(friendUid),
      {'friends': FieldValue.arrayRemove([myUid])},
    );

    await batch.commit();
  }
}
