import 'package:flutter/material.dart';

/// カードめくりの操作感をなめらかにするカスタムページスクロール物理演算クラス。
class FrictionlessPageScrollPhysics extends PageScrollPhysics {
  const FrictionlessPageScrollPhysics({super.parent});

  @override
  FrictionlessPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return FrictionlessPageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring =>
      // ζ ≈ 0.9（やや不足減衰）→ 約0.7秒で収束。
      const SpringDescription(mass: 4.0, stiffness: 100.0, damping: 36.0);

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    return offset * 1.2;
  }

  @override
  double get minFlingVelocity => 20.0;
}
