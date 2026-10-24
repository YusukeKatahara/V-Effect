import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// [PageController] の安全なプロパティ取得用拡張機能
///
/// Flutter の [PageController.page] は、内部で [ScrollController.position] を呼び出します。
/// [ScrollController.position] は単一のビューのみを想定しており、
/// 画面切り替えやアニメーション・リビルド時に一時的に複数のビューがアタッチされると、
/// [Bad state: Too many elements] という例外を投げてアプリが即座にクラッシュします。
///
/// この拡張機能 [safePage] を使用することで、複数ビューが存在する場合でも安全に最新のビューから
/// ページ位置を計算し、例外が発生した場合もクラッシュさせずに安全に null またはフォールバック値を返します。
extension SafePageController on PageController {
  /// 現在のページ番号を安全に取得します。
  /// アタッチされていない場合や、計算不能な場合は null を返します（例外は投げません）。
  double? get safePage {
    if (!hasClients) return null;
    try {
      // 1つのビューのみがアタッチされている通常のケース
      if (positions.length == 1) {
        final pos = position;
        if (pos.hasContentDimensions) {
          final p = page;
          if (p != null && !p.isNaN && !p.isInfinite) {
            return p;
          }
        }
      }

      // トランジション中などで一時的に複数のビューがアタッチされている場合、
      // または通常の page ゲッターが使えない場合は、最新の position から自前でページ番号を計算する
      if (positions.isNotEmpty) {
        final pos = positions.last;
        if (pos.hasContentDimensions) {
          final fraction = viewportFraction;
          final double dim = math.max(1.0, pos.viewportDimension * fraction);
          final double clampedPixels = pos.pixels.clamp(pos.minScrollExtent, pos.maxScrollExtent);
          final calculatedPage = math.max(0.0, clampedPixels) / dim;
          if (!calculatedPage.isNaN && !calculatedPage.isInfinite) {
            return calculatedPage;
          }
        }
      }
    } catch (e) {
      // 万が一の例外（Too many elements など）を完全捕捉してアプリの強制終了を防止
      debugPrint('SafePageController.safePage safely handled exception: $e');
    }
    return null;
  }
}
