# coding-rules
V EFFECT プロジェクトのコーディング規約。Dartコードを書くとき・レビューするときに参照する。

## V EFFECT Coding Guidelines

### 1. Architecture & Layers (アーキテクチャ)
- **Models (`lib/models/`)**: イミュータブルなデータクラス。`final` フィールド、`copyWith`、`toFirestore` / `fromMap` を持つ。
- **Services (`lib/services/`)**: シングルトン (`instance`)。外部通信 (Firestore, Storage, Auth) や複雑なロジックを担当。
- **Widgets (`lib/widgets/`)**: 再利用可能なUI部品。特定の画面に依存しない。
- **Screens (`lib/screens/`)**: 画面全体のレイアウトと、Provider を介したデータ取得の橋渡し。

### 2. Hardened Data Layer (Firestore 永続化の硬化)
- **Unified Serialization**: `fieldConstants` を定義し、`withConverter<T>` を利用する。
- **Resilient Parsing (`fromMap`)**: `Map.from()` や個別のループで解析し、`try-catch` でパース処理を保護。
- **Atomic Updates**: ドット記法 (`parentField.childKey`) を使用。
- **Redundant State Checks**: 極めて重要なステートは Map と List の両方で冗長に保持/チェックする。

### 3. State Management (状態管理)
- **Riverpod**: 全体的なデータフェッチに Riverpod (`AsyncValue`) を使用。
- **ValueNotifier / ChangeNotifier**: 局所的・頻繁に更新されるステートに使用。

### 4. Design System & UI/UX Consistency (デザインシステムとUI/UXの一貫性)
- **Absolute Monochrome + Gold Accent**: `AppColors.white`, `AppColors.black`, `AppColors.grey...` とアクセントに `AppColors.accentGold` を使用。
- **Typography (タイポグラフィの統一)**: `google_fonts` を使用。
- **Component Standardization**: 共通パーツを再利用。
- **Micro-Animations & Transitions**: アニメーションの一貫性。
- **UX & Messaging Tone**: ポジティブな表現、達成時のお祝い。

### 5. Naming & Style (命名とスタイル)
- 変数・関数名は英語。コメントは日本語。スネークケースのファイル名。

### 6. Form & Scroll Layout UI (フォーム画面レイアウト)
- 固定比率分割の禁止、メインタイトルの固定、CustomScrollViewの利用、アクションボタンの下部固定。
