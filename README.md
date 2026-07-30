# 🔥 V EFFECT

**習慣化・努力・勝利共有SNS** — 小さな勝利の積み重ねで「勝ち癖」を身につける。

> **App Store で正式リリース済み・本番運用中**（[App Store](https://apps.apple.com/app/id6763709764)）。
>
> 現行バージョン: `pubspec.yaml` の `version:` を参照
> 公式LP: https://veffect.web.app （ブログ: https://veffect.web.app/blog/ ）

---

## コンセプト

なぜ、目標を立てても続かないのだろう？ それはあなたの意志が弱いからではありません。ただ、無理なく続けられる仕組み（環境）がなかっただけ。

1. あなたが習慣化したいことを決めよう。
2. 共に高め合える友達や大切な人を誘おう。
3. 勝利したタスク（読書、勉強、ワークアウト等）を写真付きで証明しよう。

## 主要機能（2026-07）

- **ヒーロータスク（V-Quest）**: 1日1つの「自分への勝利条件」を宣言し、写真付きで達成を証明。白黒はっきりさせるデイリークエスト。
- **V-Feed**: 自分が投稿を完了すると、その日のフレンドの投稿が見られる特別なタイムライン（BeRealスタイルの閲覧ゲート）。🔥（VFIRE）や絵文字リアクションを送り合える。
- **ストリーク＆救済システム**: 連続達成日数の記録。7日ごとにシールド付与（最大2個）、途切れても24時間の救済期間＋フレンドから合計150 VFIREで完全復活。
- **ウィークリーレビュー**: 週間の達成・リアクションを振り返り、フレンドへ感謝を送れる。
- **プッシュ通知**: 投稿・リアクション・ストリークマイルストーン通知。FCMトークン自動同期＋セルフヒーリングバッチによる高信頼配信。
- **多言語対応**: 日本語 / 英語（`lib/l10n/`）。

## 技術スタック

- **フロントエンド**: Flutter (Dart) + Riverpod
- **バックエンド**: Firebase (Auth / Firestore / Storage / Messaging / Cloud Functions on Node.js 20 / Remote Config / Analytics / Crashlytics)
- **LP・ブログ**: Firebase Hosting（`public/`、記事は `content/blog/` → `tool/generate_blog.py` で静的生成）

詳細な技術構成・命名規約は [`.agents/CLAUDE.md`](.agents/CLAUDE.md)、コーディング規約は [`.agents/skills/coding-rules/SKILL.md`](.agents/skills/coding-rules/SKILL.md) を参照。

## 開発時の必読ドキュメント

| ファイル | 内容 |
|---|---|
| [`CLAUDE.md`](CLAUDE.md) | AIエージェント向けプロジェクト指示（本番運用中の注意事項） |
| [`CONTEXT.md`](CONTEXT.md) | AIエージェント間の作業同期ログ（最新の変更履歴はここ） |
| [`.agents/`](.agents/) | AI設定・スキル・規約一式 |
| `docs/` | 各種ドキュメント（`docs/archive/` は過去の計画書。現行情報ではない） |

## よく使うコマンド

```bash
flutter analyze                           # 静的解析
flutter gen-l10n                          # ローカライズ再生成（.arb変更後に必須）
firebase deploy --only firestore:rules    # ルールデプロイ（ルール変更後は必須）
firebase deploy --only hosting            # LPデプロイ
python tool/generate_blog.py              # ブログ静的生成
```

## メンバー

- **renn** — Main Developer / Planner
- **Yusuke Katahara** — Technical Advisor / Security Lead
