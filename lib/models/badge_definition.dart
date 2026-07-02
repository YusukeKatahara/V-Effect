/// バッジ情報を定義するデータクラス
class BadgeDefinition {
  final String id;
  final String name;
  final String? imageUrl;
  final String animation;

  const BadgeDefinition({
    required this.id,
    required this.name,
    this.imageUrl,
    this.animation = 'none',
  });

  /// アプリ内に存在する全バッジのマスターリスト
  /// 「なし」オプションはUI側で制御するため、ここには含めません。
  static List<BadgeDefinition> get allBadges => [
    const BadgeDefinition(
      id: 'tester',
      name: 'テスター',
      animation: 'shimmer',
    ),
    const BadgeDefinition(
      id: 'assets/icon/gratitude_heart_badge.png',
      name: '感謝',
      imageUrl: 'assets/icon/gratitude_heart_badge.png',
      animation: 'pixel_bounce',
    ),
  ];
}
