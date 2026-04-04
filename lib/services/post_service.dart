import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/post.dart';
import '../models/app_notification.dart';
import '../utils/date_helper.dart';
import 'analytics_service.dart';
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
  PostService._();
  static final PostService instance = PostService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final StreakService _streakService = StreakService.instance;
  final NotificationService _notificationService = NotificationService.instance;
  final AnalyticsService _analytics = AnalyticsService.instance;

  /// アプリ全体にデータ更新（投稿作成・削除）を通知するためのストリーム
  final _updateController = StreamController<void>.broadcast();
  Stream<void> get updateStream => _updateController.stream;

  /// ストリークサービスへの委譲メソッド
  Future<int> getStreak() => _streakService.getStreak();
  Future<bool> hasPostedToday() => _streakService.hasPostedToday();

  /// ホーム画面に必要なデータを1回のFirestore読み込みで取得します
  ///
  /// 戻り値のキー: streak, postedToday (＝1つ以上投稿済み), isAllTasksCompleted, username, tasks, friends, lastPostedDate
  Future<Map<String, dynamic>> getHomeData() async {
    final uid = _auth.currentUser!.uid;

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    // ユーザー情報と投稿を並列で取得
    // ※createdAtでのクエリフィルタは複合インデックスが必要なため、
    // 既存のインデックス環境を壊さないよう、取得後にメモリ内でフィルタリングを行う
    final results = await Future.wait([
      _db.collection('users').doc(uid).get(),
      _db.collection('posts').where('userId', isEqualTo: uid).get(),
    ]);

    final snap = results[0] as DocumentSnapshot;
    final postsSnap = results[1] as QuerySnapshot;

    if (!snap.exists) {
      return {
        'streak': 0,
        'postedToday': false,
        'isAllTasksCompleted': false,
        'username': '',
        'tasks': <String>[],
        'friends': <String>[],
        'lastPostedDate': null,
        'postedTasksToday': <Post>[],
      };
    }
    final data = snap.data() as Map<String, dynamic>;
    final rawLastPostedDate = data['lastPostedDate'];
    final lastPostedDate = rawLastPostedDate is String ? rawLastPostedDate : rawLastPostedDate?.toString();

    final dynamic rawTasks = data['tasks'];
    List<String> tasks = [];
    if (rawTasks is List) {
      tasks = rawTasks.map((e) => e.toString()).toList();
    } else if (rawTasks is Map) {
      tasks = rawTasks.keys.map((k) => k.toString()).toList();
    }


    // 今日の分だけをフィルタリング
    final postedPostsToday =
        postsSnap.docs
            .where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              if (!d.containsKey('createdAt')) return false;
              final createdAt = (d['createdAt'] as Timestamp).toDate();
              return createdAt.isAfter(startOfToday) ||
                  createdAt.isAtSameMomentAs(startOfToday);
            })
            .map((doc) => Post.fromFirestore(doc))
            .toList();

    return {
      'streak': (data['streak'] as num?)?.toInt() ?? 0,
      'postedToday': postedPostsToday.isNotEmpty,
      'isAllTasksCompleted':
          tasks.isNotEmpty &&
          tasks.every((t) => postedPostsToday.any((p) => p.taskName == t)),
      'username': data['username'] as String? ?? '',
      'tasks': tasks,
      'friends': (() {
        final dynamic f = data['following'] ?? data['friends'];
        if (f is List) return f.map((e) => e.toString()).toList();
        if (f is Map) return f.keys.map((k) => k.toString()).toList();
        return <String>[];
      })(),

      'lastPostedDate': lastPostedDate,
      'postedTasksToday': postedPostsToday,
    };
  }

  /// フレンドUID一覧から表示用のフレンド情報を一括取得します
  ///
  /// [friendUids] はgetHomeData()で取得済みのフレンドUID一覧を渡してください。
  /// これにより追加のユーザードキュメント読み込みを回避します。
  Future<List<Map<String, dynamic>>> getFriendsListFromUids(
    List<String> friendUids,
  ) async {
    if (friendUids.isEmpty) return [];

    final limitedUids = friendUids.take(30).toList();

    // Firestore の whereIn は最大30件なので分割不要
    final friendsSnap =
        await _db
            .collection('users')
            .where(FieldPath.documentId, whereIn: limitedUids)
            .get();

    final today = DateHelper.toDateString(DateTime.now());
    return friendsSnap.docs.map((doc) {
      final data = doc.data();
      return {
        'uid': doc.id,
        'username': data['username']?.toString() ?? '',
        'userId': data['userId']?.toString() ?? '',
        'photoUrl': data['photoUrl'] is String ? data['photoUrl'] as String : data['photoUrl']?.toString(),
        'hasPostedToday': data['lastPostedDate']?.toString() == today,

      };
    }).toList();
  }

  /// 写真付き投稿をFirebaseにアップロードして保存します
  /// 戻り値: {'newStreak': int, 'isRecordUpdating': bool}
  Future<Map<String, dynamic>> createPost({
    required Uint8List imageBytes,
    required String taskName,
    String? caption,
  }) async {
    final uid = _auth.currentUser!.uid;

    // Step1: Firebase Storage に画像を保存
    final ref = _storage.ref().child(
      'posts/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    // Web互換のため、putData(Uint8List) を使用
    await ref.putData(imageBytes, SettableMetadata(contentType: 'image/jpeg'));
    final imageUrl = await ref.getDownloadURL();

    // Step2: Firestoreに投稿データを保存
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(hours: 24));

    // ユーザー設定（タイムスタンプ表示）を取得
    final userPrivateSnap = await _db.collection('users').doc(uid).collection('private').doc('data').get();
    final showTimestamp = userPrivateSnap.data()?['showTimestamp'] ?? true;

    await _db.collection('posts').add({
      'userId': uid,
      'imageUrl': imageUrl,
      'taskName': taskName,
      'caption': caption,
      'createdAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'reactionCount': 0,
      'showTimestamp': showTimestamp,
    });

    // Step3: ストリークを更新
    final streakResult = await _streakService.updateStreak(uid, now);

    // Step4: Analytics イベント送信
    _analytics.logPostCreated(taskName: taskName);
    _analytics.setPostingTimeSlot(now.hour);
    final newStreak = streakResult['newStreak'] as int;
    final isRecord = streakResult['isRecordUpdating'] as bool;
    _analytics.logStreakUpdate(streak: newStreak, isRecord: isRecord);
    _analytics.setStreakTier(newStreak);
    // マイルストーン判定（7, 30, 100, 365日）
    if (const [7, 30, 100, 365].contains(newStreak)) {
      _analytics.logStreakMilestone(streak: newStreak);
    }

    // Step5: フレンドに通知を送る（バックグラウンドで処理、エラーハンドリング付き）
    _sendPostNotifications(uid).catchError((_) {
      // 通知送信失敗はクリティカルではないので静かに無視
    });

    // データの変更をアプリ全体に通知
    _updateController.add(null);

    return streakResult;
  }

  /// 投稿後のフレンド通知を送信する内部メソッド
  Future<void> _sendPostNotifications(String uid) async {
    final userSnap = await _db.collection('users').doc(uid).get();
    if (!userSnap.exists) return;
    final username = userSnap.data()?['username']?.toString() ?? 'フレンド';
    final dynamic rawFriends = userSnap.data()?['following'] ?? userSnap.data()?['friends'];
    List<String> friends = [];
    if (rawFriends is List) {
      friends = rawFriends.map((e) => e.toString()).toList();
    } else if (rawFriends is Map) {
      friends = rawFriends.keys.map((k) => k.toString()).toList();
    }


    for (final friendUid in friends) {
      await _notificationService.createNotification(
        toUid: friendUid,
        type: NotificationType.friendTaskCompleted,
        params: {'username': username},
        fromUid: uid,
      );
    }
  }

  /// フレンドの24時間以内の投稿を取得します（リアルタイム更新）
  ///
  /// [friendUids] を渡すと追加のユーザードキュメント読み込みをスキップします。
  Stream<List<Post>> getFriendsFeed({
    bool guardedByPost = true,
    List<String>? friendUids,
  }) async* {
    if (guardedByPost) {
      final posted = await hasPostedToday();
      if (!posted) {
        yield* const Stream<List<Post>>.empty();
        return;
      }
    }

    // フレンドUID一覧が未提供の場合のみFirestoreから取得
    List<String> friends;
    if (friendUids != null) {
      friends = friendUids;
    } else {
      final uid = _auth.currentUser!.uid;
      final userSnap = await _db.collection('users').doc(uid).get();
      final dynamic rawFriends = userSnap.data()?['following'] ?? userSnap.data()?['friends'];
      if (rawFriends is List) {
        friends = rawFriends.map((e) => e.toString()).toList();
      } else if (rawFriends is Map) {
        friends = rawFriends.keys.map((k) => k.toString()).toList();
      } else {
        friends = [];
      }

    }

    if (friends.isEmpty) {
      yield* const Stream<List<Post>>.empty();
      return;
    }

    final limitedFriends = friends.take(10).toList();

    yield* _db
        .collection('posts')
        .where('userId', whereIn: limitedFriends)
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .snapshots()
        .map((snap) {
          final posts =
              snap.docs.map((doc) => Post.fromFirestore(doc)).toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return posts;
        });
  }

  /// 投稿にリアクションをつけます
  Future<void> addReaction(String postId) async {
    await _db.collection('posts').doc(postId).update({
      'reactionCount': FieldValue.increment(1),
    });
    _analytics.logReactionSent();

    // リアクション通知を送付（バックグラウンドで処理、エラーハンドリング付き）
    _sendReactionNotification(postId).catchError((_) {
      // 通知送信失敗はクリティカルではないので静かに無視
    });
  }

  /// リアクション通知を送信する内部メソッド
  /// 同じ投稿に対して同じユーザーからの通知がある場合は、回数を増やして更新する
  Future<void> _sendReactionNotification(String postId) async {
    final postSnap = await _db.collection('posts').doc(postId).get();
    if (!postSnap.exists) return;
    final postData = postSnap.data()!;
    final postOwnerId = postData['userId'] as String;
    final postTaskName = postData['taskName'] as String? ?? '投稿';

    final myUid = _auth.currentUser!.uid;
    if (postOwnerId == myUid) return; // 自分への投稿には通知しない

    // 自分のユーザー名を取得
    final myUserSnap = await _db.collection('users').doc(myUid).get();
    final myUsername = myUserSnap.data()?['username'] ?? 'フレンド';

    // 同じ投稿・同じ送信者のリアクション通知が既にあるかチェック
    final existing =
        await _db
            .collection('notifications')
            .where('fromUid', isEqualTo: myUid)
            .where('relatedId', isEqualTo: postId)
            .where('type', isEqualTo: NotificationType.reactionReceived.name)
            .limit(1)
            .get();

    int newCount = 1;
    if (existing.docs.isNotEmpty) {
      final doc = existing.docs.first;
      final data = doc.data();
      final currentCount = data['reactionCount'] as int? ?? 0;
      newCount = currentCount + 1;
      await doc.reference.delete();
    }

    // ランダムな文言の選択
    final random = Random();
    final variations = [
      {
        'title': '🔥 熱狂！',
        'body': '$myUsernameさんがあなたの「$postTaskName」の達成に熱狂しています！',
      },
      {
        'title': '⚡️ V-Effect 発動！',
        'body': 'あなたの「$postTaskName」が、$myUsernameさんのモチベーションに火をつけました！',
      },
      {
        'title': '🚀 リスペクト！',
        'body': '$myUsernameさんが「$postTaskName」を頑張るあなたに特大のパワーを送りました！',
      },
      {
        'title': '👏 スーパーヒーロー！',
        'body': '$myUsernameさんから「$postTaskName」へ、$newCount回の称賛が届いています！',
      },
    ];
    final selected = variations[random.nextInt(variations.length)];

    // 新しい通知を作成
    await _db.collection('notifications').add({
      'toUid': postOwnerId,
      'fromUid': myUid,
      'relatedId': postId,
      'type': NotificationType.reactionReceived.name,
      'reactionCount': newCount,
      'title': selected['title'],
      'body': selected['body'],
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// フレンド一覧を取得します（Stories 表示用）
  /// 戻り値: List<{uid, username, userId}>
  Future<List<Map<String, dynamic>>> getFriendsList() async {
    final uid = _auth.currentUser!.uid;
    final userSnap = await _db.collection('users').doc(uid).get();
    final dynamic rawFriends = userSnap.data()?['following'] ?? userSnap.data()?['friends'];
    List<String> friendUids = [];
    if (rawFriends is List) {
      friendUids = rawFriends.map((e) => e.toString()).toList();
    } else if (rawFriends is Map) {
      friendUids = rawFriends.keys.map((k) => k.toString()).toList();
    }

    return getFriendsListFromUids(friendUids);
  }

  /// 特定フレンドの24h以内の投稿を取得します（リアルタイム）
  Stream<List<Post>> getFriendPosts(String friendUid) {
    return _db
        .collection('posts')
        .where('userId', isEqualTo: friendUid)
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .snapshots()
        .map((snap) {
          final posts =
              snap.docs.map((doc) => Post.fromFirestore(doc)).toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return posts;
        });
  }

  /// 特定フレンドの24h以内の投稿を一括取得します（ストーリー表示用）
  Future<List<Post>> getFriendPostsList(String friendUid) async {
    final snap =
        await _db
            .collection('posts')
            .where('userId', isEqualTo: friendUid)
            .where('expiresAt', isGreaterThan: Timestamp.now())
            .get();
    return snap.docs.map((doc) => Post.fromFirestore(doc)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// 自分のヒーロータスクリストを取得します
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

  /// 全フレンドの直近の投稿（24時間以内）をまとめて取得します
  Future<List<Post>> getAllFriendsPosts(List<String> friendUids) async {
    if (friendUids.isEmpty) return [];

    // Firestoreの `in` クエリは最大10件までの制限があるため、10件ごとに分割
    // 並列実行して速度を向上させる
    final List<Future<QuerySnapshot>> futures = [];
    for (var i = 0; i < friendUids.length; i += 10) {
      final chunk = friendUids.sublist(
        i,
        i + 10 > friendUids.length ? friendUids.length : i + 10,
      );
      futures.add(
        _db
            .collection('posts')
            .where('userId', whereIn: chunk)
            .where('expiresAt', isGreaterThan: Timestamp.now())
            .get(),
      );
    }

    final snapshots = await Future.wait(futures);
    List<Post> allPosts = [];
    for (var snap in snapshots) {
      allPosts.addAll(snap.docs.map((doc) => Post.fromFirestore(doc)));
    }

    // 作成日時の新しい順にソート
    allPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return allPosts;
  }

  /// 投稿を削除します
  Future<void> deletePost(String postId) async {
    final postSnap = await _db.collection('posts').doc(postId).get();
    if (!postSnap.exists) return;

    final data = postSnap.data()!;
    final imageUrl = data['imageUrl'] as String?;
    final uid = data['userId'] as String;

    // 1. Firestore から投稿を削除
    await postSnap.reference.delete();

    // 2. Storage から画像を削除
    if (imageUrl != null) {
      try {
        final ref = _storage.refFromURL(imageUrl);
        await ref.delete();
      } catch (e) {
        debugPrint('Failed to delete image from storage: $e');
      }
    }

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    // 3. 今日他に投稿があるか確認（インデックス不要のため全取得してフィルタ）
    final allUserPosts = await _db
        .collection('posts')
        .where('userId', isEqualTo: uid)
        .get();

    final remainingToday = allUserPosts.docs.where((doc) {
      if (doc.id == postId) return false;
      final d = doc.data();
      if (!d.containsKey('createdAt')) return false;
      final createdAt = (d['createdAt'] as Timestamp).toDate();
      return createdAt.isAfter(startOfToday) ||
          createdAt.isAtSameMomentAs(startOfToday);
    }).toList();

    if (remainingToday.isEmpty) {
      // 今日もう投稿がない場合、過去も含めた最新の投稿を探して lastPostedDate を戻す
      if (allUserPosts.docs.isEmpty) {
        await _db.collection('users').doc(uid).update({'lastPostedDate': null});
      } else {
        // allUserPosts から最新のものを探す
        DateTime? lastDate;
        for (var doc in allUserPosts.docs) {
          if (doc.id == postId) continue;
          final d = doc.data();
          final createdAt = (d['createdAt'] as Timestamp).toDate();
          if (lastDate == null || createdAt.isAfter(lastDate)) {
            lastDate = createdAt;
          }
        }
        await _db.collection('users').doc(uid).update({
          'lastPostedDate': lastDate != null ? DateHelper.toDateString(lastDate) : null
        });
      }
    }

    // データの変更をアプリ全体に通知
    _updateController.add(null);
  }
}
