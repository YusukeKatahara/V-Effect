import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/dev_blog_post.dart';

class DevBlogService {
  DevBlogService._();
  static final DevBlogService instance = DevBlogService._();

  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _auth = FirebaseAuth.instance;

  CollectionReference get _blogRef => _db.collection('dev_blog');

  Future<bool> isDeveloper() async {
    final authUid = _auth.currentUser?.uid;
    if (authUid == null) return false;
    try {
      // アプリ内 userId（"RN", "Y" 等）で開発者判定
      final userDoc = await _db.collection('users').doc(authUid).get();
      final userId = userDoc.data()?['userId'] as String?;
      if (userId == null) return false;

      final configDoc =
          await _db.collection('app_config').doc('developers').get();
      final ids =
          (configDoc.data()?['developerUids'] as List<dynamic>?)
              ?.cast<String>() ??
              [];
      return ids.contains(userId);
    } catch (_) {
      return false;
    }
  }

  Stream<DevBlogPost?> getPost(String id) {
    return _blogRef.doc(id).snapshots().map((snap) {
      if (!snap.exists) return null;
      return DevBlogPost.fromFirestore(snap);
    });
  }

  Stream<List<DevBlogPost>> getPosts() {
    return _blogRef
        .orderBy('isPinned', descending: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => DevBlogPost.fromFirestore(d)).toList());
  }

  Future<void> createPost(DevBlogPost post) async {
    await _blogRef.doc(post.id).set(post.toMap());
  }

  Future<void> updatePost(DevBlogPost post) async {
    await _blogRef.doc(post.id).update(post.toMap());
  }

  Future<void> deletePost(String postId) async {
    try {
      await _storage.ref('dev_blog/$postId/cover.jpg').delete();
    } catch (_) {}
    await _blogRef.doc(postId).delete();
  }

  Future<String> uploadCoverImage(String postId, File imageFile) async {
    final ref = _storage.ref('dev_blog/$postId/cover.jpg');
    await ref.putFile(imageFile);
    return await ref.getDownloadURL();
  }

  String generatePostId() {
    return _blogRef.doc().id;
  }
}
