# Project Context & Agent Sync Log (`CONTEXT.md`)

このファイルは、Gemini CLI（ターミナル）と Antigravity（IDE）の各エージェントが作業状況を同期するための共有ログです。作業の開始時と終了時に、エージェントはこのファイルを更新し、お互いの文脈を維持します。

---

## 🔄 Current Status (現在の状況)
- **Phase:** Performance Optimization & Feature Enhancement
- **Last Updated:** 2026-03-27
- **Active Agent:** Antigravity (IDE)
- **Current Task:** Planning Comprehensive UX Optimizations (Optimistic UI, Precaching, Skeletons)

---

## 📝 Recent Changes (直近の変更内容)

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
