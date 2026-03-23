# パフォーマンス改善実施計画 (Performance Improvement Plan)

アプリ内の「画像の読み込み遅延」および「実行時の発熱」を解消するための具体的な改修プランです。共同開発環境にて、Gemini 等のエージェントに以下のステップを指示してください。

---

## 🎯 目的
- 画像読み込みの高速化と通信量の削減。
- CPU/GPU 負荷を下げ、長時間利用時の発熱を抑制する。
- メモリ消費量を最適化し、アプリのクラッシュ（OOM）を防ぐ。

---

## 🛠 改修ステップ

### 1. 依存関係の追加
`pubspec.yaml` にキャッシュ管理用のライブラリを追加します。
- **対象ファイル**: `pubspec.yaml`
- **内容**: `dependencies:` セクションに `cached_network_image: ^3.4.1` を追加。
- **指示コマンド**: `flutter pub add cached_network_image`

### 2. アップロード画像のサイズ制限 (リサイズ)
カメラ/アルバムからの取得時に、巨大な元画像をそのまま扱わないよう制限します。
- **対象ファイル**: `lib/screens/camera_screen.dart`
- **変更点**: `_picker.pickImage(...)` の引数に以下を追加。
  ```dart
  maxWidth: 1080,   // Full HD 相当の幅に制限
  maxHeight: 1920,  // 縦長のアスペクト比を考慮
  imageQuality: 70, // 品質を少し下げてファイルサイズを劇的に落とす
  ```

### 3. 画像表示ロジックの置換 (Caching)
ネットワーク画像を直接読み込んでいる箇所をキャッシュ対応版に置き換えます。
- **対象ファイル**: 
  - `lib/screens/friend_feed_screen.dart`
  - `lib/screens/home_screen.dart` (もしあれば)
  - `lib/widgets/` 内の画像表示パーツ
- **変更内容**: `Image.network(...)` を `CachedNetworkImage(...)` に置換。
- **ヒント**: `memCacheWidth` / `memCacheHeight` プロパティも併用し、デコードするピクセルサイズを画面サイズに合わせる（メモリ節約に絶大）。

### 4. 再描画範囲の局所化 (Repaint Boundary)
アニメーションやタイマー更新の影響を背景画像に波及させないようにします。
- **対象ファイル**: `lib/screens/friend_feed_screen.dart`
- **変更内容**:
  - `Image` ウィジェットを `RepaintBoundary` で囲む。これにより画像が再起動されずに保持される。
  - リアクションボタン（火の粉）のアニメーションレイヤーを独立した `StatefulWidget` に抽出し、親画面の `setState` ではなく、自身の内部状態だけで火の粉を管理するようにする。

---

## 🧪 検証方法
1. **通信量確認**: フレンド間で画像を繰り返し表示した際に、ネットワーク通信が発生しないことを確認。
2. **発熱確認**: 投稿画面とフィード画面を5分間往復し、端末の過度な発熱が抑えられているか確認。
3. **メモリ計測**: Flutter DevTools (Memory) を開き、画像表示時のメモリ使用量のピークが下がっているか確認。
