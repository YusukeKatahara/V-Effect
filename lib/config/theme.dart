import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';


/// アプリ全体のテーマ — Absolute Monochrome
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final cs = ColorScheme(
      brightness: Brightness.light,
      primary:          const Color(0xFF1A1A1A),
      onPrimary:        const Color(0xFFFFFFFF),
      primaryContainer: const Color(0xFFF2F2F2), // 面 #F2F2F2
      onPrimaryContainer: const Color(0xFF1A1A1A),
      secondary:        const Color(0xFF262626), // 黒テキスト・要素 #262626
      onSecondary:      const Color(0xFFFFFFFF),
      secondaryContainer: const Color(0xFFF2F2F2),
      onSecondaryContainer: const Color(0xFF1A1A1A),
      error:            const Color(0xFFFF5252),
      onError:          const Color(0xFFFFFFFF),
      errorContainer:   const Color(0xFFFFDAD6),
      onErrorContainer: const Color(0xFF410002),
      surface:          const Color(0xFFFFFFFF), // 白背景 #FFFFFF
      onSurface:        const Color(0xFF1A1A1A), // 黒テキスト #1A1A1A
      onSurfaceVariant: const Color(0xFF737373),
      outline:          const Color(0xFFE8E8E8), // 枠線 #E8E8E8
      outlineVariant:   const Color(0xFFF2F2F2), // 枠線/面 #F2F2F2
      shadow:           const Color(0xFF000000),
      scrim:            const Color(0xFF000000),
      inverseSurface:       const Color(0xFF000000),
      onInverseSurface:     const Color(0xFFFFFFFF),
      inversePrimary:       const Color(0xFFB3B3B3),
      surfaceTint:      const Color(0xFF000000),
    );

    final base = TextTheme(
      displayLarge:  GoogleFonts.outfit(fontSize: 57, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)).copyWith(inherit: true),
      displayMedium: GoogleFonts.outfit(fontSize: 45, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)).copyWith(inherit: true),
      displaySmall:  GoogleFonts.outfit(fontSize: 36, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)).copyWith(inherit: true),
      headlineLarge: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)).copyWith(inherit: true),
      headlineMedium:GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A)).copyWith(inherit: true),
      headlineSmall: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A)).copyWith(inherit: true),
      titleLarge:    GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A)).copyWith(inherit: true),
      titleMedium:   GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500, color: const Color(0xFF1A1A1A)).copyWith(inherit: true),
      titleSmall:    GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF1A1A1A)).copyWith(inherit: true),
      bodyLarge:     GoogleFonts.notoSansJp(fontSize: 16, fontWeight: FontWeight.w400, color: const Color(0xFF1A1A1A)).copyWith(inherit: true),
      bodyMedium:    GoogleFonts.notoSansJp(fontSize: 14, fontWeight: FontWeight.w400, color: const Color(0xFF1A1A1A)).copyWith(inherit: true),
      bodySmall:     GoogleFonts.notoSansJp(fontSize: 12, fontWeight: FontWeight.w400, color: const Color(0xFF737373)).copyWith(inherit: true),
      labelLarge:    GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A)).copyWith(inherit: true),
      labelMedium:   GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF737373)).copyWith(inherit: true),
      labelSmall:    GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF4D4D4D)).copyWith(inherit: true),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      textTheme: base,

      // 画面背景を純白に設定します
      scaffoldBackgroundColor: const Color(0xFFFFFFFF),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
        ),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1A1A1A),
          letterSpacing: 0.3,
        ).copyWith(inherit: true),
        iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)),
      ),

      cardTheme: CardThemeData(
        color: const Color(0xFFFFFFFF),  // カードは純白（背景との対比で浮き上がる）
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: const Color(0xFFE8E8E8).withValues(alpha: 0.5), width: 1),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF000000),
          foregroundColor: const Color(0xFFFFFFFF),
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700).copyWith(inherit: true),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1A1A1A),
          side: const BorderSide(color: Color(0xFFE8E8E8), width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600).copyWith(inherit: true),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF1A1A1A),
          textStyle: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600).copyWith(inherit: true),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF2F2F2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF1A1A1A), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF5252)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF5252), width: 1.5),
        ),
        labelStyle: GoogleFonts.notoSansJp(color: const Color(0xFF808080), fontSize: 14).copyWith(inherit: true),
        hintStyle: GoogleFonts.notoSansJp(color: const Color(0xFF808080), fontSize: 14).copyWith(inherit: true),
        prefixIconColor: const Color(0xFF808080),
      ),

      dividerTheme: const DividerThemeData(
        color: Color(0xFFE8E8E8),
        thickness: 1,
        space: 1,
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFFFFFFFF),  // ボトムナビは純白（画面下部に浮く印象）
        selectedItemColor: Color(0xFF1A1A1A),
        unselectedItemColor: Color(0xFF737373),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFFFFFFFF),  // ナビバーも純白
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFF1A1A1A).withValues(alpha: 0.1),
        shadowColor: Colors.transparent,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFF1A1A1A), size: 24);
          }
          return const IconThemeData(color: Color(0xFF737373), size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A)).copyWith(inherit: true);
          }
          return GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF737373)).copyWith(inherit: true);
        }),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFFF2F2F2),
        contentTextStyle: GoogleFonts.notoSansJp(color: const Color(0xFF1A1A1A)).copyWith(inherit: true),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Color(0xFF1A1A1A),
      ),

      badgeTheme: const BadgeThemeData(
        backgroundColor: Color(0xFFFF5252),
        textColor: Color(0xFFFFFFFF),
      ),
    );
  }

  static ThemeData get dark {
    final cs = ColorScheme(
      brightness: Brightness.dark,
      primary:          const Color(0xFFFFFFFF),
      onPrimary:        const Color(0xFF000000),
      primaryContainer: const Color(0xFF262626),
      onPrimaryContainer: const Color(0xFFFFFFFF),
      secondary:        const Color(0xFFD9D9D9),
      onSecondary:      const Color(0xFF000000),
      secondaryContainer: const Color(0xFF333333),
      onSecondaryContainer: const Color(0xFFF2F2F2),
      error:            const Color(0xFFFF5252),
      onError:          const Color(0xFFFFFFFF),
      errorContainer:   const Color(0xFF5C0000),
      onErrorContainer: const Color(0xFFFFB4AB),
      surface:          const Color(0xFF141414),
      onSurface:        const Color(0xFFFFFFFF),
      onSurfaceVariant: const Color(0xFF808080),
      outline:          const Color(0xFF333333),
      outlineVariant:   const Color(0xFF262626),
      shadow:           const Color(0xFF000000),
      scrim:            const Color(0xFF000000),
      inverseSurface:       const Color(0xFFFFFFFF),
      onInverseSurface:     const Color(0xFF000000),
      inversePrimary:       const Color(0xFF4D4D4D),
      surfaceTint:      const Color(0xFFFFFFFF),
    );

    final base = TextTheme(
      displayLarge:  GoogleFonts.outfit(fontSize: 57, fontWeight: FontWeight.w700, color: const Color(0xFFFFFFFF)).copyWith(inherit: true),
      displayMedium: GoogleFonts.outfit(fontSize: 45, fontWeight: FontWeight.w700, color: const Color(0xFFFFFFFF)).copyWith(inherit: true),
      displaySmall:  GoogleFonts.outfit(fontSize: 36, fontWeight: FontWeight.w700, color: const Color(0xFFFFFFFF)).copyWith(inherit: true),
      headlineLarge: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w700, color: const Color(0xFFFFFFFF)).copyWith(inherit: true),
      headlineMedium:GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w600, color: const Color(0xFFFFFFFF)).copyWith(inherit: true),
      headlineSmall: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w600, color: const Color(0xFFFFFFFF)).copyWith(inherit: true),
      titleLarge:    GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w600, color: const Color(0xFFFFFFFF)).copyWith(inherit: true),
      titleMedium:   GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500, color: const Color(0xFFFFFFFF)).copyWith(inherit: true),
      titleSmall:    GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFFFFFFFF)).copyWith(inherit: true),
      bodyLarge:     GoogleFonts.notoSansJp(fontSize: 16, fontWeight: FontWeight.w400, color: const Color(0xFFFFFFFF)).copyWith(inherit: true),
      bodyMedium:    GoogleFonts.notoSansJp(fontSize: 14, fontWeight: FontWeight.w400, color: const Color(0xFFFFFFFF)).copyWith(inherit: true),
      bodySmall:     GoogleFonts.notoSansJp(fontSize: 12, fontWeight: FontWeight.w400, color: const Color(0xFF808080)).copyWith(inherit: true),
      labelLarge:    GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFFFFFFFF)).copyWith(inherit: true),
      labelMedium:   GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF808080)).copyWith(inherit: true),
      labelSmall:    GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF4D4D4D)).copyWith(inherit: true),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      textTheme: base,

      scaffoldBackgroundColor: const Color(0xFF000000),

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
          color: const Color(0xFFFFFFFF),
          letterSpacing: 0.3,
        ).copyWith(inherit: true),
        iconTheme: const IconThemeData(color: Color(0xFFFFFFFF)),
      ),

      cardTheme: CardThemeData(
        color: const Color(0xFF141414),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: const Color(0xFF333333).withValues(alpha: 0.5), width: 1),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFFFFF),
          foregroundColor: const Color(0xFF000000),
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700).copyWith(inherit: true),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFFFFFFF),
          side: const BorderSide(color: Color(0xFF333333), width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600).copyWith(inherit: true),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFFFFFFF),
          textStyle: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600).copyWith(inherit: true),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF333333)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF333333)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFFFFFF), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF5252)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF5252), width: 1.5),
        ),
        labelStyle: GoogleFonts.notoSansJp(color: const Color(0xFF808080), fontSize: 14).copyWith(inherit: true),
        hintStyle: GoogleFonts.notoSansJp(color: const Color(0xFF4D4D4D), fontSize: 14).copyWith(inherit: true),
        prefixIconColor: const Color(0xFF808080),
      ),

      dividerTheme: const DividerThemeData(
        color: Color(0xFF262626),
        thickness: 1,
        space: 1,
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF141414),
        selectedItemColor: Color(0xFFFFFFFF),
        unselectedItemColor: Color(0xFF4D4D4D),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF141414),
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFFFFFFFF).withValues(alpha: 0.1),
        shadowColor: Colors.transparent,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFFFFFFFF), size: 24);
          }
          return const IconThemeData(color: Color(0xFF4D4D4D), size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFFFFFFF)).copyWith(inherit: true);
          }
          return GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF4D4D4D)).copyWith(inherit: true);
        }),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF262626),
        contentTextStyle: GoogleFonts.notoSansJp(color: const Color(0xFFFFFFFF)).copyWith(inherit: true),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Color(0xFFFFFFFF),
      ),

      badgeTheme: const BadgeThemeData(
        backgroundColor: Color(0xFFFF5252),
        textColor: Color(0xFFFFFFFF),
      ),
    );
  }
}


