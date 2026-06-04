import 'package:cloud_firestore/cloud_firestore.dart';

class AppTask {
  final String title;
  final String? trigger;
  final String? reward; // ご褒美（したい習慣）
  final bool isOneTime;
  final bool isSeason; // シーズンタスクかどうか
  final String? seasonId; // シーズンのID
  final DateTime? completedAt;

  const AppTask({
    required this.title,
    this.trigger,
    this.reward,
    this.isOneTime = false,
    this.isSeason = false,
    this.seasonId,
    this.completedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      if (trigger != null) 'trigger': trigger,
      if (reward != null) 'reward': reward,
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
      reward: map['reward'] as String?,
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
    String? reward,
    bool clearReward = false,
    bool? isOneTime,
    bool? isSeason,
    String? seasonId,
    DateTime? completedAt,
  }) {
    return AppTask(
      title: title ?? this.title,
      trigger: clearTrigger ? null : (trigger ?? this.trigger),
      reward: clearReward ? null : (reward ?? this.reward),
      isOneTime: isOneTime ?? this.isOneTime,
      isSeason: isSeason ?? this.isSeason,
      seasonId: seasonId ?? this.seasonId,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
