import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AppTask {
  final String id; // タスクの一意な識別ID
  final String title;
  final String? trigger;

  final bool isOneTime;
  final bool isSeason; // シーズンタスクかどうか
  final String? seasonId; // シーズンのID
  final DateTime? completedAt;
  final bool isSecret; // 秘密の特訓（非公開）かどうか
  final String? reminderTime; // 個別のリマインダー時間 (HH:mm 形式)

  // ── フィールド名定数 ──
  static const String fieldId = 'id';
  static const String fieldTitle = 'title';
  static const String fieldTrigger = 'trigger';
  static const String fieldIsOneTime = 'isOneTime';
  static const String fieldIsSeason = 'isSeason';
  static const String fieldSeasonId = 'seasonId';
  static const String fieldCompletedAt = 'completedAt';
  static const String fieldIsSecret = 'isSecret';
  static const String fieldReminderTime = 'reminderTime';

  const AppTask({
    this.id = '', // 後方互換性のためデフォルト値を空文字にします
    required this.title,
    this.trigger,

    this.isOneTime = false,
    this.isSeason = false,
    this.seasonId,
    this.completedAt,
    this.isSecret = false,
    this.reminderTime,
  });

  /// 本日達成（投稿）されたタスクかどうか判定する
  bool get isCompletedToday {
    if (completedAt == null) return false;
    final now = DateTime.now();
    final cat = completedAt!;
    return cat.year == now.year && cat.month == now.month && cat.day == now.day;
  }

  Map<String, dynamic> toFirestore() {
    return {
      fieldId: id,
      fieldTitle: title,
      if (trigger != null) fieldTrigger: trigger,

      fieldIsOneTime: isOneTime,
      fieldIsSeason: isSeason,
      if (seasonId != null) fieldSeasonId: seasonId,
      fieldCompletedAt: completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      fieldIsSecret: isSecret,
      if (reminderTime != null) fieldReminderTime: reminderTime,
    };
  }

  factory AppTask.fromFirestore(dynamic data) {
    if (data is String) {
      return AppTask(id: '', title: data, isOneTime: false, isSeason: false, isSecret: false);
    }
    
    try {
      final map = data as Map<String, dynamic>;
      return AppTask(
        id: map[fieldId]?.toString() ?? '',
        title: map[fieldTitle]?.toString() ?? '',
        trigger: map[fieldTrigger]?.toString(),
        isOneTime: map[fieldIsOneTime] == true,
        isSeason: map[fieldIsSeason] == true,
        seasonId: map[fieldSeasonId]?.toString(),
        completedAt: (map[fieldCompletedAt] as Timestamp?)?.toDate(),
        isSecret: map[fieldIsSecret] == true,
        reminderTime: map[fieldReminderTime]?.toString(),
      );
    } catch (e) {
      debugPrint('Error parsing AppTask: $e');
      return const AppTask(id: '', title: 'Error loading task', isOneTime: false, isSeason: false, isSecret: false);
    }
  }

  AppTask copyWith({
    String? id,
    String? title,
    String? trigger,
    bool clearTrigger = false,

    bool? isOneTime,
    bool? isSeason,
    String? seasonId,
    DateTime? completedAt,
    bool? isSecret,
    String? reminderTime,
    bool clearReminderTime = false,
  }) {
    return AppTask(
      id: id ?? this.id,
      title: title ?? this.title,
      trigger: clearTrigger ? null : (trigger ?? this.trigger),

      isOneTime: isOneTime ?? this.isOneTime,
      isSeason: isSeason ?? this.isSeason,
      seasonId: seasonId ?? this.seasonId,
      completedAt: completedAt ?? this.completedAt,
      isSecret: isSecret ?? this.isSecret,
      reminderTime: clearReminderTime ? null : (reminderTime ?? this.reminderTime),
    );
  }
}
