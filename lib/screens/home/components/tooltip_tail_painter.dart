import 'package:flutter/material.dart';

/// ツールチップ（吹き出し）の尻尾の三角形を描画するカスタムペインター
class TooltipTailPainter extends CustomPainter {
  final Color color;
  TooltipTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
