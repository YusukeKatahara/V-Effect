import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// タスクの実行頻度タイプ
enum TaskFrequencyType {
  /// 毎日（デフォルト）
  daily,
  /// 週あたりの目標回数（例: 週3回）
  weeklyTarget,
  /// 月あたりの目標回数（例: 月10回）
  monthlyTarget,
}

class AppTask {
  final String id; // タスクの一意な識別ID
  final String title;
  final String? trigger;
  final TaskFrequencyType frequencyType; // 達成頻度タイプ (毎日 / 週○回 / 月○回)
  final int targetCount; // 目標達成回数 (週3回なら3, デフォルト1)

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
  static const String fieldFrequencyType = 'frequencyType';
  static const String fieldTargetCount = 'targetCount';
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
    this.frequencyType = TaskFrequencyType.daily,
    this.targetCount = 1,
    this.isOneTime = false,
    this.isSeason = false,
    this.seasonId,
    this.completedAt,
    this.isSecret = false,
    this.reminderTime,
  });

  /// デイリー（毎日）タスクかどうか
  bool get isDaily => frequencyType == TaskFrequencyType.daily;

  /// 週次目標タスクかどうか
  bool get isWeekly => frequencyType == TaskFrequencyType.weeklyTarget;

  /// 月次目標タスクかどうか
  bool get isMonthly => frequencyType == TaskFrequencyType.monthlyTarget;

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
      fieldFrequencyType: frequencyType.name,
      fieldTargetCount: targetCount,
      fieldIsOneTime: isOneTime,
      fieldIsSeason: isSeason,
      if (seasonId != null) fieldSeasonId: seasonId,
      fieldCompletedAt: completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      fieldIsSecret: isSecret,
      if (reminderTime != null) fieldReminderTime: reminderTime,
    };
  }

  /// JSON（ローカルキャッシュ SharedPreferences）保存用の安全な Map を返します。
  /// （Timestamp の代わりに ISO8601 文字列を使用し、jsonEncode でクラッシュしないようにします）
  Map<String, dynamic> toJson() {
    return {
      fieldId: id,
      fieldTitle: title,
      if (trigger != null) fieldTrigger: trigger,
      fieldFrequencyType: frequencyType.name,
      fieldTargetCount: targetCount,
      fieldIsOneTime: isOneTime,
      fieldIsSeason: isSeason,
      if (seasonId != null) fieldSeasonId: seasonId,
      fieldCompletedAt: completedAt?.toIso8601String(),
      fieldIsSecret: isSecret,
      if (reminderTime != null) fieldReminderTime: reminderTime,
    };
  }

  factory AppTask.fromFirestore(dynamic data) {
    if (data is String) {
      return AppTask(
        id: '',
        title: data,
        frequencyType: TaskFrequencyType.daily,
        targetCount: 1,
        isOneTime: false,
        isSeason: false,
        isSecret: false,
      );
    }
    
    try {
      final map = data as Map<String, dynamic>;

      // 達成頻度タイプのパース（後方互換性対応：未設定時は daily）
      TaskFrequencyType parsedFrequency = TaskFrequencyType.daily;
      final freqStr = map[fieldFrequencyType]?.toString();
      if (freqStr == 'weeklyTarget' || freqStr == 'weekly') {
        parsedFrequency = TaskFrequencyType.weeklyTarget;
      } else if (freqStr == 'monthlyTarget' || freqStr == 'monthly') {
        parsedFrequency = TaskFrequencyType.monthlyTarget;
      }

      final parsedTargetCount = (map[fieldTargetCount] as num?)?.toInt() ?? 1;

      // 💡 completedAt は Timestamp, ISO8601 String, または DateTime のいずれでも安全に復元可能にする
      DateTime? parsedCompletedAt;
      final rawCompletedAt = map[fieldCompletedAt];
      if (rawCompletedAt is Timestamp) {
        parsedCompletedAt = rawCompletedAt.toDate();
      } else if (rawCompletedAt is String) {
        parsedCompletedAt = DateTime.tryParse(rawCompletedAt);
      } else if (rawCompletedAt is DateTime) {
        parsedCompletedAt = rawCompletedAt;
      }

      return AppTask(
        id: map[fieldId]?.toString() ?? '',
        title: map[fieldTitle]?.toString() ?? '',
        trigger: map[fieldTrigger]?.toString(),
        frequencyType: parsedFrequency,
        targetCount: parsedTargetCount > 0 ? parsedTargetCount : 1,
        isOneTime: map[fieldIsOneTime] == true,
        isSeason: map[fieldIsSeason] == true,
        seasonId: map[fieldSeasonId]?.toString(),
        completedAt: parsedCompletedAt,
        isSecret: map[fieldIsSecret] == true,
        reminderTime: map[fieldReminderTime]?.toString(),
      );
    } catch (e) {
      debugPrint('Error parsing AppTask: $e');
      return const AppTask(
        id: '',
        title: 'Error loading task',
        frequencyType: TaskFrequencyType.daily,
        targetCount: 1,
        isOneTime: false,
        isSeason: false,
        isSecret: false,
      );
    }
  }

  AppTask copyWith({
    String? id,
    String? title,
    String? trigger,
    bool clearTrigger = false,
    TaskFrequencyType? frequencyType,
    int? targetCount,
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
      frequencyType: frequencyType ?? this.frequencyType,
      targetCount: targetCount ?? this.targetCount,
      isOneTime: isOneTime ?? this.isOneTime,
      isSeason: isSeason ?? this.isSeason,
      seasonId: seasonId ?? this.seasonId,
      completedAt: completedAt ?? this.completedAt,
      isSecret: isSecret ?? this.isSecret,
      reminderTime: clearReminderTime ? null : (reminderTime ?? this.reminderTime),
    );
  }
}
