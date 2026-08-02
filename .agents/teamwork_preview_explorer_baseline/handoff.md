# リファクタリングに向けた画面コンポーネント抽出の調査報告書 (Screen Component Extraction Analysis)

## 概要 (Summary)
`home_screen.dart`、`hero_tasks_screen.dart`、および `profile_screen.dart` のコード量が非常に肥大化しているため、再利用可能なプライベートクラスやサブ構造を調査し、別ファイルへの分割・抽出候補を選定しました。また、`flutter analyze` の実行により現状の警告内容を把握しました。

---

## 1. 観察事実 (Observation)

### 各画面ファイルのコードサイズと行数
対象となったファイルのパスと行数は以下の通りです：
- `lib/screens/home_screen.dart` — 全 2,768 行 (108,242 bytes)
- `lib/screens/hero_tasks_screen.dart` — 全 2,291 行 (85,408 bytes)
- `lib/screens/profile_screen.dart` — 全 1,848 行 (75,099 bytes)

---

### 各ファイル内の主要なプライベートクラスおよびメソッドの分布

#### ① `lib/screens/home_screen.dart`
- **`_GuardedStateLayer`** (1,802 ～ 1,963 行目, 約 160 行): 投稿前のロック画面（フレンドの投稿を隠すレイヤー）
- **`_FeedCard`** (1,968 ～ 2,289 行目, 約 320 行): フィード上の個別カードコンポーネント
- **`_FloatingFlamesLayer`** / **`_FloatingFlameWidget`** (2,290 ～ 2,434 行目, 約 140 行): VFIRE（リアクション時の上昇する炎エフェクト）
- **`_FrictionlessPageScrollPhysics`** (2,435 ～ 2,462 行目, 約 27 行): 滑らかなスワイプ動作を実現するカスタム物理挙動（`hero_tasks_screen.dart` にも同名の同一クラスが存在）
- **`_ParticleData`** / **`_DopamineEmojiExplosionLayer`** / **`_EmojiExplosionPainter`** (2,463 ～ 2,648 行目, 約 185 行): 絵文字リアクション時の爆発エフェクトを描画するレイヤー
- **`_BgmIndicator`** (2,669 ～ 2,768 行目, 約 100 行): BGM再生中のイコライザーアニメーション

#### ② `lib/screens/hero_tasks_screen.dart`
- **`_HeroTaskItem`** (35 ～ 65 行目, 30 行): 画面内で利用するタスクデータ保持用データモデル
- **`_TaskCard`** (1,274 ～ 2,100 行目, 約 827 行): タスクの一覧をスワイプ表示するカードコンポーネント。画像表示、BGM制御、長押しズーム、完了アクションを保持
- **`_PulseCameraButton`** (2,101 ～ 2,212 行目, 約 110 行): 脈動するカメラ起動ボタン（シマーエフェクト付き）
- **`_FrictionlessPageScrollPhysics`** (2,213 ～ 2,234 行目, 21 行): スワイプ物理（`home_screen.dart` と重複）
- **`_AutoSizeText`** (2,238 ～ 2,291 行目, 約 53 行): テキストサイズ自動縮小用ユーティリティ

#### ③ `lib/screens/profile_screen.dart`
- **`_buildQuestCard()`** メソッド (1,590 ～ 1,755 行目, 約 165 行): アクティブなタスクを表示するカードのビルド処理
- **`_EditableInfoRow`** (1,760 ～ 1,814 行目, 54 行): 直接編集可能なプロフィール設定項目行
- **`_SectionTitle`** (1,819 ～ 1,847 行目, 28 行): 左側にゴールド色の縦棒（インジケーター）を持つセクションタイトル

---

### `flutter analyze` の実行結果と該当画面の警告

`flutter analyze` の出力のうち、対象の3つの画面に関わるものは以下の通りです。

```
info • The private field _lastFocusedIndex could be 'final' • lib/screens/hero_tasks_screen.dart:129:7 • prefer_final_fields
warning • The value of the field '_lastFocusedIndex' isn't used • lib/screens/hero_tasks_screen.dart:129:7 • unused_field
info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/screens/hero_tasks_screen.dart:1689:60 • deprecated_member_use
warning • The '!' will have no effect because the receiver can't be null • lib/screens/hero_tasks_screen.dart:1990:38 • unnecessary_non_null_assertion

warning • The value of the field '_todayPosts' isn't used • lib/screens/profile_screen.dart:45:14 • unused_field
info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/screens/profile_screen.dart:1018:76 • deprecated_member_use
```

---

## 2. 論理展開 (Logic Chain)

1. **コード認知負荷の低減**:
   - Flutter における 1 ファイルあたり 1,500 行を超える UI クラスは、保守時にどの関数や変数がどのコンポーネントに属しているか追いにくくなります（認知負荷が高い状態）。
   - 画面専用のステート（`State`）と無関係な描画に徹している、あるいは独立した役割（アニメーションやリストアイテムの表現など）を持つプライベートクラスを抽出することで、メインクラスのコード量を劇的に削減できます。

2. **重複コードの排除**:
   - `_FrictionlessPageScrollPhysics` は、`home_screen.dart` と `hero_tasks_screen.dart` の両方で全く同じ実装で定義されています。これを `lib/widgets/` に一本化することで、変更時のメンテナンスが容易になります。

3. **ユーティリティの共通化**:
   - `_AutoSizeText` はフォントサイズ自動調整の機能を持っており、他の画面（例：マイプロフィールやフレンド一覧など）でも使い回せるため、画面フォルダ（`screens/`）内ではなく共通ウィジェット（`widgets/`）への抽出が適しています。

---

## 3. 留意事項 (Caveats)

- **状態管理とコールバック**:
  - `_FeedCard` や `_TaskCard` は、元の親ウィジェット内の状態（例：現在タップ通信中であるかどうかの `_reactingPostIds` など）やサービス（`SoundService` など）を呼び出しています。
  - これらを別ファイルに切り出す際は、単にコードをコピペするだけでなく、必要なデータ（モデルや表示設定値）をコンストラクタ経由で渡し、アクション（タップ、削除、リアクション）はコールバック関数（`VoidCallback` や `Function`）として親から渡すようにリファクタリングする必要があります。
- **deprecated の対応**:
  - `flutter analyze` で報告された `withOpacity` は Flutter SDK 3.7.0 以降で非推奨（deprecated）となっています。抽出作業を行う際、またはその前後に `.withValues(alpha: ...)` に書き換える必要があります。

---

## 4. 結論と抽出先ファイルの提案 (Conclusion & Proposed Files)

以下のフォルダ構成でコンポーネントを切り出すことを提案します。

### 📁 共有ウィジェット (`lib/widgets/`)
複数の画面から使用される汎用的なコンポーネントです。

| 元のクラス名 | 推奨抽出先パス | 役割 |
| :--- | :--- | :--- |
| `_FrictionlessPageScrollPhysics` | `lib/widgets/frictionless_page_scroll_physics.dart` | スムーズなスクロール制御（Home と HeroTasks で重複解消） |
| `_AutoSizeText` | `lib/widgets/auto_size_text.dart` | 幅に合わせたフォント縮小テキスト（再利用性大） |
| `_SectionTitle` | `lib/widgets/section_title.dart` | ゴールドの縦棒付き見出しヘッダー |

---

### 📁 ホーム画面コンポーネント (`lib/screens/home/components/`)
ホーム画面に特化したウィジェット群です。

| 元のクラス名 | 推奨抽出先パス | 役割 |
| :--- | :--- | :--- |
| `_FeedCard` | `lib/screens/home/components/feed_card.dart` | ポスト表示カード（親からコールバックで操作通知） |
| `_GuardedStateLayer` | `lib/screens/home/components/guarded_state_layer.dart` | 未投稿時のロック画面レイヤー |
| `_FloatingFlamesLayer`<br>`_FloatingFlameWidget` | `lib/screens/home/components/floating_flames_layer.dart` | 炎リアクションのフローティング演出 |
| `_DopamineEmojiExplosionLayer`<br>`_EmojiExplosionPainter`<br>`_ParticleData` | `lib/screens/home/components/dopamine_emoji_explosion_layer.dart` | 絵文字タップ時の爆発演出アニメーション |
| `_BgmIndicator` | `lib/screens/home/components/bgm_indicator.dart` | BGM 再生状態を示すアニメーション表示 |

---

### 📁 ヒーロータスク画面コンポーネント (`lib/screens/hero_tasks/components/`)
ヒーロータスク（Vクエスト）に特化したウィジェット群です。

| 元のクラス名 | 推奨抽出先パス | 役割 |
| :--- | :--- | :--- |
| `_HeroTaskItem` | `lib/screens/hero_tasks/components/hero_task_item.dart` | UIデータ保持用データモデルクラス |
| `_TaskCard` | `lib/screens/hero_tasks/components/task_card.dart` | 拡大・スワイプ・画像再生対応タスクカード |
| `_PulseCameraButton` | `lib/screens/hero_tasks/components/pulse_camera_button.dart` | シマー付きで脈動するカメラ起動ボタン |

---

### 📁 プロフィール画面コンポーネント (`lib/screens/profile/components/`)
プロフィール画面に特化したウィジェット群です。

| 元のメソッド / クラス名 | 推奨抽出先パス | 役割 |
| :--- | :--- | :--- |
| `_buildQuestCard` (メソッド) | `lib/screens/profile/components/quest_card.dart` | タスク一覧カード（Widget クラス化して抽出） |
| `_EditableInfoRow` | `lib/screens/profile/components/editable_info_row.dart` | プロフィール編集用のテキスト入力行 |

---

## 5. 検証方法 (Verification Method)

### 独立検証コマンド
抽出後に、プロジェクトの文法チェックと静的解析に問題がないか、以下のコマンドを実行します。
```bash
flutter analyze
```

### 期待される検証合格の条件
1. 新規ファイル作成、および元の画面ファイル（`home_screen.dart`, `hero_tasks_screen.dart`, `profile_screen.dart`）からコードが削除されインポート文が追加された状態で、上記の `flutter analyze` がエラー（Error）を出さずに終了すること。
2. 同時に、今回の `flutter analyze` で発見された未使用フィールド（`_lastFocusedIndex` や `_todayPosts`）が解消され、警告件数が減少していること。
