# Handoff Report — lib/screens/home_screen.dart リファクタリング戦略

本レポートは、`lib/screens/home_screen.dart` 内に定義されているプライベートウィジェットおよびカスタムクラスを抽出し、疎結合で保守性の高いコンポーネントへ分割するためのリファクタリング戦略をまとめたものです。

---

## 1. Observation (観測事項)

`lib/screens/home_screen.dart` のコードを静的解析した結果、以下のプライベートクラスが定義されていることを確認しました。

### ① `_FeedCard` (1968〜2285行目)
- **クラス型**: `StatelessWidget`
- **使用箇所**: `_HomeScreenState._buildStackedCard` (1751〜1775行目) 内で、背景カードとして重ねて表示するためにインスタンス化されています。
- **依存関係**:
  - **データモデル**: `Post` (投稿データモデル)
  - **コンポーネント**: `VBadgeWidget` (ユーザーバッジ描画用ウィジェット)
  - **外部ライブラリ**: `CachedNetworkImage` (画像キャッシュ表示), `GoogleFonts` (フォント読み込み)
  - **プロジェクト定義ファイル**: `AppColors`, `AppRoutes` (画面遷移先定義)
  - **未使用の依存**: コンストラクタで受け取る `Map<String, String?> userPhotos` は、ビルドメソッド内で一度も参照されておらず冗長です。
  - **ジェスチャーの重複**: カード内にも optionsTap, profileTap などのジェスチャ検出器がありますが、実際には前面に重ねられた `PageView.builder` の透明なオーバーレイ側 (1242〜1566行目) でタップイベントがインターセプト (横取り) されています。

### ② `_GuardedStateLayer` (1802〜1963行目)
- **クラス型**: `StatefulWidget` (状態変数を持たないため、実質 `StatelessWidget` として動作可能)
- **使用箇所**: `_HomeScreenState._buildMainContent` (1143〜1147行目) 内で、当日未投稿のユーザーに対してフレンドの投稿をロック (非表示化) するためのガード画面として表示されます。
- **依存関係**:
  - **データモデル**: `Post` (背景のぼかし画像を取得するために `feedPosts.first.imageUrl` に依存)
  - **コンポーネント**: `RefreshRingButton` (更新リングボタン)
  - **外部ライブラリ**: `CachedNetworkImage`, `GoogleFonts`
  - **多言語対応 (ローカライズ)**: `AppLocalizations` (文言の翻訳対応用クラス)
    - `homePostToSeeFriends` (友達の投稿を見るために投稿してください)
    - `homeFriendPostsTitle` (友達の投稿)
    - `homeProveVictory` (勝利を証明しよう)
    - `homeStreakResetMessage` (勝利者効果についての励ましメッセージ)

### ③ `_FloatingFlamesLayer` (2290〜2430行目)
- **クラス型**: `StatefulWidget`
- **使用箇所**: `_HomeScreenState.build` (1116行目) 内で、画面最前面にエフェクトレイヤーとして常駐。
- **制御方法**: 親の `HomeScreen` から `GlobalKey<_FloatingFlamesLayerState>` を経由し、`addFlame` メソッドを呼び出すことで炎エフェクトを動的生成します。
- **依存関係**: `_FloatingFlameWidget` (プライベートクラス) および `AppColors`。

### ④ `_DopamineEmojiExplosionLayer` (2489〜2649行目)
- **クラス型**: `StatefulWidget`
- **使用箇所**: `_HomeScreenState.build` (1123行目) 内で、画面最前面にエフェクトレイヤーとして常駐。
- **制御方法**: 親の `HomeScreen` から `GlobalKey<_DopamineEmojiExplosionLayerState>` を経由し、`explode` メソッドを呼び出すことで絵文字の粒子 (パーティクル) を爆発させます。
- **依存関係**: `_ParticleData` (不変データクラス), `_EmojiExplosionPainter` (CustomPainter), `AppColors`。
- **ハードコーディング**: 爆発の起点座標 y軸 が `size.height - 120` とハードコードされています (下部ナビゲーションバーの高さ120pxを考慮した設計)。

### ⑤ `_BgmIndicator` (2669〜2767行目)
- **クラス型**: `StatefulWidget`
- **使用箇所**: `_HomeScreenState._buildCardStack` (1341〜1346行目) 内で、BGMが設定されている投稿の上部に表示されます。
- **依存関係**:
  - **外部ライブラリ**: `CachedNetworkImage`, `GoogleFonts`
  - **プロジェクト定義ファイル**: `AppColors`
  - **サービス (密結合)**: 音声再生管理クラスである **`SoundService`** (`SoundService.instance`) に直接アクセスし、ミュート状態の判定 (`isBgmMuted`) およびトグル処理 (`toggleBgmMute`) を実行しています。

### ⑥ `_FrictionlessPageScrollPhysics` (2435〜2455行目)
- **クラス型**: `PageScrollPhysics` のサブクラス
- **使用箇所**: `PageView.builder` の `physics` パラメータ (1226行目) に指定されています。
- **依存関係**: `ScrollPhysics`, `SpringDescription`。
- **設定値**: 質量 `mass: 4.0`, 剛性 `stiffness: 100.0`, 減衰 `damping: 36.0` (約0.7秒で振動収束する設定), ユーザースワイプ増幅率 `1.2`, 最小フリング速度 `20.0`。

---

## 2. Logic Chain (論理の連鎖)

### ① `_FeedCard` の抽出方針
1. `_FeedCard` は、主にビジュアル表現とレイアウト定義を担当しています。
2. 現状、不要なパラメータ `userPhotos` が渡されているため、これを削除してシグネチャをスリム化します。
3. 他画面や独立テストでも再利用可能にするため、公開ウィジェット `FeedCard` にリネームして抽出します。

### ② `_GuardedStateLayer` の抽出方針
1. このウィジェットに必要な背景画像は「現在配信中の投稿一覧の最初の画像」です。ウィジェット全体を `Post` や `List<Post>` モデルに依存させる必要はなく、単にぼかす対象の画像URL `backgroundImageUrl` を受け取る設計にすれば疎結合になります。
2. また、内部で状態管理を行っていないため、`StatelessWidget` として抽出します。
3. ローカライズ文言の参照場所を維持するか、あるいは外部から注入できるように設計します。

### ③ `_FloatingFlamesLayer` および `_DopamineEmojiExplosionLayer` の抽出方針
1. どちらも `GlobalKey` を経由してメソッド (`addFlame`, `explode`) を呼び出す必要があるため、抽出後も `State` クラスをパブリックとして公開し、親からキー経由でコントロールできる設計を維持します。
2. `_DopamineEmojiExplosionLayer` の爆発起点位置 (下部マージン) は現状 `120.0` に固定されていますが、再利用性を高めるために `bottomOffset` 引数を追加します。

### ④ `_BgmIndicator` の抽出方針
1. 現在は `SoundService.instance` を直接呼び出していますが、テストの容易性 (Testability) と再利用性を考慮すると、UIコンポーネントは状態を持たないピュアなプレゼンテーション層にすべきです。
2. ミュート状態 `isMuted` を外部から受け取り、トグルタップ時に親へ通知するコールバック `onMuteToggle` を設けることで、`SoundService` との直接的な結合を解消します。

### ⑤ `_FrictionlessPageScrollPhysics` の抽出方針
1. 状態やコールバックの依存はなく、純粋なパラメータ定義クラスです。
2. 単体のファイルとして別ディレクトリ (例: `lib/widgets/home/physics/`) または共通のファイルに移動するだけで安全に抽出可能です。

---

## 3. Caveats (注意事項・検討事項)

- **ジェスチャーの重複制御**: `HomeScreen` では、`PageView` 側のオーバーレイエリアがジェスチャーを検知し、裏に配置された `_FeedCard` に対するタップを無効化しています。リファクタリング後も、前面の検知エリアと背面カードの表示の同期が崩れないように注意する必要があります。
- **多言語対応のインポート**: `AppLocalizations` を参照しているため、ファイルを移動した際にインポートパスを `import 'package:v_effect/l10n/app_localizations.dart';` へ解決する必要があります。
- **グローバルBGM状態の同期**: `_BgmIndicator` をピュアUI化する場合、親の `HomeScreen` 側で Riverpod の状態または `SoundService` の状態を監視し、ミュート状態の変化に応じて indicator をリビルドする必要があります。

---

## 4. Conclusion (結論・設計書)

### 抽出後のディレクトリ構造案
```
lib/
├── config/
├── models/
├── screens/
│   └── home_screen.dart (リファクタリング後、軽量化)
├── services/
└── widgets/
    └── home/
        ├── feed_card.dart (★抽出先)
        ├── guarded_state_layer.dart (★抽出先)
        ├── bgm_indicator.dart (★抽出先)
        ├── effects/
        │   ├── floating_flames_layer.dart (★抽出先)
        │   └── dopamine_emoji_explosion_layer.dart (★抽出先)
        └── physics/
            └── frictionless_page_scroll_physics.dart (★抽出先)
```

---

### コンポーネント設計およびインターフェース定義

#### 選択肢の比較検討 (Pros/Cons テーブル)

##### 選択肢A: `GuardedStateLayer` に渡す背景画像データの設計
| 選択肢 | メリット (Pros) | デメリット (Cons) | 推奨度 |
| :--- | :--- | :--- | :--- |
| **A1: `List<Post> feedPosts` をそのまま渡す** | `HomeScreen` 側の呼び出しコードを変更しなくて済む。 | `Post` データモデルに強く依存してしまい、他画面での再利用がしづらくなる。投稿が0件の時の範囲外例外防止処理がウィジェット内に必要。 | 低 |
| **A2: `String? backgroundImageUrl` のみ渡す** | `Post` への依存が一切なくなり、任意のURL画像やプレースホルダーでぼかし背景を表示可能。非常に疎結合。 | 親側で `feedPosts.firstOrNull?.imageUrl` を抽出して渡す必要がある。 | **高 (推奨)** |

##### 選択肢B: `BgmIndicator` の状態管理設計
| 選択肢 | メリット (Pros) | デメリット (Cons) | 推奨度 |
| :--- | :--- | :--- | :--- |
| **B1: 内部で直接 `SoundService.instance` を呼ぶ** | 状態とコールバックを渡す必要がなく、呼び出しコードがシンプルになる。 | ユニットテストが困難になり、音声サービスの実装に依存する。UIとロジックが混ざる。 | 低 |
| **B2: `isMuted` 状態と `onMuteToggle` コールバックを外部から受ける** | テストが容易で、UIのモック化が簡単。ピュアなUI部品としてどこでも使える。 | 親側で `SoundService` を監視するか、Notifier経由で状態を再描画するボイラープレートが必要。 | **高 (推奨)** |

---

### 抽出ウィジェットのクラス定義・インターフェース定義

#### 1. `FeedCard` (`lib/widgets/home/feed_card.dart`)
```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/app_colors.dart';
import '../../models/post.dart';
import '../v_badge_widget.dart';

class FeedCard extends StatelessWidget {
  final Post post;
  final String username;
  final String? userPhotoUrl;
  final String? userBadgeUrl;
  final String? userBadgeAnimation;
  final double dimAlpha;
  final bool isTop;
  final Color tierColor;
  final VoidCallback? onReactionTap; // V Fireのタップ
  final VoidCallback? onProfileTap;  // プロフィールのタップ
  final VoidCallback? onOptionsTap;  // 三点リーダーのタップ
  final ValueNotifier<int>? reactionCountNotifier; // 部分リビルド用

  const FeedCard({
    super.key,
    required this.post,
    required this.username,
    this.userPhotoUrl,
    this.userBadgeUrl,
    this.userBadgeAnimation,
    required this.dimAlpha,
    required this.isTop,
    required this.tierColor,
    this.onReactionTap,
    this.onProfileTap,
    this.onOptionsTap,
    this.reactionCountNotifier,
  });

  @override
  Widget build(BuildContext context) {
    // 既存の _FeedCard の build 実装 (userPhotos 依存を除く)
  }
}
```

#### 2. `GuardedStateLayer` (`lib/widgets/home/guarded_state_layer.dart`)
```dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import '../../config/app_colors.dart';
import '../home/refresh_ring_button.dart';

class GuardedStateLayer extends StatelessWidget {
  final String? backgroundImageUrl;
  final List<Map<String, dynamic>> postedFriends;
  final VoidCallback? onRefresh;

  const GuardedStateLayer({
    super.key,
    this.backgroundImageUrl,
    required this.postedFriends,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    // 既存の _GuardedStateLayer の build 実装 (feedPosts.first 依存を backgroundImageUrl に差し替え)
  }
}
```

#### 3. `FloatingFlamesLayer` (`lib/widgets/home/effects/floating_flames_layer.dart`)
```dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';

class FloatingFlamesLayer extends StatefulWidget {
  const FloatingFlamesLayer({super.key});

  @override
  State<FloatingFlamesLayer> createState() => FloatingFlamesLayerState();
}

class FloatingFlamesLayerState extends State<FloatingFlamesLayer> {
  int _counter = 0;
  final Map<int, Widget> _flames = {};

  void addFlame({
    Color? color,
    Color? glowColor,
    double? size,
    bool isGold = false,
    double bottomOffset = 120.0,
  }) {
    final id = _counter++;
    final randomX = (Random().nextDouble() - 0.5) * 60;

    setState(() {
      _flames[id] = Positioned(
        key: ValueKey(id),
        bottom: bottomOffset,
        right: 40 + randomX,
        child: FloatingFlameWidget(
          key: ValueKey('flame_$id'),
          isGold: isGold,
          color: color,
          glowColor: glowColor,
          size: size,
          onComplete: () {
            if (mounted) {
              setState(() => _flames.remove(id));
            }
          },
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: _flames.values.toList());
  }
}

// 内部アニメーションウィジェット
class FloatingFlameWidget extends StatefulWidget {
  final VoidCallback onComplete;
  final bool isGold;
  final Color? color;
  final Color? glowColor;
  final double? size;

  const FloatingFlameWidget({
    super.key,
    required this.onComplete,
    this.isGold = false,
    this.color,
    this.glowColor,
    this.size,
  });

  @override
  State<FloatingFlameWidget> createState() => _FloatingFlameWidgetState();
}

// _FloatingFlameWidgetState の実装はそのまま移動
```

#### 4. `DopamineEmojiExplosionLayer` (`lib/widgets/home/effects/dopamine_emoji_explosion_layer.dart`)
```dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class DopamineEmojiExplosionLayer extends StatefulWidget {
  final double bottomOffset; // 爆発起点のy軸オフセット (デフォルト120.0)

  const DopamineEmojiExplosionLayer({
    super.key,
    this.bottomOffset = 120.0,
  });

  @override
  State<DopamineEmojiExplosionLayer> createState() => DopamineEmojiExplosionLayerState();
}

class DopamineEmojiExplosionLayerState extends State<DopamineEmojiExplosionLayer> with SingleTickerProviderStateMixin {
  final List<ParticleData> _particles = [];
  late final Ticker _ticker;
  double _elapsed = 0.0;
  Duration? _prevTickTime;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  // _onTick などのロジックと爆発トリガー
  void explode(String emoji) {
    // 既存の explode 実装
  }

  @override
  Widget build(BuildContext context) {
    if (_particles.isEmpty) return const SizedBox.expand();
    return CustomPaint(
      painter: EmojiExplosionPainter(
        particles: _particles, 
        elapsed: _elapsed,
        bottomOffset: widget.bottomOffset, // ペインターに渡す
      ),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

// ParticleData / EmojiExplosionPainter のクラス定義も同居させて抽出
```

#### 5. `BgmIndicator` (`lib/widgets/home/bgm_indicator.dart`)
```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/app_colors.dart';

class BgmIndicator extends StatelessWidget {
  final String title;
  final String? artist;
  final String? url;
  final String? artworkUrl;
  final bool isMuted;
  final VoidCallback onMuteToggle;

  const BgmIndicator({
    super.key,
    required this.title,
    this.artist,
    this.url,
    this.artworkUrl,
    required this.isMuted,
    required this.onMuteToggle,
  });

  @override
  Widget build(BuildContext context) {
    // 既存の _BgmIndicatorState.build の実装を基に構築
    // SoundService への直接参照はなくなり、isMuted と onMuteToggle コールバックを使用
  }
}
```

#### 6. `FrictionlessPageScrollPhysics` (`lib/widgets/home/physics/frictionless_page_scroll_physics.dart`)
```dart
import 'package:flutter/material.dart';

class FrictionlessPageScrollPhysics extends PageScrollPhysics {
  const FrictionlessPageScrollPhysics({super.parent});

  @override
  FrictionlessPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return FrictionlessPageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring =>
      const SpringDescription(mass: 4.0, stiffness: 100.0, damping: 36.0);

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    return offset * 1.2;
  }

  @override
  double get minFlingVelocity => 20.0;
}
```

---

## 5. Verification Method (検証方法)

### ① 静的解析およびコンパイル検証
コードの書き換え自体は行いませんが、抽出を安全に実行したかを確認するために以下のコマンドを使用します。
```bash
# 依存関係を最新化し、構文や静的解析のエラーがないか確認する
flutter analyze
```

### ② 挙動およびインタラクションの検証
各ウィジェット抽出後に正しく動作することを確認するためのチェック項目：
1. **背景ロック層の表示**: `_postedToday` が `false` の場合に、ローカライズテキストと友達のアバターリストがブレンドされた背景とともに正しく表示されること。
2. **スクロール感度**: `FrictionlessPageScrollPhysics` 適用下でのスワイプ挙動が、摩擦なくスムーズにカードを切り替えられること。
3. **炎エフェクト & 爆発**: リアクションボタンおよびコンボ発生時に、画面右端の炎 (`FloatingFlamesLayer`) および中央からの絵文字爆発 (`DopamineEmojiExplosionLayer`) が正しい座標 (120pxオフセット考慮) で再生され、再生完了後にメモリから削除されること。
4. **BGMインジケーター**: 曲名とアートワーク画像が正しくプレースホルダー付きでロードされ、タップ時にミュートが正しく機能すること。
