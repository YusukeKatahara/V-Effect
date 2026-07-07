# V EFFECT ランディングページ 運用ガイド

公式LP(https://veffect.web.app)の構成と、今後アップデートする際の技術的な手順のまとめ。
2026-07-07 の本格リニューアル時点の内容。

---

## 1. 概要

| 項目 | 内容 |
|---|---|
| 公開URL | https://veffect.web.app (日本語) / https://veffect.web.app/en/ (英語) |
| ホスティング | Firebase Hosting(プロジェクト `veffect`、`firebase.json` の `hosting.public = "public"`) |
| 技術方式 | 静的 HTML + CSS。ビルドツール・フレームワーク・JS なし |
| デプロイ | firebase CLI 手動(CI なし)。**必ず `--only hosting`**(理由は §7) |
| 多言語 | 2ページ静的方式。`/` = 日本語(メイン市場)、`/en/` = 英語。JS切替や自動リダイレクトは不採用(hreflang / OGPクローラ対応のため) |

## 2. ファイル構成

```
public/
├── index.html               # 日本語LP(本体)
├── en/index.html            # 英語LP(日本語版と完全に同一構造・文言のみ違う)
├── assets/
│   ├── css/lp.css           # 日英共通スタイル(デザイントークンはここに集約)
│   └── img/
│       ├── screen-1..5.webp # アプリスクショ(幅720px、tool/generate_lp_images.py で生成)
│       ├── ogp.png          # OGP画像 1200x630(日英共通)
│       ├── icon-192.png     # favicon用PNG
│       └── apple-touch-icon.png
├── favicon.ico
├── robots.txt               # 全許可 + Sitemap 行
├── sitemap.xml              # 5 URL + hreflang アノテーション
│
│  ▼ 以下は LP とは別物。アプリ・審査・広告の生命線なので変更禁止(§8)
├── privacy/  terms/  support/
├── .well-known/apple-app-site-association
├── .well-known/assetlinks.json
└── app-ads.txt

tool/generate_lp_images.py    # LP用画像の一括生成スクリプト(§4)
assets/store/phone_1..5.png   # スクショの元素材(ストア申請用と共用)
assets/store/feature_graphic.png / icon_512.png  # OGP・favicon の元素材
```

## 3. ページ構成(セクション)

日英でセクション構造・class 名は完全に一致させてある。**片方を変えたら必ずもう片方も同じ構造で更新する**(diff で対応関係を追えるようにするため)。

| # | セクション | class / id | 内容・使用画像 |
|---|---|---|---|
| 1 | ヘッダー | `.site-header` | ロゴ + アンカーナビ + 言語切替(EN ⇄ 日本語) |
| 2 | ヒーロー | `.hero` | H1 タグライン + App Store バッジ + Google Play 近日公開チップ + `screen-3.webp`(ヒーロータスク画面) |
| 3 | 共感コピー帯 | `.empathy` | 「なぜ続かない → 仕組みがなかっただけ」 |
| 4 | 機能紹介 | `.features` `#features` | 交互レイアウト×4:HERO TASK(`screen-1` V FEED投稿)/ V FEED ロック(`screen-2`)/ V STREAK(`screen-5` ランク)/ IDENTITY(`screen-4` プロフィール) |
| 5 | 使い方 | `.how` `#how` | 3ステップカード(旧LPの文言を継承) |
| 6 | ギャラリー | `.gallery` | screen-1〜5 の横スクロール(scroll-snap、JS不要) |
| 7 | 最終CTA | `.cta` `#download` | 「今日から、自分に勝つ。」+ バッジ再掲 |
| 8 | フッター | `.site-footer` | `/support` `/terms` `/privacy` + 言語切替 + © |

### デザイントークン(`lp.css` の `:root`)

- 背景 `#000000` / ゴールドアクセント `#D4AF37` / セカンダリ文字 `#86868b`
- フォント: Outfit(英字見出し・ロゴ)+ Noto Sans JP(日本語本文)+ Inter。Google Fonts 読み込み
- 英語ページは `<html lang="en">` に対する `html:lang(en)` セレクタで本文フォントを Inter に切替(EN側は Noto Sans JP を読み込まない)
- スマホモックは `.device`(ゴールド枠 + 角丸 + グロー)。実画像を入れるだけでフレームが付く

## 4. 画像のアップデート方法

元素材(`assets/store/phone_1..5.png` 等)を差し替えたら:

```powershell
python tool/generate_lp_images.py
```

これだけで `public/` 配下の WebP / OGP / favicon が全て再生成される(依存: Pillow)。

- スクショは幅720px(表示幅~360pxのRetina 2x)・WebP quality 80。1枚 10〜25KB 程度になる
- OGP は `feature_graphic.png`(1024x500)を 1200x630 の黒キャンバスに中央合成
- **キャッシュ注意**: 画像の内容を差し替えたのにファイル名が同じだと、CDN・ブラウザキャッシュで旧画像が表示され続けることがある。見た目が大きく変わる差し替え時はファイル名を変える(例: `screen-1@2.webp`)か、デプロイ後にシークレットウィンドウで確認する
- HTML 側の `<img>` には `width="720" height="1280"` と `loading="lazy"` を付けてある(ヒーローの1枚だけ `fetchpriority="high"`)。新規画像追加時も踏襲する

## 5. 文言のアップデート方法

1. `public/index.html`(日本語)を編集
2. `public/en/index.html` の**同じ箇所**を英語で編集
3. 見出しレベルの変更なら `<head>` 内も忘れず更新:
   - `<title>` / `<meta name="description">`
   - `og:title` / `og:description`
   - JSON-LD の `description`
4. タグラインはアプリ内と揃える(ソース: `lib/l10n/app_ja.arb` / `app_en.arb` の `loginTagline`)

### SEO まわりの決まりごと

- hreflang は3行セット(`ja` → `/`、`en` → `/en/`、`x-default` → `/`)を**両ページに**記述。ページを増やしたら `sitemap.xml` にも追加
- JSON-LD は `SoftwareApplication`。**`aggregateRating` は実データがないので入れない**(Google のポリシー違反になる)
- og:image は絶対URL必須(`https://veffect.web.app/assets/img/ogp.png`)

### ストアリンク

- App Store: 日本語ページは `https://apps.apple.com/jp/app/v-effect/id6763709764`、英語ページは `/jp/` なし(地域自動判定)
- **Google Play は未公開**。「近日公開 / Coming soon」の非リンクチップ(`.store-chip`)で表現し、URLは書かない。公開されたら `.store-button` を複製して Play バッジに差し替える(日英2ページ × ヒーロー/CTA の計4箇所)

## 6. 検証手順

```powershell
# ローカル確認(http://127.0.0.1:5000)
firebase emulators:start --only hosting
```

チェックリスト:

- [ ] `/` と `/en/` の表示、言語切替リンク、アンカーナビ
- [ ] モバイル幅とデスクトップ幅のレスポンシブ(ブレークポイントは 860px / 640px)
- [ ] 既存URLの不変性: `/privacy/` `/terms/` `/support/` `/app-ads.txt` `/.well-known/apple-app-site-association` `/.well-known/assetlinks.json` がすべて 200

既知のツール癖(異常ではない):

- **エミュレータは AASA(拡張子なしファイル)の Content-Type を `false` と返す**。本番は firebase.json の headers 設定により `application/json` が正しく返る。本番/プレビューURLで確認すること
- **headless Edge/Chrome は最小ウィンドウ幅 ~492px 未満にできない**。`--window-size=375,...` でスクショを撮ると右側が切れた画像になるが、レイアウト崩れではない。モバイル確認は 500px 幅で撮るか、DevTools のデバイスエミュレーションを使う

## 7. デプロイ手順

```powershell
# 1) プレビューチャネル(7日で自動失効。URLが発行されるので実機確認に使う)
firebase hosting:channel:deploy lp-renewal --expires 7d

# 2) 本番
firebase deploy --only hosting
```

> ⚠️ **`firebase deploy`(全体デプロイ)は禁止**。本番にのみ存在するソース未管理の Cloud Functions(孤児関数)があり、全体デプロイは途中で中断する。hosting 限定を厳守すること。

デプロイ後の確認:

- [ ] `curl -I https://veffect.web.app/.well-known/apple-app-site-association` → `Content-Type: application/json`
- [ ] OGP の見た目(X Card Validator や LINE でURLを貼って確認)
- [ ] 差し替えた画像がキャッシュされていないか(シークレットウィンドウ)

## 8. 変更禁止ファイル

| ファイル | 理由 |
|---|---|
| `public/privacy/` `terms/` `support/` | アプリ内・App Store 審査情報から URL 参照されている |
| `public/.well-known/apple-app-site-association` | iOS ユニバーサルリンク(招待リンク `/u/{userId}`)の生命線 |
| `public/.well-known/assetlinks.json` | Android App Links の生命線 |
| `public/app-ads.txt` | AdMob の広告配信認証 |
| `firebase.json` の `hosting.headers` | 上記 .well-known の Content-Type 指定 |

補足: AASA が `paths: ["*"]` のため、アプリインストール済み端末では veffect.web.app のリンクがアプリで開くことがある(既存仕様)。

## 9. 今後のTODO(未着手)

- [ ] 英語UIのスクリーンショット撮影 → 言語別画像に差し替え(現状は英語ページにも日本語スクショ+注記)
- [ ] 英語専用 OGP 画像(現状は日本語入り feature_graphic を日英共通で使用)
- [ ] Google Play 公開時のバッジ差し替え(§5)
- [ ] GitHub Actions による hosting 自動デプロイ(現状 CI なし)
- [ ] Search Console へのサイトマップ送信(未登録なら登録から)
