import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../models/post.dart';
import '../models/app_notification.dart';
import '../utils/date_helper.dart';
import 'analytics_service.dart';
import 'streak_service.dart';
import 'push_notification_service.dart';
import '../models/app_task.dart';
import '../models/season.dart';
import '../models/app_user.dart';
import 'widget_service.dart';

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
  final AnalyticsService _analytics = AnalyticsService.instance;

  CollectionReference<Post> get _postsRef =>
      _db.collection('posts').withConverter<Post>(
            fromFirestore: (snapshot, _) => Post.fromFirestore(snapshot),
            toFirestore: (post, _) => post.toFirestore(),
          );

  /// アプリ全体にデータ更新（投稿作成・削除）を通知するためのストリーム
  final _updateController = StreamController<void>.broadcast();
  Stream<void> get updateStream => _updateController.stream;

  /// 外部から手動で更新シグナルを送るためのメソッド（深夜0時の日付更新など）
  void notifyUpdate() {
    _updateController.add(null);
  }

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

    // 🚀 【動的マージ対応】ユーザー情報、今日の投稿、そして現在進行中のシーズンタスクを並列（同時）で取得して高速化
    final results = await Future.wait([
      _db.collection('users').doc(uid).get(),
      _postsRef
          .where(Post.fieldUserId, isEqualTo: uid)
          .where('expiresAt', isGreaterThan: now)
          .get(),
      _db.collection('seasons')
          .where('startDate', isLessThanOrEqualTo: now)
          .get(),
    ]);

    final snap = results[0] as DocumentSnapshot;
    final postsSnap = results[1] as QuerySnapshot<Post>;
    final seasonsSnap = results[2] as QuerySnapshot;

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
    final isRecommended = data['isRecommended'] == true;
    
    // Firestore（ファイアストア：データベース）からユーザー自身のタスクをロード
    final userTasks = (data['tasks'] as List? ?? [])
        .map((item) => AppTask.fromFirestore(item))
        .toList();

    // 処理済み（削除・完了など）にマークしたシーズンIDを取得
    final processedIds = (data[AppUser.fieldProcessedSeasonTaskIds] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    // 開催期間内のシーズンタスクをメモリ上で抽出（endDateがない、または現在時刻より後、かつ処理済みでないもの）
    final activeSeasons = seasonsSnap.docs
        .map((doc) => Season.fromFirestore(doc))
        .where((s) => now.isBefore(s.endDate) && !processedIds.contains(s.id))
        .toList();

    // シーズンタスクを AppTask オブジェクトに変換
    final seasonTasks = activeSeasons.map((s) => AppTask(
      title: s.taskName,
      isOneTime: false,
      isSeason: true,
      seasonId: s.id,
    )).toList();

    // 🚀 シーズンタスクをタスク一覧の最上部（最初）に自動でマージ（合体）
    // ユーザー自身が設定したトリガー（きっかけ）やご褒美のカスタム情報を維持するため、
    // 既存のタスクリスト内に同名のシーズンタスクがあれば、その設定（トリガーなど）を優先してマージします。
    final mergedTasks = <AppTask>[];
    for (final sTask in seasonTasks) {
      final existing = userTasks.firstWhere(
        (uTask) => uTask.title == sTask.title && uTask.isSeason,
        orElse: () => sTask,
      );
      mergedTasks.add(existing);
    }
    // 重複を防ぐため、ユーザー固有のタスクからはシーズンタスクを除外して追加します。
    final normalTasks = userTasks.where((t) => !t.isSeason).toList();
    mergedTasks.addAll(normalTasks);


    // 今日の分だけをフィルタリング
    final postedPostsToday =
        postsSnap.docs
            .map((doc) => doc.data())
            .where((post) {
               return post.createdAt.isAfter(startOfToday) ||
                   post.createdAt.isAtSameMomentAs(startOfToday);
            })
            .toList();

    final effectiveStreakData = StreakService.calculateEffectiveStreak(
      streak: (data['streak'] as num?)?.toInt() ?? 0,
      protections: (data['streakProtections'] as num?)?.toInt() ?? 0,
      lastPostedDate: lastPostedDate,
    );

    return {
      'streak': effectiveStreakData['streak'],
      'streakProtections': effectiveStreakData['streakProtections'],
      'postedToday': postedPostsToday.isNotEmpty,
      'isAllTasksCompleted':
          mergedTasks.isNotEmpty &&
          mergedTasks.every((t) => postedPostsToday.any((p) => p.taskName == t.title)),
      'username': data['username'] as String? ?? '',
      'tasks': mergedTasks, // マージされたタスク一覧を返す
      'friends': (() {
        final dynamic f = data['following'] ?? data['friends'];
        if (f is List) return f.map((e) => e.toString()).toList();
        if (f is Map) return f.keys.map((k) => k.toString()).toList();
        return <String>[];
      })(),
      'lastPostedDate': lastPostedDate,
      'postedTasksToday': postedPostsToday,
      'isRecommended': isRecommended,
    };
  }

  /// 指定したユーザーの全てのシーズンタスクについて、現在の進捗（投稿数）を計算します。
  /// [ProfileScreen] や [HeroTasksScreen] でプログレスバー等を表示するために利用します。
  Future<Map<String, dynamic>> getSeasonProgressMap(String uid, List<AppTask> seasonTasks) async {
    final Map<String, dynamic> result = {
      'seasonsMap': <String, Season>{},
      'seasonPostsCountMap': <String, int>{},
    };

    if (seasonTasks.isEmpty) return result;

    final seasonIds = seasonTasks.where((t) => t.seasonId != null).map((t) => t.seasonId!).toSet().toList();
    if (!seasonIds.contains('debug_season')) seasonIds.add('debug_season');
    if (!seasonIds.contains('debug_season_test')) seasonIds.add('debug_season_test');

    final seasonsSnap = await _db.collection('seasons').where(FieldPath.documentId, whereIn: seasonIds).get();
    final newSeasonsMap = <String, Season>{};
    for (var doc in seasonsSnap.docs) {
      newSeasonsMap[doc.id] = Season.fromFirestore(doc);
    }

    QuerySnapshot? allPostsSnap;
    try {
      allPostsSnap = await _db.collection('posts').where('userId', isEqualTo: uid).get();
    } catch (e) {
      debugPrint('Error fetching posts for season count: $e');
    }

    final newSeasonPostsCountMap = <String, int>{};

    for (var task in seasonTasks) {
      final sId = task.seasonId ?? 'debug_season_test';
      final season = newSeasonsMap[sId] ?? Season.createFallback(task.title, seasonId: sId);
      newSeasonsMap[sId] = season;

      if (allPostsSnap != null) {
        int count = 0;
        final Map<String, int> dailyPostCounts = {};
        final targetName = season.taskName.replaceAll(RegExp(r'\s+'), '');

        for (var postDoc in allPostsSnap.docs) {
          final postData = postDoc.data() as Map<String, dynamic>;
          final postTaskName = (postData['taskName'] as String? ?? '').replaceAll(RegExp(r'\s+'), '');
          
          final isMatch = postTaskName.contains(targetName) || 
                          targetName.contains(postTaskName) || 
                          (postTaskName.contains('感謝を伝える') && targetName.contains('感謝を伝える'));
          
          if (!isMatch) continue;

          final createdAt = (postData['createdAt'] as Timestamp?)?.toDate();
          if (createdAt != null &&
              createdAt.isAfter(season.startDate) &&
              createdAt.isBefore(season.endDate)) {
            final dateKey = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
            final currentDailyCount = dailyPostCounts[dateKey] ?? 0;
            if (currentDailyCount < 1) {
              count++;
              dailyPostCounts[dateKey] = currentDailyCount + 1;
            }
          }
        }
        newSeasonPostsCountMap[sId] = count;
      }
    }

    result['seasonsMap'] = newSeasonsMap;
    result['seasonPostsCountMap'] = newSeasonPostsCountMap;
    return result;
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
      final effective = StreakService.calculateEffectiveStreak(
        streak: (data['streak'] as num?)?.toInt() ?? 0,
        protections: (data['streakProtections'] as num?)?.toInt() ?? 0,
        lastPostedDate: data['lastPostedDate']?.toString(),
      );
      return {
        'uid': doc.id,
        'username': data['username']?.toString() ?? '',
        'userId': data['userId']?.toString() ?? '',
        'photoUrl': data['photoUrl'] is String ? data['photoUrl'] as String : data['photoUrl']?.toString(),
        'hasPostedToday': data['lastPostedDate']?.toString() == today,
        'streak': effective['streak'],
        'equippedBadgeUrl': data['equippedBadgeUrl']?.toString(),
        'equippedBadgeAnimation': data['equippedBadgeAnimation']?.toString(),
      };
    }).toList();
  }

  /// 写真付き投稿をFirebaseにアップロードして保存します
  /// 戻り値: {'newStreak': int, 'isRecordUpdating': bool}
  Future<Map<String, dynamic>> createPost({
    required Uint8List imageBytes,
    required String taskName,
    String? caption,
    String? bgmUrl,
    String? bgmTitle,
    String? bgmArtist,
    String? bgmArtworkUrl,
    bool isPublic = false,
  }) async {
    final uid = _auth.currentUser!.uid;

    // 複数回投稿を許容するため、タイムスタンプを付与
    final dateStr = DateHelper.toDateString(DateTime.now());
    final taskHash = taskName.hashCode.abs();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final postId = 'post_${uid}_${dateStr}_${taskHash}_$timestamp';

    // Step1: Firebase Storage に画像アップロードを開始
    final ref = _storage.ref().child('posts/$uid/$postId.jpg');
    final uploadTask = ref.putData(imageBytes, SettableMetadata(contentType: 'image/jpeg'));

    // 🚀 サムネイル用画像の生成とアップロード (超軽量プレースホルダー)
    // Web など圧縮が利用できない環境では元画像をそのまま使う（投稿自体は成功させる）
    Uint8List thumbBytes;
    try {
      thumbBytes = await FlutterImageCompress.compressWithList(
        imageBytes,
        minWidth: 150,
        minHeight: 266,
        quality: 30,
        format: CompressFormat.jpeg,
      );
      if (thumbBytes.isEmpty) thumbBytes = imageBytes;
    } catch (e) {
      debugPrint('サムネイル圧縮エラー（未対応環境では元画像を使用）: $e');
      thumbBytes = imageBytes;
    }
    final thumbRef = _storage.ref().child('posts/$uid/post_thumb_$postId.jpg');
    final thumbUploadTask = thumbRef.putData(thumbBytes, SettableMetadata(contentType: 'image/jpeg'));

    // 🚀 【爆速化 1】Storageのアップロードと並列で、Firestoreからユーザー情報を事前フェッチ
    final fetchDataFuture = _db.collection('users').doc(uid).get();

    // 両方の完了を同時に待つことで、シーケンシャルな待ち時間を劇的に削減
    final results = await Future.wait<dynamic>([
      uploadTask,
      thumbUploadTask,
      fetchDataFuture,
    ]);

    final userSnap = results[2] as DocumentSnapshot;

    final imageUrl = await ref.getDownloadURL();
    final thumbnailUrl = await thumbRef.getDownloadURL();

    // 🚀 ローカルキャッシュに先回りして保存 (Optimistic Cache Seeding)
    try {
      await DefaultCacheManager().putFile(
        imageUrl,
        imageBytes,
        fileExtension: 'jpg',
      );
      await DefaultCacheManager().putFile(
        thumbnailUrl,
        thumbBytes,
        fileExtension: 'jpg',
      );
    } catch (e) {
      debugPrint('CACHE SEEDING ERROR: $e');
    }

    // Step2: Firestoreに投稿データを保存する準備
    final now = DateTime.now();
    final expiresAt = DateTime(now.year, now.month, now.day + 1); // 翌日0:00

    final userData = userSnap.data() as Map<String, dynamic>? ?? {};

    // ユーザーのタスクリストを解析して、一致するタスクIDを特定する
    final tasks = (userData['tasks'] as List? ?? [])
        .map((item) => AppTask.fromFirestore(item))
        .toList();

    String? matchedTaskId;
    bool isSecretTask = false;
    for (final t in tasks) {
      if (t.title == taskName) {
        matchedTaskId = t.id;
        isSecretTask = t.isSecret;
        break;
      }
    }

    final newPost = Post(
      id: postId,
      userId: uid,
      taskId: matchedTaskId,
      imageUrl: imageUrl,
      thumbnailUrl: thumbnailUrl,
      taskName: taskName,
      caption: caption,
      createdAt: now,
      expiresAt: expiresAt,
      reactionCount: 0,
      emojiReactedUserIds: const [],
      userReactions: const {},
      bgmUrl: bgmUrl,
      bgmTitle: bgmTitle,
      bgmArtist: bgmArtist,
      bgmArtworkUrl: bgmArtworkUrl,
      isSecret: isSecretTask,
      isPublic: isPublic,
    );
    
    bool taskUpdated = false;
    final updatedTasks = tasks.map((t) {
      if (t.title == taskName && t.isOneTime && t.completedAt == null) {
        taskUpdated = true;
        return t.copyWith(completedAt: now);
      }
      return t;
    }).toList();

    // 🚀 【爆速化 2】ストリーク計算をメモリ上で行い、書き込み用更新データを取得
    final streakResultData = _streakService.calculateStreakUpdates(
      userData: userData,
      now: now,
      uid: uid,
    );
    final streakUpdates = streakResultData['updates'] as Map<String, dynamic>;
    final streakResult = streakResultData['result'] as Map<String, dynamic>;

    // 🚀 【爆速化 3】タスク更新とストリーク更新のクエリを1つのドキュメント更新にマージ
    final combinedUserUpdates = Map<String, dynamic>.from(streakUpdates);
    combinedUserUpdates['totalPosts'] = FieldValue.increment(1);
    if (taskUpdated) {
      combinedUserUpdates['tasks'] = updatedTasks.map((t) => t.toFirestore()).toList();
    }

    // 🚀 【新規追加】シーズンタスクの判定とバッジ付与ロジック
    final List<Future> writeFutures = [
      _postsRef.doc(postId).set(newPost),
    ];

    try {
      final seasonsSnap = await _db
          .collection('seasons')
          .where('taskName', isEqualTo: taskName)
          .where('startDate', isLessThanOrEqualTo: now)
          .get();

      for (var doc in seasonsSnap.docs) {
        final seasonData = doc.data();
        final endDate = (seasonData['endDate'] as Timestamp?)?.toDate();
        if (endDate != null && now.isBefore(endDate)) {
          // 過去の投稿をカウント（日付ベースでユニーク）
          final postsSnap = await _db
              .collection('posts')
              .where('userId', isEqualTo: uid)
              .where('taskName', isEqualTo: taskName)
              .get();
              
          int count = 0;
          final Map<String, int> dailyPostCounts = {};
          final startDate = (seasonData['startDate'] as Timestamp).toDate();
          
          for (var postDoc in postsSnap.docs) {
            final postCreatedAt = (postDoc.data()['createdAt'] as Timestamp?)?.toDate();
            if (postCreatedAt != null &&
                postCreatedAt.isAfter(startDate) &&
                postCreatedAt.isBefore(endDate)) {
              final dateKey = '${postCreatedAt.year}-${postCreatedAt.month.toString().padLeft(2, '0')}-${postCreatedAt.day.toString().padLeft(2, '0')}';
              final currentDailyCount = dailyPostCounts[dateKey] ?? 0;
              if (currentDailyCount < 1) {
                count++;
                dailyPostCounts[dateKey] = currentDailyCount + 1;
              }
            }
          }
          
          // 今回の投稿分を追加（今日まだカウントされていなければ）
          final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          if ((dailyPostCounts[todayKey] ?? 0) < 1) {
            count++;
          }
          
          final requiredCount = (seasonData['requiredPostsCount'] as num?)?.toInt() ?? 12;
          final badgeUrl = seasonData['badgeImageUrl']?.toString();
          
          if (count >= requiredCount && badgeUrl != null && badgeUrl.isNotEmpty) {
            final ownedBadges = List<String>.from(userData['ownedBadges'] ?? []);
            if (!ownedBadges.contains(badgeUrl)) {
              // バッジ付与と自動装備
              combinedUserUpdates['ownedBadges'] = FieldValue.arrayUnion([badgeUrl]);
              combinedUserUpdates['equippedBadgeUrl'] = badgeUrl;
              combinedUserUpdates['equippedBadgeAnimation'] = seasonData['badgeAnimation'] ?? 'none';
              
              // アプリ内通知の作成
              final notificationId = 'badge_${uid}_${doc.id}';
              final badgeNotification = AppNotification(
                id: notificationId,
                toUid: uid,
                type: NotificationType.badgeAcquired,
                title: '🎉 バッジ獲得！',
                body: 'シーズンタスク「$taskName」を達成し、新しいバッジを獲得しました！プロフィールで確認できます。',
                createdAt: now,
                sendPush: false,
                isRead: false,
                relatedId: doc.id,
              );
              writeFutures.add(
                _db.collection('users').doc(uid).collection('notifications').doc(notificationId).set(badgeNotification.toFirestore())
              );
            }
          }
          break; // 最初に見つかった有効なシーズンタスクで処理完了
        }
      }
    } catch (e) {
      debugPrint('Error processing season task badge: $e');
    }

    // 🚀 【爆速化 4】「投稿の保存（新規ドキュメント）」と「ユーザー情報の更新（既存ドキュメント）」を並列実行
    if (combinedUserUpdates.isNotEmpty) {
      writeFutures.add(_db.collection('users').doc(uid).update(combinedUserUpdates));
    }

    await Future.wait(writeFutures);

    // Step4: Analytics イベント送信
    _analytics.logPostCreated(taskName: taskName);
    _analytics.setPostingTimeSlot(now.hour);
    final newStreak = streakResult['newStreak'] as int;
    final isRecord = streakResult['isRecordUpdating'] as bool;
    _analytics.logStreakUpdate(streak: newStreak, isRecord: isRecord);
    _analytics.setStreakTier(newStreak);
    if (const [7, 30, 100, 365].contains(newStreak)) {
      _analytics.logStreakMilestone(streak: newStreak);
    }

    // 保護スケジュールを再計算
    PushNotificationService().restoreProtectionAlertSchedule().catchError((_) {});

    // データの変更をアプリ全体に通知
    _updateController.add(null);

    // ウィジェットのデータを更新（データ自体は WidgetService 内部で取得）
    WidgetService.instance.updateWidgetData();

    return streakResult;
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
  Future<void> addEmojiReaction(
    String postId,
    String emoji, {
    String targetUid = '',
    String targetTaskName = '',
    bool triggerUpdateStream = false, // 2026ベストプラクティス：自分自身の送信時は無駄な再フェッチを避けるためデフォルトfalse
  }) async {
    final myUid = _auth.currentUser!.uid;
    final docRef = _postsRef.doc(postId);

    // ドット記法でマップの自分のキーだけを更新し、他ユーザーの反応を上書きしない
    await docRef.update({
      '${Post.fieldUserReactions}.$myUid': emoji,
      Post.fieldEmojiReactedUserIds: FieldValue.arrayUnion([myUid]),
    });

    _analytics.logReactionSent(
      targetUid: targetUid,
      targetTaskName: targetTaskName,
      reactionType: 'emoji',
      emoji: emoji,
    );
    if (triggerUpdateStream) {
      _updateController.add(null);
    }
    _sendReactionNotification(postId, emoji: emoji).catchError((_) {});
  }

  /// 投稿の VFIRE (炎) カウントを増やします（連打対応の高速アトミック操作）
  Future<void> incrementFlameCount(
    String postId,
    int count, {
    String targetUid = '',
    String targetTaskName = '',
    bool triggerUpdateStream = false, // 2026ベストプラクティス：自分自身の送信時は無駄な再フェッチを避けるためデフォルトfalse
  }) async {
    if (count <= 0) return;
    final docRef = _db.collection('posts').doc(postId);

    try {
      // トランザクション不使用：アトミックなインクリメントのみを行う
      await docRef.update({
        'reactionCount': FieldValue.increment(count),
      });

      _analytics.logReactionSent(
        targetUid: targetUid,
        targetTaskName: targetTaskName,
        reactionType: 'flame',
        flameCount: count,
      );
      if (triggerUpdateStream) {
        _updateController.add(null);
      }
      
      // 通知は1回にまとめて送信
      _sendReactionNotification(postId, flameIncrement: count).catchError((_) {});
    } catch (e) {
      debugPrint('Flame increment failed: $e');
      rethrow; // 楽観的UI更新（画面側の仮表示）をロールバックできるよう呼び出し元へ例外を伝播
    }
  }

  /// 指定した postId に対する addReaction は非推奨になりました。
  /// addEmojiReaction または incrementFlameCount を使用してください。
  @Deprecated('Use addEmojiReaction or incrementFlameCount instead')
  Future<void> addReaction(String postId, {String? emoji}) async {
    if (emoji != null) {
      return addEmojiReaction(postId, emoji, triggerUpdateStream: true);
    } else {
      return incrementFlameCount(postId, 1, triggerUpdateStream: true);
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

    // 相手の通知設定を確認
    final receiverSnap = await _db.collection('users').doc(postOwnerId).get();
    final receiverData = receiverSnap.data() ?? {};
    final allowReaction = receiverData['reactionNotifications'] ?? true;
    final allowVFire = receiverData['vFireNotifications'] ?? true;

    // 通知ドキュメントのIDを固定化し、トランザクションでアトミックに更新する
    final isEmoji = emoji != null;
    final notifId = isEmoji 
        ? 'reaction_emoji_${postId}_$myUid' 
        : 'reaction_vfire_${postId}_$myUid';
    final notifRef = _db.collection('notifications').doc(notifId);

    try {
      await _db.runTransaction((transaction) async {
        final docSnap = await transaction.get(notifRef);
        final data = docSnap.exists ? docSnap.data()! : {};
        
        int reactionCount = 1;
        if (docSnap.exists) {
          // 既存のドキュメントがあればカウントを合算
          final existingCount = data['reactionCount'] as int? ?? 0;
          reactionCount = existingCount + (isEmoji ? 1 : (flameIncrement > 0 ? flameIncrement : 1));
        } else {
          reactionCount = isEmoji ? 1 : (flameIncrement > 0 ? flameIncrement : 1);
        }

        if (isEmoji) {
          title = '✨ リアクション！';
          body = reactionCount > 1
              ? '$myUsernameさんが今日の達成に「$emoji」を$reactionCount回贈りました！'
              : '$myUsernameさんが今日の達成に「$emoji」を贈りました！';
          sendPush = allowReaction;
        } else {
          final random = Random();
          final variations = [
            {
              'title': '👹 やばい！',
              'body': '「$postTaskName」によってあなたは$myUsernameさんを焚き付けてしまいました！$reactionCount回のV FIRE❗️',
            },
            {
              'title': '⚡️ V EFFECT 発動！',
              'body': 'あなたの「$postTaskName」が、$myUsernameさんのモチベーションに火をつけました！',
            },
            {
              'title': '👏 スーパーヒーロー！',
              'body': '$myUsernameさんから「$postTaskName」へ、$reactionCount回の称賛が届いています！',
            },
          ];
          final selected = variations[random.nextInt(variations.length)];
          title = selected['title']!;
          body = selected['body']!;
          sendPush = allowVFire;
        }

        final notifData = {
          'toUid': postOwnerId,
          'fromUid': myUid,
          'relatedId': postId,
          'type': NotificationType.reactionReceived.name,
          'emoji': emoji, // どの絵文字か記録
          'reactionCount': reactionCount,
          'title': title,
          'body': body,
          'sendPush': sendPush, // プッシュ送出フラグ
          // isRead は既存が未読なら未読のまま、既読なら未読に戻す
          'isRead': false, 
          // timestamp は常に最新に更新（一覧で一番上にくるように）
          'createdAt': FieldValue.serverTimestamp(),
        };

        transaction.set(notifRef, notifData);
      });
    } catch (e) {
      debugPrint('Reaction notification failed: $e');
    }
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

  /// 今週（月曜〜日曜）の自分の投稿を取得します（WEEKLY REVIEW用）
  ///
  /// パフォーマンス最適化のため、Firestore サーバー側でフィルタリングを行います。
  /// ※このクエリの実行には userId と createdAt の複合インデックスが必要です。
  Future<List<Post>> getWeeklyReviewPosts() async {
    final uid = _auth.currentUser!.uid;
    final now = DateTime.now();
    // 月曜日の0:00を計算 (weekday: 1=Monday, 7=Sunday)
    final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    
    try {
      // 1. 最適化クエリ（要：複合インデックス）
      final snap = await _postsRef
          .where(Post.fieldUserId, isEqualTo: uid)
          .where(Post.fieldCreatedAt, isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
          .get();

      return snap.docs
          .map((doc) => doc.data())
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } on FirebaseException catch (e) {
      // 2. フォールバック（インデックス不足時など）
      if (e.code == 'failed-precondition' || e.code == 'invalid-argument') {
        debugPrint('⚠️ WeeklyReview: Composite index missing or query failed. Falling back to local filtering. Error: ${e.message}');

        // Vuln-2 対応のセキュリティルールに合わせ、14日以内に限定して取得する
        final fourteenDaysAgo =
            DateTime.now().subtract(const Duration(days: 14));
        final snap = await _postsRef
            .where(Post.fieldUserId, isEqualTo: uid)
            .where(Post.fieldCreatedAt,
                isGreaterThan: Timestamp.fromDate(fourteenDaysAgo))
            .get();

        return snap.docs
            .map((doc) => doc.data())
            .where((p) => p.createdAt.isAfter(startOfWeek) || p.createdAt.isAtSameMomentAs(startOfWeek))
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      }
      rethrow;
    } catch (e) {
      debugPrint('WeeklyReview unexpected error: $e');
      rethrow;
    }
  }

  /// 自分の過去のすべての投稿を取得します（過去の自分と比較する機能用）
  Future<List<Post>> getAllMyPastPosts({Source? source}) async {
    final uid = _auth.currentUser!.uid;
    
    try {
      final snap = await _postsRef
          .where(Post.fieldUserId, isEqualTo: uid)
          .get(source != null ? GetOptions(source: source) : null);

      return snap.docs
          .map((doc) => doc.data())
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // 新しい順
    } catch (e) {
      debugPrint('getAllMyPastPosts unexpected error: $e');
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

  /// 投稿の公開ステータス（isPublic）を更新します
  Future<void> updatePostPublicStatus(String postId, bool isPublic) async {
    try {
      await _db.collection('posts').doc(postId).update({
        'isPublic': isPublic,
      });
      _updateController.add(null);
    } catch (e) {
      debugPrint('updatePostPublicStatus error: $e');
      rethrow;
    }
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
    await _db.collection('users').doc(uid).update({
      'totalPosts': FieldValue.increment(-1),
    });

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

    // 3. 今日他に投稿があるか確認（Vuln-2 対応のセキュリティルールに合わせ
    //    14日以内に限定して取得。さらに今日の分をローカルでフィルタ）
    final fourteenDaysAgo =
        DateTime.now().subtract(const Duration(days: 14));
    final allUserPosts = await _db
        .collection('posts')
        .where('userId', isEqualTo: uid)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(fourteenDaysAgo))
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

    // 保護スケジュールを再計算
    PushNotificationService().restoreProtectionAlertSchedule().catchError((_) {});
  }

  /// タスク名が変更された際に、該当ユーザーの既存の投稿のタスク名も一括更新します
  /// Vuln-2 対応のセキュリティルールに合わせ、14日以内の投稿に限定して更新する
  Future<void> updateTaskNameForPosts(String oldTaskName, String newTaskName) async {
    final uid = _auth.currentUser!.uid;
    final fourteenDaysAgo =
        DateTime.now().subtract(const Duration(days: 14));
    final postsSnap = await _db.collection('posts')
        .where('userId', isEqualTo: uid)
        .where('taskName', isEqualTo: oldTaskName)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(fourteenDaysAgo))
        .get();
        
    if (postsSnap.docs.isEmpty) return;
    
    final batch = _db.batch();
    for (final doc in postsSnap.docs) {
      batch.update(doc.reference, {'taskName': newTaskName});
    }
    await batch.commit();
    _updateController.add(null);
  }

  /// 全体公開（Vタイムライン）用の投稿一覧をリアルタイム購読（Stream）します
  Stream<List<Post>> getPublicPostsStream() {
    return _postsRef
        .where('isPublic', isEqualTo: true)
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .snapshots()
        .map((snap) {
          final posts = snap.docs.map((doc) => doc.data()).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return posts;
        });
  }
}
