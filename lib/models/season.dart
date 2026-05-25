import 'package:cloud_firestore/cloud_firestore.dart';

class Season {
  final String id;
  final String taskName;
  final DateTime startDate;
  final DateTime endDate;
  final int requiredPostsCount;
  final String? hintTitle;
  final String? hintBody;
  final String? relatedBlogId;
  final String? badgeImageUrl;
  final String? badgeAnimation;

  const Season({
    required this.id,
    required this.taskName,
    required this.startDate,
    required this.endDate,
    this.requiredPostsCount = 12,
    this.hintTitle,
    this.hintBody,
    this.relatedBlogId,
    this.badgeImageUrl,
    this.badgeAnimation = 'none',
  });

  Map<String, dynamic> toFirestore() {
    return {
      'taskName': taskName,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'requiredPostsCount': requiredPostsCount,
      if (hintTitle != null) 'hintTitle': hintTitle,
      if (hintBody != null) 'hintBody': hintBody,
      if (relatedBlogId != null) 'relatedBlogId': relatedBlogId,
      if (badgeImageUrl != null) 'badgeImageUrl': badgeImageUrl,
      if (badgeAnimation != null) 'badgeAnimation': badgeAnimation,
    };
  }

  factory Season.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Season(
      id: doc.id,
      taskName: data['taskName'] as String? ?? '',
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      requiredPostsCount: data['requiredPostsCount'] as int? ?? 12,
      hintTitle: data['hintTitle'] as String?,
      hintBody: data['hintBody'] as String?,
      relatedBlogId: data['relatedBlogId'] as String?,
      badgeImageUrl: data['badgeImageUrl'] as String?,
      badgeAnimation: data['badgeAnimation'] as String? ?? 'none',
    );
  }
}
