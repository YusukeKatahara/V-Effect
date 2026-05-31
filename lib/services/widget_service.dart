import 'package:home_widget/home_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/date_helper.dart';
import 'streak_service.dart';

class WidgetService {
  WidgetService._();
  static final WidgetService instance = WidgetService._();

  static const String appGroupId = 'group.com.veffect.app.vEffect';
  static const String iOSWidgetName = 'VEffectWidget';

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await HomeWidget.setAppGroupId(appGroupId);
      _initialized = true;
    } catch (e) {
      debugPrint('WidgetService initialization error: $e');
    }
  }

  /// ウィジェットのデータを更新する
  Future<void> updateWidgetData() async {
    try {
      if (!_initialized) await initialize();

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final userSnap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!userSnap.exists) return;

      final userData = userSnap.data()!;
      final today = DateHelper.toDateString(DateTime.now());
      final lastPostedDate = userData['lastPostedDate']?.toString();
      final isCompleted = lastPostedDate == today;

      final streakData = StreakService.calculateEffectiveStreak(
        streak: (userData['streak'] as num?)?.toInt() ?? 0,
        protections: (userData['streakProtections'] as num?)?.toInt() ?? 0,
        lastPostedDate: lastPostedDate,
      );
      final streakCount = streakData['streak'] ?? 0;

      final recentDatesRaw = userData['recentPostDates'] as List? ?? [];
      final historyDates = recentDatesRaw.map((e) => e.toString()).join(',');

      double monthlyRate = 0.0;
      if (recentDatesRaw.isNotEmpty) {
        int count = 0;
        final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
        for (final dateStr in recentDatesRaw) {
          final parts = dateStr.toString().split('-');
          if (parts.length == 3) {
            final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
            if (d.isAfter(thirtyDaysAgo) || d.isAtSameMomentAs(thirtyDaysAgo)) count++;
          }
        }
        monthlyRate = count / 30.0;
        if (monthlyRate > 1.0) monthlyRate = 1.0;
      }

      await HomeWidget.saveWidgetData<bool>('isCompleted', isCompleted);
      await HomeWidget.saveWidgetData<int>('streakCount', streakCount);
      await HomeWidget.saveWidgetData<String>('historyDates', historyDates);
      await HomeWidget.saveWidgetData<double>('monthlyRate', monthlyRate);
      
      await HomeWidget.updateWidget(
        iOSName: iOSWidgetName,
      );
      
      debugPrint('Widget updated: isCompleted=$isCompleted, streak=$streakCount, historyDatesLength=${historyDates.length}, monthlyRate=$monthlyRate');
    } catch (e) {
      debugPrint('Widget update error: $e');
    }
  }
}
