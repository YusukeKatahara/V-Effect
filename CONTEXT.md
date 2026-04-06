# Project Context & Agent Sync Log (`CONTEXT.md`)

このファイルは、Gemini CLI（ターミナル）と Antigravity（IDE）の各エージェントが作業状況を同期するための共有ログです。作業の開始時と終了時に、エージェントはこのファイルを更新し、お互いの文脈を維持します。

---

## 🔄 Current Status (現在の状況)
- **Phase:** Performance Optimization & Feature Enhancement (Data Hardening Focus)
- **Last Updated:** 2026-04-06
- **Activeエージェント:** Antigravity
- **Current Task:** Established Comprehensive Coding Guidelines & Hardened Data Layer
- **Action:** Formulated project-wide coding standards in SKILL.md and implemented Firestore hardening for reaction persistence.


---

## 📝 Recent Changes (直近の変更内容)

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
