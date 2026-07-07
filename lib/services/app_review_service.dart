import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class AppReviewService {
  AppReviewService._privateConstructor();
  static final AppReviewService instance = AppReviewService._privateConstructor();

  final InAppReview _inAppReview = InAppReview.instance;
  static const String _requestedMilestonesKey = 'requested_review_milestones';

  /// 連続ストリーク数に基づき、レビューポップアップを表示すべきか判定し、
  /// 必要であれば In-App Review API を呼び出します。
  /// 
  /// 10日以上（すでに超えている既存ユーザー含む）に達した際に一度だけ表示します。
  Future<void> requestReviewIfNeeded(int currentStreak) async {
    if (kIsWeb) return; // in_app_review は Web 非対応（ストアレビューはアプリのみ）
    try {
      final eligibleMilestone = _getEligibleMilestone(currentStreak);
      if (eligibleMilestone == -1) {
        return; // 対象となる節目がない
      }

      final prefs = await SharedPreferences.getInstance();
      final requestedMilestones = prefs.getStringList(_requestedMilestonesKey) ?? [];

      // その節目ですでにレビューを要求している場合はスキップ
      if (requestedMilestones.contains(eligibleMilestone.toString())) {
        return;
      }

      // レビューダイアログが利用可能かチェック
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
        
        // 記録を保存
        requestedMilestones.add(eligibleMilestone.toString());
        await prefs.setStringList(_requestedMilestonesKey, requestedMilestones);
        
        debugPrint('AppReviewService: Requested review for milestone $eligibleMilestone');
      }
    } catch (e) {
      debugPrint('AppReviewService: Error requesting review: $e');
    }
  }

  /// 現在のストリーク数が満たしている節目を返します
  /// （今回は「10日」のみ。満たしていない場合は -1）
  int _getEligibleMilestone(int streak) {
    if (streak >= 10) return 10;
    return -1;
  }
}
