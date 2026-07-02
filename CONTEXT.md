# Project Context & Agent Sync Log (`CONTEXT.md`)

このファイルは、Gemini CLI（ターミナル）と Antigravity（IDE）の各エージェントが作業状況を同期するための共有ログです。作業の開始時と終了時に、エージェントはこのファイルを更新し、お互いの文脈を維持します。

---

## 🔄 Current Status (現在の状況)
- **Phase:** Live in Production / Performance Optimization & Feature Enhancement
- **⚠️ IMPORTANT:** このアプリは既にApp Storeにて正式リリース済み（本番運用中）です。未リリースの前提で回答・実装を行わないこと。
- **Last Updated:** 2026-07-01
- **Activeエージェント:** Antigravity (Idle)
- **Current Task:** Scalable Daily Stats & Summarized Trends (Completed)
- **Action:** Implemented createDailyTaskStats to summary posts at 1:50 JST, and refactored aggregateTrendingTasks at 2:00 JST to merge summaries (14 docs) instead of scanning posts.


---

## 📝 Recent Changes (直近の変更内容)

### 2026-07-01 (Antigravity)
- **Scalable Daily Stats & Summarized Trends (日次確定サマリー方式によるデータスケール対策):**
    - [functions/index.js](file:///Users/rennlikeu/development/V-Effect/functions/index.js) に `createDailyTaskStats` スケジュール関数（毎日午前1時50分実行）を新規追加。前日の投稿（JST基準）を集計し、加重スコアをまとめた日次サマリーを `daily_task_stats` コレクションに作成する処理を実装しました。
    - `aggregateTrendingTasks`（毎日午前2時00分実行）を、過去14日間の `posts` を直接全件取得する方式から、過去14日分の日次サマリー（計14件のドキュメント）をマージする方式へ移行。これにより、ユーザー数が急増した際も深夜バッチの Firestore 読み込み数（Read数）が最小化され、課金コストがほぼ増えないスケーラブルなアーキテクチャとなりました。

### 2026-06-30 (Antigravity)
- **Weighted Trend Scoring & Hot Badge UI (トレンドの加重スコアリングと急上昇バッジ表示):**
    - [functions/index.js](file:///Users/rennlikeu/development/V-Effect/functions/index.js) 内の `aggregateTrendingTasks`（毎日午前2時のバッチ処理）を更新。単純カウントから、VFIRE/絵文字リアクション数および投稿者のストリーク（継続日数）を加味した重み付けスコア（加重スコアリング）に変更しました。
    - 直近14日間のデータを取得し、前週比で **1.3倍（30%増）以上** に急増しているタスクに対して `isTrending: true` を判定・保存する急上昇（Velocity）検知ロジックを実装。
    - [trending_tasks_bottom_sheet.dart](file:///Users/rennlikeu/development/V-Effect/lib/screens/profile/components/trending_tasks_bottom_sheet.dart) にて、急上昇トレンドの横に「🔥 HOT」バッジを表示する UI を追加し、長いテキストに対しても `Flexible` / `ellipsis` によるレイアウト崩れ対策を施しました。
- **AI Trend Categorization & Topic Hierarchy (AI統計のトピック階層化):**
    - [functions/index.js](file:///Users/rennlikeu/development/V-Effect/functions/index.js) 内の `onPostCreated` にて、Gemini API の構造化出力スキーマに `sub_activity`（小カテゴリ）を追加。
    - Firestore の `posts` ドキュメントに `aiSubActivity` フィールドを保存するように拡張し、3階層でのデータ蓄積を可能にしました。

### 2026-06-18 (Gemini CLI)
- **Unify Game Trends to "Ranked Match" (ランク戦への名称統一):**
    - [functions/index.js](file:///Users/rennlikeu/development/V-Effect/functions/index.js) 内の Gemini API によるタスク名寄せプロンプトを更新し、ゲーム関連の努力を「ランク戦」と命名するように調整しました。
    - ウィークリートレンドの集計ロジックを修正し、「ゲーム」「Game」などの抽象的な名称を自動的に「ランク戦」にマッピングするように変更しました。
    - [functions/force_trends.js](file:///Users/rennlikeu/development/V-Effect/functions/force_trends.js) の手動集計スクリプトも同様に「ランク戦」へ統一されるよう修正しました。
    - これにより、遊びの「ゲーム」ではなく、LoLやValorantなどの本気で取り組む「ランク戦」としての努力が正しくランキングに反映されるようになります。

### 2026-06-17 (Gemini CLI)
- **Unify Streak Text Color on Profile Pages (プロフィールページのストリーク文字色の統一):**
    - [profile_header_section.dart](file:///Users/rennlikeu/development/V-Effect/lib/screens/profile/components/profile_header_section.dart) および [user_profile_screen.dart](file:///Users/rennlikeu/development/V-Effect/lib/screens/user_profile_screen.dart) にて、統計情報の「STREAK（ストリーク）」というラベルテキストの色を、炎アイコンや数値と同じティア色（ランクに応じた色）に変更しました。
    - これにより、ストリーク項目全体が統一されたテーマカラーで表示されるようになり、視覚的な一貫性が向上しました。
    - 「Following」や「Followers」のラベル色は従来通り `AppColors.textSecondary` を維持しています。

### 2026-06-12 (Antigravity)
- **Adjust Top-Left UI Padding on HeroTasksScreen (カード左上UIの位置調整):**
    - [hero_tasks_screen.dart](file:///Users/rennlikeu/development/V-Effect/lib/screens/hero_tasks_screen.dart) 内のカード左上のUIブロック（タスク名、起床時間、音楽情報など）の余白を `EdgeInsets.fromLTRB(40, 40, 40, 120)` から **`EdgeInsets.fromLTRB(24, 24, 24, 120)`** に縮小しました。
    - カードの角丸（24px）の内側に美しく収まるアライメント（位置合わせ）になり、しっかりと左上に寄ったレイアウトに改善しました。
- **Fix Caption Disappearance and Line-Breaking Bug on HeroTasksScreen (キャプション消失と不自然な改行・折り返しバグの修正):**
    - [hero_tasks_screen.dart](file:///Users/rennlikeu/development/V-Effect/lib/screens/hero_tasks_screen.dart) にて、直前のUI編集で消失してしまった「自分の一言（キャプション）」のUIブロックを復元しました。
    - 右側に位置する「リアクションアバター群」を横並びのRowから外し、V FIREボタンの真上に独立して配置（`Positioned(bottom: 124)`）することで、キャプションの横幅を最大約294pxまで劇的に拡大し、不自然な改行バグを完全に解決しました。
- **Redesign Caption UI to IG Reels Style (キャプションUIをIGリール風デザインに変更):**
    - [hero_tasks_screen.dart](file:///Users/rennlikeu/development/V-Effect/lib/screens/hero_tasks_screen.dart) および [home_screen.dart](file:///Users/rennlikeu/development/V-Effect/lib/screens/home_screen.dart) の両方において、キャプションの表示スタイルを従来の「Zenly風の吹き出し（グレー背景）」から「IGリール風」のスタイルへ一新しました。
    - アイコンとユーザー名が横並びになり、その直下に背景なしの透過テキスト（自然なドロップシャドウ付き）が表示されるようになり、標準フォント（SF Pro等）が適用されるため、より洗練されたIGライクな見た目と統一感を実現しました。
    - [hero_tasks_screen.dart](file:///Users/rennlikeu/development/V-Effect/lib/screens/hero_tasks_screen.dart) 内のタスクカード上部タスク名のフォントサイズを自動調整する自作カスタムウィジェット `_AutoSizeText` を導入しました。
    - 標準の `TextPainter` を用いて描画幅を測定し、1行に収まるまでフォントサイズを最大 `22` から自動で縮小します。
    - 極端に長いタスク名（目安30文字以上）で文字が潰れてしまわないよう、最小フォントサイズの下限を `14` に設定し、それを下回る場合のみ最大2行の折り返し表示を許可します。
    - トリガーやご褒美がない場合のタスク名表示および美麗ステップUI内のタスク名表示の双方に適用しました。
    - `flutter analyze` で静的解析エラー・警告（未使用パラメータ含む）がないことを確認しました。
- **Mutual Follow Social Proof on UserProfileScreen (他ユーザーのプロフィール画面での共通フォロー表示):**
    - [app_ja.arb](file:///Users/rennlikeu/development/V-Effect/lib/l10n/app_ja.arb) と [app_en.arb](file:///Users/rennlikeu/development/V-Effect/lib/l10n/app_en.arb) に、共通のフォロー関係を表す翻訳キー（`mutualFollowedBy`, `mutualFollowedByAndOthers`）を追加しました。
    - `flutter gen-l10n` を実行して localization クラスを更新しました。
    - [user_profile_screen.dart](file:///Users/rennlikeu/development/V-Effect/lib/screens/user_profile_screen.dart) にて、自分と対象ユーザーの共通のフォロー（自分の `following` と相手の `followers` の積集合（共通する要素の集まりのこと））を計算するロジックを実装しました。
    - 最大3名の共通フォローユーザー情報を `FriendService.instance.getUsersByUids()` で一括ロードするようにしました。
    - フォローボタンの下部に、アバター画像が重なって並ぶ `Stack`（ウィジェットを重ねて配置するレイアウト）と、動的に言語に応じたテキスト（「○○、□□、他N人がフォローしています」）を生成するUIを追加しました。
    - `flutter analyze` で静的解析エラーがないことを確認しました。
- **Post Elapsed Time Display on HomeScreen (ホーム画面の投稿経過時間表示):**
    - [app_ja.arb](file:///Users/rennlikeu/development/V-Effect/lib/l10n/app_ja.arb) と [app_en.arb](file:///Users/rennlikeu/development/V-Effect/lib/l10n/app_en.arb) に、経過時間を表す翻訳キー（`timeNow`, `timeMinutesAgo`, `timeHoursAgo`, `timeDaysAgo`）を追加しました。
    - `flutter gen-l10n` で localization クラスを同期しました。
    - [home_screen.dart](file:///Users/rennlikeu/development/V-Effect/lib/screens/home_screen.dart) 内に、投稿日時（`createdAt`）と現在時刻の差分から経過時間テキストを生成する `_formatPostTime` メソッドを実装しました。
    - タスク名が表示される吹き出しバッジの右隣に、少しスペースを空けて経過時間をプレーンテキストで表示するようにしました（例: `[Quest] 3時間`）。
    - 背景画像（写真）と同化して文字が見えなくならないよう、テキストに薄いドロップシャドウ（`Shadow`（影））を適用して視認性を高めました。
- **Own Caption Display on HeroTasksScreen (自分の投稿への一言表示をフレンドカードと完全統一・改行不具合解消):**
    - [hero_tasks_screen.dart](file:///Users/rennlikeu/development/V-Effect/lib/screens/hero_tasks_screen.dart) 内の一言（キャプション）表示のUIを、ホーム画面のフレンド投稿カードと**完全に同一のデザインおよび横幅の自動調整（RowとExpanded）構造**に統合・統一しました。
    - 既存の個別 `Positioned`（V FIREボタン、アバター、キャプション）をすべて削除し、単一の `Positioned(bottom: 32, left: 20, right: 20)` 内の `Row` と `Expanded` に統合しました。これにより、キャプション吹き出しの最大横幅が右側のボタン幅を避けて自動計算されるようになり、不要な極端な改行（折り返し）が発生するバグを解決しました。
    - 吹き出し本体（グレー背景、最大幅240px、明朝体の `GoogleFonts.notoSerifJp`）、ちっちゃなドット、自分自身のアバター画像、ユーザー名、装備中のバッジ（`VBadgeWidget`）を縦並びで表示する同一デザインを完全に再現しました。
    - 自分のアバター情報（画像URL、名前、バッジ画像URL、バッジアニメーション）をロードするため、`_loadData` 内でFirestoreの `users/{uid}` ドキュメントから自分自身の最新プロフィール情報を取得して状態変数に格納するロジックを実装しました。
    - 以前 `Column`（縦並び配置のレイアウト）の中に残っていた古いキャプション表示ウィジェットを、完了時・未完了時の両ブロックから完全にクリーンアップしました。

### 2026-06-11 (Antigravity)
- **Streak Milestone Notifications (20日・30日・50日・70日・90日・110日・130日連続達成時の特別通知実装):**
    - `functions/index.js` の `onUserStreakUpdated` および `processPostNotifications` 内のマイルストーン判定リストに `20`, `70`, `90`, `110`, `130` を追加しました（`30`, `50` は元から存在）。
    - 20日「脳の書き換え」、および30日・50日・70日連続達成時の「名作SFオマージュ三部作」（電気羊 / HAL9000の警告 / 月は無慈悲な夜の女王）の通知を設定。
    - 90日・110日・130日達成時の「物理法則三部作」（慣性の法則 / 独自の重力場 / 物理法則の誕生）の通知を設定。
    - 20日・50日の通知の接続記号を冷静な「。」に、それ以外の熱量の高いものは「！」に調整し、以前のタイポを修正。
    - `node --check` コマンドにより構文上の問題がないことを検証しました。

### 2026-06-02 (Antigravity)
- **App Version Update to ver1.3.2 (アプリバージョンのver1.3.2への更新):**
    - `pubspec.yaml` のアプリバージョンを `1.3.1+10` から `1.3.2+11` にアップデートしました。
    - `flutter pub get` および `flutter build ios --config-only` を実行し、Xcodeのビルド設定ファイル（`Generated.xcconfig`）まで最新化を同期しました。
- **Widget UI Optimization (ウィジェットUIの最適化):**
    - ホーム画面ウィジェットの「MONTHLY %」表示を廃止し、左上に英語の月名（例：June）、左下にSTREAK（ゴールド）を表示するようSwiftおよびFlutter側のウィジェット連携ロジックを最適化しました。

### 2026-05-31 (Antigravity)
- **App Version Update to ver1.3.1 (アプリバージョンのver1.3.1への更新):**
    - `pubspec.yaml` のアプリバージョンを `1.3.0+9` から `1.3.1+10` にアップデートしました。
    - `flutter pub get` および `flutter build ios --config-only` を実行し、Xcodeのビルド設定ファイル（`Generated.xcconfig`）まで最新化を同期しました。
- **In-App Review Implementation for ASO:**
    - `in_app_review` パッケージを追加し、iOS向けのApp Storeレビューリクエストを組み込みました。
    - `AppReviewService` を実装し、ストリーク数が `10日` の節目に達した際に一度だけレビューをリクエストするように設定。すでに10日を超えているユーザーは次回達成時に一度だけ表示されるよう判定を工夫しました。
    - `HeroTasksScreen` 内の「プレミアム・ヴィクトリー」の7秒間の演出（`PostSuccessDialog`）が完全に終了した直後にポップアップが表示されるようにし、ユーザーの達成感の余韻の中で★5レビューを促すよう最適化しました。

### 2026-05-29 (Antigravity)
- **App Version Update to ver1.2 (アプリバージョンのver1.2への更新):**
    - `pubspec.yaml` のアプリバージョンを `1.1.1+5` から `1.2.0+6` にアップデート（バージョン表記を1.2.0、ビルド番号（端末側での識別番号）を6に設定）しました。
    - `flutter pub get`（パッケージ情報を同期するコマンド）および `flutter build ios --config-only` を実行し、Xcodeのビルド設定ファイル（`Generated.xcconfig`）まで一気通貫で最新化しました。
- **Rule Addition in GEMINI.md (ルール追加):**
    - 今後エージェントがバージョンを変更する際、Xcode側でのバージョン不整合を防ぐため、`pubspec.yaml` 更新時に `flutter pub get` と `flutter build ios --config-only` コマンドを必ず自動で連続実行する開発ルールを `GEMINI.md`（エージェント設定ファイル）に規定しました。

### 2026-05-25 (Antigravity)
- **Smooth Date Reset Implementation:**
    - `PostService` に `notifyUpdate()` を追加し、手動でのアプリ全体更新トリガーを実装。
    - `main.dart` に `_scheduleMidnightTimer` を導入し、アプリ起動中に深夜0時をまたいだ際の自動更新を実現。
    - `AppLifecycleState.resumed` 時に前回確認日（`_lastCheckedDate`）と比較し、スリープ・バックグラウンドからの復帰時に自動で画面をリフレッシュする処理を追加。

### 2026-04-06 (Antigravity)
- **Data Hardening & Persistence:**
    - Firestore `withConverter<Post>` による型安全なデータ層を構築。
    - パース例外を許容する `resilient parsing` と、ドット記法による `atomic updates` を実装。
    - リアクション情報を Map と List の冗長チェックで判定する仕組みを導入。
- **Coding Guidelines Establishment:**
    - `.agents/skills/coding-rules/SKILL.md` を全面的に刷新。レイヤードアーキテクチャ、データ層の硬化、モノクロームデザイン言語を明文化。

### 2026-03-28 (Gemini CLI)
- **Premium Victory Animation:**
    - タスク投稿後の演出を「プレミアム・ヴィクトリー」へと大幅に強化。
    - **V-Flash:** 投稿完了時に画面全体を包む閃光と `heavyImpact` 振動を追加。
    - **Victory Text:** 高級感のある「VICTORY」タイポグラフィが浮かび上がる演出を実装。
    - **Sublimation Sequence:** 他のカードが一時的に退避し、対象のカードが中央で「DONE」へと昇華する 2.0秒 のシーケンスアニメーションを構築。
    - **Tier-based Aura:** ユーザーのストリークに応じたティアカラー（ゴールド等）の後光（オーラ）を背後に配置。
    - **Synchronized Haptics:** 演出の各ステージ（溜め、閃光、出現）に合わせた触覚フィードバックを詳細に設定。

### 2026-03-28 (Antigravity)
- **Gemini CLI Setup:**
    - `GEMINI.md` をルートに作成。既存の `.agents/skills` および `CONTEXT.md` をインポートし、CLI からもプロジェクト全体の文脈を参照可能に設定。
    - `.geminiignore` を作成し、不要なビルドファイルや機密ファイルを CLI の文脈から除外。


### 2026-03-27 (Antigravity)
- **Features & UI:** 
    - 通知画面の全面改修（アバター表示、時間表示、タップ遷移機能、未読インジケーターの追加）。
    - 投稿へのリアクション通知（🔥激しい炎）の本文に、個別のヒーロータスク名が含まれるように修正。

### 2026-03-27 (Gemini CLI)
- **UI & Feature Improvements:**
    - **Crop Feature:** `image_cropper` を導入し、投稿写真の撮影後に 9:16 でクロップ（切り抜き）できる機能を実装。
    - **Compact Notifications:** 通知画面のデザインを全面的にリファクタリング。カード形式を廃止し、シームレスなリスト形式（細い区切り線）に移行。アバターの小型化やタイポグラフィの調整により、モダンでスタイリッシュな見た目に変更。
    - **Layout Restoration:** タスクカードのレイアウトをユーザーの要望に基づき元の構成（QUESTラベル上部、タスク名下部）に完全に復元。
- **UX Improvements:**
    - **Optimistic UI:** プロフィール画面のフォローボタンを即時反映化。
    - **Skeleton Screens:** ホーム画面起動時およびプロフィール画面ロード時に、スピナーではなくスケルトン（骨組み）を表示するように変更。
    - **Image Precaching:** ホーム画面のスワイプ時に次のカードの画像をプリキャッシュし、表示の遅延を解消。
    - **Story Optimization:** フィード画面でのフレンド切り替え時に上部アイコンを維持し、画像エリアのみスケルトン表示にすることで体感速度を向上。
- **Performance:** 
    - `HeroTasksScreen` の `setState` を削減し `ValueNotifier` に移行（発熱対策）。高速回転時のクラッシュ防止ロジック（スタック数制限やMod演算の修正）を追加。
    - `CachedNetworkImage` + `ResizeImage` による画像デコード負荷の軽減。
    - `main.dart` の初期化プロセス、および `PostService` のデータ取得を並列化（ロード時間短縮）。
- **Features:** 
    - ホーム画面の投稿カードからユーザーアイコン/名前タップで `UserProfileScreen` への遷移を実装。 initialData を渡すことで爆速遷移を実現。

---

## 📌 Pending Tasks & Context (保留中のタスクとコンテキスト)
- [x] **MCP Sync:** Antigravity側でもこの `CONTEXT.md` を読み込み、作業開始時に「Active Agent」を自分に書き換える運用を開始する。
- [ ] **Optimization Check:** ユーザーからの「ロードが長い」という指摘に対し、Firestoreクエリの最適化（`createdAt` フィルタ追加）を行ったため、インデックス作成が必要な場合がある。
- [ ] **Next:** 別の機能追加（通知詳細など）への着手、または現在の最適化結果のユーザー確認。

---

## 🛠 Agent Operation Rules (エージェント運用ルール)
1. **作業開始時:** 
   - `CONTEXT.md` を読み込み、他方のエージェントがやり残したことや最新の状態を把握する。
   - `Active Agent` を自分の名前に更新する。
2. **作業終了時（またはターン交代時）:**
   - `Recent Changes` に箇条書きで実施内容を追記する。
   - `Pending Tasks` を更新し、次に引き継ぐべき情報を残す。
3. **競合回避:**
   - 同じファイルを同時に編集しないよう、タスクの範囲を明確にする。

---

- **Victory at All Costs**: 達成感の最大化。

---

## 🏗 Coding Guidelines Reference
詳細な技術規約は以下を参照してください。
- [Coding Guidelines](file:///Users/rennlikeu/Desktop/V-Effect/.agents/skills/coding-rules/SKILL.md)

エージェントはコード生成・修正時、常にこの規約に沿っているか確認すること。
