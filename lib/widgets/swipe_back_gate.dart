import 'package:flutter/material.dart';

/// 画面の左半分から右へスワイプした際に前の画面に戻るためのラッパーウィジェット
class SwipeBackGate extends StatefulWidget {
  final Widget child;
  const SwipeBackGate({super.key, required this.child});

  @override
  State<SwipeBackGate> createState() => _SwipeBackGateState();
}

class _SwipeBackGateState extends State<SwipeBackGate> {
  double _startX = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent, // 子要素のタップイベントを妨げない
      onHorizontalDragStart: (details) {
        _startX = details.globalPosition.dx;
      },
      onHorizontalDragEnd: (details) {
        final screenWidth = MediaQuery.of(context).size.width;
        
        // 条件: 
        // 1. スワイプ開始位置が画面の左半分であること
        // 2. 右方向へのスワイプ速度が一定以上(600px/s)であること
        if (_startX < screenWidth / 2 && 
            details.primaryVelocity != null && 
            details.primaryVelocity! > 600) {
          Navigator.pop(context);
        }
      },
      child: widget.child,
    );
  }
}
