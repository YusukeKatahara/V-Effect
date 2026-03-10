import 'dart:async';
import 'package:flutter/material.dart';

/// 投稿完了時のお祝いダイアログ
/// 【設計コンセプト】
/// - 高級感: ダークトーンとガラスモーフィズム、ゴールドのアクセント
/// - スマート: シンプルな幾何学構成と滑らかなアニメーション
/// - 達成感: 独自描画のダイナミックな炎と記録更新時のエフェクト
class PostSuccessDialog extends StatefulWidget {
  final int streakDays;
  final bool isRecordUpdating;

  const PostSuccessDialog({
    super.key,
    required this.streakDays,
    this.isRecordUpdating = false,
  });

  /// ダイアログを表示する静的メソッド
  static Future<void> show(
    BuildContext context, {
    required int streakDays,
    bool isRecordUpdating = false,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder:
          (_) => PostSuccessDialog(
            streakDays: streakDays,
            isRecordUpdating: isRecordUpdating,
          ),
    );
  }

  @override
  State<PostSuccessDialog> createState() => _PostSuccessDialogState();
}

class _PostSuccessDialogState extends State<PostSuccessDialog>
    with TickerProviderStateMixin {
  late AnimationController _flameController;
  late AnimationController _shimmerController;
  Timer? _autoCloseTimer;

  @override
  void initState() {
    super.initState();

    // 炎のアニメーション
    _flameController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.isRecordUpdating ? 400 : 800),
    )..repeat(reverse: true);

    // 光沢感（シマー）のアニメーション（記録更新時のみ）
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    if (widget.isRecordUpdating) {
      _shimmerController.repeat();
    }

    // 5秒後に自動で閉じる
    _autoCloseTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) _close();
    });
  }

  @override
  void dispose() {
    _flameController.dispose();
    _shimmerController.dispose();
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  void _close() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 280,
          height: 400,
          decoration: BoxDecoration(
            color: const Color(0xFF1A2637), // 高級感のあるダークネイビー
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color:
                  widget.isRecordUpdating
                      ? Colors.amber.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.1),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (widget.isRecordUpdating ? Colors.amber : Colors.black)
                    .withValues(alpha: 0.3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // 背景の光沢エフェクト
              if (widget.isRecordUpdating) _buildShimmerEffect(),

              // メインコンテンツ
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // カスタム炎
                    _buildFlameIcon(),
                    const SizedBox(height: 40),

                    // ストリーク日数
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${widget.streakDays}',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -1,
                            shadows: [
                              Shadow(
                                color: Colors.amber.withValues(alpha: 0.5),
                                blurRadius: widget.isRecordUpdating ? 15 : 0,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '日',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ステータステキスト
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            widget.isRecordUpdating
                                ? Colors.amber.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.isRecordUpdating ? '記録更新中' : '継続中',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color:
                              widget.isRecordUpdating
                                  ? Colors.amberAccent
                                  : Colors.white70,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 閉じるボタン
              Positioned(
                top: 12,
                right: 12,
                child: IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white54,
                    size: 28,
                  ),
                  onPressed: _close,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlameIcon() {
    return AnimatedBuilder(
      animation: _flameController,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(80, 100),
          painter: FlamePainter(
            animationValue: _flameController.value,
            isIntense: widget.isRecordUpdating,
          ),
        );
      },
    );
  }

  Widget _buildShimmerEffect() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _shimmerController,
        builder: (context, child) {
          final v = _shimmerController.value;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [
                  (v - 0.3).clamp(0.0, 1.0),
                  v.clamp(0.0, 1.0),
                  (v + 0.3).clamp(0.0, 1.0),
                ],
                colors: [
                  Colors.white.withValues(alpha: 0),
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 炎を描画するカスタムペインター
class FlamePainter extends CustomPainter {
  final double animationValue;
  final bool isIntense;

  FlamePainter({required this.animationValue, required this.isIntense});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.8);
    final flicker = animationValue * (isIntense ? 0.15 : 0.08);

    // 1. 外側の炎 (Deep Orange)
    _drawFlamePart(
      canvas,
      center,
      size.width * 0.5,
      size.height * 0.9 * (1.0 + flicker),
      const Color(0xFFFF4D00),
    );

    // 2. 中間の炎 (Orange/Amber)
    _drawFlamePart(
      canvas,
      center,
      size.width * 0.35,
      size.height * 0.7 * (1.1 + flicker),
      Colors.amber.shade700,
    );

    // 3. 内側の芯 (Yellow)
    _drawFlamePart(
      canvas,
      center,
      size.width * 0.2,
      size.height * 0.4 * (1.2 + flicker),
      Colors.yellow.shade400,
    );

    // 4. 最深部の光 (White)
    final whitePaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(center.translate(0, -10), 5, whitePaint);
  }

  void _drawFlamePart(
    Canvas canvas,
    Offset baseCenter,
    double width,
    double height,
    Color color,
  ) {
    final path = Path();
    final paint =
        Paint()
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    // 炎のしずく型を描画
    path.moveTo(baseCenter.dx, baseCenter.dy);

    // 右側
    path.quadraticBezierTo(
      baseCenter.dx + width,
      baseCenter.dy,
      baseCenter.dx + width * 0.5,
      baseCenter.dy - height * 0.4,
    );
    path.quadraticBezierTo(
      baseCenter.dx,
      baseCenter.dy - height,
      baseCenter.dx,
      baseCenter.dy - height,
    );

    // 左側
    path.quadraticBezierTo(
      baseCenter.dx,
      baseCenter.dy - height,
      baseCenter.dx - width * 0.5,
      baseCenter.dy - height * 0.4,
    );
    path.quadraticBezierTo(
      baseCenter.dx - width,
      baseCenter.dy,
      baseCenter.dx,
      baseCenter.dy,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant FlamePainter oldDelegate) => true;
}
