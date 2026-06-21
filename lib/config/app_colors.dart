import 'dart:ui';
import 'package:flutter/material.dart';

/// V EFFECT カラーシステム — Absolute Monochrome
///
/// 有彩色を一切排除。白・黒・グレーの階調のみで構成。
class AppColors {
  AppColors._();

  // ── Absolute Monochrome Constants ─────────────────
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color pureBlack = Color(0xFF000000);
  static const Color lightGrey95 = Color(0xFFF2F2F2);
  static const Color lightGrey90 = Color(0xFFE6E6E6);
  static const Color lightGrey85 = Color(0xFFD9D9D9);
  static const Color lightGrey70 = Color(0xFFB3B3B3);
  static const Color lightGrey55 = Color(0xFF666666);
  static const Color lightGrey50 = Color(0xFF808080);
  static const Color lightGrey30 = Color(0xFF4D4D4D);
  static const Color darkGrey15 = Color(0xFF262626);
  static const Color darkGrey20 = Color(0xFF333333);
  static const Color darkGrey08 = Color(0xFF141414);
  static const Color darkGrey10 = Color(0xFF1A1A1A);

  static ThemeMode _themeMode = ThemeMode.dark;

  /// テーマモードを更新します（ThemeProviderなどから呼び出します）
  static void updateThemeMode(ThemeMode mode) {
    _themeMode = mode;
  }

  /// 現在のテーマがダークモードかどうかを判定します
  static bool get isDark {
    if (_themeMode == ThemeMode.system) {
      return PlatformDispatcher.instance.platformBrightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  // ── Monochrome Scale ─────────────────────
  static Color get white => isDark ? const Color(0xFFFFFFFF) : const Color(0xFF1A1A1A);
  static Color get grey95 => isDark ? const Color(0xFFF2F2F2) : const Color(0xFF0D0D0D);
  static Color get grey85 => isDark ? const Color(0xFFD9D9D9) : const Color(0xFF1A1A1A);
  static Color get grey70 => isDark ? const Color(0xFFB3B3B3) : const Color(0xFF333333);
  static Color get grey50 => isDark ? const Color(0xFF808080) : const Color(0xFF737373);
  static Color get grey30 => isDark ? const Color(0xFF4D4D4D) : const Color(0xFFB3B3B3);
  static Color get grey20 => isDark ? const Color(0xFF333333) : const Color(0xFFD4D4D4);
  // ライトモード時のコントラスト階層（明暗差）崩壊を防ぐため、グレー値を調整しています。
  // ライトモードでは grey15(F7F7F7・中間) > grey10(EFEFEF) > grey08(FFFFFF・純白) > grey05(FAFAFA・極薄) の順になります。
  static Color get grey15 => isDark ? const Color(0xFF262626) : const Color(0xFFF7F7F7);
  static Color get grey10 => isDark ? const Color(0xFF1A1A1A) : const Color(0xFFEFEFEF);
  // ライトモードでは grey08 を純白にし、bgSurface（カード背景）として使用。
  // 画面背景（bgBase = black）を純白（FFFFFF）にすることで、Instagramのようなクリーンな見た目にします。
  static Color get grey08 => isDark ? const Color(0xFF141414) : const Color(0xFFFFFFFF);
  static Color get grey05 => isDark ? const Color(0xFF0D0D0D) : const Color(0xFFFAFAFA);
  static Color get black => isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);

  // ── Semantic aliases ─────────────────────
  static Color get primary => white;
  static Color get primaryLight => grey95;
  static Color get primaryDark => grey85;

  static Color get bgBase => black;
  static Color get bgSurface => grey08;
  static Color get bgElevated => grey15;
  static Color get border => grey20;

  static Color get textPrimary => white;
  static Color get textSecondary => grey50;
  static Color get textMuted => grey30;

  static Color get success => grey85;
  static Color get error => const Color(0xFFFF5252); // 唯一の例外：エラーは赤を許容
  static Color get warning => grey70;

  // ── Accent Colors ────────────────────────
  static Color get accentGold => const Color(0xFFD4AF37);
  static Color get accentGoldLight => const Color(0xFFFFD700);

  // ── Gradients ────────────────────────────
  static LinearGradient get primaryGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [white, grey85],
      );

  static LinearGradient get bgGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [grey10, black],
      );

  static LinearGradient get cardGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [grey15, grey10],
      );

  static LinearGradient get glassGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? const [Color(0x1AFFFFFF), Color(0x08FFFFFF)]
            : const [Color(0x1A000000), Color(0x08000000)],
      );
}

