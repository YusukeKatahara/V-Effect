import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../models/post.dart';
import '../models/app_notification.dart';
import '../utils/date_helper.dart';
import 'analytics_service.dart';
import 'streak_service.dart';
import 'notification_service.dart';
import '../models/app_task.dart';

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

  CollectionReference<Post> get _postsRef =>
      _db.collection('posts').withConverter<Post>(
            fromFirestore: (snapshot, _) => Post.fromFirestore(snapshot),
            toFirestore: (post, _) => post.toFirestore(),
          );

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

    // ユーザー情報と投稿を並列で取得（投稿は過去24時間以内の期限切れでないものに限定して高速化）
    final results = await Future.wait([
      _db.collection('users').doc(uid).get(),
      _postsRef
          .where(Post.fieldUserId, isEqualTo: uid)
          .where('expiresAt', isGreaterThan: now)
          .get(),
    ]);

    final snap = results[0] as DocumentSnapshot;
    final postsSnap = results[1] as QuerySnapshot<Post>;

    if (!snap.exists) {
      return {
        'streak': 0,
        'streakProtections': 0,
        'postedToday': false,
        'isAllTasksCompleted': false,
        'username': '',
        'tasks': <AppTask>[],
        'friends': <String>[],
        'lastPostedDate': null,
        'postedTasksToday': <Post>[],
      };
    }
    final data = snap.data() as Map<String, dynamic>;

    final lastPostedDate = data['lastPostedDate'] as String?;
    final tasks = (data['tasks'] as List? ?? [])
        .map((item) => AppTask.fromFirestore(item))
        .toList();

    // 今日の分だけをフィルタリング
    final postedPostsToday =
        postsSnap.docs
            .map((doc) => doc.data())
            .where((post) {
               return post.createdAt.isAfter(startOfToday) ||
                   post.createdAt.isAtSameMomentAs(startOfToday);
            })
            .toList();

    return {
      'streak': (data['streak'] as num?)?.toInt() ?? 0,
      'streakProtections': (data['streakProtections'] as num?)?.toInt() ?? 0,
      'postedToday': postedPostsToday.isNotEmpty,
      'isAllTasksCompleted':
          tasks.isNotEmpty &&
          tasks.every((t) => postedPostsToday.any((p) => p.taskName == t.title)),
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

    // 🚀 【爆速化】ローカルキャッシュに先回りして保存 (Optimistic Cache Seeding)
    try {
      await DefaultCacheManager().putFile(
        imageUrl,
        imageBytes,
        fileExtension: 'jpg',
      );
    } catch (e) {
      debugPrint('CACHE SEEDING ERROR: $e');
    }

    // Step2: Firestoreに投稿データを保存
    final now = DateTime.now();
    final expiresAt = DateTime(now.year, now.month, now.day + 1); // 翌日0:00

    // ユーザー設定（タイムスタンプ表示）を取得
    final userSnap = await _db.collection('users').doc(uid).get();
    final userData = userSnap.data() as Map<String, dynamic>;
    
    final userPrivateSnap = await _db.collection('users').doc(uid).collection('private').doc('data').get();
    final showTimestamp = userPrivateSnap.data()?['showTimestamp'] ?? true;

    final newPost = Post(
      id: '', // Firestore will generate
      userId: uid,
      imageUrl: imageUrl,
      taskName: taskName,
      caption: caption,
      createdAt: now,
      expiresAt: expiresAt,
      reactionCount: 0,
      showTimestamp: showTimestamp,
      emojiReactedUserIds: const [],
      userReactions: const {},
    );

    await _postsRef.add(newPost);

    // ワンタイムタスクの完了時間を記録
    final tasks = (userData['tasks'] as List? ?? [])
        .map((item) => AppTask.fromFirestore(item))
        .toList();
    
    bool taskUpdated = false;
    final updatedTasks = tasks.map((t) {
      if (t.title == taskName && t.isOneTime && t.completedAt == null) {
        taskUpdated = true;
        return t.copyWith(completedAt: now);
      }
      return t;
    }).toList();

    if (taskUpdated) {
      await _db.collection('users').doc(uid).update({
        'tasks': updatedTasks.map((t) => t.toFirestore()).toList(),
      });
    }

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

    yield* _postsRef
        .where(Post.fieldUserId, whereIn: limitedFriends)
        .where(Post.fieldExpiresAt, isGreaterThan: Timestamp.now())
        .snapshots()
        .map((snap) {
          final posts = snap.docs.map((doc) => doc.data()).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return posts;
        });
  }

  /// 投稿に絵文字リアクションをつけます（1人1回制限）
  ///
  /// Transaction の代わりに通常 update + FieldValue.arrayUnion を使用。
  /// オフライン時もローカルキャッシュに即時反映され、復帰後に自動同期される。
  /// 失敗時は例外を呼び出し元に伝播し、楽観的更新のロールバックを可能にする。
  Future<void> addEmojiReaction(String postId, String emoji) async {
    final myUid = _auth.currentUser!.uid;
    final docRef = _postsRef.doc(postId);

    // ドット記法でマップの自分のキーだけを更新し、他ユーザーの反応を上書きしない
    await docRef.update({
      '${Post.fieldUserReactions}.$myUid': emoji,
      Post.fieldEmojiReactedUserIds: FieldValue.arrayUnion([myUid]),
    });

    _analytics.logReactionSent();
    _updateController.add(null);
    _sendReactionNotification(postId, emoji: emoji).catchError((_) {});
  }

  /// 投稿の VFIRE (炎) カウントを増やします（連打対応の高速アトミック操作）
  Future<void> incrementFlameCount(String postId, int count) async {
    if (count <= 0) return;
    final docRef = _db.collection('posts').doc(postId);

    try {
      // トランザクション不使用：アトミックなインクリメントのみを行う
      await docRef.update({
        'reactionCount': FieldValue.increment(count),
      });

      _analytics.logReactionSent();
      _updateController.add(null);
      
      // 通知は1回にまとめて送信
      _sendReactionNotification(postId, flameIncrement: count).catchError((_) {});
    } catch (e) {
      debugPrint('Flame increment failed: $e');
    }
  }

  /// 指定した postId に対する addReaction は非推奨になりました。
  /// addEmojiReaction または incrementFlameCount を使用してください。
  @Deprecated('Use addEmojiReaction or incrementFlameCount instead')
  Future<void> addReaction(String postId, {String? emoji}) async {
    if (emoji != null) {
      return addEmojiReaction(postId, emoji);
    } else {
      return incrementFlameCount(postId, 1);
    }
  }

  /// リアクション通知を送信する内部メソッド
  Future<void> _sendReactionNotification(
    String postId, {
    String? emoji,
    int flameIncrement = 0,
  }) async {
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

    // 1. 基本的な通知内容
    String title;
    String body;
    bool sendPush = false;
    int reactionCount = 1;

    if (emoji != null) {
      // 絵文字リアクション：重複チェックしてカウントを増やす（プッシュあり）
      final existing = await _db
          .collection('notifications')
          .where('fromUid', isEqualTo: myUid)
          .where('relatedId', isEqualTo: postId)
          .where('type', isEqualTo: NotificationType.reactionReceived.name)
          .where('emoji', isEqualTo: emoji) // 同じ絵文字のみを対象
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        final doc = existing.docs.first;
        final data = doc.data();
        reactionCount = (data['reactionCount'] as int? ?? 0) + 1;
        await doc.reference.delete();
      }

      title = '✨ リアクション！';
      body = reactionCount > 1
          ? '$myUsernameさんが今日の達成に「$emoji」を$reactionCount回贈りました！'
          : '$myUsernameさんが今日の達成に「$emoji」を贈りました！';
      sendPush = true;
    } else {
      // V Fireリアクション：重複チェックしてカウントを増やす（プッシュあり）
      // flameIncrement 分を既存の通知に加算する
      final int addedCount = flameIncrement > 0 ? flameIncrement : 1;

      // 同じ投稿・同じ送信者のV Fireリアクションが既にあるかチェック
      final existing = await _db
          .collection('notifications')
          .where('fromUid', isEqualTo: myUid)
          .where('relatedId', isEqualTo: postId)
          .where('type', isEqualTo: NotificationType.reactionReceived.name)
          .where('emoji', isNull: true) // V Fireのみ
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        final doc = existing.docs.first;
        final data = doc.data();
        reactionCount = (data['reactionCount'] as int? ?? 0) + addedCount;
        await doc.reference.delete();
      } else {
        reactionCount = addedCount;
      }

      // ランダムな文言の選択
      final random = Random();
      final variations = [
        {
          'title': '🔥 熱狂！',
          'body': '$myUsernameさんがあなたの「$postTaskName」の達成に熱狂しています！',
        },
        {
          'title': '⚡️ V EFFECT 発動！',
          'body': 'あなたの「$postTaskName」が、$myUsernameさんのモチベーションに火をつけました！',
        },
        {
          'title': '🚀 リスペクト！',
          'body': '$myUsernameさんが「$postTaskName」を頑張るあなたに特大のパワーを送りました！',
        },
        {
          'title': '👏 スーパーヒーロー！',
          'body': '$myUsernameさんから「$postTaskName」へ、$reactionCount回の称賛が届いています！',
        },
      ];
      final selected = variations[random.nextInt(variations.length)];
      title = selected['title']!;
      body = selected['body']!;
      sendPush = true;
    }

    // 2. 通知ドキュメント作成
    await _db.collection('notifications').add({
      'toUid': postOwnerId,
      'fromUid': myUid,
      'relatedId': postId,
      'type': NotificationType.reactionReceived.name,
      'emoji': emoji, // どの絵文字か記録
      'reactionCount': reactionCount,
      'title': title,
      'body': body,
      'sendPush': sendPush, // プッシュ送出フラグ
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
        await _postsRef
            .where(Post.fieldUserId, isEqualTo: friendUid)
            .where(Post.fieldExpiresAt, isGreaterThan: Timestamp.now())
            .get();
    return snap.docs.map((doc) => doc.data()).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// 今週（直近7日間）の自分の投稿を取得します（WEEKLY REVIEW用）
  ///
  /// パフォーマンス最適化のため、Firestore サーバー側でフィルタリングを行います。
  /// ※このクエリの実行には userId と createdAt の複合インデックスが必要です。
  Future<List<Post>> getWeeklyReviewPosts() async {
    final uid = _auth.currentUser!.uid;
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    
    try {
      // 1. 最適化クエリ（要：複合インデックス）
      final snap = await _postsRef
          .where(Post.fieldUserId, isEqualTo: uid)
          .where(Post.fieldCreatedAt, isGreaterThan: Timestamp.fromDate(sevenDaysAgo))
          .get();

      return snap.docs
          .map((doc) => doc.data())
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } on FirebaseException catch (e) {
      // 2. フォールバック（インデックス不足時など）
      if (e.code == 'failed-precondition' || e.code == 'invalid-argument') {
        debugPrint('⚠️ WeeklyReview: Composite index missing or query failed. Falling back to local filtering. Error: ${e.message}');
        
        // userId だけで取得（単一インデックスのみで可能）し、メモリ上で日付フィルタリング
        final snap = await _postsRef
            .where(Post.fieldUserId, isEqualTo: uid)
            .get();
        
        return snap.docs
            .map((doc) => doc.data())
            .where((p) => p.createdAt.isAfter(sevenDaysAgo))
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      }
      rethrow;
    } catch (e) {
      debugPrint('WeeklyReview unexpected error: $e');
      rethrow;
    }
  }

  /// 自分のヒーロータスクリストを取得します
  Future<List<AppTask>> getMyTasks() async {
    final uid = _auth.currentUser!.uid;
    final snap = await _db.collection('users').doc(uid).get();
    return (snap.data()?['tasks'] as List? ?? [])
        .map((item) => AppTask.fromFirestore(item))
        .toList();
  }

  /// 自分のユーザー名を取得します
  Future<String> getMyUsername() async {
    final uid = _auth.currentUser!.uid;
    final snap = await _db.collection('users').doc(uid).get();
    return snap.data()?['username'] ?? '';
  }

  /// 全フレンド（および自分）の直近の投稿（24時間以内）をまとめて取得します
  Future<List<Post>> getAllFriendsPosts(List<String> friendUids, {bool includeMe = true}) async {
    final myUid = _auth.currentUser?.uid;
    final List<String> targetUids = List.from(friendUids);
    if (includeMe && myUid != null && !targetUids.contains(myUid)) {
      targetUids.add(myUid);
    }

    if (targetUids.isEmpty) return [];

    // Firestoreの `in` クエリは最大10件までの制限があるため、10件ごとに分割
    final List<Future<QuerySnapshot>> futures = [];
    for (var i = 0; i < targetUids.length; i += 10) {
      final chunk = targetUids.sublist(
        i,
        i + 10 > targetUids.length ? targetUids.length : i + 10,
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
      final userSnap = await _db.collection('users').doc(uid).get();
      final userData = userSnap.data()!;
      final currentStreak = (userData['streak'] as num?)?.toInt() ?? 0;
      final lastPostedDateStr = userData['lastPostedDate'] as String?;
      final todayStr = DateHelper.toDateString(now);

      if (lastPostedDateStr == todayStr) {
        // 今日すでに投稿完了フラグが立っている場合は、削除してもストリークを保護する。
        // 「その日に投稿した」という実績は維持し、lastPostedDate / streak を変更しない。
      } else if (allUserPosts.docs.length <= 1) {
        // これが最後の1件かつ今日の投稿でない場合（通常は発生しないが念のため）
        await _db.collection('users').doc(uid).update({
          'lastPostedDate': null,
          'streak': 0,
        });
      } else {
        // 今日以外の投稿を削除した場合：直近の投稿日に合わせて更新
        DateTime? lastDate;
        for (var doc in allUserPosts.docs) {
          if (doc.id == postId) continue;
          final d = doc.data();
          final createdAt = (d['createdAt'] as Timestamp).toDate();
          if (lastDate == null || createdAt.isAfter(lastDate)) {
            lastDate = createdAt;
          }
        }

        final lastDateStr = lastDate != null ? DateHelper.toDateString(lastDate) : null;
        final newStreak = (currentStreak > 0) ? currentStreak - 1 : 0;

        await _db.collection('users').doc(uid).update({
          'lastPostedDate': lastDateStr,
          'streak': newStreak,
        });
      }
    }

    // 4. (追加機能) 削除した投稿がワンタイムタスクのものであれば、再度挑戦できるようにステータスをリセットする
    if (remainingToday.isEmpty) {
      final userSnap = await _db.collection('users').doc(uid).get();
      if (userSnap.exists) {
        final userData = userSnap.data()!;
        final tasks = (userData['tasks'] as List? ?? [])
            .map((item) => AppTask.fromFirestore(item))
            .toList();
        
        final postData = postSnap.data()!;
        final deletedTaskName = postData['taskName'] as String?;
        
        bool taskReset = false;
        final updatedTasks = tasks.map((t) {
          if (t.title == deletedTaskName && t.isOneTime && t.completedAt != null) {
            taskReset = true;
            return t.copyWith(completedAt: null);
          }
          return t;
        }).toList();

        if (taskReset) {
          await _db.collection('users').doc(uid).update({
            'tasks': updatedTasks.map((t) => t.toFirestore()).toList(),
          });
          debugPrint('ワンタイムタスク "$deletedTaskName" の完了ステータスをリセットしました');
        }
      }
    }

    // 5. データの変更をアプリ全体に通知
    _updateController.add(null);
  }
}
