# 機能追加およびエラー修正 実装計画 (Implementation Plan)

先ほど追加された「ユーザー検索とフォロー」機能について、コードの分析と仕様確認を行った結果、以下のエラー・改善が必要な箇所が見つかりました。この計画書に沿って修正を進めます。

---

## 🎯 発見された課題と修正目的
1. **フォロー状態の未反映 (UI/UXの致命的欠陥)**
   現状の検索画面（`SearchScreen`）では、既にフォローしているユーザーに対してもすべて「フォロー」ボタンが表示されてしまいます。「フォロー中」フラグを取得・管理し、「フォロー解除」へと切り替える必要があります。
2. **自分自身へのフォロー制限 (バグ)**
   検索結果に自分自身が表示された場合、フォローボタンを押すとエラー（例外）がスローされます。自分自身の場合はボタンを非表示にするか無効化する必要があります。
3. **新規ルールの適用 (アーキテクチャ)**
   `.agents/GEMINI.md` に追加された新ルール **「状態管理はRiverpodを使用し、providers/ フォルダに配置すること」** に基づき、検索結果やフォロー状況の管理を Riverpod (Provider) に移行します。
4. **静的解析エラーの解消 (クリーンコード)**
   `flutter analyze` にて不要な import や、`final` 宣言可能な変数の警告が 6 件検出されています。
5. **部分一致検索フィールドの確認**
   Firestore の `usernameLower` を用いた検索が行われていますが、既存のユーザー登録処理において `usernameLower` が確実に保存される仕組みになっているかの確認・補強が必要です。

---

## 🛠 スキームと実行ステップ

### ステップ 1: Riverpod (Provider) による状態管理構造の導入
フォロー状況（自分が誰をフォローしているか）をアプリ全体で共有するため、`providers` フォルダを新設し、Riverpod/Provider を用いた状態管理クラスを作成します。
- **対象**: `lib/providers/following_provider.dart` (新規作成)
- **内容**: `FriendService.getFollowing()` のストリームを読み込み、現在のフォロー中の User ID リストを保持・提供する Provider を実装します。

### ステップ 2: SearchScreen の改修 (UI/UX・状態反映)
Riverpod 等を用いて、検索結果のユーザー一覧から「未フォロー」「フォロー中」「自分自身」を判別できるように修正します。
- **対象**: `lib/screens/search_screen.dart`
- **内容**: 
  - `_results` の宣言を `final` に直す（analyze 警告解消）。
  - リスト描画時に、自分の UID の場合はボタンを非表示。
  - すでにフォローしている UID の場合は「フォロー解除（Unfollow）」ボタンを表示し、タップで `FriendService.unfollowUser` を呼び出す。
  - State 管理をローカルの `setState` から Riverpod/Provider ベースへ移行するようリファクタリング（または `Consumer` でフォロー状態を監視）。

### ステップ 3: flutter analyze 警告の修正
コードの健全性を保つため、使用されていない引数や import を削除します。
- **対象**: 
  - `lib/screens/friend_feed_screen.dart` (未使用の key 引数)
  - `lib/screens/home_screen.dart` (未使用の key 引数)
  - `lib/screens/main_shell.dart` (未使用の import `google_fonts`)
  - `lib/services/post_service.dart` (不要な import `dart:typed_data`)

### ステップ 4: Firebase ユーザー登録時の属性追加 (必要に応じて)
ユーザーの名前（`username`）で検索できるようにするため、プロフィール更新時や登録時に `usernameLower` が保存されるロジックが `UserService` に欠けている場合は追加します。
- **対象**: `lib/services/user_service.dart`

---

## 🧪 検証方法 (Artifacts利用)
- 修正が完了した UI（検索画面のボタンの状態変化など）は、Antigravity の機能（Artifacts やブラウザプレビューエージェント）を利用するか、スクリーンショット動画を通じて「フォロー・フォロー解除」が正しく切り替わることを提示します。
- ターミナルで `flutter analyze` がエラー 0 件になることを確認します。

---
※ この指示書 (`implementation_plan.md`) の内容に基づき、各ステップの実装を AI エージェントに依頼してください。
