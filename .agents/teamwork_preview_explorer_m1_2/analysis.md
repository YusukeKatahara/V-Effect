# R1 (Monochrome Light Theme) テーマ構成と設計プランの分析レポート

## 1. はじめに
本レポートは、V EFFECT プロジェクトにおけるライトモード（R1: Absolute Monochrome Light Theme）導入のための設計分析レポートです。
現在アプリはダークモード（Dark Theme）主体で構成されており、ライトモード用のテーマ定義（`AppTheme.light`）は仮のプレースホルダー（一時的な枠組み）となっています。本分析では、現在のテーマの登録・初期化プロセスを整理し、要求されたカラーパレットを用いたライトモードの具体的な定義プラン（設計図）を提示します。

---

## 2. 現在のテーマ登録とインスタンス化の流れ
アプリが起動してからテーマが決定され、画面に適用されるまでの制御フローは以下の通りです。

### 2.1. テーマ設定の永続化と初期化（`lib/main.dart`）
1. **初期ロード (`_AppInitializerState._initialize`)**:
   - `SharedPreferences` (端末内データ保存ライブラリ) を介して、キー `'isDarkMode'` に保存された設定値を取得します（デフォルトは `true`：ダークモード）。
   - 取得した設定値に応じて、`VEffectApp.themeNotifier.value` に `ThemeMode.dark` または `ThemeMode.light` を設定します。
2. **動的変更の購読と適用**:
   - `VEffectApp` クラスには、アプリ全体のテーマ状態を管理する `static final ValueNotifier<ThemeMode> themeNotifier` が定義されています。
   - `_VEffectAppState.build` 内で `ValueListenableBuilder<ThemeMode>` を使用して `themeNotifier` を購読（変更の監視）しています。
   - テーマが変更されると、`MaterialApp` に渡されている `themeMode` が動的に更新され、アプリ全体に新しいテーマが再描画されます。

### 2.2. テーマデータのマッピング
`MaterialApp` には以下の通りテーマデータが登録されています。
- **`theme`**: `AppTheme.light` (ライトモード時の `ThemeData`)
- **`darkTheme`**: `AppTheme.dark` (ダークモード時の `ThemeData`)
- **`themeMode`**: `themeMode` (現在の選択状態)

---

## 3. 現行の `AppTheme` 実装状況（`lib/config/theme.dart`）
### 3.1. `AppTheme.dark` (既存)
非常に詳細なUIコンポーネント定義がなされており、ダークトーン主体のデザインが適用されています。
- `scaffoldBackgroundColor`: `AppColors.black` (#000000)
- `Card`: 背景 `AppColors.bgSurface` (#080808) / 境界線 `AppColors.grey20`
- `ElevatedButton`: 背景 `AppColors.white` / 文字 `AppColors.black`
- 各種テキスト: `GoogleFonts.outfit` および `GoogleFonts.notoSansJp` を使用し、主に `AppColors.white` を指定。

### 3.2. `AppTheme.light` (現状)
現在は以下のような最小限の定義（プレースホルダー）に留まっており、文字色やボタン、インプットボックスなどの各コンポーネント用テーマ（`ThemeData`）が定義されていません。
```dart
  static ThemeData get light {
    const cs = ColorScheme.light(
      primary: AppColors.black,
      onPrimary: AppColors.white,
      surface: AppColors.white,
      onSurface: AppColors.black,
      error: AppColors.error,
    );
    
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: AppColors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.black),
      ),
    );
  }
```

---

## 4. R1 (Absolute Monochrome Light Theme) 設計プラン
要求された以下のカラーパレットを完全に適用した `AppTheme.light` を定義します。

### 4.1. 要求カラーと `AppColors` のマッピング
| 用途 | 指定カラー (HEX) | 対応する `AppColors` 定数 |
| :--- | :--- | :--- |
| 背景 (Background) | `#FFFFFF` | `AppColors.white` |
| 主要テキスト (Text Primary) | `#000000` | `AppColors.black` |
| 副次的テキスト (Text Secondary) | `#1A1A1A` | `AppColors.grey10` |
| 境界線/サーフェス 1 (Border/Surface Light) | `#F2F2F2` | `AppColors.grey95` |
| 境界線/サーフェス 2 (Border/Surface Dark) | `#D9D9D9` | `AppColors.grey85` |

### 4.2. `ColorScheme` の設計 (Light Theme)
M3 (Material Design 3) 準拠の `ColorScheme.light` を以下のように構築します。
```dart
const cs = ColorScheme(
  brightness: Brightness.light,
  primary:          AppColors.black,
  onPrimary:        AppColors.white,
  primaryContainer: AppColors.grey95,      // #F2F2F2
  onPrimaryContainer: AppColors.black,
  secondary:        AppColors.grey85,      // #D9D9D9
  onSecondary:      AppColors.black,
  secondaryContainer: AppColors.grey95,    // #F2F2F2
  onSecondaryContainer: AppColors.grey10,  // #1A1A1A
  error:            AppColors.error,       // 赤（例外許可）
  onError:          AppColors.white,
  errorContainer:   Color(0xFFFFDAD6),
  onErrorContainer: Color(0xFF410002),
  surface:          AppColors.white,       // 基本背景 #FFFFFF
  onSurface:        AppColors.black,       // #000000
  onSurfaceVariant: AppColors.grey10,      // #1A1A1A
  outline:          AppColors.grey85,      // #D9D9D9 (境界線用)
  outlineVariant:   AppColors.grey95,      // #F2F2F2
  shadow:           AppColors.black,
  scrim:            AppColors.black,
  inverseSurface:   AppColors.black,
  onInverseSurface: AppColors.white,
  inversePrimary:   AppColors.grey85,
  surfaceTint:      AppColors.black,
);
```

### 4.3. 各種コンポーネントテーマの設計詳細

#### ① TextTheme (テキストスタイル)
ダークモードと対比させ、基本色を白から黒系に変更します。フォントの種類やサイズは統一します。
- **`displayLarge` ~ `titleLarge`**: `GoogleFonts.outfit` (color: `AppColors.black` = `#000000`)
- **`bodyLarge`, `bodyMedium`, `labelLarge`**: `GoogleFonts.notoSansJp`/`outfit` (color: `AppColors.black` = `#000000`)
- **`bodySmall`**: `GoogleFonts.notoSansJp` (color: `AppColors.grey10` = `#1A1A1A` - 副次的なテキスト色)
- **`labelMedium`, `labelSmall`**: `GoogleFonts.outfit` (color: `AppColors.grey10` = `#1A1A1A`)

#### ② AppBarTheme (アプリバー)
ライト背景に合わせてステータスバーのアイコン色をダーク（黒）に変更します。
- `backgroundColor`: `Colors.transparent`
- `surfaceTintColor`: `Colors.transparent`
- `elevation`: 0
- `systemOverlayStyle`: `SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent)` (ステータスバーの文字やアイコンを黒くし、白背景でも視認可能にします)
- `titleTextStyle`: `GoogleFonts.outfit(color: AppColors.black, fontSize: 20, fontWeight: FontWeight.w700)`
- `iconTheme`: `IconThemeData(color: AppColors.black)`

#### ③ CardTheme (カードコンポーネント)
カードなどのサーフェス背景には `#F2F2F2` を使用し、境界線に `#D9D9D9` を薄く適用します。
- `color`: `AppColors.grey95` (`#F2F2F2`)
- `surfaceTintColor`: `Colors.transparent`
- `elevation`: 0
- `shape`: `RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: AppColors.grey85, width: 1))` (境界線に `#D9D9D9` を指定)

#### ④ Buttons (ボタン類)
白黒反転のコントラストを維持し、モノクロームの美しさを表現します。
- **`ElevatedButtonThemeData`**:
  - `backgroundColor`: `AppColors.black` (`#000000`)
  - `foregroundColor`: `AppColors.white` (`#FFFFFF`)
- **`OutlinedButtonThemeData`**:
  - `foregroundColor`: `AppColors.black` (`#000000`)
  - `side`: `BorderSide(color: AppColors.grey85, width: 1.5)` (境界線に `#D9D9D9`)
- **`TextButtonThemeData`**:
  - `foregroundColor`: `AppColors.black` (`#000000`)

#### ⑤ InputDecorationTheme (テキスト入力欄)
入力フィールド背景にサーフェス色 `#F2F2F2` を使い、フォーカス時に枠線を黒にします。
- `filled`: `true`
- `fillColor`: `AppColors.grey95` (`#F2F2F2`)
- `enabledBorder` / `border`: `OutlineInputBorder(borderSide: BorderSide(color: AppColors.grey85))` (境界線に `#D9D9D9`)
- `focusedBorder`: `OutlineInputBorder(borderSide: BorderSide(color: AppColors.black, width: 1.5))` (フォーカス時に黒枠)
- `labelStyle`: `GoogleFonts.notoSansJp(color: AppColors.grey10)` (`#1A1A1A`)
- `hintStyle`: `GoogleFonts.notoSansJp(color: AppColors.grey50)`

#### ⑥ Navigation (ナビゲーション)
ボトムナビゲーションバー等の背景を `#F2F2F2` にし、選択時/非選択時の色を制御します。
- **`BottomNavigationBarThemeData` & `NavigationBarThemeData`**:
  - `backgroundColor`: `AppColors.grey95` (`#F2F2F2`)
  - `indicatorColor`: `AppColors.black.withValues(alpha: 0.05)` (薄い黒のハイライト)
  - 選択時: `AppColors.black` (`#000000`)
  - 非選択時: `AppColors.grey50` (`#808080`)

#### ⑦ その他UI部品
- **`dividerTheme`**: `color: AppColors.grey85` (`#D9D9D9`), `thickness: 1`
- **`snackBarTheme`**: `backgroundColor: AppColors.grey85` (`#D9D9D9`), `contentTextStyle: GoogleFonts.notoSansJp(color: AppColors.black)`
- **`progressIndicatorTheme`**: `color: AppColors.black`
- **`badgeTheme`**: `backgroundColor: AppColors.error` (赤), `textColor: AppColors.white`

---

## 5. 実装に向けた注意点とリファクタリング計画
`AppTheme.light` 内の `ThemeData` を定義するだけでなく、アプリ内の各画面（`lib/screens/`）でカラーがどのように指定されているかを精査する必要があります。

1. **直接的な `AppColors` 参照の修正**:
   - `lib/screens/` 内のUIコードで `AppColors.white` や `AppColors.black` がレイアウトの背景や文字色として直接ハードコーディング（直書き）されている場合、テーマをライトモードに切り替えても色が変わりません。
   - これらを `Theme.of(context).colorScheme.surface` や `Theme.of(context).colorScheme.onSurface` に置き換えるリファクタリング（再構築）が必要です。
2. **グラデーションの取り扱い**:
   - `AppColors.bgGradient` などのグラデーション定数が使われている箇所についても、ライトモード時には白基調のグラデーションにする等の動的ハンドリングが必要です。
3. **ステータスバー制御の検証**:
   - 各画面の `AnnotatedRegion<SystemUiOverlayStyle>` などで個別にステータスバーの明暗（`SystemUiOverlayStyle.light` 等）が上書きされている場合、テーマ切り替え時にステータスバーの文字が見えなくなる可能性があります。グローバルな `AppBarTheme` 側の設定に寄せるか、テーマの状態を監視して動的に切り替える仕組みが必要です。
