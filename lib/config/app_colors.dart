import 'package:flutter/material.dart';

/// V-Effect のカラーシステム
///
/// ブラック × アンバーゴールドのプレミアムダークテーマ
class AppColors {
  AppColors._();

  // ── Brand ──────────────────────────────────
  /// メインアクセント（アンバーゴールド）
  static const Color primary = Color(0xFFFFB800);

  /// プライマリの薄いバリアント
  static const Color primaryLight = Color(0xFFFFD54F);

  /// プライマリの暗いバリアント
  static const Color primaryDark = Color(0xFFF59E0B);

  // ── Backgrounds ────────────────────────────
  /// アプリ最底面の背景
  static const Color bgBase = Color(0xFF0A0A0B);

  /// カード・モーダルなどの浮いた面
  static const Color bgSurface = Color(0xFF141417);

  /// 少し明るい面（入力欄、チップなど）
  static const Color bgElevated = Color(0xFF1E1E24);

  /// ボーダー・区切り線
  static const Color border = Color(0xFF2A2A32);

  // ── Text ───────────────────────────────────
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFAAAAAF);
  static const Color textMuted     = Color(0xFF666672);

  // ── Semantic ───────────────────────────────
  static const Color success = Color(0xFF34D399);
  static const Color error   = Color(0xFFFF5252);
  static const Color warning = Color(0xFFFFB800);

  // ── Gradients ──────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFB800), Color(0xFFF59E0B)],
  );

  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF12121A), Color(0xFF0A0A0B)],
  );

  static const LinearGradient streakActiveGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF8C00), Color(0xFFFFB800)],
  );

  static const LinearGradient streakInactiveGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E1E24), Color(0xFF2A2A32)],
  );
}
