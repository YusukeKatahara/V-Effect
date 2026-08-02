# 画面表示設定（R2: テーマ・プロバイダーと永続化 / R3: 表示設定UI）実装設計書

## 1. 概要
本設計書は、V EFFECT アプリケーションにおけるダークモード/ライトモード/システム設定の動的切り替え（R2）および、X（旧Twitter）のUXを参考にした表示設定UI（R3）の実装計画である。
調査の結果、アプリ内の多くのUIコンポーネントが `AppColors.bgBase`（黒で固定）や `AppColors.textPrimary`（白で固定）などの定数を直接参照しており、単純に `ThemeMode.light` に切り替えるだけではライトモードが正しく反映されないという重要課題（ハードコードされた色の依存）が判明した。本計画では、この依存の解消手順も含めた安全な移行パスを提示する。

---

## 2. R2計画: テーマ・プロバイダーと永続化 (Theme Provider & Persistence)

### 2.1. 状態管理ライブラリの選定
V EFFECTの既存コードベースは **Riverpod** (`package:flutter_riverpod`) で統一されている（言語切り替えは `languageProvider` で実装）。
しかし、要件に「`provider` と `shared_preferences` を使用した永続化」とあるため、本設計ではプロジェクトの統一性を保つための「Riverpod（推奨案）」と「標準Provider（代替案）」の2つのアプローチを提示し、それぞれのメリット・デメリットを比較する。

#### 【比較】状態管理アプローチの比較
| 項目 | アプローチA: Riverpod (推奨案) | アプローチB: 標準Provider (代替案) |
| --- | --- | --- |
| **概要** | `StateNotifierProvider` を使用し、既存の言語設定プロバイダーと同様のパターンで実装。 | `package:provider` の `ChangeNotifier` と `ChangeNotifierProvider` を使用して実装。 |
| **一貫性** | **極めて高い**。他のすべてのプロバイダー（`languageProvider` 等）や画面（`ConsumerStatefulWidget`）と統一された記述。 | **低い**。同一アプリ内で2つの異なるプロバイダーシステム（Riverpodと標準Provider）が混在することになり、コードが乱雑化する。 |
| **実装の容易性**| 容易。`ref.watch(themeProvider)` で簡単にテーマ変更を検知可能。 | 中程度。Riverpodの `Consumer` と標準の `Consumer` が混在するため、ネストが深くなり、バグの原因になりやすい。 |
| **結論** | **推奨**（コードクオリティとメンテナビリティの観点から最適） | 非推奨（どうしても標準Providerパッケージに依存させたい理由がある場合のみ採用） |

### 2.2. テーマ永続化の移行設計 (Migration Design)
既存のアプリ初期化時（`main.dart`）では、テーマを Boolean (`isDarkMode`）で保持している。
```dart
// main.dart の既存ロジック
final isDarkMode = prefs.getBool('isDarkMode') ?? true;
VEffectApp.themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;
```
システム設定（`ThemeMode.system`）を含む3状態を管理するため、保存キーを新キー `'theme_mode'` (String型) に拡張する。

#### 下位互換性 (Backward Compatibility) の担保ロジック
1. 最初に新キー `'theme_mode'` (String) を検索する。
2. 新キーが存在しない場合、旧キー `'isDarkMode'` (Boolean) を検索する。
   - `true` の場合 → `ThemeMode.dark` と解釈。
   - `false` の場合 → `ThemeMode.light` と解釈。
3. 旧キーも存在しない場合、デフォルト値として `ThemeMode.system`（または従来同様に `ThemeMode.dark`）を設定する。

---

### 2.3. プロバイダーの設計契約 (Interface Contracts)

#### 【推奨】Riverpod版: `ThemeProvider` (`lib/providers/theme_provider.dart`)
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// テーマ設定を管理するグローバルプロバイダー
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

/// テーマの状態管理を行うNotifierクラス
/// [rennさんへ] ChangeNotifierの代わりにStateNotifierを使うことで、状態(ThemeMode)の変更を不変(Immutable)に扱えます。
class ThemeNotifier extends StateNotifier<ThemeMode> {
  // 初期値は一旦ThemeMode.systemに設定し、_loadThemeにて保存値をロードします
  ThemeNotifier() : super(ThemeMode.system) {
    _loadTheme();
  }

  static const String _themeKey = 'theme_mode';
  static const String _legacyKey = 'isDarkMode';

  /// SharedPreferencesからテーマ設定を非同期で読み込むメソッド
  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(_themeKey);

      if (savedTheme != null) {
        switch (savedTheme) {
          case 'light':
            state = ThemeMode.light;
            break;
          case 'dark':
            state = ThemeMode.dark;
            break;
          case 'system':
          default:
            state = ThemeMode.system;
            break;
        }
      } else {
        // レガシー(古い)キーの移行処理
        final legacyIsDark = prefs.getBool(_legacyKey);
        if (legacyIsDark != null) {
          state = legacyIsDark ? ThemeMode.dark : ThemeMode.light;
        } else {
          // 初回起動時のデフォルトは system に設定
          state = ThemeMode.system;
        }
      }
    } catch (e) {
      debugPrint('テーマのロード中にエラーが発生しました: $e');
    }
  }

  /// テーマモードを切り替えてSharedPreferencesに永続化するメソッド
  /// [mode] 新しく設定するThemeMode (system / light / dark)
  Future<void> setThemeMode(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String modeStr;
      switch (mode) {
        case ThemeMode.light:
          modeStr = 'light';
          break;
        case ThemeMode.dark:
          modeStr = 'dark';
          break;
        case ThemeMode.system:
          modeStr = 'system';
          break;
      }
      await prefs.setString(_themeKey, modeStr);
      state = mode; // 状態を更新（自動的にUIへ通知・再描画されます）
    } catch (e) {
      debugPrint('テーマの保存中にエラーが発生しました: $e');
    }
  }
}
```

#### 【代替案】標準Provider版: `ThemeProvider` (`lib/providers/theme_provider.dart`)
```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 標準Providerパッケージに対応したChangeNotifierベースのテーマプロバイダー
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  static const String _themeKey = 'theme_mode';
  static const String _legacyKey = 'isDarkMode';

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themeKey);

    if (savedTheme != null) {
      switch (savedTheme) {
        case 'light':
          _themeMode = ThemeMode.light;
          break;
        case 'dark':
          _themeMode = ThemeMode.dark;
          break;
        case 'system':
        default:
          _themeMode = ThemeMode.system;
          break;
      }
    } else {
      final legacyIsDark = prefs.getBool(_legacyKey);
      if (legacyIsDark != null) {
        _themeMode = legacyIsDark ? ThemeMode.dark : ThemeMode.light;
      } else {
        _themeMode = ThemeMode.system;
      }
    }
    notifyListeners(); // 変更通知をしてUIを更新
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    String modeStr;
    switch (mode) {
      case ThemeMode.light:
        modeStr = 'light';
        break;
      case ThemeMode.dark:
        modeStr = 'dark';
        break;
      case ThemeMode.system:
        modeStr = 'system';
        break;
    }
    await prefs.setString(_themeKey, modeStr);
    _themeMode = mode;
    notifyListeners();
  }
}
```

---

## 3. R3計画: XのUXを参考にした画面表示設定UI

### 3.1. 画面構成設計 (UX/UI Structure)
X（旧Twitter）の表示設定は、選択されたテーマがその場ですぐにどう見えるかを示す **「動的プレビュー（Live Preview）」** と、視覚的・直感的に操作できる **「グリッド/カード形式のセレクター」** が特徴である。V EFFECT でもこの優れたUXを採用する。

![Display Settings UI Mockup](/Users/rennlikeu/.gemini/antigravity/brain/98c35cc0-e740-461c-a96e-55cf6af876c0/display_settings_ui_mockup_1781567889145.png)

1. **画面表示プレビュー (Live Preview Card)**
   - 画面最上部に、モックのタイムライン投稿（または今日のクエストカード）を配置。
   - 下部セレクターでテーマを変更した瞬間、このプレビューカードの背景色、テキスト色、枠線がリアルタイムで変化する。
   - 【目的】ユーザーが設定確定前に全体の視覚イメージ（ライト、ダーク、システム）を直感的に掴めるようにするため。

2. **背景モードの選択カード (Background Cards)**
   - 3つの選択肢「ライト」「ダーク」「システムデフォルト」を横並び of 3枚のカードとして表示。
   - 各カードには以下の要素を配置：
     - 各モードを模したミニプレビュー色（ライトカードは背景白、ダークカードは背景黒、システムカードは半分分割グラデーションまたは中立グレー）。
     - モード名（ライト、ダーク、システム設定）。
     - ラジオボタン風の選択状態インジケーター。
     - 選択されたカードは **ゴールドの境界線（`AppColors.accentGold`）** とハイライトで強調される。

---

### 3.2. 画面実装の移行オプション
設定画面内にどのようにUIを配置するか、2つの選択肢がある。

#### 【比較】UI配置オプションの比較
| 項目 | オプション1: 設定画面内に直接インライン実装する | オプション2: 独立した「表示設定画面」へ遷移する（推奨） |
| --- | --- | --- |
| **概要** | `SettingsScreen` の中にプレビューと背景選択カードを直接埋め込む。 | `SettingsScreen` に「表示とデザイン」のメニューを追加し、新規作成する `DisplaySettingsScreen` へ遷移させる。 |
| **UXの良さ** | **低い**。設定の一番上にプレビューが入るため縦長になり、他の「通知」や「セキュリティ」の設定項目が画面下部に追いやられて見にくくなる。 | **極めて高い**。Xの遷移フローと完全に一致し、すっきりしたデザインを実現。将来的なフォントサイズ変更やコントラスト設定の追加も容易。 |
| **実装コスト**| 低い（画面を新規作成・ルート登録する必要がない）。 | 中程度（新規画面の作成、`AppRoutes` へのルート定義が必要）。 |
| **結論** | 簡易的な切り替えのみであれば可能。 | **推奨**（UXのクオリティおよび将来的な拡張性の観点から最適）。 |

---

### 3.3. 設計コード契約: `DisplaySettingsScreen` (`lib/screens/display_settings_screen.dart`)
以下は、X風のUXを備えた独立型の表示設定画面の設計コードである。

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_colors.dart';
import '../providers/theme_provider.dart';
import '../widgets/responsive_container.dart';
import 'package:v_effect/l10n/app_localizations.dart';

class DisplaySettingsScreen extends ConsumerWidget {
  const DisplaySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 現在選択されているテーマモードを監視
    final currentTheme = ref.watch(themeProvider);
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      // 画面の背景色はテーマに合わせて自動で追随するように設定
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          localizations.settingsDisplay, // "表示設定" (新規ローカライズ)
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
      ),
      body: ResponsiveContainer(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Section 1: Live Preview Card (動的プレビュー) ─────────────────────
            _buildLivePreviewCard(context, currentTheme),
            const SizedBox(height: 24),

            // セクションタイトル
            Text(
              localizations.themeSetting, // "テーマ設定"
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              localizations.themeDescription, // "アプリの見た目を切り替えます。"
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),

            // ── Section 2: Background Selector Cards (X風カードセレクター) ─────────
            Row(
              children: [
                Expanded(
                  child: _buildThemeCard(
                    context: context,
                    ref: ref,
                    mode: ThemeMode.light,
                    title: localizations.themeLight, // "ライト"
                    isActive: currentTheme == ThemeMode.light,
                    cardBg: AppColors.white,
                    textCol: AppColors.black,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildThemeCard(
                    context: context,
                    ref: ref,
                    mode: ThemeMode.dark,
                    title: localizations.themeDark, // "ダーク"
                    isActive: currentTheme == ThemeMode.dark,
                    cardBg: AppColors.black,
                    textCol: AppColors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildThemeCard(
                    context: context,
                    ref: ref,
                    mode: ThemeMode.system,
                    title: localizations.themeSystem, // "システム"
                    isActive: currentTheme == ThemeMode.system,
                    // システムカードは中間色のグレーまたは分割デザインを表現
                    cardBg: AppColors.grey20,
                    textCol: AppColors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 動的プレビューカードを構築するヘルパーメソッド
  Widget _buildLivePreviewCard(BuildContext context, ThemeMode mode) {
    // 現在有効な明るさを解決（システムモード時は実デバイスの輝度を参照）
    final isDark = _resolveIsDark(context, mode);

    final previewBg = isDark ? AppColors.grey08 : AppColors.grey95;
    final previewText = isDark ? AppColors.white : AppColors.black;
    final previewBorder = isDark ? AppColors.grey20 : AppColors.grey70;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: previewBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: previewBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: isDark ? AppColors.grey30 : AppColors.grey50,
                child: Icon(Icons.person, color: isDark ? AppColors.white : AppColors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'V EFFECT Support',
                    style: TextStyle(color: previewText, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    '@veffect_official',
                    style: TextStyle(color: isDark ? AppColors.grey50 : AppColors.grey70, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'これは表示設定のプレビューです。カードを選択すると、リアルタイムで全体のカラーが変化します。',
            style: TextStyle(color: previewText, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? AppColors.grey15 : AppColors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline, color: AppColors.accentGold, size: 16),
                const SizedBox(width: 6),
                Text(
                  '今日のクエスト: 完了',
                  style: TextStyle(color: previewText, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 各テーマ選択用カードのビルド
  Widget _buildThemeCard({
    required BuildContext context,
    required WidgetRef ref,
    required ThemeMode mode,
    required String title,
    required bool isActive,
    required Color cardBg,
    required Color textCol,
  }) {
    return GestureDetector(
      onTap: () => ref.read(themeProvider.notifier).setThemeMode(mode),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          // 選択中はゴールドの太枠、非選択時は細いグレーの枠線を表示
          border: Border.all(
            color: isActive ? AppColors.accentGold : AppColors.grey20,
            width: isActive ? 2.0 : 1.0,
          ),
          boxShadow: isActive
              ? [BoxShadow(color: AppColors.accentGold.withOpacity(0.2), blurRadius: 8, spreadRadius: 1)]
              : [],
        ),
        child: Stack(
          children: [
            // 中央配置のラベル
            Center(
              child: Text(
                title,
                style: TextStyle(
                  color: textCol,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            // 右下のチェックマーク/ラジオボタン
            Positioned(
              right: 8,
              bottom: 8,
              child: Icon(
                isActive ? Icons.radio_button_checked : Icons.radio_button_off,
                color: isActive ? AppColors.accentGold : AppColors.grey50,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 実際のダークモード判定
  bool _resolveIsDark(BuildContext context, ThemeMode mode) {
    if (mode == ThemeMode.dark) return true;
    if (mode == ThemeMode.light) return false;
    // system の場合は実画面の輝度を参照
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }
}
```

---

## 4. インターフェース規約と状態遷移 (Interface Contracts and State Changes)

### 4.1. 状態遷移フロー (State Transitions)
アプリ内テーマの状態は、ユーザーの選択（UI）およびアプリの起動（Preferencesロード）によって以下のように遷移する。

```
                       [ アプリ起動 (main.dart) ]
                                  │
                       SharedPreferencesを読み込み
                                  │
          ┌───────────────────────┼───────────────────────┐
          ▼                       ▼                       ▼
    [ 'light' が保存 ]       [ 'dark' が保存 ]     [ 'system' 又は保存なし ]
          │                       │                       │
          ▼                       ▼                       ▼
   (ThemeMode.light)       (ThemeMode.dark)       (ThemeMode.system)
          │                       │                       │
          │                       │                 端末の照度を解決
          │                       │             (MediaQuery.platformBrightness)
          │                       │                       │
          │                       │             ┌─────────┴─────────┐
          │                       │             ▼                   ▼
          │                       │        [Brightness.light]  [Brightness.dark]
          │                       │             │                   │
          ▼                       ▼             ▼                   ▼
    《ライトテーマ適用》      《ダークテーマ適用》  《ライトテーマ適用》  《ダークテーマ適用》
          │                       │             │                   │
          └───────────────────────┼─────────────┴───────────────────┘
                                  │
                        ユーザーがUIでモード変更
                                  │
          ┌───────────────────────┼───────────────────────┐
          ▼                       ▼                       ▼
   「ライト」を選択         「ダーク」を選択        「システム設定」を選択
          │                       │                       │
          ▼                       ▼                       ▼
  `setThemeMode(light)`   `setThemeMode(dark)`   `setThemeMode(system)`
          │                       │                       │
   SharedPreferencesに      SharedPreferencesに      SharedPreferencesに
     'light' を保存          'dark' を保存          'system' を保存
          │                       │                       │
          └───────────────────────┴───────────────────────┘
                                  │
                         UI状態が自動更新(Rebuild)
```

### 4.2. `MaterialApp` へのバインド
`main.dart` を以下のようにリファクタリングし、`themeProvider` (Riverpod) と `MaterialApp` を連携する。

```dart
// main.dart の build メソッド変更箇所の設計
@override
Widget build(BuildContext context) {
  // テーマプロバイダーを監視
  final themeMode = ref.watch(themeProvider);
  final lang = ref.watch(languageProvider);

  return MaterialApp(
    navigatorKey: VEffectApp.navigatorKey,
    title: 'V EFFECT',
    // テーマ設定
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: themeMode, // プロバイダーから渡されたThemeModeをそのまま指定
    
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [
      Locale('ja', 'JP'),
      Locale('en', 'US'),
    ],
    locale: Locale(lang),
    initialRoute: AppRoutes.wrapper,
    routes: AppRoutes.routes,
    navigatorObservers: [AnalyticsService.instance.observer],
  );
}
```

---

## 5. 技術的なリスクと解決策 (Technical Risks and Solutions)

### 5.1. 最大のリスク：ハードコードされた色依存 (`AppColors` 定数の直読み)
#### 【問題分析】
現在、`Scaffold(backgroundColor: AppColors.bgBase)` のように、UIの大部分で `AppColors` の定数を直接指定している。ライトモード（`ThemeMode.light`）を選択しても、これらのカラー指定が定数で固定されているため、画面は真っ黒のままで変化しない（さらに文字色 `AppColors.textPrimary` が白で固定されているため、Scaffoldの背景色自体がテーマによって白くなると、文字が見えなくなるバグが発生する）。

#### 【対策：段階的移行計画】
1. **フェーズ1（Milestone 1の適用範囲）**
   - 新規作成する `DisplaySettingsScreen` および既存の `SettingsScreen` を優先して **`Theme.of(context)` 依存にリファクタリング** する。これにより、設定画面単体でライト/ダークの完璧なテーマ動作を実証する。
2. **フェーズ2（全体リファクタリング計画）**
   - 他の主要画面（ホーム、クエスト、プロフィールなど）の配色定義を、以下のように `Theme.of(context).colorScheme` から解決するように段階的に書き換える。

#### 【リファクタリング用】配色マッピング表
| 従来の定数指定 | 移行後の推奨記述 (Theme.of(context) から取得) | ライトモード時の色 | ダークモード時の色 |
| --- | --- | --- | --- |
| `AppColors.bgBase` | `Theme.of(context).scaffoldBackgroundColor` | 白色 (`#FFFFFF`) | 黒色 (`#000000`) |
| `AppColors.textPrimary` | `Theme.of(context).colorScheme.onSurface` | 黒色 (`#000000`) | 白色 (`#FFFFFF`) |
| `AppColors.bgSurface` | `Theme.of(context).colorScheme.surface` | 薄い灰色 (`#F2F2F2`) | 極暗灰色 (`#0D0D0D`) |
| `AppColors.bgElevated` | `Theme.of(context).colorScheme.primaryContainer` | 灰色 (`#D9D9D9`) | 暗灰色 (`#262626`) |
| `AppColors.border` | `Theme.of(context).colorScheme.outline` | 中間灰色 (`#B3B3B3`) | 濃い灰色 (`#333333`) |

### 5.2. システムデフォルト設定時のOSテーマ変更検知
#### 【仕様】
Flutterの `MaterialApp` は、OS側でライト/ダークの切り替えが発生した際、自動的に再描画を行う。しかし、アプリがバックグラウンドから復帰した際に、テーマ設定の変更を確実に反映させたい場合、またはネイティブOS側のステータスバーなどの配色を同期させたい場合は、`WidgetsBindingObserver` の `didChangePlatformBrightness` をオーバーライドして検知することが可能。

#### 【実装案】
`main.dart` の `_VEffectAppState` クラス内に以下のライフサイクルメソッドを追加してログやネイティブ連携（StatusBarの輝度調整）を行う。
```dart
@override
void didChangePlatformBrightness() {
  super.didChangePlatformBrightness();
  final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
  debugPrint('OSテーマの変更を検知しました: $brightness');
  // システムテーマ変更に伴う追加のネイティブ制御（StatusBarスタイル適用など）が必要な場合はここに記述
}
```

---

## 6. 実装タスクチェックリスト
実装を担当するメンバーに向けた、具体的なステップ順の作業リストである。

- [ ] **1. Localization (`.arb`) ファイルの更新**
  - `lib/l10n/app_ja.arb` と `lib/l10n/app_en.arb` に表示設定用の翻訳テキストキーを追加。
  - ローカライズ生成コマンドを実行 (`flutter pub get` または `flutter gen-l10n`)。
- [ ] **2. `ThemeProvider` の新規作成**
  - `lib/providers/theme_provider.dart` ファイルを作成し、SharedPreferences永続化を伴うNotifierを実装。
- [ ] **3. `main.dart` の改修**
  - アプリ起動時のテーマロード処理を `themeProvider` から行うように変更。
  - `MaterialApp` を `ref.watch(themeProvider)` で購読し、`themeMode` をバインド。
- [ ] **4. `DisplaySettingsScreen` の新規作成**
  - `lib/screens/display_settings_screen.dart` を作成し、X風のライブプレビューと3枚の背景変更カードをレイアウト。
- [ ] **5. ルートの追加と設定画面の導線接続**
  - `lib/config/routes.dart` に `/display-settings` ルートを登録。
  - `lib/screens/settings_screen.dart` のリスト項目に「表示設定」への遷移を追加。
  - 設定画面関連の配色記述を `Theme.of(context)` にリファクタリング。
