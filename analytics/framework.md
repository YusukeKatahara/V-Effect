# V-EFFECT 解析フレームワーク — ユーザー数増加のための開発優先度特定

---

## このドキュメントの使い方（Claude Code 向け）

このファイルは Claude Code が **そのまま読み込んで実行する仕様書**です。  
以下のルールに従って実装・実行してください。

1. **M0 から順番に**実行してください。後続モジュールは前のモジュールの出力に依存します。
2. 各モジュールは `analytics/analysis/mX_xxxx.py` として独立したスクリプトを作成してください。
3. 出力ファイルはすべて `analytics/data/analysis/` に保存してください（`data/` は `.gitignore` 済み）。
4. 実装前に「実装仕様」を必ず読み、仕様に忠実に実装してください。
5. モジュール実行後、コンソール出力の主要な数値を会話に報告してください。
6. **データが存在しない場合**: `python export_raw_data.py --format json` を先に実行してください。

---

## 解析の目的

**最終目標**: アクティブユーザー数（DAU/MAU）を増やすために、開発チームが次に取り組むべき機能・改善を、データに基づいて優先順位付けすること。

V-EFFECT は「習慣継続を仲間と支え合うSNS」であり、成長の核心は以下の2つです。

- **継続率（Retention）**: ユーザーが翌日・翌週も投稿し続けるか
- **紹介（Referral）**: ユーザーが新規ユーザーを連れてくるか（ソーシャルグラフ拡張）

この2つを阻む要因を8つの解析モジュールで特定し、最後に開発優先度マトリクスを生成します。

---

## 前提条件

### ディレクトリ構成

```
analytics/
  analysis/          ← 各モジュールのスクリプトを配置
  data/
    raw/             ← export_raw_data.py の出力（gitignore済み）
    analysis/        ← 各モジュールの出力（gitignore済み）
  config/
    firebase_admin_key.json  ← gitignore済み
```

### 必要ライブラリ

既存の `requirements.txt` に以下を追記してインストールしてください（未インストールの場合）。

```
scikit-learn>=1.5.0  # 既存
plotly>=5.22.0       # 既存
pandas>=2.2.2        # 既存
```

---

## データスキーマ

### users コレクション（`data/raw/users_*.json`）

| フィールド | 型 | 説明 |
|---|---|---|
| uid | string | ドキュメントID（識別子） |
| birthDate | string | 生年月日（YYYY-MM-DD または YYYY/MM/DD） |
| gender | string | 性別 |
| occupation | string | 職業 |
| streak | int | 現在の継続日数（ストリーク） |
| maxStreak | int | 歴代最大ストリーク |
| streakProtections | int | 残シールド数 |
| lastPostedDate | string | 最終投稿日（YYYY-MM-DD） |
| following | list[uid] | フォロー中のUID一覧 |
| followers | list[uid] | フォロワーUID一覧 |
| tasks | list[dict] | 現在のタスク一覧（各要素に `title` キーを含む） |
| isPrivateAccount | bool | 非公開アカウントか |

### posts コレクション（`data/raw/posts_*.json`）

| フィールド | 型 | 説明 |
|---|---|---|
| post_id | string | ドキュメントID |
| userId | string | 投稿者UID |
| taskName | string | タスク名 |
| createdAt | Timestamp / ISO文字列 | 投稿日時 |
| reactionCount | int | 🔥 炎リアクション数 |
| emojiReactedUserIds | list[uid] | 絵文字リアクションしたUID一覧 |
| caption | string | キャプション（任意） |

### action_logs コレクション（`data/raw/action_logs_*.json`）

| フィールド | 型 | 説明 |
|---|---|---|
| doc_id | string | ドキュメントID |
| uid | string | 操作ユーザーUID |
| eventName | string | イベント名 |
| clientTimestamp | Timestamp / ISO文字列 | クライアント側の発生時刻 |
| timestamp | Timestamp / ISO文字列 | Firestore 書き込み時刻 |
| appVersion | string | アプリバージョン |
| platform | string | "ios" または "android" |
| parameters | dict | イベント固有のパラメータ |

**既知のイベント名と parameters のキー**:

| eventName | parameters のキー |
|---|---|
| reaction_sent | target_uid, target_task_name, reaction_type, flame_count, emoji |
| friend_feed_viewed | today_friend_post_count |
| ※その他のイベントは M0 の探索で実際のデータから確認すること | |

---

## M0: データ探索・スキーマ実態確認

**実装ファイル**: `analytics/analysis/m0_explore.py`

**目的**: 実際のデータを確認し、想定外のフィールド・欠損・イベント名を把握する。後続モジュールの実装精度を上げるための必須ステップ。

### 実装仕様

以下の内容を出力・保存するスクリプトを作成してください。

```
1. 各コレクションのレコード数
2. users:
   - 全フィールド名と非null率
   - streak の分布（min/25%/50%/75%/max/mean）
   - maxStreak の分布
   - streakProtections の分布
   - lastPostedDate の最古〜最新（ユーザーの利用期間の把握）
   - tasks の要素数の分布（タスク0件・1件・複数件の人数）
   - followers・following のリスト長の分布
   - isPrivateAccount の True/False 比率
   - gender・occupation の値の種類と件数
3. posts:
   - 全フィールド名と非null率
   - createdAt の最古〜最新（データ期間の確認）
   - reactionCount の分布
   - emojiReactedUserIds の長さの分布
   - userId のユニーク数（投稿したことがあるユーザー数）
   - taskName のユニーク数・上位20件
4. action_logs:
   - eventName の種類と件数（ソート済み）
   - clientTimestamp の最古〜最新
   - uid のユニーク数（行動ログのあるユーザー数）
   - platform 別件数
   - appVersion 別件数
   - 各 eventName の parameters に含まれるキーの種類
```

**出力ファイル**: `analytics/data/analysis/m0_schema_report.txt`（上記をテキストで保存）

**報告事項**: 実行後、以下を会話に報告してください。
- 各コレクションのレコード数
- action_logs の全 eventName 一覧
- データ期間（最古〜最新の日付）
- 特筆すべき欠損・異常値

---

## M1: コホート × リテンション分析

**実装ファイル**: `analytics/analysis/m1_retention.py`

**目的**: 登録（初回投稿）コホート別に、N日後も投稿を続けているユーザーの割合を算出する。これがアプリの「体力」を示す最重要指標。

**仮説と重要性**: 習慣アプリの業界標準では D7 リテンション 25%・D30 リテンション 10% が平均的な閾値。これを上回っているか否かで、「獲得施策を強化すべき」か「継続率を改善すべき」かが決まる。

### 実装仕様

#### Step 1: ユーザー活動履歴の構築

```python
# posts から各ユーザーの投稿日一覧を作成
# {uid: sorted list of date strings (YYYY-MM-DD)}
user_post_dates = defaultdict(set)
for post in posts:
    dt = ts_to_dt(post.get("createdAt"))
    if dt:
        user_post_dates[post["userId"]].add(dt.date().isoformat())
```

#### Step 2: 初回投稿日（activation_date）の特定

```python
# 各ユーザーの最も古い投稿日を activation_date とする
user_activation = {
    uid: min(dates)
    for uid, dates in user_post_dates.items()
    if dates
}
```

#### Step 3: コホート定義

```python
# activation_date の YYYY-MM（月）でコホートを定義
# コホートが3件以上あるときのみ集計対象とする（小サンプルノイズ回避）
```

#### Step 4: リテンション計算

各コホートについて、以下の指定日後のリテンション率を計算してください。

- D1（翌日）: activation_date の翌日に投稿があるか
- D3: activation_date + 3日後の日付に投稿があるか
- D7: activation_date + 7日後
- D14: activation_date + 14日後
- D30: activation_date + 30日後

**重要**: 「N日後に投稿があるか」は、activation_date + N日の「±1日」ウィンドウで判定してください（例: D7 は day6〜day8 のいずれかに投稿があれば retained とする）。

#### Step 5: ヒートマップの生成

- 行: コホート月（YYYY-MM）
- 列: D1 / D3 / D7 / D14 / D30
- 値: リテンション率（0.0〜1.0）
- Plotly の heatmap で色付け（0%=白、100%=濃青）
- 各セルに「X%\n(N人)」を表示

#### Step 6: 平均リテンション曲線

全コホートを合算した平均リテンション曲線を折れ線グラフで出力。

### 出力ファイル

- `analytics/data/analysis/m1_cohort_retention_heatmap.html`
- `analytics/data/analysis/m1_retention_curve.html`
- `analytics/data/analysis/m1_retention_table.csv`（コホート × 日数のテーブル）

### 解釈ガイド

| D30 リテンション | 評価 | 開発優先度 |
|---|---|---|
| ≥ 20% | 優秀（業界トップ水準） | 獲得（広告・ASO）を優先 |
| 10〜19% | 平均的 | 継続率とソーシャル機能を並行改善 |
| 5〜9% | 要改善 | リテンション改善が最優先 |
| < 5% | 危機的 | オンボーディング再設計が急務 |

### 開発への示唆

- D1 が低い（< 40%）→ 初日体験の問題。オンボーディングフロー再設計。
- D7 が低いが D1 は高い → 「3日坊主」問題。4〜6日目のリマインド通知が有効。
- D30 まで緩やかに低下 → 正常な逓減。獲得コストを下げる施策へ。
- 特定コホートのみ低い → アプリアップデートやイベントとの相関を調査。

---

## M2: ストリーク離脱 × チャーン相関分析

**実装ファイル**: `analytics/analysis/m2_streak_churn.py`

**目的**: ストリークが途切れた後、ユーザーがどれだけの割合でアプリを離脱するかを定量化する。ストリーク保護（シールド）機能の重要度と、新機能の必要性を判断する。

**仮説**: ストリークが高い水準で途切れたユーザーほど、失望感からチャーン率が高い。このパターンを特定できれば、事前介入（シールド贈与・リカバリー誘導）で離脱を防げる。

### 実装仕様

#### Step 1: 各ユーザーのストリーク破綻を特定

現在のスナップショットから直接算出します。

```python
# users から以下の特徴量を計算
# - days_since_last_post: 今日 - lastPostedDate（日数）
# - is_churned: days_since_last_post >= 30
# - streak_gap: maxStreak - streak（ストリーク損失量）
# - had_streak_break: streak_gap > 0
# - had_high_streak_break: streak_gap >= 7（7日以上のストリークを失った）
```

注意: `lastPostedDate` が存在しないユーザーは除外してください。今日の日付は `datetime.date.today()` を使用してください。

#### Step 2: ストリーク損失量別チャーン率

`streak_gap` を以下のビンに分類してチャーン率を計算してください。

- 0（ストリーク継続中または未投稿）
- 1〜3
- 4〜6
- 7〜13
- 14〜29
- 30以上

棒グラフで可視化（X軸: ストリーク損失区分、Y軸: チャーン率%）。

#### Step 3: maxStreak 別チャーン率

`maxStreak` を以下のビンで分類してチャーン率を計算。

- 0〜2
- 3〜6
- 7〜13
- 14〜29
- 30以上

#### Step 4: シールド保有とチャーン率の関係

```python
# streakProtections の値で以下のグループに分けてチャーン率を比較
# - 0（シールドなし）
# - 1〜2
# - 3以上
```

#### Step 5: 散布図（maxStreak vs days_since_last_post）

- 色: is_churned（赤=チャーン / 青=アクティブ）
- X軸: maxStreak、Y軸: days_since_last_post
- これで「高ストリーク × 長期未投稿」というリスクゾーンを可視化

### 出力ファイル

- `analytics/data/analysis/m2_streak_gap_churn.html`（ストリーク損失別チャーン率棒グラフ）
- `analytics/data/analysis/m2_max_streak_churn.html`（maxStreak別チャーン率）
- `analytics/data/analysis/m2_shield_effect.html`（シールド保有とチャーンの関係）
- `analytics/data/analysis/m2_scatter.html`（maxStreak vs 未投稿日数の散布図）
- `analytics/data/analysis/m2_summary.csv`

### 解釈ガイド

- **ストリーク損失が大きいほどチャーン率が上がる** → シールド機能の拡充が最優先
- **maxStreak 30以上のユーザーのチャーン率が低い** → 長期ユーザーの囲い込みに注力
- **シールド保有者のチャーン率が低い** → シールド付与を積極的な施策として推進すべき
- **高 maxStreak でもチャーンしている** → ストリーク以外の離脱要因がある（→ M3・M4 で調査）

### 開発への示唆

- ストリーク損失 7日以上でチャーン率 > 50% → 「ストリークリカバリー機能」（例: 特定条件で過去ストリークを部分復元する仕組み）の優先度が極めて高い
- シールドの効果が大きい → 「フォロワーからシールドをもらえる機能」「達成マイルストーンでシールド付与」が有効

---

## M3: ソーシャルグラフ効果 × リテンション分析

**実装ファイル**: `analytics/analysis/m3_social_retention.py`

**目的**: フォロワー数・フォロー数がリテンションに与える影響を定量化し、「ソーシャル機能への投資対効果」を明らかにする。

**仮説**: フォロワーが多いユーザーは「見られている意識」によって投稿継続率が高い。一方、フォローしているユーザーが多いユーザーは「友達の投稿を見たい」モチベーションで継続する。どちらの効果が強いかによって開発方針が変わる。

### 実装仕様

#### Step 1: 特徴量作成

```python
for user in users:
    follower_count = len(user.get("followers", []))
    following_count = len(user.get("following", []))
    mutual_count = len(set(user.get("followers", [])) & set(user.get("following", [])))
    # 相互フォロー数（両方向のつながり）
    
    days_since_last_post = ...  # M2 と同様
    is_active = days_since_last_post <= 14
    is_churned = days_since_last_post >= 30
```

#### Step 2: フォロワー数ビン別アクティブ率・チャーン率

フォロワー数を以下のビンに分類して、アクティブ率とチャーン率を算出。

- 0人
- 1人
- 2〜4人
- 5〜9人
- 10〜19人
- 20人以上

同様にフォロー数でも算出。相互フォロー数でも算出。

**グループごとにアクティブ率を折れ線グラフで比較**（横軸: ビン、縦軸: アクティブ率%）。

#### Step 3: 閾値の特定

「アクティブ率が急上昇するフォロワー数」を特定してください。

```python
# フォロワー数 0〜20 それぞれの精密なアクティブ率を1人刻みで計算
# 前後比較でアクティブ率の上昇率が最大になる点 = ソーシャル閾値
```

#### Step 4: 相関係数の算出

```python
# Spearman 相関係数（非線形データに適切）
from scipy.stats import spearmanr
corr_follower, p_follower = spearmanr(df["follower_count"], df["days_since_last_post"])
corr_following, p_following = spearmanr(df["following_count"], df["days_since_last_post"])
corr_mutual, p_mutual = spearmanr(df["mutual_count"], df["days_since_last_post"])
```

#### Step 5: 散布図（フォロワー数 vs ストリーク）

```python
# 色: チャーン状態（赤=チャーン/青=アクティブ）
# サイズ: maxStreak
# X軸: follower_count（上限50でクリップ）
# Y軸: streak
```

### 出力ファイル

- `analytics/data/analysis/m3_follower_active_rate.html`（フォロワー数別アクティブ率）
- `analytics/data/analysis/m3_following_active_rate.html`（フォロー数別アクティブ率）
- `analytics/data/analysis/m3_mutual_active_rate.html`（相互フォロー数別アクティブ率）
- `analytics/data/analysis/m3_social_streak_scatter.html`（散布図）
- `analytics/data/analysis/m3_summary.csv`（相関係数・閾値をまとめたCSV）

### 解釈ガイド

- **フォロワー数の閾値が明確（例: 3人以上でアクティブ率が20pt上昇）** → 「最初の3人フォロワーを獲得させる」オンボーディング設計が急務
- **相互フォローの相関が最も強い** → 「知り合いを招待してお互いフォロー」機能の強化が有効
- **フォロー数よりフォロワー数の効果が大きい** → 「見てもらえている感」がモチベーション源。コンテンツ拡散機能が有効
- **フォロー数の効果が大きい** → フィード体験の改善（見る理由を増やす）が有効

### 開発への示唆

- 閾値（例: 相互フォロー3人）を特定できたら → オンボーディングで「最初に◯人と繋がる」を必須ステップとして設計
- ソーシャル効果が弱い場合 → ゲーミフィクション（バッジ・ランキング）など非ソーシャルの継続メカニズムを検討

---

## M4: 初週行動パターン分析（action_logs）

**実装ファイル**: `analytics/analysis/m4_first_week.py`

**目的**: 登録後7日間にどんな行動をしたユーザーが長期的に継続するかを特定する。これが「オンボーディングで促すべき行動」を決める。

**仮説**: 「最初の1週間に仲間とリアクションを交わしたユーザー」が最も継続する。ソーシャルな体験を早期に得られるかが分岐点。

### 実装仕様

#### Step 1: ユーザーの activation_date 取得

M1 で使用した `user_activation`（uid → 最初の投稿日）を再利用してください。同一ロジックをここでも実装してください。

#### Step 2: 各ユーザーの初週 action_logs を抽出

```python
# activation_date から7日以内の action_logs を抽出
# activation_date が不明なユーザーは除外
for log in action_logs:
    uid = log.get("uid")
    activation = user_activation.get(uid)
    if activation is None:
        continue
    dt = ts_to_dt(log.get("clientTimestamp"))
    if dt is None:
        continue
    days_since_activation = (dt.date() - date.fromisoformat(activation)).days
    if 0 <= days_since_activation <= 6:
        first_week_logs[uid].append(log)
```

#### Step 3: ユーザーを「継続グループ」と「離脱グループ」に分類

```python
# 継続グループ: activation_date + 30日後も投稿があるユーザー
# 離脱グループ: activation_date + 30日後に投稿がないユーザー
# （M1のリテンション判定と同じ±1日ウィンドウを使用）
```

#### Step 4: 初週行動の比較

2グループ間で以下の指標を比較してください。

```python
for group in ["retained", "churned"]:
    users_in_group = ...
    for uid in users_in_group:
        logs = first_week_logs.get(uid, [])
        features[uid] = {
            "total_events": len(logs),
            "unique_event_types": len({l["eventName"] for l in logs}),
            "reaction_sent_count": sum(1 for l in logs if l["eventName"] == "reaction_sent"),
            "days_with_activity": len({ts_to_dt(l["clientTimestamp"]).date() for l in logs if ts_to_dt(l["clientTimestamp"])}),
            # action_logs から判明する他イベントも同様に集計
        }
```

#### Step 5: グループ別平均値の比較棒グラフ

各特徴量について「継続グループ」vs「離脱グループ」の平均値を並べた棒グラフを作成。

#### Step 6: 初週イベント種類別の「継続率への寄与度」

```python
# 各イベントを「初週に1回以上発生した」/「発生しなかった」でグループを分け、
# それぞれの 30日後リテンション率を計算
# 例: 「reaction_sent を初週に行ったユーザーの D30 リテンション率」vs「行わなかったユーザー」
# 差分が大きいイベント = 「magic moment」となる重要行動
```

結果を差分降順でソートした棒グラフとして出力。

### 出力ファイル

- `analytics/data/analysis/m4_first_week_feature_comparison.html`（2グループ特徴量比較）
- `analytics/data/analysis/m4_magic_moments.html`（イベント別リテンション寄与度）
- `analytics/data/analysis/m4_magic_moments.csv`（イベント名・継続率差分・サンプル数）

### 解釈ガイド

- **reaction_sent を初週に行うと D30 リテンション率が15pt以上高い** → 「最初の1週間でリアクションを送る動線を強化」（例: チュートリアル内でリアクション送信を誘導）
- **7日間連続でアクティビティがある** → 7日ストリークの達成がターニングポイント。7日目達成時に強い祝福UXを設計
- **特定のイベントが離脱グループでほぼゼロ** → そのイベントが起きない理由を調査（UI上の見つけにくさ等）

### 開発への示唆

- Magic moment と特定されたアクションをオンボーディングで「最初の3分以内に体験させる」設計に変更
- 特定イベントの実行率が低い → UIの視認性改善・チュートリアル追加

---

## M5: タスクカテゴリ別 定着率・エンゲージメント分析

**実装ファイル**: `analytics/analysis/m5_category_retention.py`

**目的**: どのカテゴリのタスクを持つユーザーが最も継続し、どのカテゴリの投稿が最も多くのリアクションを受けるかを特定する。「どんな人を獲得すべきか」「何の訴求で広告を打つか」の指針になる。

**仮説**: Fitness（筋トレ・ランニング）は継続率が高い（毎日の習慣として自然）。Education（英語・勉強）はリアクションは少なめだがストリークが長い。

### 実装仕様

既存の `src/task_classifier.py` を利用してタスク分類を行ってください。

```python
import sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from src.task_classifier import TaskClassifier
from src.translator import translate_batch

classifier = TaskClassifier()
```

#### Step 1: ユーザー別タスクカテゴリの特定

```python
# users のタスク一覧から代表カテゴリを算出
# 既存の src/user_typer.py: infer_user_type() を使用
from src.user_typer import infer_user_type
```

#### Step 2: カテゴリ別ユーザー特性

カテゴリ（Fitness / Education / Life / Creative / Work / Other）ごとに以下を集計。

```python
stats_by_category = {
    "category": ...,
    "user_count": ...,
    "median_streak": ...,
    "mean_streak": ...,
    "median_max_streak": ...,
    "active_rate_14d": ...,   # 直近14日以内に投稿があるユーザーの割合
    "churn_rate_30d": ...,    # 30日以上未投稿の割合
    "median_followers": ...,
    "median_task_count": ..., # 保有タスク数の中央値
}
```

箱ひげ図（カテゴリ別ストリーク分布）と棒グラフ（カテゴリ別アクティブ率・チャーン率）を作成。

#### Step 3: カテゴリ別投稿エンゲージメント

`posts` コレクションから、各投稿のカテゴリを分類（task_classifier を使用）。

```python
# タスク名の翻訳は translate_batch() を使用（ただし件数が多い場合は先頭500件に限定）
# 分類後の集計
engagement_by_category = {
    "category": ...,
    "post_count": ...,
    "mean_reaction_count": ...,      # 平均🔥リアクション数
    "mean_emoji_reaction_count": ..., # 平均絵文字リアクション数
    "reaction_rate": ...,            # (reactionCount > 0 の投稿) / 全投稿
}
```

#### Step 4: カテゴリ別「継続率 × エンゲージメント」マトリクス

散布図（X軸: カテゴリ別アクティブ率、Y軸: カテゴリ別平均リアクション数）を作成。各点にカテゴリ名をラベル表示。これにより4象限に分類できる。

- **高アクティブ率 × 高リアクション** → 最重要ターゲット（獲得広告の訴求軸）
- **高アクティブ率 × 低リアクション** → ユーザー自身の習慣化には良いが、拡散力が低い
- **低アクティブ率 × 高リアクション** → 投稿は楽しいが継続できない。継続サポートが必要
- **低アクティブ率 × 低リアクション** → 改善またはターゲットから外す

### 出力ファイル

- `analytics/data/analysis/m5_category_streak_boxplot.html`
- `analytics/data/analysis/m5_category_active_churn.html`
- `analytics/data/analysis/m5_category_engagement.html`
- `analytics/data/analysis/m5_category_matrix.html`（4象限散布図）
- `analytics/data/analysis/m5_category_stats.csv`

---

## M6: ユーザーセグメンテーション（行動クラスタリング）

**実装ファイル**: `analytics/analysis/m6_segmentation.py`

**目的**: ユーザーを行動パターンで4〜6セグメントに分類し、各セグメントが抱える課題と有効な施策を明確化する。

**仮説**: 大きく「パワーユーザー」「ソーシャル離脱リスク層」「完全離脱層」「潜在成長層」に分かれる。各層への施策は異なる。

### 実装仕様

#### Step 1: 特徴量エンジニアリング

```python
features = {
    "streak": user["streak"],
    "max_streak": user["maxStreak"],
    "streak_ratio": user["streak"] / max(user["maxStreak"], 1),  # 現在/最大（離脱度合い）
    "follower_count": len(user.get("followers", [])),
    "following_count": len(user.get("following", [])),
    "mutual_count": ...,  # 相互フォロー数
    "task_count": len(user.get("tasks", [])),
    "days_since_last_post": ...,
    "streak_protections": user.get("streakProtections", 0),
}
```

#### Step 2: 前処理

```python
from sklearn.preprocessing import StandardScaler
# 上記特徴量を StandardScaler で標準化
# NaN は列の中央値で補完
```

#### Step 3: クラスタリング

```python
from sklearn.cluster import KMeans
from sklearn.metrics import silhouette_score

# k=2〜8 でシルエットスコアを計算し、最適 k を特定
# 最適 k で KMeans を実行（random_state=42）
```

#### Step 4: 各クラスタの特性分析

各クラスタについて、全特徴量の平均値を計算し、最も特徴的な点を言語化してください。

命名規則（実際のデータに合わせて調整）:
- **パワーユーザー**: 高ストリーク・高フォロワー・高活動
- **ソーシャル活動型**: フォロー多い・ストリーク中程度
- **孤独な継続者**: ストリーク高いがフォロワー少ない
- **休眠ユーザー**: 低活動・長期未投稿
- **新規ユーザー**: ストリーク低・フォロー少ない（まだ習慣化前）

#### Step 5: 可視化

- レーダーチャート（クラスタ別の特徴量プロファイル）
- 棒グラフ（クラスタ別人数）
- PCA で2次元に削減した散布図（色: クラスタ）

### 出力ファイル

- `analytics/data/analysis/m6_cluster_radar.html`
- `analytics/data/analysis/m6_cluster_size.html`
- `analytics/data/analysis/m6_cluster_pca_scatter.html`
- `analytics/data/analysis/m6_cluster_profiles.csv`（クラスタ別特徴量平均）
- `analytics/data/analysis/m6_user_clusters.csv`（uid → クラスタIDの対応表）

### 解釈ガイド と 開発への示唆

クラスタ分析後、各クラスタに対して以下の対応を検討してください（結果に応じて具体化）。

| セグメント | 課題 | 施策候補 |
|---|---|---|
| 孤独な継続者 | フォロワーがいない → ソーシャル効果ゼロ | 類似タスクユーザーの自動サジェスト |
| 休眠ユーザー | 長期離脱 | ウィンバック通知（「久しぶり！」） |
| 新規ユーザー | 習慣化前に離脱 | 7日チャレンジ等の構造化オンボーディング |
| パワーユーザー | すでに満足 | アンバサダープログラム・紹介機能 |

---

## M7: チャーンリスクスコアリング

**実装ファイル**: `analytics/analysis/m7_churn_risk.py`

**目的**: 現時点でチャーンリスクが高いユーザーをスコアリングし、プッシュ通知戦略の優先対象を特定する。

**仮説**: 「直近の投稿日数の減少 × ストリーク損失 × フォロワー少ない」のユーザーが最もチャーンしやすい。

### 実装仕様

#### Step 1: リスクスコア計算

```python
def calc_churn_risk_score(user, today) -> float:
    """0〜100のチャーンリスクスコアを返す（高いほどリスク大）"""
    score = 0.0
    
    # 要因1: 直近未投稿日数（最大40点）
    days_silent = (today - date.fromisoformat(user["lastPostedDate"])).days
    score += min(days_silent / 30 * 40, 40)
    
    # 要因2: ストリーク損失率（最大30点）
    max_s = max(user.get("maxStreak", 0), 1)
    curr_s = user.get("streak", 0)
    loss_ratio = max(0, (max_s - curr_s) / max_s)
    score += loss_ratio * 30
    
    # 要因3: ソーシャル孤立度（最大20点）
    # フォロワー0人 = 20点、10人以上 = 0点
    followers = len(user.get("followers", []))
    score += max(0, 20 - followers * 2)
    
    # 要因4: タスクなし（10点）
    if not user.get("tasks"):
        score += 10
    
    return min(score, 100)
```

重みは仮設定です。M2・M3 の結果を受けて実際の寄与度で調整してください。

#### Step 2: リスク分布

ヒストグラム（X軸: チャーンリスクスコア、Y軸: ユーザー数）を作成。

#### Step 3: 高リスクユーザーの特定

スコア上位20%のユーザーリストを出力。匿名化（uid をハッシュ化）してCSVに保存。

#### Step 4: ロジスティック回帰による要因分析（検証）

```python
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import cross_val_score

# 目的変数: is_churned (days_since_last_post >= 30)
# 特徴量: days_silent, streak_loss_ratio, follower_count, task_count, streak_protections
# 5-fold cross-validation で AUC を計算
# 係数から「チャーンに最も寄与する要因」を特定
```

### 出力ファイル

- `analytics/data/analysis/m7_churn_risk_distribution.html`
- `analytics/data/analysis/m7_high_risk_users.csv`（匿名化UID・スコア・要因）
- `analytics/data/analysis/m7_feature_importance.html`（ロジスティック回帰の係数棒グラフ）
- `analytics/data/analysis/m7_model_performance.txt`（AUC等の精度指標）

### 開発への示唆

- 高リスクスコアのユーザーへ「◯日ぶり！今日また始めよう」プッシュ通知を実装
- スコアが急上昇するタイミング（例: 7日未投稿）を通知タイミングとして設定
- シールド贈与の自動トリガー（例: 「スコアが閾値超えたらシールドを1個付与」）

---

## M8: アクションログ行動ファネル分析

**実装ファイル**: `analytics/analysis/m8_funnel.py`

**目的**: ユーザーがアプリ内でどの行動フローを踏んでいるかを可視化し、離脱・未到達が多いステップを特定する。

**仮説**: 「投稿を見る → リアクションする → フォローする」という社会的なアクションの連鎖が形成されていないユーザーが多い。

### 実装仕様

#### Step 0: 実際のイベント名確認

M0 の出力（`m0_schema_report.txt`）から全 eventName 一覧を確認し、以下のファネルに当てはまるイベント名を特定してください。M0 の結果を参照して、存在するイベント名のみを使用してください。

#### Step 1: セッション分割

```python
# 同一 uid の action_logs を clientTimestamp でソート
# 連続するイベントの間隔が 30分以上空いたら別セッションとする
# セッションIDを付与
```

#### Step 2: 以下のファネルを分析（存在するイベントのみ）

**ファネル A: ソーシャルエンゲージメントファネル**
```
friend_feed_viewed
  → reaction_sent（リアクション送信）
    → [フォローアクション（イベント名を M0 で確認）]
      → [プロフィール閲覧]
```

**ファネル B: 投稿完了ファネル**
```
[投稿開始イベント]（M0で確認）
  → [写真/テキスト入力]
    → [投稿送信完了]
```

**ファネル C: 新規ユーザーファネル（初日のみ）**
```
[アプリ起動 / チュートリアル開始]
  → [タスク設定]
    → [初回投稿]
      → [初回リアクション受信 or 送信]
```

各ファネルについて:
- 各ステップのユーザー数と通過率を集計
- Plotly の funnel chart で可視化
- 最も離脱率が高いステップを特定

#### Step 3: イベント遷移マトリクス

```python
# 同一セッション内の連続するイベントペア (event_A → event_B) の頻度を集計
# ヒートマップ（行: event_A、列: event_B、値: 遷移頻度）で可視化
# 「reaction_sent の後に何が起きているか」「friend_feed_viewed の後に何も起きていないか」を確認
```

#### Step 4: 時間帯別活動分析

```python
# clientTimestamp の時間帯（0〜23時）別のイベント件数を集計
# 日本時間に変換（UTC+9）
# 棒グラフで可視化
# ユーザーがアプリを使う時間帯 → プッシュ通知の最適タイミング
```

### 出力ファイル

- `analytics/data/analysis/m8_funnel_social.html`（ソーシャルファネル）
- `analytics/data/analysis/m8_funnel_post.html`（投稿ファネル）
- `analytics/data/analysis/m8_event_transition_heatmap.html`（遷移マトリクス）
- `analytics/data/analysis/m8_hourly_activity.html`（時間帯別活動）
- `analytics/data/analysis/m8_funnel_stats.csv`

### 開発への示唆

- 「friend_feed_viewed」後にリアクションしない率が高い → フィード上でのリアクションUIの改善（タップ領域拡大・アニメーション追加）
- 投稿ファネルの途中離脱が多い → 投稿フローの簡素化（ステップ削減）
- 最も多くの活動が起きる時間帯 → プッシュ通知の送信時刻に採用

---

## M9: 統合サマリー・開発優先度マトリクス生成

**実装ファイル**: `analytics/analysis/m9_priority_matrix.py`

**目的**: M1〜M8 の結果を統合し、「インパクト × 実装コスト」の2軸で開発施策を優先順位付けした優先度マトリクスを生成する。

### 実装仕様

#### Step 1: 各モジュールからキーメトリクスを読み込む

```python
# 以下のCSVから主要指標を読み込む
# m1_retention_table.csv → D30 リテンション率（全体平均）
# m2_summary.csv → ストリーク離脱チャーン率（streak_gap 7+ のチャーン率）
# m3_summary.csv → ソーシャル閾値・相関係数
# m4_magic_moments.csv → 最重要イベントとリテンション差分
# m5_category_stats.csv → 最高アクティブ率カテゴリ
# m6_cluster_profiles.csv → 最大セグメントと第2セグメントの課題
# m7_model_performance.txt → チャーン予測 AUC
```

#### Step 2: 施策リストと評価

以下の施策候補を評価してください（読み込んだデータで数値を埋めること）。

```python
initiatives = [
    {
        "name": "オンボーディング改善（初週の magic moment 誘導）",
        "impact_basis": "D30リテンション改善 × ユーザー数",
        "relevant_modules": ["M1", "M4"],
    },
    {
        "name": "ソーシャル接続促進（最初の◯人フォロー誘導）",
        "impact_basis": "ソーシャル閾値到達ユーザーのアクティブ率向上",
        "relevant_modules": ["M3", "M6"],
    },
    {
        "name": "ストリークリカバリー機能",
        "impact_basis": "ストリーク離脱後チャーン率の低減",
        "relevant_modules": ["M2"],
    },
    {
        "name": "チャーンリスクユーザーへのプッシュ通知",
        "impact_basis": "高リスクユーザー数 × 通知開封率",
        "relevant_modules": ["M7", "M8"],
    },
    {
        "name": "高定着カテゴリへの新規流入施策（ASO・広告）",
        "impact_basis": "カテゴリ別アクティブ率差分",
        "relevant_modules": ["M5"],
    },
    {
        "name": "フィードUI改善（リアクション導線強化）",
        "impact_basis": "ファネル通過率改善",
        "relevant_modules": ["M8"],
    },
    {
        "name": "タスクなしユーザーのタスク設定誘導",
        "impact_basis": "タスク0件ユーザーのチャーン率低減",
        "relevant_modules": ["M6", "M7"],
    },
]
```

#### Step 3: スコアリング

各施策に対して、読み込んだデータから以下を算出。

```python
# impact_score: 影響を受けるユーザー数 × 改善期待値（0〜10の推定値）
# effort_score: 実装の相対的な難易度（1=低, 3=中, 5=高 の主観評価をここで固定）
# priority_score: impact_score / effort_score
```

#### Step 4: 優先度マトリクス（バブルチャート）

```python
# X軸: effort_score（左ほど低コスト）
# Y軸: impact_score（上ほど高インパクト）
# バブルサイズ: priority_score
# ラベル: 施策名
# 色: priority_score（高=赤, 低=青）
```

#### Step 5: テキストサマリーの生成

```python
# 以下の内容をテキストファイルに書き出す
summary = f"""
== V-EFFECT 解析サマリー ({datetime.date.today()}) ==

[アプリの現状]
- D30 リテンション率: {d30_retention:.1%}
- 直近14日アクティブ率: {active_rate_14d:.1%}
- チャーン率（30日以上未投稿）: {churn_rate:.1%}
- action_logs のイベント種類数: {event_type_count}

[最重要発見]
1. {finding_1}  （M1より）
2. {finding_2}  （M2より）
3. {finding_3}  （M3より）
4. {finding_4}  （M4より）

[開発優先度 TOP5]
1位: {top1_initiative} — 根拠: {top1_basis}
2位: {top2_initiative} — 根拠: {top2_basis}
3位: {top3_initiative} — 根拠: {top3_basis}
4位: {top4_initiative} — 根拠: {top4_basis}
5位: {top5_initiative} — 根拠: {top5_basis}
"""
```

### 出力ファイル

- `analytics/data/analysis/m9_priority_matrix.html`（バブルチャート）
- `analytics/data/analysis/m9_summary.txt`（テキストサマリー）
- `analytics/data/analysis/m9_initiatives_ranked.csv`（施策ランキングテーブル）

---

## 実行コマンド一覧

以下を `analytics/` ディレクトリ内で順番に実行してください。

```bash
# 0. データが未取得の場合は取得
python export_raw_data.py --format json

# 1. 解析ディレクトリの初期化
mkdir -p data/analysis

# 2. 各モジュールを順番に実行
python analysis/m0_explore.py
python analysis/m1_retention.py
python analysis/m2_streak_churn.py
python analysis/m3_social_retention.py
python analysis/m4_first_week.py
python analysis/m5_category_retention.py
python analysis/m6_segmentation.py
python analysis/m7_churn_risk.py
python analysis/m8_funnel.py
python analysis/m9_priority_matrix.py
```

---

## 出力ファイル一覧

すべて `analytics/data/analysis/` に保存（gitignore済み）。

| ファイル | モジュール | 内容 |
|---|---|---|
| m0_schema_report.txt | M0 | データスキーマ・件数レポート |
| m1_cohort_retention_heatmap.html | M1 | コホート別リテンションヒートマップ |
| m1_retention_curve.html | M1 | 平均リテンション曲線 |
| m1_retention_table.csv | M1 | リテンション数値テーブル |
| m2_streak_gap_churn.html | M2 | ストリーク損失別チャーン率 |
| m2_max_streak_churn.html | M2 | maxStreak 別チャーン率 |
| m2_shield_effect.html | M2 | シールド効果グラフ |
| m2_scatter.html | M2 | maxStreak vs 未投稿日数 散布図 |
| m3_follower_active_rate.html | M3 | フォロワー数別アクティブ率 |
| m3_mutual_active_rate.html | M3 | 相互フォロー数別アクティブ率 |
| m3_social_streak_scatter.html | M3 | ソーシャル × ストリーク散布図 |
| m3_summary.csv | M3 | 相関係数・閾値 |
| m4_first_week_feature_comparison.html | M4 | 初週行動グループ比較 |
| m4_magic_moments.html | M4 | Magic moment（重要行動）ランキング |
| m5_category_matrix.html | M5 | カテゴリ別アクティブ率 × リアクション 4象限 |
| m5_category_stats.csv | M5 | カテゴリ別全指標テーブル |
| m6_cluster_radar.html | M6 | クラスタ別レーダーチャート |
| m6_cluster_pca_scatter.html | M6 | クラスタ PCA 散布図 |
| m6_user_clusters.csv | M6 | UID → クラスタ対応表 |
| m7_churn_risk_distribution.html | M7 | チャーンリスクスコア分布 |
| m7_high_risk_users.csv | M7 | 高リスクユーザー一覧（匿名化） |
| m7_feature_importance.html | M7 | チャーン寄与要因ランキング |
| m8_funnel_social.html | M8 | ソーシャルエンゲージメントファネル |
| m8_event_transition_heatmap.html | M8 | イベント遷移ヒートマップ |
| m8_hourly_activity.html | M8 | 時間帯別活動グラフ |
| m9_priority_matrix.html | M9 | 開発施策優先度バブルチャート |
| m9_summary.txt | M9 | 統合テキストサマリー |
| m9_initiatives_ranked.csv | M9 | 施策優先度ランキング |

---

## 注意事項

1. **プライバシー**: `data/analysis/` はすべて `.gitignore` 対象です。UID は可能な限りハッシュ化してください（`src/anonymizer.py` の `anonymize_uid()` を使用）。
2. **データ量**: action_logs が大量の場合、M4・M8 は直近90日分に限定して実行してください。
3. **サンプルサイズ**: コホートのサンプルが5件未満の場合は「データ不足」として除外してください。
4. **タイムゾーン**: すべての日時はJST（UTC+9）に変換して表示してください。
5. **再現性**: `random_state=42` を固定してください（KMeans等）。
