# V-Effect リリース準備チェックリスト

## Context
V-Effect（Flutter + Firebase）はMVP機能がほぼ完成し、App Store / Google Play へのリリース直前の段階。
このドキュメントでは「リリースまでに必ずやること」と「リリース後の準備」を整理する。

---

## 🔴 リリース前：必須対応（ブロッカー）

### 1. Android リリース署名の設定
**現状:** `build.gradle.kts` でリリースビルドにデバッグキーを使用中
```
signingConfig = signingConfigs.getByName("debug")  ← 要修正
```
**対応手順:**
1. `keytool` でリリース用 keystore を生成
2. `android/key.properties` に keystore のパス・パスワードを記述
3. `build.gradle.kts` に `releaseSigningConfig` を追加
4. `.gitignore` に `*.jks`, `*.keystore`, `key.properties` が含まれていることを確認
5. keystore ファイルをチームで安全に共有（Google Drive 等）

### 2. iOS GoogleService-Info.plist の確認
**現状:** Xcodeプロジェクトで参照されているが、実ファイルが見つからない可能性あり
**対応:** Firebase Console → iOS アプリ → `GoogleService-Info.plist` をダウンロードして `ios/Runner/` に配置

### 3. google-services.json の古い設定削除
**現状:** `android/app/google-services.json` に旧パッケージ名 `com.mycompany.veffect` の設定が残存
**対応:** Firebase Console から最新版を再ダウンロード、または古いクライアント定義を削除

---

## 🟡 リリース前：品質・提出準備

### 4. バージョン番号の確定
- `pubspec.yaml` の `version: 1.0.0+1` を確認
- versionCode (build number) は Play Store に提出するたびに増やす必要あり
- 初回リリースは `1.0.0+1` のままで問題なし

### 5. デバッグログの整理
**該当ファイル:**
- `lib/screens/home_screen.dart` に `[EMOJI_DEBUG]` タグのついた `debugPrint` が複数存在
- `lib/services/post_service.dart` にも同様

**対応:** `debugPrint` はリリースビルドでは出力されないが、ログを整理しておくと保守性が上がる。ブロッカーではない。

### 6. ストア提出物の準備

#### App Store Connect（iOS）
- [ ] アプリのスクリーンショット（iPhone 6.5インチ, 5.5インチ 各最低3枚）
- [ ] アプリの説明文（日本語）
- [ ] キーワード設定
- [ ] 審査用テストアカウント（Email/パスワードでログインできるもの）
- [ ] サポートURL（フィードバックフォーム: `https://forms.gle/Zj29yQmSSKCZ4Kar8` で代用可）
- [ ] プライバシーポリシーURL（`https://v-effect.web.app/privacy/` ← 既存）
- [ ] App Privacy（Data Collection の申告。Analytics/Crashlytics のデータ収集を申告必須）

#### Google Play Console（Android）
- [ ] ストアのスクリーンショット（最低2枚）
- [ ] フィーチャーグラフィック（1024×500px）
- [ ] アプリアイコン（512×512px）
- [ ] 簡単な説明文（80文字以内）と詳細説明文
- [ ] コンテンツレーティングのアンケート回答
- [ ] プライバシーポリシーURL
- [ ] データセーフティセクションの回答（収集データの申告）

### 7. Firebase Budget Alert の設定
`release_risk_guide.md` にも記載あり。Firebase Console → Billing で月額上限アラートを設定。
推奨: まず $50/月 でアラートを設定

### 8. 審査用テストアカウントの用意
- フレンド機能・リアクション機能のテストのため、2アカウント程度用意
- App Store 審査提出時に Notes に記載する

---

## 🟢 リリース後：優先度高

### 9. Firebase Analytics のデータ確認
- リリース直後から Firebase Console でリアルタイムイベントを監視
- `app_open_custom`, `post_created`, `streak_update` が正常に流れているか確認

### 10. Crashlytics のモニタリング
- クラッシュ率が 1% を超えたら即対応
- Firebase Console → Crashlytics でアラート設定

### 11. BigQuery Export の設定
**現状:** 未設定（Phase 2 として先送り中）
**対応:** Firebase Console → Analytics → BigQuery Export を有効化
- ユーザー増加後の詳細分析に必須
- リリース初日から有効にしておくとデータが蓄積される

### 12. ユーザーフィードバック収集体制
- フィードバックフォーム（`https://forms.gle/Zj29yQmSSKCZ4Kar8`）への導線確認
- `settings_screen.dart` 等からアクセスできるか確認

---

## 🔵 リリース後：中長期準備（Phase 2）

### 13. UTMパラメータによる流入元トラッキング
- 広告施策開始時に対応
- `analytics_service.dart` の `referral_source` イベントを拡張

### 14. 広告戦略の策定
- Analytics で蓄積した `streak_tier`, `primary_task_category`, `posting_time_slot` を活用
- リリース後 2〜4 週間でデータが溜まり次第、ターゲティング方針を検討

### 15. 通知最適化
- `open_from_notification` イベントで通知開封率を計測
- 開封率が低ければ通知文面・タイミングの改善

---

## 📣 リリース後：SNS 広告・宣伝戦略

### 前提条件
| 項目 | 内容 |
|------|------|
| ターゲット地域 | 日本 + 英語圏（グローバル） |
| 広告予算 | 未定（リリース後の状況を見て判断） |
| 使用プラットフォーム | TikTok / Instagram / Threads（メイン）、X（補助） |
| クリエイティブ | 自前実写 ＋ AI生成（Firefly / Claude / Gemini）組み合わせ |

---

### 使用ツール
| ツール | 用途 |
|--------|------|
| **Adobe Creative Cloud（Firefly 500cr/月 + Premiere Pro + After Effects + Photoshop）** | 映像編集・モーショングラフィクス・AI画像生成 |
| **Gemini AI Plus** | 脚本・ナレーション案・ターゲット別コピー生成 |
| **Claude Pro** | クリエイティブ・ディレクション・スクリプト精査・戦略立案 |

---

### 広告コアコンセプト

Apple・TOYOTA・映画予告編・Googleが共通して持つ広告の核：
> **機能を売らない。感情を売る。「その人が主人公になれる世界」を見せる。**

V-Effect のコア感情：
> **「努力は、仲間内で伝染する。」**

一方通行の「頑張れ」ではなく、**投稿という行為そのものが相手を動かす連鎖**がアプリの本質。
機能説明なしにこのループを映像で見せることが広告の最重要ミッション。

```
自分が努力して投稿する
    ↓
仲間に届く → 刺激を受ける → 仲間が投稿する
    ↓
自分に届く → また動く
```

#### キャッチコピー候補
- 「努力は、見せると伝染する。」
- 「あなたの今日が、誰かの明日を動かす。」
- 「一人では折れる。でも、証拠があれば続く。」
- 「バズらなくていい。仲間に届けばいい。」
- 「1000人のいいねより、仲間の1リアクション。」

---

### 想定ターゲット（2層構造）

| 層 | 対象 | 広告の役割 |
|----|------|-----------|
| **第1層（コア）** | 10〜30代、努力している人。受験生・フィットネス・ボディメイク・資格勉強など | 広告が直接刺さる人 |
| **第2層（波及）** | コアターゲットの友人・チームメンバー | 誘われて始める人 |

広告を見た人が「○○と一緒にやりたい」と感じ、仲間を誘う行動がバイラルの起点。
アプリのコンセプト（連鎖）と広告戦略が一致している構造。

---

### 広告シーン共通骨格

全コンセプト共通で「連鎖ループ」を映像内で完結させる：

```
[A が努力] → [B の投稿が届く] → [A が動く] → [A が投稿] → [C に届く]
```

登場人物は既存の友人関係として描く。視聴者が「○○と自分みたい」と感じると誘いが生まれる。

---

### 広告コンセプト案（3パターン）

---

**[コンセプト A] "Contagion" — 連鎖ループ実写スタイル**

- **ターゲット:** 10〜30代、努力に苦しんでいる全員
- **トーン:** ドラマチック・重厚・無音からの爆発的音楽
- **ストーリー:**
  深夜、薄暗い部屋でAが机に向かっている。しんどそう。やめようとする。
  スマホに通知。Bの投稿が届く。ジムで汗をかく写真。一言もない。ただ、証拠だけがある。
  Aの表情が変わる。また向き直る。AがV-Effectに投稿する。
  別の場所でCのスマホに通知が届く。
  テキスト：「努力は、仲間内で伝染する。」
- **媒体:** TikTok 縦型60秒 / Instagram Reels
- **制作ツール:** Premiere Pro（編集）+ After Effects（Vロゴ・ストリークCG）+ Firefly（背景生成）

---

**[コンセプト B] "Private Stage" — 閉じたコミュニティの安心感訴求**

- **ターゲット:** 22〜30代。SNSの「映える」疲れを感じており、本物の繋がりを求める層
- **トーン:** 静か・温かい・手持ちカメラ的リアリズム
- **ストーリー:**
  朝の光の中、ヨガをする人。深夜に参考書を開く人。早朝のランニング。
  それぞれがV-Effectに投稿する。小さなグループにだけ届く。
  画面に通知。仲間のリアクション（絵文字）がゆっくり浮かぶ。
  テキスト：「バズらなくていい。仲間に届けばいい。」
- **媒体:** Instagram Reels / TikTok
- **制作ツール:** Firefly（雰囲気カット生成）+ Premiere Pro + Claude でナレーション脚本

---

**[コンセプト C] "Streak Chain" — TikTokバズ特化・仲間誘い型**

- **ターゲット:** 16〜24歳、TikTok常用者。ストリーク文化になじみがある層
- **トーン:** 早口・テンポ速い・字幕中心・テンポよいカット割り
- **ストーリー:**
  「一人で続けるの、むずくない？」→ 仲間の投稿が届く画面 → 「これ見たら動けるんだよな」
  ストリーク数がカウントアップ。100日。200日。
  「本物の streak の話しようか？友達を誘ってみて。」
- **媒体:** TikTok メイン / Threads でテキスト版展開
- **制作ツール:** Adobe Premiere Rush + Firefly でビジュアル生成

---

### コンテンツ制作ワークフロー（実写 ＋ AI生成）

#### 素材の分担
| カテゴリ | 撮影方法 |
|---------|---------|
| **実写（自前）** | 人物の表情・動作（努力シーン）、アプリ操作・投稿の瞬間、通知が届くスマホ画面 |
| **AI生成（Firefly）** | 夜明け・深夜・ジムなどの背景シーン、雰囲気カット |
| **CG演出（After Effects）** | ストリーク数のカウントアップ、通知アニメーション、Vロゴ |
| **多言語キャプション（Claude / Gemini）** | 日英両方のキャプション・ハッシュタグ |

#### 制作フロー
```
① アイデア出し（Claude / Gemini）
   ↓ ターゲット・トーン・ストーリーの骨格を決める
② ビジュアル素材生成（Adobe Firefly）
   ↓ 背景・コンセプトビジュアル・テキストエフェクト画像を生成
   ↓ 500cr/月 → コンセプトA・B: 50〜80cr/本、C: 10〜20cr/本
③ 映像撮影（スマホ実機）
   ↓ 人物・アプリ操作・通知受信シーンを実写収録（テストアカウント2台で連携シーンを撮影）
④ 編集（Premiere Pro）
   ↓ カット編集 / 字幕（自動文字起こし機能）/ BGM / Beat sync
⑤ モーション・CG（After Effects）
   ↓ ストリーク数カウントアップ / Vロゴアニメーション / エンドカード
⑥ 多言語キャプション（Gemini / Claude）
   ↓ 日英両方のキャプション・ハッシュタグを生成
⑦ 投稿 → パフォーマンス計測 → 次回に活かす
```

#### 制作コストとクレジット配分の目安

| 用途 | Firefly消費 | 月間本数 |
|------|------------|--------|
| コンセプト A・B（高品質動画） | 50〜80cr/本 | 月5〜6本 |
| コンセプト C（軽量・バズ特化） | 10〜20cr/本 | 月15〜20本 |
| サムネイル・ストーリー画像 | 5〜10cr/枚 | 月30〜50枚 |

---

### Phase 0：オーガニック（予算ゼロ）で土台を作る（リリース〜1ヶ月）

開発者・仲間内でのクチコミと並行して、SNS アカウントを育てる段階。
有料広告は「バズる素材」と「訴求できるストア評価」が揃ってから投下する方が費用対効果が高い。

#### アカウント開設・統一ブランディング
- 3プラットフォームで `@v_effect_app`（または類似）の統一ハンドルを取得
- プロフィール文を日英両対応にする（例: "証明し合う習慣アプリ / Habit app where friends hold each other accountable"）
- App Store / Play Store のURLをバイオに設置

#### 投稿コンテンツ軸（3本柱）

| 柱 | 内容 | 頻度 |
|---|---|---|
| **リアル投稿UGC** | 実際のストリーク・投稿画面を見せる。「今日もやった」感 | 毎日〜週5 |
| **機能紹介** | 24時間消滅・リアクション・ストリーク等をデモ動画で | 週1〜2 |
| **感情訴求** | 「仲間の投稿を見て自分も続けられた」系のストーリー | 週1 |

#### TikTok 戦略（最優先）
- 短尺（15〜30秒）で「投稿→仲間のリアクション→ストリーク更新」の連鎖を見せる
- 日英字幕を両方つけることでグローバルリーチを狙う
- ハッシュタグ: `#habittracking` `#accountability` `#selfimprovement` `#streaks`（英語圏）+ `#習慣化` `#毎日投稿` `#継続は力なり`（日本）
- 最初の1〜2ヶ月はデータ収集。「再生数が10万超えた動画」の型を見極めてから広告化

#### Instagram 戦略
- Reels はTikTok動画を流用（TikTokロゴを消す）
- Stories で「今日の投稿」を毎日シェア → アプリの日常感を演出
- グローバル展開: キャプションを日英両方書く（日本語→英語の順）

#### Threads 戦略（新規追加）
- テキストで「仲間の投稿を見て動けた話」を語る共感投稿が中心
- 「○日連続達成しました」「友達が投稿してたから自分もやった」系の短文
- アプリのリリース告知・アップデート情報をスレッドで発信
- X より拡散性は低いが、30代以上のリテラシー層への親和性が高い

---

### Phase 1：有料広告の準備（1〜2ヶ月後）

オーガニックで「バズった投稿」または「CTR が高かった投稿」を特定してから投下する。
予算が決まっていない今は、以下を準備しておく。

#### 広告運用に必要な準備物
- [ ] **TikTok Ads アカウント**の作成（事前登録だけしておく）
- [ ] **Meta Ads Manager（Instagram）**の設定
- [ ] **iOS：SKAdNetwork** の対応確認（iOS向け広告計測に必須）
- [ ] **Android：Firebase の UTMパラメータ**の実装（Phase 2 として設計済み）
- [ ] ストアのレビューを5件以上集める（広告のLP品質に影響）

#### 予算の目安と戦略（参考）

| 月間予算 | 推奨アプローチ |
|---------|--------------|
| 〜¥30,000 | TikTok 1本に絞る。バズった動画を¥5,000/日 で3〜5日ブーストするだけで十分 |
| ¥30,000〜¥100,000 | TikTok + Instagram の2本立て。ABテスト（クリエイティブ2〜3種）を回す |
| ¥100,000〜 | UA（ユーザー獲得）専任で動かす。CPI（インストール単価）を測りながら最適化 |

---

### 効果測定の指標（KPI）

| 指標 | ツール | 目標値（参考） |
|------|--------|-------------|
| インストール数 | Firebase Analytics | D7で100インストール/月〜 |
| D7 継続率 | Firebase Analytics（`app_open_custom`） | 20% 以上が目標ライン |
| 投稿率（初回） | `post_created` イベント | インストールの50%以上 |
| ストリーク継続率 | `streak_update` イベント | 7日継続: 15%以上 |
| 広告 CTR | TikTok/Meta Ads | TikTok: 1.5%以上、Instagram: 0.8%以上 |
| CPI（インストール単価） | Ads + Analytics | 国内: ¥200〜¥500 が目安 |

Analytics で既に収集中の `referral_source` と組み合わせることで、
どのSNSからの流入が「定着するユーザー」を生んでいるか判断できる。

---

## 検証方法

### リリースビルドの動作確認
```bash
# Android
flutter build apk --release
flutter build appbundle --release

# iOS
flutter build ipa --release
```

### 署名確認（Android）
```bash
# APKに正しい署名がついているか確認
keytool -printcert -jarfile app-release.apk
```

### Firebase 動作確認
- テスト端末で DebugView を有効にして Analytics イベントが届くか確認
  `adb shell setprop debug.firebase.analytics.app com.veffect.app.v_effect`

---

## ファイルリファレンス

| 項目 | パス |
|------|------|
| バージョン番号 | `pubspec.yaml` |
| Android 署名設定 | `android/app/build.gradle.kts` |
| iOS Bundle ID | `ios/Runner/Info.plist` |
| Firebase 設定 | `lib/firebase_options.dart` |
| Analytics サービス | `lib/services/analytics_service.dart` |
| デバッグログ箇所 | `lib/screens/home_screen.dart`, `lib/services/post_service.dart` |
| プライバシーポリシー | `https://v-effect.web.app/privacy/` |
| 利用規約 | `https://v-effect.web.app/terms/` |
| リスクガイド | `docs/release_risk_guide.md` |
