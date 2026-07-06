import 'package:flutter/widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum BlogCategory {
  progress,
  concept,
  howto,
  thanks,
  seasonTask;

  String label(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final isJa = locale == 'ja';
    switch (this) {
      case BlogCategory.progress:
        return isJa ? '開発進捗' : 'Dev Progress';
      case BlogCategory.concept:
        return isJa ? '新構想' : 'Concept';
      case BlogCategory.howto:
        return isJa ? 'ヒント' : 'Tips';
      case BlogCategory.thanks:
        return isJa ? '感謝' : 'Thanks';
      case BlogCategory.seasonTask:
        return isJa ? 'シーズンタスク' : 'Season Task';
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
    this.titleEn,
    this.bodyEn,
    this.isDraft = false,
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
  final String? titleEn;
  final String? bodyEn;
  final bool isDraft;

  // ── フィールド名定数 ──
  static const String fieldTitle = 'title';
  static const String fieldBody = 'body';
  static const String fieldCategory = 'category';
  static const String fieldAuthorId = 'authorId';
  static const String fieldAuthorName = 'authorName';
  static const String fieldCoverImageUrl = 'coverImageUrl';
  static const String fieldIsPinned = 'isPinned';
  static const String fieldCreatedAt = 'createdAt';
  static const String fieldUpdatedAt = 'updatedAt';
  static const String fieldTitleEn = 'titleEn';
  static const String fieldBodyEn = 'bodyEn';
  static const String fieldIsDraft = 'isDraft';

  static DevBlogPost fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return DevBlogPost.fromMap(doc.id, data ?? {});
  }

  static DevBlogPost fromMap(String id, Map<String, dynamic> data) {
    try {
      return DevBlogPost(
        id: id,
        title: data[fieldTitle]?.toString() ?? '',
        body: data[fieldBody]?.toString() ?? '',
        category: BlogCategory.values.firstWhere(
          (e) => e.name == data[fieldCategory]?.toString(),
          orElse: () => BlogCategory.progress,
        ),
        authorId: data[fieldAuthorId]?.toString() ?? '',
        authorName: data[fieldAuthorName]?.toString() ?? 'Developer',
        coverImageUrl: data[fieldCoverImageUrl]?.toString(),
        isPinned: data[fieldIsPinned] == true,
        createdAt: (data[fieldCreatedAt] as Timestamp?)?.toDate() ?? DateTime.now(),
        updatedAt: (data[fieldUpdatedAt] as Timestamp?)?.toDate() ?? DateTime.now(),
        titleEn: data[fieldTitleEn]?.toString(),
        bodyEn: data[fieldBodyEn]?.toString(),
        isDraft: data[fieldIsDraft] == true,
      );
    } catch (e) {
      debugPrint('Error parsing DevBlogPost $id: $e');
      return DevBlogPost(
        id: id,
        title: 'Error loading post',
        body: '',
        category: BlogCategory.progress,
        authorId: '',
        authorName: 'System',
        isPinned: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isDraft: false,
      );
    }
  }

  Map<String, dynamic> toMap() => {
        fieldTitle: title,
        fieldBody: body,
        fieldCategory: category.name,
        fieldAuthorId: authorId,
        fieldAuthorName: authorName,
        fieldCoverImageUrl: coverImageUrl,
        fieldIsPinned: isPinned,
        fieldCreatedAt: Timestamp.fromDate(createdAt),
        fieldUpdatedAt: Timestamp.fromDate(updatedAt),
        fieldTitleEn: titleEn,
        fieldBodyEn: bodyEn,
        fieldIsDraft: isDraft,
      };

  DevBlogPost copyWith({
    String? title,
    String? body,
    BlogCategory? category,
    String? coverImageUrl,
    bool? isPinned,
    DateTime? updatedAt,
    String? titleEn,
    String? bodyEn,
    bool? isDraft,
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
      titleEn: titleEn ?? this.titleEn,
      bodyEn: bodyEn ?? this.bodyEn,
      isDraft: isDraft ?? this.isDraft,
    );
  }
}
