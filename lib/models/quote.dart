import 'dart:math';

/// 名言（引用）を表すデータモデルクラス。
///
/// V EFFECTアプリの「シークレットタスク」や「V Alertリマインダー」などで、
/// ユーザーのモチベーションや自己規律を高めるために使用されます。
/// 
/// このクラスはイミュータブル（不変：一度作成したら変更できない設計）なデータクラスとして設計されています。
class Quote {
  /// 名言の本文
  final String text;

  /// 著者名
  final String author;

  /// コンストラクタ
  const Quote({
    required this.text,
    required this.author,
  });

  // ── フィールド名定数 ──
  static const String fieldText = 'text';
  static const String fieldAuthor = 'author';

  /// マップデータ（`Map<String, dynamic>`）からインスタンスを安全に生成します。
  factory Quote.fromMap(Map<String, dynamic> map) {
    try {
      return Quote(
        text: map[fieldText] as String? ?? '',
        author: map[fieldAuthor] as String? ?? '',
      );
    } catch (e) {
      return const Quote(text: '', author: '');
    }
  }

  /// インスタンスをマップデータに変換します。
  Map<String, dynamic> toMap() {
    return {
      fieldText: text,
      fieldAuthor: author,
    };
  }

  /// インスタンスの一部を更新した新しいインスタンスを複製します。
  Quote copyWith({
    String? text,
    String? author,
  }) {
    return Quote(
      text: text ?? this.text,
      author: author ?? this.author,
    );
  }

  // ── ランダム取得用 ──
  static final Random _random = Random();

  // ── 静的（static）名言データ ──

  /// 日本語のモチベーションを高める名言リスト（7個）
  static const List<Quote> quotesJa = [
    Quote(
      text: '天才とは努力する凡才のことである',
      author: 'アルベルト・アインシュタイン',
    ),
    Quote(
      text: '楽観的？悲観的？そんなことは知らん。やる。やり遂げる。必ずやり遂げると神に誓うんだ',
      author: 'イーロン・マスク',
    ),
    Quote(
      text: '時間をかけることを恐れてはいけないよ。それは、いちばん洗練されたかたちでの復讐なんだ',
      author: '村上春樹',
    ),
    Quote(
      text: '貪欲であれ、愚かであれ',
      author: 'スティーブ・ジョブズ',
    ),
    Quote(
      text: '小さいことを重ねることが、とんでもないところに行くただ一つの道',
      author: 'イチロー',
    ),
    Quote(
      text: '自分にできると信じるか、できないと信じるか、どちらにしても君は正しい',
      author: 'ヘンリー・フォード',
    ),
    Quote(
      text: '無意識を意識しないかぎり、それはあなたの人生を支配し、あなたはそれを運命と呼ぶだろう',
      author: 'カール・ユング',
    ),
  ];

  /// 英語のモチベーションを高める名言リスト（7個）
  static const List<Quote> quotesEn = [
    Quote(
      text: 'Genius is one percent inspiration and ninety-nine percent perspiration.',
      author: 'Albert Einstein',
    ),
    Quote(
      text: 'I don\'t give up. I\'d have to be dead or completely incapacitated.',
      author: 'Elon Musk',
    ),
    Quote(
      text: 'Spending plenty of time on something can be the most sophisticated form of revenge.',
      author: 'Haruki Murakami',
    ),
    Quote(
      text: 'Stay hungry. Stay foolish.',
      author: 'Steve Jobs',
    ),
    Quote(
      text: 'We are what we repeatedly do. Excellence, then, is not an act, but a habit.',
      author: 'Aristotle',
    ),
    Quote(
      text: 'Whether you think you can, or you think you can\'t—you\'re right.',
      author: 'Henry Ford',
    ),
    Quote(
      text: 'Until you make the unconscious conscious, it will direct your life and you will call it fate.',
      author: 'Carl Jung',
    ),
  ];

  /// 指定された言語コード（例: 'ja' または 'en'）に応じた名言リストを取得します。
  static List<Quote> getQuotes(String languageCode) {
    if (languageCode.toLowerCase() == 'en') {
      return quotesEn;
    }
    return quotesJa;
  }

  /// 指定された言語コードの名言リストから、ランダムに1つの名言を取得します。
  static Quote getRandomQuote(String languageCode) {
    final list = getQuotes(languageCode);
    if (list.isEmpty) {
      return const Quote(text: '', author: 'Unknown');
    }
    return list[_random.nextInt(list.length)];
  }
}
