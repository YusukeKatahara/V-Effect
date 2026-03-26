/// 日付フォーマットの共通ユーティリティ
class DateHelper {
  /// DateTime を "2026-03-06" 形式の文字列に変換します
  static String toDateString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 現在時刻からの相対時間を「〇分前」「昨日」などの文字列で返します
  static String timeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return toDateString(date);
    } else if (difference.inDays >= 2) {
      return '${difference.inDays}日前';
    } else if (difference.inDays >= 1) {
      return '昨日';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}時間前';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}分前';
    } else {
      return 'たった今';
    }
  }
}
