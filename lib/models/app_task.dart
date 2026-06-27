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

  // ── フィールド名定数 ──
  static const String fieldId = 'id';
  static const String fieldTitle = 'title';
  static const String fieldTrigger = 'trigger';
  static const String fieldIsOneTime = 'isOneTime';
  static const String fieldIsSeason = 'isSeason';
  static const String fieldSeasonId = 'seasonId';
  static const String fieldCompletedAt = 'completedAt';

  const AppTask({
    this.id = '', // 後方互換性のためデフォルト値を空文字にします
    required this.title,
    this.trigger,

    this.isOneTime = false,
    this.isSeason = false,
    this.seasonId,
    this.completedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      fieldId: id,
      fieldTitle: title,
      if (trigger != null) fieldTrigger: trigger,

      fieldIsOneTime: isOneTime,
      fieldIsSeason: isSeason,
      if (seasonId != null) fieldSeasonId: seasonId,
      fieldCompletedAt: completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  factory AppTask.fromFirestore(dynamic data) {
    if (data is String) {
      return AppTask(id: '', title: data, isOneTime: false, isSeason: false);
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
      );
    } catch (e) {
      debugPrint('Error parsing AppTask: $e');
      return const AppTask(id: '', title: 'Error loading task', isOneTime: false, isSeason: false);
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
  }) {
    return AppTask(
      id: id ?? this.id,
      title: title ?? this.title,
      trigger: clearTrigger ? null : (trigger ?? this.trigger),

      isOneTime: isOneTime ?? this.isOneTime,
      isSeason: isSeason ?? this.isSeason,
      seasonId: seasonId ?? this.seasonId,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
