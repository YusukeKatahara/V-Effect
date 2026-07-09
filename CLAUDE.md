# V EFFECT

習慣化・努力・勝利共有SNS（Flutter / Firebase）。

**⚠️ 本番運用中**: App Store で正式リリース済み（id6763709764）。未リリース前提で回答・実装しないこと。Firestore スキーマ変更・functions デプロイ・破壊的変更は影響範囲を明示してから行う。

## 技術詳細・命名規約
@.agents/CLAUDE.md

## マルチエージェント同期
`CONTEXT.md` は Gemini CLI / Antigravity との作業同期ログ。大きな作業の完了時はここに日付・変更内容を追記して他エージェントと文脈を共有する。

## よく使うコマンド
- 静的解析: `flutter analyze`
- ローカライズ再生成: `flutter gen-l10n`（`lib/l10n/app_ja.arb` / `app_en.arb` 変更後に必須）
- Firestore ルールのデプロイ: `firebase deploy --only firestore:rules`（ルールを変更したら必ずデプロイ。未デプロイのまま実装して本番で PERMISSION_DENIED になった前例あり）
- LP デプロイ: `firebase deploy --only hosting`（`public/` → https://veffect.web.app）

## 注意
- functions の全体デプロイは、本番にのみ存在するソース未管理の関数によって中断する（詳細はプロジェクトメモリ `project_orphan_functions.md`）。`--only functions:関数名` で個別デプロイを検討
- 未修正のセキュリティ指摘が残っている（プロジェクトメモリ `project_security_findings.md` 参照）。関連箇所を触るときは確認する
