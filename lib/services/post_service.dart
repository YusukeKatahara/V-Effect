import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import '../models/post.dart';
import '../models/app_notification.dart';
import '../utils/date_helper.dart';
import 'streak_service.dart';
import 'notification_service.dart';

/// 投稿の作成・取得・リアクションを担当するサービス
///
/// Firestoreのデータ構造:
///  posts/{postId}
///    - userId: string
///    - imageUrl: string
///    - taskName: string
///    - createdAt: Timestamp
///    - expiresAt: Timestamp
///    - reactionCount: number
class PostService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final StreakService _streakService = StreakService();
  final NotificationService _notificationService = NotificationService();

  /// ストリークサービスへの委譲メソッド
  Future<int> getStreak() => _streakService.getStreak();
  Future<bool> hasPostedToday() => _streakService.hasPostedToday();

  /// 写真付き投稿をFirebaseにアップロードして保存します
  Future<void> createPost({
    required Uint8List imageBytes,
    required String taskName,
  }) async {
    final uid = _auth.currentUser!.uid;

    // Step1: Firebase Storage に画像を保存
    final ref = _storage.ref().child(
      'posts/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    // Web互換のため、putData(Uint8List) を使用
    await ref.putData(
      imageBytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final imageUrl = await ref.getDownloadURL();

    // Step2: Firestoreに投稿データを保存
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(hours: 24));

    await _db.collection('posts').add({
      'userId': uid,
      'imageUrl': imageUrl,
      'taskName': taskName,
      'createdAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'reactionCount': 0,
    });

    // Step3: ストリークを更新
    await _streakService.updateStreak(uid, now);

    // Step4: フレンドに通知を送る（バックグラウンドで処理）
    _db.collection('users').doc(uid).get().then((userSnap) {
      if (!userSnap.exists) return;
      final username = userSnap.data()?['username'] ?? 'フレンド';
      final friends = List<String>.from(userSnap.data()?['friends'] ?? []);
      
      for (final friendUid in friends) {
        _notificationService.createNotification(
          toUid: friendUid,
          type: NotificationType.friendTaskCompleted,
          params: {'username': username},
          fromUid: uid,
        );
      }
    });
  }

  /// フレンドの24時間以内の投稿を取得します（リアルタイム更新）
  Stream<QuerySnapshot> getFriendsFeed({bool guardedByPost = true}) async* {
    if (guardedByPost) {
      final posted = await hasPostedToday();
      if (!posted) {
        yield* const Stream.empty();
        return;
      }
    }

    final uid = _auth.currentUser!.uid;
    final userSnap = await _db.collection('users').doc(uid).get();
    final friends = List<String>.from(userSnap.data()?['friends'] ?? []);

    if (friends.isEmpty) {
      yield* const Stream.empty();
      return;
    }

    final now = Timestamp.now();
    final limitedFriends = friends.take(10).toList();

    yield* _db
        .collection('posts')
        .where('userId', whereIn: limitedFriends)
        .where('expiresAt', isGreaterThan: now)
        .orderBy('expiresAt', descending: true)
        .snapshots();
  }

  /// 投稿にリアクションをつけます
  Future<void> addReaction(String postId) async {
    await _db.collection('posts').doc(postId).update({
      'reactionCount': FieldValue.increment(1),
    });

    // リアクション通知を送付（バックグラウンドで処理）
    _db.collection('posts').doc(postId).get().then((postSnap) async {
      if (!postSnap.exists) return;
      final postData = postSnap.data()!;
      final postOwnerId = postData['userId'] as String;
      
      final myUid = _auth.currentUser!.uid;
      if (postOwnerId == myUid) return; // 自分への投稿には通知しない
      
      final myUserSnap = await _db.collection('users').doc(myUid).get();
      final myUsername = myUserSnap.data()?['username'] ?? 'フレンド';
      
      await _notificationService.createNotification(
        toUid: postOwnerId,
        type: NotificationType.reactionReceived,
        params: {'username': myUsername},
        fromUid: myUid,
        relatedId: postId,
      );
    });
  }

  /// フレンド一覧を取得します（Stories 表示用）
  /// 戻り値: List<{uid, username, userId}>
  Future<List<Map<String, dynamic>>> getFriendsList() async {
    final uid = _auth.currentUser!.uid;
    final userSnap = await _db.collection('users').doc(uid).get();
    final friendUids = List<String>.from(userSnap.data()?['friends'] ?? []);
    if (friendUids.isEmpty) return [];

    final limitedUids = friendUids.take(30).toList();
    final friendsSnap = await _db
        .collection('users')
        .where(FieldPath.documentId, whereIn: limitedUids)
        .get();

    final today = DateHelper.toDateString(DateTime.now());
    return friendsSnap.docs.map((doc) {
      final data = doc.data();
      return {
        'uid': doc.id,
        'username': data['username'] ?? '',
        'userId': data['userId'] ?? '',
        'hasPostedToday': data['lastPostedDate'] == today,
      };
    }).toList();
  }

  /// 特定フレンドの24h以内の投稿を取得します（リアルタイム）
  Stream<QuerySnapshot> getFriendPosts(String friendUid) {
    final now = Timestamp.now();
    return _db
        .collection('posts')
        .where('userId', isEqualTo: friendUid)
        .where('expiresAt', isGreaterThan: now)
        .orderBy('expiresAt', descending: true)
        .snapshots();
  }

  /// 特定フレンドの24h以内の投稿を一括取得します（ストーリー表示用）
  Future<List<Post>> getFriendPostsList(String friendUid) async {
    final now = Timestamp.now();
    final snap = await _db
        .collection('posts')
        .where('userId', isEqualTo: friendUid)
        .where('expiresAt', isGreaterThan: now)
        .orderBy('expiresAt', descending: true)
        .get();
    return snap.docs.map((doc) => Post.fromFirestore(doc)).toList();
  }

  /// 自分のタスクリストを取得します
  Future<List<String>> getMyTasks() async {
    final uid = _auth.currentUser!.uid;
    final snap = await _db.collection('users').doc(uid).get();
    return List<String>.from(snap.data()?['tasks'] ?? []);
  }

  /// 自分のユーザー名を取得します
  Future<String> getMyUsername() async {
    final uid = _auth.currentUser!.uid;
    final snap = await _db.collection('users').doc(uid).get();
    return snap.data()?['username'] ?? '';
  }
}
