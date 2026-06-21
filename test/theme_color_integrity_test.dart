import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_effect/config/app_colors.dart';
import 'package:v_effect/config/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Theme Color Integrity Tests', () {
    testWidgets('Verify Light Theme is statically Light regardless of active AppColors mode', (WidgetTester tester) async {
      // 1. Test when AppColors is set to dark
      AppColors.updateThemeMode(ThemeMode.dark);
      expect(AppColors.isDark, isTrue);

      // ライトテーマの背景は純白（Instagram風デザイン）
      final lightThemeUnderDark = AppTheme.light;
      expect(lightThemeUnderDark.scaffoldBackgroundColor, const Color(0xFFFFFFFF));
      expect(lightThemeUnderDark.colorScheme.surface, const Color(0xFFFFFFFF));
      expect(lightThemeUnderDark.colorScheme.onSurface, const Color(0xFF1A1A1A));

      // 2. Test when AppColors is set to light
      AppColors.updateThemeMode(ThemeMode.light);
      expect(AppColors.isDark, isFalse);

      final lightThemeUnderLight = AppTheme.light;
      expect(lightThemeUnderLight.scaffoldBackgroundColor, const Color(0xFFFFFFFF));
      expect(lightThemeUnderLight.colorScheme.surface, const Color(0xFFFFFFFF));
      expect(lightThemeUnderLight.colorScheme.onSurface, const Color(0xFF1A1A1A));
    });

    testWidgets('Verify Dark Theme is statically Dark regardless of active AppColors mode', (WidgetTester tester) async {
      // 1. Test when AppColors is set to light
      AppColors.updateThemeMode(ThemeMode.light);
      expect(AppColors.isDark, isFalse);

      final darkThemeUnderLight = AppTheme.dark;
      expect(darkThemeUnderLight.scaffoldBackgroundColor, const Color(0xFF000000));
      expect(darkThemeUnderLight.colorScheme.surface, const Color(0xFF141414));
      expect(darkThemeUnderLight.colorScheme.onSurface, const Color(0xFFFFFFFF));

      // 2. Test when AppColors is set to dark
      AppColors.updateThemeMode(ThemeMode.dark);
      expect(AppColors.isDark, isTrue);

      final darkThemeUnderDark = AppTheme.dark;
      expect(darkThemeUnderDark.scaffoldBackgroundColor, const Color(0xFF000000));
      expect(darkThemeUnderDark.colorScheme.surface, const Color(0xFF141414));
      expect(darkThemeUnderDark.colorScheme.onSurface, const Color(0xFFFFFFFF));
    });
  });
}
