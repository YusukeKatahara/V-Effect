import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

/// 【rennさんへ】
/// このファイルは「サービス層」と呼ばれる、データの読み書き処理を専門に担当するファイルです。
/// 画面ファイル(screen_*.dart)から「投稿して」「データを取ってきて」と頼まれたら、
/// このファイルが実際にFirebaseと通信して結果を返します。
///
/// 【yusukeさんへ】
/// PostServiceクラスに主要なCRUD処理を集約しています。
/// Firestoreのデータ構造は以下の通りです：
///
///  posts/{postId}
///    - userId: string        投稿者のUID
///    - imageUrl: string      Firebase StorageのダウンロードURL
///    - taskName: string      今日のタスク名
///    - createdAt: Timestamp  投稿時刻（この時刻+24hで表示期限切れ）
///    - expiresAt: Timestamp  非表示になる時刻（createdAt + 24時間）
///    - reactionCount: number リアクション数
///
///  users/{uid}
///    - email: string
///    - displayName: string
///    - streak: number        現在の連続記録日数
///    - lastPostedDate: string "2026-03-05"形式の最終投稿日
///    - friends: string[]     フレンドのUIDリスト
class PostService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// ───────────────────────────
  /// 今日の投稿を写真ごとFirebaseにアップロードして保存します
  /// ───────────────────────────
  /// 【rennさんへ】
  /// imageFile: 撮影した写真ファイル
  /// taskName: 「ランニング」や「読書」などのタスク名
  Future<void> createPost({
    required File imageFile,
    required String taskName,
  }) async {
    final uid = _auth.currentUser!.uid;

    // ── Step1: Firebase Storage に画像を保存 ──
    // posts/{uid}/{現在の時刻ミリ秒}.jpg という名前で保存します
    final ref = _storage.ref().child(
      'posts/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await ref.putFile(imageFile);

    // 保存した画像の「ダウンロードURL」（インターネット上の住所）を取得します
    final imageUrl = await ref.getDownloadURL();

    // ── Step2: Firestoreに投稿データを保存 ──
    final now = DateTime.now();
    // expireAt = 今から24時間後。この時刻を過ぎた投稿は表示されません。
    final expiresAt = now.add(const Duration(hours: 24));

    await _db.collection('posts').add({
      'userId': uid,
      'imageUrl': imageUrl,
      'taskName': taskName,
      'createdAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'reactionCount': 0,
    });

    // ── Step3: ストリーク（連続記録）を更新 ──
    await _updateStreak(uid, now);
  }

  /// ───────────────────────────
  /// ストリーク（連続記録）を更新する内部処理
  /// ───────────────────────────
  /// 【yusukeさんへ】
  /// 昨日も投稿していればstreak+1、昨日投稿がなければ1にリセット、
  /// 今日いつも投稿している場合はそのまま（重複カウントしない）。
  Future<void> _updateStreak(String uid, DateTime now) async {
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final userRef = _db.collection('users').doc(uid);
    final userSnap = await userRef.get();

    if (!userSnap.exists) {
      // 初めての投稿のときにユーザー文書を作ります
      await userRef.set({
        'streak': 1,
        'lastPostedDate': today,
        'email': _auth.currentUser!.email,
        'friends': [],
      });
      return;
    }

    final data = userSnap.data()!;
    final lastPostedDate = data['lastPostedDate'] as String?;
    final currentStreak = (data['streak'] as num?)?.toInt() ?? 0;

    if (lastPostedDate == today) {
      // もう今日は投稿済みなので何もしません
      return;
    }

    // 昨日の日付を計算します
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayStr =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    final newStreak = (lastPostedDate == yesterdayStr) ? currentStreak + 1 : 1;

    await userRef.update({'streak': newStreak, 'lastPostedDate': today});
  }

  /// ───────────────────────────
  /// 自分が今日投稿済みかどうかをチェックします
  /// ───────────────────────────
  /// 【rennさんへ】
  /// BeRealのルール：自分が投稿していないとフレンドの投稿は見られません。
  /// この関数が「true」なら今日投稿済み、「false」なら未投稿です。
  Future<bool> hasPostedToday() async {
    final uid = _auth.currentUser!.uid;
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final userSnap = await _db.collection('users').doc(uid).get();
    if (!userSnap.exists) return false;

    return userSnap.data()?['lastPostedDate'] == today;
  }

  /// ───────────────────────────
  /// フレンドの24時間以内の投稿を取得します（Firestoreのリアルタイム更新）
  /// ───────────────────────────
  /// 【rennさんへ】
  /// Streamとは「水道の蛇口みたいなもの」で、データが変わるたびに自動で更新を流してくれます。
  /// これを使うと、誰かが投稿した瞬間に自分の画面にも表示されます！
  ///
  /// [guardedByPost]がtrueの時は、自分が今日投稿していないと空のStreamを返します。
  Stream<QuerySnapshot> getFriendsFeed({bool guardedByPost = true}) async* {
    if (guardedByPost) {
      final posted = await hasPostedToday();
      if (!posted) {
        // 投稿していないので空のデータを返して終了
        yield* const Stream.empty();
        return;
      }
    }

    final uid = _auth.currentUser!.uid;
    final userSnap = await _db.collection('users').doc(uid).get();

    // フレンドのUIDリストを取得します
    final friends = List<String>.from(userSnap.data()?['friends'] ?? []);

    if (friends.isEmpty) {
      // フレンドがいないと何も表示されません
      yield* const Stream.empty();
      return;
    }

    // 現在時刻より後に期限が来る投稿のみ取得。
    // つまり「まだ24時間が経っていない投稿」だけを取ります。
    final now = Timestamp.now();

    // FirestoreはIN句で最大30件まで、かつ OR 条件を直接使えないため
    // フレンドのリストを30件以下ずつに分けてクエリします（MVP段階では簡易版として10件制限）。
    final limitedFriends = friends.take(10).toList();

    yield* _db
        .collection('posts')
        .where('userId', whereIn: limitedFriends)
        .where('expiresAt', isGreaterThan: now)
        .orderBy('expiresAt', descending: true)
        .snapshots();
  }

  /// ───────────────────────────
  /// 投稿に🔥リアクションをつけます
  /// ───────────────────────────
  Future<void> addReaction(String postId) async {
    // FieldValue.increment(1) はFirestoreが安全にカウントを増やしてくれる方法です。
    // 複数の人が同時にリアクションしても数がおかしくなりません。
    await _db.collection('posts').doc(postId).update({
      'reactionCount': FieldValue.increment(1),
    });
  }

  /// ───────────────────────────
  /// 自分のストリーク数を取得します
  /// ───────────────────────────
  Future<int> getStreak() async {
    final uid = _auth.currentUser!.uid;
    final snap = await _db.collection('users').doc(uid).get();
    return (snap.data()?['streak'] as num?)?.toInt() ?? 0;
  }
}
