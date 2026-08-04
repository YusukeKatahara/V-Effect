import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// IndexedStack 配下の各タブページをラップし、
/// 非アクティブ（非表示）時やアプリバックグラウンド時に自動で TickerMode(enabled: false) を適用して
/// アニメーションや再描画による CPU/GPU 負荷・発熱を一括停止する最適化コンポーネント。
class AutoPauseTab extends StatefulWidget {
  final String tabKey;
  final Widget child;

  const AutoPauseTab({
    super.key,
    required this.tabKey,
    required this.child,
  });

  @override
  State<AutoPauseTab> createState() => _AutoPauseTabState();
}

class _AutoPauseTabState extends State<AutoPauseTab>
    with WidgetsBindingObserver {
  bool _isVisible = true;
  bool _isAppActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = (state == AppLifecycleState.resumed);
    if (_isAppActive != active) {
      if (mounted) {
        setState(() {
          _isAppActive = active;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _isVisible && _isAppActive;
    return VisibilityDetector(
      key: Key(widget.tabKey),
      onVisibilityChanged: (info) {
        if (!mounted) return;
        final isVisibleNow = info.visibleFraction > 0.01;
        if (_isVisible != isVisibleNow) {
          setState(() {
            _isVisible = isVisibleNow;
          });
        }
      },
      child: TickerMode(
        enabled: enabled,
        child: widget.child,
      ),
    );
  }
}
