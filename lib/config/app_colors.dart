import "package:v_effect/config/app_colors.dart";
import 'package:flutter/material.dart';

/// V EFFECT カラーシステム — Absolute Monochrome
///
/// 有彩色を一切排除。白・黒・グレーの階調のみで構成。
class AppColors {
  AppColors._();

  // ── Monochrome Scale ─────────────────────
  static const Color white = Color(0xFFFFFFFF);
  static const Color grey95 = Color(0xFFF2F2F2);
  static const Color grey85 = Color(0xFFD9D9D9);
  static const Color grey70 = Color(0xFFB3B3B3);
  static const Color grey50 = Color(0xFF808080);
  static const Color grey30 = Color(0xFF4D4D4D);
  static const Color grey20 = Color(0xFF333333);
  static const Color grey15 = Color(0xFF262626);
  static const Color grey10 = Color(0xFF1A1A1A);
  static const Color grey08 = Color(0xFF141414);
  static const Color grey05 = Color(0xFF0D0D0D);
  static const Color black = Color(0xFF000000);

  // ── Semantic aliases ─────────────────────
  static const Color primary = white;
  static const Color primaryLight = grey95;
  static const Color primaryDark = grey85;

  static const Color bgBase = black;
  static const Color bgSurface = grey08;
  static const Color bgElevated = grey15;
  static const Color border = grey20;

  static const Color textPrimary = white;
  static const Color textSecondary = grey50;
  static const Color textMuted = grey30;

  static const Color success = grey85;
  static const Color error = Color(0xFFFF5252); // 唯一の例外：エラーは赤を許容
  static const Color warning = grey70;

  // ── Accent Colors ────────────────────────
  static const Color accentGold = Color(0xFFD4AF37);
  static const Color accentGoldLight = Color(0xFFFFD700);

  // ── Gradients ────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [white, grey85],
  );

  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [grey10, black],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [grey15, grey10],
  );

  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x1AFFFFFF), Color(0x08FFFFFF)],
  );
}
