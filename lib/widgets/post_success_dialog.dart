import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_colors.dart';

/// 投稿完了時のお祝いダイアログ — Absolute Monochrome
class PostSuccessDialog extends StatefulWidget {
  final int streakDays;
  final bool isRecordUpdating;

  const PostSuccessDialog({
    super.key,
    required this.streakDays,
    this.isRecordUpdating = false,
  });

  static Future<void> show(
    BuildContext context, {
    required int streakDays,
    bool isRecordUpdating = false,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.black.withValues(alpha: 0.85),
      builder: (_) => PostSuccessDialog(
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
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  Timer? _autoCloseTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.isRecordUpdating ? 600 : 1000),
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    if (widget.isRecordUpdating) _shimmerController.repeat();

    _autoCloseTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    _autoCloseTimer?.cancel();
    super.dispose();
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
            color: AppColors.grey08,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: widget.isRecordUpdating
                  ? AppColors.white.withValues(alpha: 0.2)
                  : AppColors.white.withValues(alpha: 0.08),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.white.withValues(
                    alpha: widget.isRecordUpdating ? 0.08 : 0.03),
                blurRadius: 40,
                spreadRadius: 4,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              if (widget.isRecordUpdating) _buildShimmerEffect(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStreakIcon(),
                    const SizedBox(height: 40),
                    // Streak number
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [AppColors.white, AppColors.grey70],
                          ).createShader(bounds),
                          child: Text(
                            '${widget.streakDays}',
                            style: GoogleFonts.outfit(
                              fontSize: 56,
                              fontWeight: FontWeight.w900,
                              color: AppColors.white,
                              letterSpacing: -2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '日',
                          style: GoogleFonts.notoSansJp(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.grey50,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: widget.isRecordUpdating
                            ? AppColors.white.withValues(alpha: 0.1)
                            : AppColors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.white.withValues(
                              alpha: widget.isRecordUpdating ? 0.15 : 0.08),
                        ),
                      ),
                      child: Text(
                        widget.isRecordUpdating ? '記録更新' : '継続中',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: widget.isRecordUpdating
                              ? AppColors.white
                              : AppColors.grey50,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: IconButton(
                  icon: const Icon(Icons.close,
                      color: AppColors.grey30, size: 24),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreakIcon() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + _pulseController.value * 0.08;
        final glowAlpha =
            0.06 + _pulseController.value * (widget.isRecordUpdating ? 0.12 : 0.06);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.grey15,
              border: Border.all(
                color: AppColors.white.withValues(alpha: 0.15),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.white.withValues(alpha: glowAlpha),
                  blurRadius: 32,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(
              Icons.local_fire_department_rounded,
              size: 40,
              color: AppColors.white.withValues(
                  alpha: 0.7 + _pulseController.value * 0.3),
            ),
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
                  AppColors.white.withValues(alpha: 0),
                  AppColors.white.withValues(alpha: 0.06),
                  AppColors.white.withValues(alpha: 0),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
