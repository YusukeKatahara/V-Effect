import 'package:cloud_firestore/cloud_firestore.dart';

class AppTask {
  final String title;
  final String? trigger;

  final bool isOneTime;
  final bool isSeason; // シーズンタスクかどうか
  final String? seasonId; // シーズンのID
  final DateTime? completedAt;

  const AppTask({
    required this.title,
    this.trigger,

    this.isOneTime = false,
    this.isSeason = false,
    this.seasonId,
    this.completedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      if (trigger != null) 'trigger': trigger,

      'isOneTime': isOneTime,
      'isSeason': isSeason,
      if (seasonId != null) 'seasonId': seasonId,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  factory AppTask.fromFirestore(dynamic data) {
    if (data is String) {
      return AppTask(title: data, isOneTime: false, isSeason: false);
    }
    
    final map = data as Map<String, dynamic>;
    return AppTask(
      title: map['title'] ?? '',
      trigger: map['trigger'] as String?,

      isOneTime: map['isOneTime'] ?? false,
      isSeason: map['isSeason'] ?? false,
      seasonId: map['seasonId'] as String?,
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
    );
  }

  AppTask copyWith({
    String? title,
    String? trigger,
    bool clearTrigger = false,

    bool? isOneTime,
    bool? isSeason,
    String? seasonId,
    DateTime? completedAt,
  }) {
    return AppTask(
      title: title ?? this.title,
      trigger: clearTrigger ? null : (trigger ?? this.trigger),

      isOneTime: isOneTime ?? this.isOneTime,
      isSeason: isSeason ?? this.isSeason,
      seasonId: seasonId ?? this.seasonId,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
