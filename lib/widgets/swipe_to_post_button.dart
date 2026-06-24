import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_colors.dart';

class SwipeToPostButton extends StatefulWidget {
  final bool isUploading;
  final VoidCallback onComplete;
  final String text;

  const SwipeToPostButton({
    super.key,
    required this.isUploading,
    required this.onComplete,
    required this.text,
  });

  @override
  State<SwipeToPostButton> createState() => _SwipeToPostButtonState();
}

class _SwipeToPostButtonState extends State<SwipeToPostButton> with SingleTickerProviderStateMixin {
  double _dragFraction = 0.0;
  double _lastHapticFraction = 0.0;
  bool _isCompleted = false;

  late AnimationController _snapController;
  late Animation<double> _snapAnimation;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _snapController.addListener(() {
      setState(() {
        _dragFraction = _snapAnimation.value;
      });
    });
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SwipeToPostButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isUploading && oldWidget.isUploading) {
      // 投稿完了後またはエラー時に元の状態へリセット
      setState(() {
        _isCompleted = false;
        _dragFraction = 0.0;
        _lastHapticFraction = 0.0;
      });
    }
  }

  void _onDragUpdate(DragUpdateDetails details, double maxWidth) {
    if (widget.isUploading || _isCompleted) return;

    final thumbSize = 52.0 - 8.0; // height(52) - padding(8)
    final usableWidth = maxWidth - thumbSize - 8.0;
    if (usableWidth <= 0) return;

    setState(() {
      _dragFraction += details.delta.dx / usableWidth;
      _dragFraction = _dragFraction.clamp(0.0, 1.0);
    });

    // 10%進むごとに「チキッ」と軽い振動を鳴らす
    if ((_dragFraction - _lastHapticFraction).abs() >= 0.1) {
      HapticFeedback.selectionClick();
      _lastHapticFraction = _dragFraction;
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (widget.isUploading || _isCompleted) return;

    if (_dragFraction >= 1.0) {
      setState(() {
        _isCompleted = true;
      });
      // 完了時に強めの振動
      HapticFeedback.heavyImpact();
      widget.onComplete();
    } else {
      // 途中で離した場合はバネのように戻る
      _snapAnimation = Tween<double>(begin: _dragFraction, end: 0.0).animate(
        CurvedAnimation(parent: _snapController, curve: Curves.easeOutBack),
      );
      _snapController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    const height = 52.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final thumbSize = height - 8;
        final maxDragDistance = maxWidth - thumbSize - 8;
        final currentDrag = maxDragDistance * _dragFraction;

        return Container(
          height: height,
          decoration: BoxDecoration(
            color: widget.isUploading ? Colors.white24 : AppColors.pureBlack.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(color: widget.isUploading ? Colors.transparent : AppColors.grey70),
            boxShadow: widget.isUploading
                ? []
                : [
                    BoxShadow(
                      color: AppColors.pureBlack.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: widget.isUploading
              ? Center(
                  child: SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.grey50,
                    ),
                  ),
                )
              : Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // 充填されるプログレスゲージ
                    Container(
                      width: 8 + thumbSize + currentDrag,
                      height: height,
                      decoration: BoxDecoration(
                        color: AppColors.accentGold.withValues(alpha: _dragFraction * 0.8 + 0.2),
                        borderRadius: BorderRadius.circular(height / 2),
                      ),
                    ),
                    
                    // 背景のテキスト（ツマミが近づくとフェードアウト）
                    Center(
                      child: Opacity(
                        opacity: (1.0 - _dragFraction).clamp(0.0, 1.0),
                        child: Text(
                          widget.text,
                          style: GoogleFonts.notoSansJp(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.pureWhite,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),

                    // ドラッグできるツマミ
                    Positioned(
                      left: 4 + currentDrag,
                      child: GestureDetector(
                        onHorizontalDragUpdate: (details) => _onDragUpdate(details, maxWidth),
                        onHorizontalDragEnd: _onDragEnd,
                        child: Container(
                          width: thumbSize,
                          height: thumbSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.pureWhite,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.pureBlack.withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.keyboard_double_arrow_right_rounded,
                            color: AppColors.pureBlack,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
