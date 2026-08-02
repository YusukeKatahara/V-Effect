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

### 4. Design System (デザインシステム)

- **Absolute Monochrome + Gold Accent**:
  - `AppColors.white`, `AppColors.black`, `AppColors.grey...` 以外の色は直接指定しない（エラー表示など例外を除く）。
  - アクセントカラーとして `AppColors.accentGold` を効果的に使用する。
- **Typography**: 
  - `google_fonts` (Inter, Orbitron, Outfit 等) を使用し、システムのデフォルトフォントに依存しない。

---

### 5. Naming & Style (命名とスタイル)

- **Language**: 変数・関数名は **英語**。コメントは **日本語**。
- **File Names**: スネークケース (`snake_case.dart`)。
- **Comments**: 
  - `///` (ドキュメントコメント) をクラスや主要メソッドに使用する。
  - 「なぜそうしたか（Rationale）」を意識してコメントを残す。

---
*この規約は、プロジェクトの成長に合わせて随時更新されます。*
