import 'package:cloud_firestore/cloud_firestore.dart';

enum BlogCategory {
  progress,
  concept,
  howto,
  thanks;

  String get label {
    switch (this) {
      case BlogCategory.progress:
        return '開発進捗';
      case BlogCategory.concept:
        return '新構想';
      case BlogCategory.howto:
        return '使い方';
      case BlogCategory.thanks:
        return '感謝';
    }
  }
}

class DevBlogPost {
  const DevBlogPost({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.authorId,
    required this.authorName,
    this.coverImageUrl,
    required this.isPinned,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String body;
  final BlogCategory category;
  final String authorId;
  final String authorName;
  final String? coverImageUrl;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  static DevBlogPost fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DevBlogPost(
      id: doc.id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      category: BlogCategory.values.firstWhere(
        (e) => e.name == (data['category'] as String?),
        orElse: () => BlogCategory.progress,
      ),
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? 'Developer',
      coverImageUrl: data['coverImageUrl'] as String?,
      isPinned: (data['isPinned'] as bool?) ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'body': body,
        'category': category.name,
        'authorId': authorId,
        'authorName': authorName,
        'coverImageUrl': coverImageUrl,
        'isPinned': isPinned,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  DevBlogPost copyWith({
    String? title,
    String? body,
    BlogCategory? category,
    String? coverImageUrl,
    bool? isPinned,
    DateTime? updatedAt,
  }) {
    return DevBlogPost(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      authorId: authorId,
      authorName: authorName,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
