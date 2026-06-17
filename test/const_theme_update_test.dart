import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_effect/config/app_colors.dart';
import 'package:v_effect/providers/theme_provider.dart';

// テーマ変更時に再ビルドされるかを検証するための const ウィジェット
class ConstColoredWidget extends StatelessWidget {
  const ConstColoredWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('const_container'),
      color: AppColors.white,
      child: const Text('Const Widget'),
    );
  }
}

// 比較用の非 const ウィジェット
class NonConstColoredWidget extends StatelessWidget {
  const NonConstColoredWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('non_const_container'),
      color: AppColors.white,
      child: const Text('Non-Const Widget'),
    );
  }
}

// VEffectApp 内で実装したテーマ変更時の再帰的Elementツリー再構築処理をシミュレートするテスト用ラッパー
class TestThemeRebuildWrapper extends StatefulWidget {
  final Widget child;
  const TestThemeRebuildWrapper({super.key, required this.child});

  @override
  State<TestThemeRebuildWrapper> createState() => _TestThemeRebuildWrapperState();
}

class _TestThemeRebuildWrapperState extends State<TestThemeRebuildWrapper> {
  ThemeProvider? _themeProvider;

  void _onThemeChanged() {
    if (!mounted) return;
    void rebuildElement(Element element) {
      element.markNeedsBuild();
      element.visitChildren(rebuildElement);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        (context as Element).visitChildren(rebuildElement);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    _themeProvider?.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeProvider?.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestApp(ThemeProvider themeProvider) {
    return ChangeNotifierProvider<ThemeProvider>.value(
      value: themeProvider,
      child: TestThemeRebuildWrapper(
        child: Consumer<ThemeProvider>(
          builder: (context, provider, child) {
            // ThemeProvider が更新されたときに再描画を発生させる
            return MaterialApp(
              themeMode: provider.themeMode,
              home: Scaffold(
                body: Column(
                  children: [
                    const ConstColoredWidget(), // const で配置
                    NonConstColoredWidget(),    // 非 const で配置
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  group('Const Widget Theme Update Regression Test', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AppColors.updateThemeMode(ThemeMode.dark); // 初期はダーク
    });

    testWidgets('const widgets DO rebuild and capture theme changes when using recursive element rebuild traversal', (WidgetTester tester) async {
      final themeProvider = ThemeProvider();
      await themeProvider.loadFuture;
      await themeProvider.setThemeMode(ThemeMode.dark);

      await tester.pumpWidget(buildTestApp(themeProvider));
      await tester.pumpAndSettle();

      // 初期状態 (Dark Mode) の色を確認
      // AppColors.white は Dark Mode 時は 0xFFFFFFFF (Pure White)
      var constContainer = tester.widget<Container>(find.byKey(const Key('const_container')));
      var nonConstContainer = tester.widget<Container>(find.byKey(const Key('non_const_container')));

      expect(constContainer.color, const Color(0xFFFFFFFF));
      expect(nonConstContainer.color, const Color(0xFFFFFFFF));

      // テーマを Light Mode に切り替える
      await themeProvider.setThemeMode(ThemeMode.light);
      await tester.pumpAndSettle();

      // テーマ切り替え後の色を確認
      // AppColors.white は Light Mode 時は 0xFF000000 (Pure Black) になるべき
      constContainer = tester.widget<Container>(find.byKey(const Key('const_container')));
      nonConstContainer = tester.widget<Container>(find.byKey(const Key('non_const_container')));

      // 非 const ウィジェットは当然更新される
      expect(nonConstContainer.color, const Color(0xFF000000));

      // テーマ変更リスナーと再帰的走査により、const ウィジェットも正しく更新されていることをアサーション
      expect(constContainer.color, const Color(0xFF000000));

      print('Const container color after theme change: ${constContainer.color}');
      print('Non-const container color after theme change: ${nonConstContainer.color}');
    });
  });
}
