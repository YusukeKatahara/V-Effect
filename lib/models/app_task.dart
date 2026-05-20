import 'package:cloud_firestore/cloud_firestore.dart';

class AppTask {
  final String title;
  final String? trigger;
  final bool isOneTime;
  final DateTime? completedAt;

  const AppTask({
    required this.title,
    this.trigger,
    this.isOneTime = false,
    this.completedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      if (trigger != null) 'trigger': trigger,
      'isOneTime': isOneTime,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  factory AppTask.fromFirestore(dynamic data) {
    if (data is String) {
      return AppTask(title: data, isOneTime: false);
    }
    
    final map = data as Map<String, dynamic>;
    return AppTask(
      title: map['title'] ?? '',
      trigger: map['trigger'] as String?,
      isOneTime: map['isOneTime'] ?? false,
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
    );
  }

  AppTask copyWith({
    String? title,
    String? trigger,
    bool? isOneTime,
    DateTime? completedAt,
  }) {
    return AppTask(
      title: title ?? this.title,
      trigger: trigger ?? this.trigger,
      isOneTime: isOneTime ?? this.isOneTime,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
