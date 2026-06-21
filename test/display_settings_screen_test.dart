import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import 'package:v_effect/providers/theme_provider.dart';
import 'package:v_effect/screens/display_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestWidget(ThemeProvider themeProvider) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ja'),
        home: const DisplaySettingsScreen(),
      ),
    );
  }

  group('DisplaySettingsScreen Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('renders all visual elements correctly', (WidgetTester tester) async {
      final themeProvider = ThemeProvider();
      await tester.pumpWidget(buildTestWidget(themeProvider));
      await tester.pumpAndSettle();

      // Verify the app bar title matches the localization for themeSetting
      expect(find.text('テーマ設定'), findsAtLeastNWidgets(1));

      // Verify that the Preview text is rendered
      expect(find.text('プレビュー'), findsOneWidget);

      // Verify the mock card contents (New profile preview contents)
      expect(find.text('renn'), findsOneWidget);
      expect(find.text('@rennlikeu'), findsOneWidget);
      expect(find.text('40'), findsOneWidget); // Streak count
      expect(find.text('13'), findsAtLeastNWidgets(2)); // Follow and follower count

      // Verify the theme option cards are rendered
      expect(find.text('ライトモード'), findsOneWidget);
      expect(find.text('ダークモード'), findsOneWidget);
      expect(find.text('システム設定に同期'), findsOneWidget);
    });

    testWidgets('tapping theme options changes the theme mode', (WidgetTester tester) async {
      final themeProvider = ThemeProvider();
      await themeProvider.loadFuture; // Wait for initial load if any

      await tester.pumpWidget(buildTestWidget(themeProvider));
      await tester.pumpAndSettle();

      // Initially, it should be dark mode or system, let's verify switching to light mode
      await tester.tap(find.text('ライトモード'));
      await tester.pumpAndSettle();

      expect(themeProvider.themeMode, ThemeMode.light);

      // Switch to dark mode
      await tester.tap(find.text('ダークモード'));
      await tester.pumpAndSettle();

      expect(themeProvider.themeMode, ThemeMode.dark);

      // Switch to system settings
      await tester.tap(find.text('システム設定に同期'));
      await tester.pumpAndSettle();

      expect(themeProvider.themeMode, ThemeMode.system);
    });
  });
}
