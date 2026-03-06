/// 日付フォーマットの共通ユーティリティ
class DateHelper {
  /// DateTime を "2026-03-06" 形式の文字列に変換します
  static String toDateString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
