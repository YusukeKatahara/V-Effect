# v-effect-context
V EFFECT プロジェクトの概要・チーム構成・フォルダ構造のコンテキスト。Flutterアプリ開発の相談・コード作成・設計に関するやり取りすべてで参照する。

## Project Overview

- **Project Name:** V EFFECT
- **App Description:** An all-positive SNS app where users share their daily efforts with photos and praise each other to maintain motivation for growth. Users post photos once a day in a narrow community such as among friends, and only those who post can view others' posts (BeReal style). Combines goal management, roadmap creation, and game elements (skill tree, XP, streak) to visualize self-growth.
- **Target Users:** 自分磨きを頑張る、習慣化したいことがある、または常にある良習慣を強固にしたい人たちへ。サブタイトルは習慣化,努力と勝利の共有である。
- **Platform:** Android / iOS (Cross-platform development using Flutter)
- **Development Language:** Dart (Flutter framework)
- **Development Members:** 2 members
  - **renn** (Main Developer / Planner): アプリの開発・コーディング、およびコマンド実行やデプロイ等の作業を自ら担当しています。
  - **yusuke** (Technical Advisor / Security Lead): 技術設計のレビュー、セキュリティの監修・担当をしており、rennさんの開発を技術面・安全性から監修・サポートしています。
- **Source Code Management:** GitHub (Repository: YusukeKatahara/V-Effect)

## Folder Structure (Flutter Project)

```
V-Effect/
├── .agents/          ... AI configuration files
│   ├── skills/       ... Skill definitions (this folder)
│   └── workflows/    ... Workflow definitions
├── docs/             ... Documents
├── setup/            ... Setup guides
├── lib/              ... Dart source code (main development area)
│   ├── main.dart     ... App entry point (startup file)
│   ├── screens/      ... Widgets for each screen
│   ├── widgets/      ... Reusable UI parts
│   ├── models/       ... Data models (defines data shapes)
│   ├── services/     ... API communication and database processing
│   └── utils/        ... Common utility functions
├── test/             ... Test code
├── android/          ... Android-specific settings (auto-generated, usually don't touch)
├── ios/              ... iOS-specific settings (auto-generated, usually don't touch)
├── pubspec.yaml      ... Package (external library) management file
└── README.md
```

## Security Rules

1. **Never write API keys or passwords directly in the code**
   - Write them in the `.env` file and register it in `.gitignore`
2. **Always configure `.gitignore`** (refer to `docs/release_risk_guide.md` for details)
3. **Encrypt and save user's personal information**

---

## Season Task Announcements (シーズンタスクのお知らせテンプレート)

※プレビュー画面（アプリ内）で文字の太字や改行を確実に反映させるための「マークダウン最適化版（空行・半角スペース調整済み）」です。

```markdown
初のシーズンタスクが始まります！
今回オテーマは **「感謝」** です。

私たち開発チームも、日頃から支えてくださっている身の回りの方々へ、改めて深く感謝の気持ちを伝えたいと考えています。

---

### 🔥 今回のタスク：[タスク名（例：感謝を伝える）]

* **📅 開催期間**
  `[開始日]` 〜 `[終了日]`

* **🏆 クリア条件**
  期間中に **計[目標回数（例：12）]回** の投稿
  *(※ 1日1投稿までがカウント対象となります)*

---

### 💡 なぜ今「[タスク名]」なのか？

[ここに脳科学的・心理的な理由や、ライフハックに基づいた効果を書く]
（例：感謝タスクの場合）

「感謝するだけで習慣が変わるの？」と思うかもしれません。
しかし、最新 of ライフハック（人生の生産性を高める工夫）や脳科学において、感謝は **「人生を楽しむための最強のツール」** とされています。

1. **🧠 脳に「安全」を知らせてストレスを消す**

   人間はストレスを感じると、脳が「危険だ！」と判断して戦闘モードになります。感謝は、脳と身体に「今は安全だよ」と知らせて心身をリラックスさせる、最も効果的な方法です。

2. **⚙️ ポジティブ思考を「初期設定（デフォルト）」にする**

   毎日少しずつ感謝のタスクを繰り返すことで、脳の神経回路が書き換わります。これにより、特別な意識をしなくても、日常のハッピーなことに自然と目が向く「ポジティブ脳」が作られていきます。

3. **🚀 困難を乗り越えるエネルギーになる**

   うまくいかない時や苦しい時にこそ「ありがたいこと」を探す習慣が身につくと、逆境を跳ね返す強い心が育ち、成功や幸福を引き寄せやすくなります。

---

### 🎁 達成報酬

期間中にクリア条件を達成した方全員に、 **限定「[バッジ名]バッジ」** をプレゼント！
```

---
*Last applied: 2026-06-15*
