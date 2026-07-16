---
name: coding-rules
description: V EFFECT プロジェクトのコーディング規約。Dartコードを書くとき・レビューするときに参照する。
---

## V EFFECT Coding Guidelines

### 1. Architecture & Layers (アーキテクチャ)

プロジェクトは機能と責務に基づいて以下のレイヤーに分割します。

- **Models (`lib/models/`)**: 
  - イミュータブルなデータクラス。`final` フィールド、`copyWith`、`toFirestore` / `fromMap` を持つ。
  - ビジネスロジックの補助メソッド（例: `hasEmojiReacted`）をここに閉じ込める。
- **Services (`lib/services/`)**: 
  - シングルトン (`instance`)。外部通信 (Firestore, Storage, Auth) や複雑なロジックを担当。
- **Widgets (`lib/widgets/`)**: 
  - 再利用可能なUI部品。特定の画面に依存しない。
- **Screens (`lib/screens/`)**: 
  - 画面全体のレイアウトと、Provider を介したデータ取得の橋渡し。

---

### 2. Hardened Data Layer (Firestore 永続化の硬化)

データの不整合や再起動時の消失を防ぐため、以下の規約を厳守してください。

- **Unified Serialization**:
  - 各モデルに `fieldConstants` (`static const String fieldName = '...'`) を定義し、マジックストリングを排除する。
  - `withConverter<T>` を全てのコレクション参照で利用し、型安全な DTO (Data Transfer Object) として扱う。
- **Resilient Parsing (`fromMap`)**:
  - `as Map<String, dynamic>` のような直接キャストを避け、`Map.from()` や個別のループで解析する。
  - `try-catch` でパース処理を保護し、エラー時もデフォルト値でフォールバックさせる。
- **Atomic Updates**:
  - マップ全体の更新ではなく、特定のキーのみを更新する場合はドット記法 (`parentField.childKey`) を使用して競合を防ぐ。
- **Redundant State Checks**:
  - 極めて重要なステート（リアクション済み等）は、Map と List の両方で冗長に保持/チェックすることを検討する。

---

### 3. State Management (状態管理)

- **Riverpod**: 
  - 全体的なデータフェッチには Riverpod (`AsyncValue`) を使用する。
  - インスタンスが必要な場合は `ref.watch(homeDataProvider)` 等で取得し、`setState` を最小限に抑える。
- **ValueNotifier / ChangeNotifier**: 
  - テーマ変更やスクロール位置など、局所的・頻繁に更新されるステートに使用する。

---

### 4. Design System & UI/UX Consistency (デザインシステムとUI/UXの一貫性)

ブランド力を高め、ユーザーに洗練された一貫性のある体験（UX）を提供するため、以下のデザインルールを厳守してください。

- **Absolute Monochrome + Gold Accent**:
  - `AppColors.white`, `AppColors.black`, `AppColors.grey...` 以外の色は直接指定しない（エラー表示などの例外を除く）。
  - アクセントカラーとして `AppColors.accentGold` を効果的に使用し、アプリの「勝利（Victory）」や「プレミアム感」を演出する。
- **Typography (タイポグラフィの統一)**:
  - `google_fonts` (Inter, Orbitron, Outfit 等) を使用し、システムのデフォルトフォントに依存しない。
  - フォントファミリーの使い分け（例: 数値や英字タイトルには `Orbitron` や `Outfit`、通常の読みやすい文章には `Inter`）を統一する。
- **Component Standardization (UIコンポーネントの共通化と再利用)**:
  - ボタン（`PrimaryButton` や `GoldButton` など）、ダイアログ、テキスト入力フィールド、カード等の主要コンポーネントは、個別の画面でアドホックにスタイリングせず、共通パーツ（`lib/widgets/` 配下）を再利用する。
  - 新規にカスタムUIを作成する際は、既存のUIとの類似性を担保し、形状・角丸（`BorderRadius`）・影（`BoxShadow`）のパラメータを一貫させる。
- **Micro-Animations & Transitions (アニメーションの一貫性)**:
  - 画面遷移（Transition）やボタン押下時のフィードバック、達成演出などのアニメーションは、イージングや速度を一貫させる（例: `Curves.easeOutExpo`, 200ms〜300ms）。
  - ゴールドの光彩（Glow）やフェードインなどのプレミアム演出をルール化し、アプリ全体の「V EFFECT」としてのブランド体験を統一する。
- **UX & Messaging Tone (メッセージングとフィードバックの一貫性)**:
  - エラーメッセージや案内文は、ユーザーを責めないポジティブな表現（「エラーが発生しました」ではなく、親しみやすく丁寧なトーン）に統一する。
  - 操作完了時（投稿完了、目標達成時）には、必ず「お祝い」や「承認」を想起させる気持ちの良いインタラクションや視覚的フィードバック（ゴールドアクセントの演出等）を提供する。

---

### 5. Naming & Style (命名とスタイル)

- **Language**: 変数・関数名は **英語**。コメントは **日本語**。
- **File Names**: スネークケース (`snake_case.dart`)。
- **Comments**: 
  - `///` (ドキュメントコメント) をクラスや主要メソッドに使用する。
  - 「なぜそうしたか（Rationale）」を意識してコメントを残す。

---
*この規約は、プロジェクトの成長に合わせて随時更新されます。*

### 6. Form & Scroll Layout UI (フォーム画面レイアウト)

画面サイズの違い（iPhone SE〜Pro Max, iPhone Airなど）やキーボードの開閉に関わらず、XやInstagramのような洗練されたレイアウトを維持するため以下のルールを厳守する。

- **画面の固定比率分割の禁止**:
  - `Expanded(flex: 2)` と `Expanded(flex: 8)` のような固定割合での縦の空間分割は行わない。
- **メインタイトルの固定**:
  - 画面の主題となるタイトル（「アカウント作成」など）はスクロールエリア外の最上部（または AppBar）に固定し、スクロールによって隠れないようにする。
- **CustomScrollViewの利用**:
  - 入力フォーム等のコンテンツは `CustomScrollView` と `SliverList` を用いて、中身の自然な高さで配置する。
- **アクションボタンの下部固定**:
  - 「完了」「次へ」などの主要アクションボタンは、`SliverFillRemaining(hasScrollBody: false)` の中に配置し、余白があれば画面最下部に固定、画面が小さければコンテンツの最後に自然に続くようにする。

---

### 7. Responsive & Multi-Device Layout (マルチデバイス・レスポンシブ対応)

異なるデバイスの画面サイズやアスペクト比、キーボードの開閉によって画面が崩れないよう、以下のレイアウト規約を厳守してください。

- **大画面での横幅制限 (`ResponsiveContainer` の使用)**:
  - ログイン画面、登録画面、プロフィール編集画面などのフォームや設定画面において、大画面（iPadやデスクトップ）でコンテンツが横に伸びすぎないよう、[ResponsiveContainer](file:///Users/rennlikeu/development/V-Effect/lib/widgets/responsive_container.dart) を使用して最大幅（デフォルト 480px）を制限し、中央に寄せる。

- **安全領域の確保 (`SafeArea`)**:
  - デバイス上部のノッチやカメラの切り欠き、下部のホームバーなどのシステムUIとアプリの操作要素が重ならないよう、Scaffold の内側やヘッダー部分で `SafeArea` を適切に配置する。

- **比率固定のカードUI設計 (`LayoutBuilder` の活用)**:
  - タイムラインのようにアスペクト比（例: 9:16）を維持したカードを表示する場合、固定の width/height は使用しない。
  - `LayoutBuilder` で得られる親の制約（`constraints.maxWidth` / `constraints.maxHeight`）を基に比率計算を行い、さらに `clamp` などを用いて画面からはみ出さないように上限高さを算出して逆算した幅（`finalCardWidth` 等）を使用する。

- **キーボード表示時のオーバーフロー防止**:
  - テキスト入力フォームを持つすべての画面では、キーボード表示時にレイアウト崩れエラー（黄黒のストライプ模様）が発生しないよう、`SingleChildScrollView` または `CustomScrollView` でスクロール可能にする。

- **タブレット等での動的ナビゲーション高さ調整**:
  - ボトムナビゲーション周辺のパディングは、`MediaQuery.of(context).size.width` に応じてタブレットとスマホで適切な余白量に動的に切り替える（例: `isTablet ? 80 : 30`）。

