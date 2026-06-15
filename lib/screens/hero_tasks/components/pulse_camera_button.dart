import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../config/app_colors.dart';

// ────────────────────────────────────────────
// ドーパミン刺激カメラボタン（呼吸 + ゴールドシマー）
// ────────────────────────────────────────────
class PulseCameraButton extends StatefulWidget {
  const PulseCameraButton({super.key, required this.tierColor});
  final Color tierColor;

  @override
  State<PulseCameraButton> createState() => _PulseCameraButtonState();
}

class _PulseCameraButtonState extends State<PulseCameraButton>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _shimmerController;
  late final Animation<double> _shimmerAngle;

  bool _isVisible = true;
  bool _isAppForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // ゴールドシマー：3秒で一周
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _shimmerAngle = Tween<double>(begin: 0, end: 2 * 3.14159265).animate(
      _shimmerController,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isFg = state == AppLifecycleState.resumed;
    if (_isAppForeground == isFg) return;
    _isAppForeground = isFg;
    _syncTickers();
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    if (!mounted) return;
    final visible = info.visibleFraction > 0.01;
    if (_isVisible == visible) return;
    _isVisible = visible;
    _syncTickers();
  }

  void _syncTickers() {
    final shouldRun = _isVisible && _isAppForeground;
    if (shouldRun) {
      if (!_shimmerController.isAnimating) {
        _shimmerController.repeat();
      }
    } else {
      _shimmerController.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: const Key('pulse_camera_button'),
      onVisibilityChanged: _handleVisibilityChanged,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _shimmerAngle,
          builder: (context, _) {
            const innerSize = 76.0;
            const outerSize = 104.0;

            return SizedBox(
              width: outerSize,
              height: outerSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 内側サークル＋アイコン (ゴールドの縁取り)
                  Container(
                    width: innerSize,
                    height: innerSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.white.withValues(alpha: 0.06),
                      border: Border.all(
                        color: AppColors.accentGold.withValues(alpha: 0.8),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      color: AppColors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
