# 役割と目的
あなたはFlutter/Firebase開発の専門家として、V-Effectアプリに「ローカルバッチ型の高度なアナリティクス収集機能 (action_logs)」を実装します。
LLMやPython/MATLABを用いた仮説検証（リテンション分析、ペルソナ特定等）のための生データ基盤を構築することが目的です。

# 絶対条件（Safety & UX）
1. 既存体験の保護: すでにいるユーザーのアプリ体験を一切損ねないでください。Firestoreの書き込み失敗や遅延によってUIが固まることは許されません（非同期とエラーハンドリングを徹底）。
2. 既存ログの維持: 現在 `analytics_service.dart` で行われている `FirebaseAnalytics` への送信処理は絶対に削除せず、そのまま共存させてください。
3. データ正規化の徹底: `action_logs` への保存データには、年齢や性別などの「静的データ」は含めません。分析時にPython等で `uid` を使ってJOINすることを前提とし、可変データ（イベント固有パラメータ）と `uid` だけを保存して通信量を最小化してください。

# 実装ステップと要件

## 1. AnalyticsService の改修 (`lib/services/analytics_service.dart`)
- ローカルにイベントを溜め込むキュー（List<Map<String, dynamic>>）を作成してください。
- 溜まったログを `Firestore` の `action_logs` コレクションに `WriteBatch` を用いて一括送信するメソッド `flushBatch()` を実装してください（エラー時は安全に握り潰すかリトライする）。
- キューの件数が一定（例：10件）に達した際に、自動で `flushBatch()` が呼ばれるようにしてください。
- 新しい内部メソッド `_logToActionLogs(String eventName, Map<String, dynamic> parameters)` を作成し、既存のログ送信処理（`logAppOpen`, `logPostCreated`, `logReactionSent`等）の末尾で呼び出されるように追加してください。
- `action_logs` の各ドキュメントに含める必須フィールド: `uid`, `timestamp` (FieldValue.serverTimestamp()), `eventName`, `appVersion`, `platform`, および引数の `parameters`。

## 2. ライフサイクル監視でのバッチ確実送信
- アプリのベースとなる画面（例：`lib/main.dart` のMyApp、または適当なルートウィジェット）に `WidgetsBindingObserver` を実装してください。
- アプリが `AppLifecycleState.paused` または `detached`（バックグラウンド移行時）になった瞬間に `AnalyticsService.instance.flushBatch()` を呼び出し、ローカルに溜まったログを確実にFirestoreに送信しきるようにしてください。

## 3. リアクション詳細パラメータの追加 (`lib/services/post_service.dart` & `AnalyticsService`)
- `AnalyticsService.logReactionSent()` の引数を拡張し、`String targetUid`, `String targetTaskName`, `String reactionType` ('flame' または 'emoji'), `int? flameCount`, `String? emoji` を受け取れるようにしてください。
- `post_service.dart` の `incrementFlameCount` メソッド内で `logReactionSent` を呼ぶ際、対象投稿の `userId` (targetUid) と `taskName` (targetTaskName)、および `count` (flameCount) を渡すように修正してください。
- 同様に `addEmojiReaction` メソッド内でも、該当パラメータ（emoji等）を渡して `logReactionSent` を呼ぶように修正してください。
※ 対象投稿のデータは、可能な限り追加のFirestore Readを行わず、既存の変数や引数から取得してコストを抑えてください。

## 4. アクティブコミュニティ指標（フィード投稿数）の収集
- `AnalyticsService.logFriendFeedViewed()`（または `logAppOpen`）の引数に `int todayFriendPostsCount` を追加してください。
- フィード（タイムライン）を表示するUI側（`home_screen` 等）で、今日表示されている友達の投稿件数をカウントし、このメソッドに渡すように修正してください。これにより「コミュニティの活発度」と「明日の継続率」の相関を分析できるようになります。

コードの修正を開始し、完了したら結果を報告してください。
