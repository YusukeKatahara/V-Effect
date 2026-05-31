import 'package:home_widget/home_widget.dart';
import 'package:flutter/foundation.dart';

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
  Future<void> updateWidgetData({
    required bool isCompleted,
    required int streakCount,
  }) async {
    try {
      if (!_initialized) await initialize();

      await HomeWidget.saveWidgetData<bool>('isCompleted', isCompleted);
      await HomeWidget.saveWidgetData<int>('streakCount', streakCount);
      
      await HomeWidget.updateWidget(
        iOSName: iOSWidgetName,
      );
      
      debugPrint('Widget updated: isCompleted=$isCompleted, streakCount=$streakCount');
    } catch (e) {
      debugPrint('Widget update error: $e');
    }
  }
}
