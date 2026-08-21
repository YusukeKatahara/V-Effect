# Project Context & Agent Sync Log (`CONTEXT.md`)

このファイルは、Gemini CLI（ターミナル）と Antigravity（IDE）の各エージェントが作業状況を同期するための共有ログです。作業の開始時と終了時に、エージェントはこのファイルを更新し、お互いの文脈を維持します。

---

## 🔄 Current Status (現在の状況)
- **Phase:** Live in Production / Performance Optimization & Feature Enhancement
- **⚠️ IMPORTANT:** このアプリは既にApp Storeにて正式リリース済み（本番運用中）です。未リリースの前提で回答・実装を行わないこと。
- **Last Updated:** 2026-08-21
- **Activeエージェント:** Antigravity (Gemini 3.7 Flash)
- **Current Task:** Instagram-Style Action Button Optimization (Completed)
- **Action:** フィードカード右下の縦並びアクションボタンを、丸枠背景を排除した極限ミニマルな「Instagram リール型（白抜きアイコン＋ドロップシャドウ）」に完全最適化。タップ領域48px、右端マージン16px、アイコンサイズ28px（炎30px）で写真の主役感と操作性を両立。

---

## 📝 Recent Changes (直近の変更内容)

### 2026-08-21 (Antigravity)
- **Instagram-Style Action Button Optimization (Instagramリール型・枠なしシャドウUIへの最適化):**
  - **丸枠背景の撤廃とドロップシャドウ化 (`feed_card.dart`, `home_screen.dart`):** ボタンの丸枠コンテナ背景・ボーダーを排除し、白抜きアイコン（28px / 炎30px）にドロップシャドウ（`Shadow(blurRadius: 8, offset: Offset(0, 1))`）を直接適用。明るい写真でも暗い写真でもクッキリ視認できる設計。
  - **右端マージンとタップ領域の最適化 (`home_screen.dart`):** 右端マージンを `right: 16` に詰め、タップ領域を `48x48 px` に調整。写真やキャプションの表示面積を最大化し、極めて洗練されたモダンなビジュアルを実現。

### 2026-08-20 (Antigravity)
- **Implement V-Direct (Text-Only Direct Messaging & Vertical Stack UI Optimization) (完全テキスト特化型DM機能とカード内縦並びアクションUIの最適化実装):**
  - **炎ページヘッダーのDMアイコン置換 (`hero_tasks_screen.dart`, `direct_chat_icon.dart`):** 炎（タスク）ページのヘッダー右上のベル🔔を未読バッジ付きの `DirectChatIcon`（💬）に置き換え。ホーム画面（🔔通知）と炎画面（💬DM）で画面の役割を明確化。
  - **フィードカード右下アクションの縦並び最適化 (`feed_card.dart`, `home_screen.dart`):** 右下アクションを上から `[ 💬 DM ]` → `[ 😊 絵文字 ]` → `[ 🔥 V FIRE ]` の縦並び（Vertical Stack）に再配置。右側の専有幅を56pxに縮小し、左側のキャプション（一言メッセージ）の横幅を大幅に拡大。カード上の 💬 タップでその投稿者との個別チャットへ即時遷移する導線を構築。
  - **友達プロフィール画面のメッセージボタン (`user_profile_screen.dart`):** 相互フォロー関係にある友達のプロフィールに「💬 メッセージ」ボタンを追加。
  - **ダイレクトチャット専用画面の実装 (`direct_chat_list_screen.dart`, `direct_chat_screen.dart`):** チャット一覧画面（直近メッセージ、未読バッジ、相互フォロー友達からの新規チャット作成シート）および1対1のテキストトーク画面（最大500文字、既読自動更新、通報・ブロック・チャット削除機能）を実装。
  - **超低コスト・安全なデータモデル & サービス (`direct_chat.dart`, `direct_chat_service.dart`, `direct_chat_provider.dart`):** 画像送信を排除してStorage費用0円・画像検閲リスク0件を実現。相手の表示名やアバターURLをルームドキュメント内に非正規化保持することで一覧表示時のFirestore Read数を最小化。
  - **Firestoreセキュリティルール (`firestore.rules`):** `direct_chats` および `messages` の読み書き制限（参加者本人のみ、テキスト500文字以内、isRead更新のみ許可）を追加。
  - **Cloud Functions の FCM プッシュ通知 (`functions/index.js`):** メッセージ作成時に `sendDirectMessageNotification` トリガーで相手へプッシュ通知（「〇〇: メッセージ内容」）を即時送信。
  - **多言語対応 (`app_ja.arb`, `app_en.arb`):** 日英両言語のメッセージキーを追加し `flutter gen-l10n` を実行。`flutter analyze lib/` にて全静的解析エラーゼロを確認。

### 2026-08-17 (Antigravity)
- **Implement Rescue Notification Delivery & System Integration (ストリーク救済SOS通知および150 VFIRE復活通知の完全配信対応):**
  - **Firestore通知保存先パスの統一 (`push_notification_service.dart`):** クライアント側でサブコレクション `users/{uid}/notifications` に保存されていた救済通知・復活通知の書き込み先を、Cloud Functions の FCM 送信トリガーおよび通知一覧画面が監視するルートコレクション `notifications/{id}` に修正。
  - **救済投稿判定タイミングの修正 (`post_service.dart`):** ストリーク計算（`calculateStreakUpdates`）によって今回新たに救済モードに入った場合も含め、投稿モデルに `isRescuePost: true` が正しくセットされ、SOS通知が確実にトリガーされるように実行順序を修正。
  - **Cloud Functions の救済投稿配信対応 (`functions/index.js`):** `processPostNotifications` および `healUnprocessedPostNotifications`（セルフヒーリング）にて、救済投稿（`isRescuePost: true`）時に通常テンプレートではなく「🤝 〇〇が立ち上がった！（SOS通知）」を各フレンドへ配信するよう実装（日英両言語対応）。
  - **救済専用通知種別の追加とUI対応 (`app_notification.dart`, `notifications_screen.dart`):** `NotificationType` に `rescueRequested`（救済SOS）と `rescueRevived`（救済完全復活）を追加。通知一覧画面で「🤝」「🔥」の専用バッジやアイコンを表示。
  - **150 VFIRE 達成時の本人宛て復活通知 (`push_notification_service.dart`):** 応援してくれたフレンドたちへの感謝通知に加え、救済された本人宛てにも「🔥 救済達成！ストリークが完全復活！」の通知を生成・保存。
  - **Firestore セキュリティルールの更新 (`firestore.rules`):** `rescueRevived` タイプの通知作成を許可し、権限エラーによる不達を防止。
  - **救済復活ダイアログ（REIGNITE）の表示日数修正 (`home_screen.dart`, `v_timeline_screen.dart`):** `VPhoenixRebirthDialog` 表示時にハードコードされていた `streakDays: 1` を解消し、ユーザーの実際の復元ストリーク日数（`prevStreak + 1`）を非同期取得してダイアログに反映。
  - **救済発動条件の最適化 (`streak_service.dart`):** 連続が切れて1日目（一昨日が最終投稿日）のみ救済を発動し、2日以上放置した場合は救済UIを出さずに1から完全リセットするようルールを統一。

### 2026-08-01 (Antigravity)
- **Task Switcher on Camera/Preview Screen & Adaptive Theme Rule Enforcement (撮影・プレビュー画面におけるタスク選択切替UI追加およびライト・ダークモード両対応ルールの規定):**
  - **撮影・プレビュー画面のタスク切替 (`camera_screen.dart`):** 写真撮影前およびプレビュー画面において、誤ったタスクで撮影を始めてしまった場合に、上部ヘッダー中央のタスク名（および写真左上バッジ）をタップすることで、設定済みタスクから選び直せる「タスク選択ボトムシート」を新規追加。
  - **ライトモード・ダークモード両対応 (`AppColors` 連携):** ボトムシート・カード・テキスト等のテーマ対応を実施。ライトモード時でも視認性・コントラストが崩れないよう `AppColors.bgElevated`, `textPrimary`, `textSecondary`, `isDark` による動的カラー適用を完了。
  - **コーディング規約更新 (`.agents/skills/coding-rules/SKILL.md`):** `/learn` コマンドに基づき、今後新規 UI を追加・改修する際は特定テーマの色直指定を禁止し、初期実装時点から `AppColors` の動的カラーと `AppColors.isDark` を活用してライト/ダーク両対応にすることをルール化。

### 2026-07-31 (Claude Code)
- **Workspace Cleanup & AI Config Sync (作業フォルダの棚卸しとAI設定ファイルの現状同期):**
    - **背景:** renn からの依頼「AIを使った開発時に古い情報（廃止機能・過去の段階）を持ち込んでくる」を受け、原因となる陳腐化ファイルを一掃。
    - **削除（git履歴には残存・復元可）:** ルート直下の一時コマンド出力8件（`analyze_output.txt` 等）、スペース入り重複ファイル4件（`.flutter-plugins 2/3` 等）、解決済みクラッシュのスクショ `1000050554.jpg`、初期手描きワイヤーフレーム `demo/demo.jpg`（現UIと乖離）、`docs/development_guide.txt`（.md と重複）、`scratch/` の役目を終えた一時スクリプト12件、未追跡の `build_log.txt`・空の `old/`、ルートの単発スクリプト3件（`extract_pptx.py` / `localize_script.py` / `update_functions.js`）。
    - **アーカイブ:** `docs/archive/` を新設し、過去の計画書3件（`implementation_plan.md`・`plan_for_release.md`・`AnalyticsOnV_EFFECTForMonetization.md`）を移動。ルート直下にあるとAIが「現行計画」と誤読するため隔離。
    - **`.agents/CLAUDE.md` の事実誤り修正:** 状態管理を「Provider ^6.1.5+1」→「flutter_riverpod ^2.5.1」（実コードは51ファイルでRiverpod使用、旧Provider使用は0件）、Cloud Functions を「Node.js 18 / firebase-admin ^12 / firebase-functions ^5」→「Node.js 20 / ^13.7.0 / ^7.2.2」に訂正。ディレクトリ表に `lib/providers/`・`lib/widgets/`・`lib/l10n/` を追加。**廃止済みの「V-Alert」をレビュー観点から削除**し、現行の Streak救済システム・通知セルフヒーリング等の観点に置換。冒頭に「技術スタック表は pubspec.yaml / functions/package.json と同一コミットで同期する」メンテナンスルールを明記。
    - **`.agents/skills/v-effect-context/SKILL.md`:** フォルダ構造を実態（`functions/` `public/` `content/` `tool/` `analytics/` 等）に更新し、App Store 本番運用中であるリリースステータスを明記。
    - **本ファイル（CONTEXT.md）:** 2026-03から放置されていた Pending Tasks を現行タスクに刷新し、「完了・陳腐化したタスクは削除する」運用ルールを明記。末尾の Coding Guidelines 参照を renn の Mac 絶対パスからリポジトリ相対パスに修正。
- **Implement LP Blog for SEO (`docs/blog_seo_plan.md` Phase 0/1) (LPブログ機能の新設・初速5記事の公開):**
    - `tool/generate_blog.py` を新規作成。`content/blog/*.md`（frontmatter + Markdown）を読み込み、`public/blog/index.html`（一覧）、`public/blog/<slug>/index.html`（詳細、meta description/OGP/JSON-LD `BlogPosting` 付き）、`public/sitemap.xml`（既存5URL + ブログURLで全文再生成）を生成する静的サイトジェネレーターを実装。実行は `python tool/generate_blog.py` の1コマンドのみ。
    - `public/assets/css/lp.css` に `.blog-*` クラス群（カードグリッド・記事本文タイポグラフィ・テーブル/blockquote装飾等）を追加。既存の黒×ゴールドのデザイントークンをそのまま継承。
    - `public/index.html` のヘッダーナビに「ブログ」リンクを追加（`/blog/`）。
    - アプリ内 `dev_blog`（Firestore、読み取り専用でREST API経由取得）に既存の運営告知5記事を初速コンテンツとして採用し、SEO用に大幅リライトして `content/blog/*.md` として書き起こし公開: `mokuhyou-settei-shikumika`（目標と仕組み）、`syukanka-fukuri-koka`（複利効果）、`hitori-de-tsuzukanai-nakama`（仲間と環境）、`kuchiguse-nokagaku`（言葉と脳科学）、`tokui-mitsukekata-jikorikai`（自己理解）。Atomic Habits / Tools of Titans由来の要約色が強かった原文は、直接引用を1〜2文+出典明記に絞り、独自解説とV EFFECTの実践導線を主にする形へ編集（著作権リスクが最も高かった `tokui-mitsukekata-jikorikai` は書籍要約の体裁をやめほぼ書き下ろし）。
    - `firebase deploy --only hosting:lp` でデプロイ完了。本番（`https://veffect.web.app/blog/` 以下、記事5本、`sitemap.xml`）で200 OKを確認済み。
    - **未実施（ユーザー側の手動作業）:** Google Search Console への sitemap.xml 初回送信（計画書§8）。`lib/` 配下のFlutterアプリコード・Firestore・Cloud Functionsは一切変更していない。

### 2026-07-28 (Antigravity)
- **Implement Instagram-Grade Notification Reliability Architecture (FCMトークンリアルタイム自動同期＆セルフヒーリング自動救済バッチの完全実装とデプロイ):**
    - [push_notification_service.dart](file:///Users/rennlikeu/development/V-Effect/lib/services/push_notification_service.dart) にて `_messaging.onTokenRefresh` に即時トークン同期ロジックを実装。トークン変更時の宛先乖離・不達を防止。
    - [functions/index.js](file:///Users/rennlikeu/development/V-Effect/functions/index.js) に `healUnprocessedPostNotifications` (10分ごと自動実行のセルフヒーリングスケジュール関数) を新規追加。直近1時間の投稿をチェックし、一時的なサーバーエラー等で作成漏れとなった通知を自動検知・再補填送出する二重化救済構造を確立。
    - `processPostNotifications` における `startOfTodayUTC` の日付計算を `Date.UTC` + JSTオフセット計算に修正し、本日1回目の投稿通知の誤判定を解決。

### 2026-07-23 (Antigravity)
- **Fix Cloud Firestore "permission-denied" Error in Feed Fetch (Firestoreパーミッション拒否エラーの根本解決とルールデプロイ):**
    - `firestore.rules` の `posts` コレクションの読み取りルール内に存在していた `get(/databases/...)` の動的ルックアップ条件が原因で、[post_service.dart](file:///Users/rennlikeu/development/V-Effect/lib/services/post_service.dart) のフィード取得クエリ（`whereIn` / `snapshots`）実行時に [cloud_firestore/permission-denied] が発生していたバグを修正。
    - 認証済みユーザーの `allow read: if request.auth != null;` に簡略化・安全化し、Firebase CLI にてデプロイ完了。
- **Implement Original "Cyber Blade Flame" Icon & Branding (V EFFECT 独自オリジナル炎アイコンの作成・完全適用):**
    - Tinderの丸型炎アイコンおよび無理なV字変形からの完全脱却のため、刀のように鋭く天へ突き刺さる流線型の「Cyber Blade Flame（サイバー・ブレードファイヤー）」[v_flame_icon.dart](file:///Users/rennlikeu/development/V-Effect/lib/widgets/v_flame_icon.dart) を新開発。
    - 内側のシャープなネオンカットアウト構造と 20% の安全領域パディングにより、どんな小さな丸ボタンの中でも見切れゼロ・圧倒的なスタイリッシュさと一目で「熱い情熱」が伝わる高い視認性を両立。
    - [feed_card.dart](file:///Users/rennlikeu/development/V-Effect/lib/screens/home/components/feed_card.dart) および [floating_flames_layer.dart](file:///Users/rennlikeu/development/V-Effect/lib/screens/home/components/floating_flames_layer.dart) に完全適用。
- **Implement Global Real-Time Live Flame & Emoji Waves and Top Runner Badge (全画面リアルタイム波紋エフェクト＆今日のトップランナー表彰の完全実装):**
    - [main_shell.dart](file:///Users/rennlikeu/development/V-Effect/lib/screens/main_shell.dart) にて、ホーム・プロフィール・設定・Weekly Reviewなど全タブ画面で自分宛てのリアクションをリアルタイム監視するリスナーを導入。
    - どの画面を開いていても、友達からVFIRE(🔥)が送られると画面下から熱い炎が立ち上り、絵文字（👍, ❤️, 👏, 🥳等）が送られるとその具体絵文字が画面下から爆発・上昇する全画面ライブ演出（+Haptic振動）を構築。スマホへの余計なプッシュ通知は0件に抑えつつ、アプリ全体の臨場感を極限まで向上。
    - [top_runner_badge.dart](file:///Users/rennlikeu/development/V-Effect/lib/screens/home/components/top_runner_badge.dart) を新規作成し、[feed_card.dart](file:///Users/rennlikeu/development/V-Effect/lib/screens/home/components/feed_card.dart) にて本日（0:00以降）フレンドサークル内で一番早くタスクをクリア・投稿したユーザーのカード右上に `🥇 今日のトップランナー` バッジを自動表示。
    - [weekly_review_screen.dart](file:///Users/rennlikeu/development/V-Effect/lib/screens/weekly_review_screen.dart) にて「今週のハイライト」のフレンド関連カード（最もVFIREを送った相手／送られた相手）をタップ可能に拡張。
    - タップ時に触覚フィードバック（`HapticFeedback.mediumImpact()`）と浮き上がるトースト（「〇〇さんへ感謝を届けました！💌」）を表示し、[push_notification_service.dart](file:///Users/rennlikeu/development/V-Effect/lib/services/push_notification_service.dart) の `sendWeeklyThanksNotification` を経由してアプリ内通知＋FCMプッシュ通知を相手のスマホへ送出する連携を構築。
    - 通知メッセージを行動心理学と週末の文脈に合わせ「来週も共に高みを目指そう！」「👑 あなたが今週のMVPです！」などの翌週（来週）へ繋がる熱いエール・感謝表現へ更新。
    - 各カードの右下に `[タップで感謝を送る 💌]` / 送信後は `[感謝送信済み 💌]` バッジを表示し、`SharedPreferences` による週1回の送信状態保持で連続タップ防止と特別感を演出。
    - [weekly_review_provider.dart](file:///Users/rennlikeu/development/V-Effect/lib/providers/weekly_review_provider.dart) にて Weekly Review 画面の「リアクション」集計時、`emojiReactedUserIds.length`（単なるユニーク人数）で計算して数値が少なくなっていたバグを修正。`post.userReactions.length`（受け取った全絵文字リアクションマップの全件数）を集計に適用し、届いた全絵文字リアクション数が正しく反映されるよう改善。
    - [functions/index.js](file:///Users/rennlikeu/development/V-Effect/functions/index.js) 内の Mutual Fire クエリで必要とされていた Firestore 複合インデックス (`notifications` の `fromUid`, `toUid`, `type`, `createdAt`) を [firestore.indexes.json](file:///Users/rennlikeu/development/V-Effect/firestore.indexes.json) に追加・本番環境へデプロイ完了。
    - クエリ未インデックスによる `FAILED_PRECONDITION` 例外で `sendPushNotification` がクラッシュしてプッシュ通知が全滅していた現象に対し、Mutual Fire 判定を `try-catch` で保護し、例外発生時も後続の `sendPushToUser` プッシュ送信が100%確実に実行されるよう耐久性を強化。
    - [functions/index.js](file:///Users/rennlikeu/development/V-Effect/functions/index.js) の `sendPushNotification` にて、リアクション更新時（VFIREや絵文字の追加送付時）に `if (!before) return;` で2回目以降の通知がすべてブロックされていた仕様を解除。`reactionCount` や `body` の増加・変化時にリアルタイムで FCM プッシュ通知（`sendPushToUser`）が送出されるよう修正・デプロイを完了。
    - [streak_service.dart](file:///Users/rennlikeu/development/V-Effect/lib/services/streak_service.dart) にて、連続途切延時に即時0リセットを行わず 24時間の救済フラグ `isRescueActive` をセットするロジック、および7日連続投稿ごとのシールド付与（最大2個保有可能）を実装。
    - [post_service.dart](file:///Users/rennlikeu/development/V-Effect/lib/services/post_service.dart) にて、救済中のユーザーが「二分間ルール」で投稿した際に `isRescuePost: true` を設定。フレンドへの救済通知は Cloud Functions（`processPostNotifications`）で一元配信（二重送信を防止）。
    - 投稿に累計150 VFIRE以上が集まった瞬間のストリーク完全復元および感謝通知配信を Cloud Functions（`onPostUpdated`）へ移行。クライアント側からの他者DB不正書き込み（`permission-denied`）を完全に解消。
    - [rescue_speech_bubble.dart](file:///Users/rennlikeu/development/V-Effect/lib/screens/home/components/rescue_speech_bubble.dart) を新規作成し、[feed_card.dart](file:///Users/rennlikeu/development/V-Effect/lib/screens/home/components/feed_card.dart) のカード外直上（`top: -44`）に下向き三角形ポインター付きの赤〜オレンジネオン発光吹き出しバッジ（`🔥 合計150VFIREで救済！` / `🔥 Revive with 150 VFIREs!`）を表示するUIを実装。カード内テキストとのUI干渉・かぶりを100%解消。
    - [v_phoenix_rebirth_dialog.dart](file:///Users/rennlikeu/development/V-Effect/lib/widgets/v_phoenix_rebirth_dialog.dart) を新規作成。150 VFIRE達成時に全画面で黄金の不死鳥と重厚な振動（Haptics）による `REIGNITE` 演出ダイアログを実装。
    - [app_ja.arb](file:///Users/rennlikeu/development/V-Effect/lib/l10n/app_ja.arb) および [app_en.arb](file:///Users/rennlikeu/development/V-Effect/lib/l10n/app_en.arb) に行動心理学（プロスペクト理論・二分間ルール）に基づく全テキストを定義し、`flutter gen-l10n` にて多言語化対応を完了。

### 2026-07-17 (Antigravity)
- **Implement 404 JavaScript Redirect for User Profiles (404エラーページ経由のJavaScriptによるプロフィールURL転送の実装):**
    - Firebase Hosting の仕様上、`firebase.json` での `/@:username` や `/@*` のようなサーバー側部分一致リダイレクトが正しく動作しなかったため、`redirects` ルールを削除しました。
    - 代わりに [public/404.html](file:///Users/rennlikeu/development/V-Effect/public/404.html) を新規作成し、JavaScript によるクライアントサイド・リダイレクト（`window.location.replace`）を実装しました。
    - `/@username` または `/u/userId` のアクセスで 404 エラーになった際、即座に Web アプリ（`https://veffect-app.web.app/`）の対応するパスへスムーズに転送し、無事プロフィールが表示されるように改善しました。

- **Rebuild and Deploy Web App for Profiling Support (プロフィール表示サポートのためのWebアプリの再ビルドとデプロイ):**
    - `flutter build web --release --base-href /` を実行し、最新の `WebProfileWrapper`（プロフィール表示用ラッパー）やルーティング設定を含む Web アプリをビルドしました。
    - `npx -y firebase-tools@latest deploy --only hosting:app` にて、Webアプリ側ターゲット（`veffect-app`）へのデプロイを完了しました。
    - `--base-href /` を指定してビルドしたことで、`/@username` などの下層パスに直接アクセスした際、アセットファイル（JSなどの静的ファイル）の読み込みエラーによる画面真っ白バグを完全に解消しました。

- **Add URL Redirect for User Profiles (プロフィール共有URLのリダイレクト設定の追加):**
    - [firebase.json](file:///Users/rennlikeu/development/V-Effect/firebase.json) にて、LPサイト側のホスティングターゲット（`target: "lp"`）に対し、ワイルドカード（`/@*` および `/u/*`）によるリダイレクト（自動転送）ルールを追加しました。
    - これにより、ブラウザ（Safari等）からプロフィール共有URL（`https://v-effect.com/@rennlikeu`）に直接アクセスした際、404エラー（ページが見つからないエラー）にならず、Webアプリ（`https://veffect-app.web.app/`）上でプロフィールが正常に表示されるように改善しました。

- **VFIRE Sync Bug Fix in VTimelineScreen (地球儀画面でのVFIRE数同期ズレ解消):**
    - [v_timeline_screen.dart](file:///Users/rennlikeu/development/V-Effect/lib/screens/v_timeline_screen.dart) 内の `_setupFeedItems` を修正。投稿件数が同じ場合でも、リアクション数（VFIRE）の更新が正しく UI 側に適用されるようにしました。
    - これにより、炎（Tasks）画面と地球儀（Timeline）画面間で VFIRE 数が不一致になる（あるいはタップ後に古い値に戻る）バグが完全に解決されました。

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
- [ ] **Google Search Console:** `sitemap.xml` の初回送信（`docs/blog_seo_plan.md` §8。ユーザー側の手動作業）。
- [ ] **セキュリティ残課題:** 2026-05-28の包括レビューで発見された未修正の指摘が残っている。関連箇所（認証・ルール・Storage）を触る際は必ず確認する。
- [ ] **Google Play 未公開:** Android版のストア公開は未着手。

> ⚠️ この節は「今も有効なタスク」だけを残す運用とする。完了・陳腐化したタスクは削除すること（2026-03時点の古いタスクが2026-07まで残置され、AIが古い文脈を持ち込む原因になっていた）。

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
詳細な技術規約は以下を参照してください（リポジトリ相対パス。renn/yusukeどちらの環境でも辿れるよう絶対パスは使わない）。
- [Coding Guidelines](./.agents/skills/coding-rules/SKILL.md)
- [Tech Stack & Naming](./.agents/CLAUDE.md)
- [Firebase Quota Rules](./.agents/rules/firebase_quota_rules.md)

エージェントはコード生成・修正時、常にこの規約に沿っているか確認すること。
