import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// アプリ全体のテーマ — Absolute Monochrome
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    // 【rennさん・yusukeさんへ】
    // 将来的なライトモード実装のためのベースです。
    // 現状はアプリ内の大部分がAppColorsの固定色を使っているため、完全なライトモード対応には
    // 全画面のリファクタリング（Theme.of(context)を使った動的な色取得への変更）が必要です。
    // 今回は設定切り替えの基盤として仮の ThemeData を提供しています。
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

  static ThemeData get dark {
    const cs = ColorScheme(
      brightness: Brightness.dark,
      primary:          AppColors.white,
      onPrimary:        AppColors.black,
      primaryContainer: AppColors.grey15,
      onPrimaryContainer: AppColors.white,
      secondary:        AppColors.grey85,
      onSecondary:      AppColors.black,
      secondaryContainer: AppColors.grey20,
      onSecondaryContainer: AppColors.grey95,
      error:            AppColors.error,
      onError:          Colors.white,
      errorContainer:   Color(0xFF5C0000),
      onErrorContainer: Color(0xFFFFB4AB),
      surface:          AppColors.bgSurface,
      onSurface:        AppColors.white,
      onSurfaceVariant: AppColors.grey50,
      outline:          AppColors.grey20,
      outlineVariant:   AppColors.grey15,
      shadow:           AppColors.black,
      scrim:            AppColors.black,
      inverseSurface:       AppColors.white,
      onInverseSurface:     AppColors.black,
      inversePrimary:       AppColors.grey30,
      surfaceTint:      AppColors.white,
    );

    final base = TextTheme(
      displayLarge:  GoogleFonts.outfit(fontSize: 57, fontWeight: FontWeight.w700, color: AppColors.white),
      displayMedium: GoogleFonts.outfit(fontSize: 45, fontWeight: FontWeight.w700, color: AppColors.white),
      displaySmall:  GoogleFonts.outfit(fontSize: 36, fontWeight: FontWeight.w700, color: AppColors.white),
      headlineLarge: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.white),
      headlineMedium:GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w600, color: AppColors.white),
      headlineSmall: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.white),
      titleLarge:    GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.white),
      titleMedium:   GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.white),
      titleSmall:    GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.white),
      bodyLarge:     GoogleFonts.notoSansJp(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.white),
      bodyMedium:    GoogleFonts.notoSansJp(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.white),
      bodySmall:     GoogleFonts.notoSansJp(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.grey50),
      labelLarge:    GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.white),
      labelMedium:   GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.grey50),
      labelSmall:    GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.grey30),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      textTheme: base,

      scaffoldBackgroundColor: AppColors.black,

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
        ),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.white,
          letterSpacing: 0.3,
        ),
        iconTheme: const IconThemeData(color: AppColors.white),
      ),

      cardTheme: CardThemeData(
        color: AppColors.bgSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.grey20.withValues(alpha: 0.5), width: 1),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.black,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.white,
          side: BorderSide(color: AppColors.grey20, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.white,
          textStyle: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.grey10,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.grey20),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.grey20),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.white, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        labelStyle: GoogleFonts.notoSansJp(color: AppColors.grey50, fontSize: 14),
        hintStyle: GoogleFonts.notoSansJp(color: AppColors.grey30, fontSize: 14),
        prefixIconColor: AppColors.grey50,
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.grey15,
        thickness: 1,
        space: 1,
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.bgSurface,
        selectedItemColor: AppColors.white,
        unselectedItemColor: AppColors.grey30,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.bgSurface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.white.withValues(alpha: 0.1),
        shadowColor: Colors.transparent,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.white, size: 24);
          }
          return const IconThemeData(color: AppColors.grey30, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.white);
          }
          return GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.grey30);
        }),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.grey15,
        contentTextStyle: GoogleFonts.notoSansJp(color: AppColors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.white,
      ),

      badgeTheme: const BadgeThemeData(
        backgroundColor: AppColors.error,
        textColor: Colors.white,
      ),
    );
  }
}
