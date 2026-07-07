import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../models/dev_blog_post.dart';

class DevBlogService {
  DevBlogService._();
  static final DevBlogService instance = DevBlogService._();

  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _auth = FirebaseAuth.instance;

  CollectionReference<DevBlogPost> get _blogRef =>
      _db.collection('dev_blog').withConverter<DevBlogPost>(
        fromFirestore: (snapshot, _) => DevBlogPost.fromFirestore(snapshot),
        toFirestore: (post, _) => post.toMap(),
      );

  Future<bool> isDeveloper() async {
    final authUid = _auth.currentUser?.uid;
    if (authUid == null) return false;
    try {
      // Auth UID で開発者判定（userId は本人による書き換えが可能なため使用しない）
      final configDoc =
          await _db.collection('app_config').doc('developers').get();
      final ids =
          (configDoc.data()?['developerUids'] as List<dynamic>?)
              ?.cast<String>() ??
              [];
      return ids.contains(authUid);
    } catch (_) {
      return false;
    }
  }

  Stream<DevBlogPost?> getPost(String id) {
    return _blogRef.doc(id).snapshots().map((snap) => snap.data());
  }

  Stream<List<DevBlogPost>> getPosts() {
    return _blogRef
        .orderBy(DevBlogPost.fieldIsPinned, descending: true)
        .orderBy(DevBlogPost.fieldCreatedAt, descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  Future<void> createPost(DevBlogPost post) async {
    await _blogRef.doc(post.id).set(post);
  }

  Future<void> updatePost(DevBlogPost post) async {
    await _db.collection('dev_blog').doc(post.id).update(post.toMap());
  }

  Future<void> deletePost(String postId) async {
    try {
      await _storage.ref('dev_blog/$postId/cover.jpg').delete();
    } catch (_) {}
    await _blogRef.doc(postId).delete();
  }

  // Web では File が使えないため、XFile から bytes を読み putData でアップロードする
  Future<String> uploadCoverImage(String postId, XFile imageFile) async {
    final ref = _storage.ref('dev_blog/$postId/cover.jpg');
    await ref.putData(
      await imageFile.readAsBytes(),
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return await ref.getDownloadURL();
  }

  Future<String> uploadBadgeImage(XFile imageFile) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    // Web の path は blob URL で拡張子が取れないため name から判定する
    final name = imageFile.name.isNotEmpty ? imageFile.name : imageFile.path;
    const contentTypes = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
      'gif': 'image/gif',
    };
    var fileExt = name.contains('.') ? name.split('.').last.toLowerCase() : 'png';
    if (!contentTypes.containsKey(fileExt)) fileExt = 'png';
    final ref = _storage.ref('badges/badge_$timestamp.$fileExt');
    await ref.putData(
      await imageFile.readAsBytes(),
      SettableMetadata(contentType: contentTypes[fileExt]),
    );
    return await ref.getDownloadURL();
  }

  String generatePostId() {
    return _blogRef.doc().id;
  }
}
