import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_colors.dart';

// ── Tier System ──────────────────────────────────────────────────────────────

class _TierStyle {
  final String label;
  final Color primaryColor;
  final Color glowColor;
  final Color flameColor;
  final bool hasParticles;
  final int nextMilestone;
  final int prevMilestone;
  final String nextLabel;

  const _TierStyle({
    required this.label,
    required this.primaryColor,
    required this.glowColor,
    required this.flameColor,
    required this.hasParticles,
    required this.nextMilestone,
    required this.prevMilestone,
    required this.nextLabel,
  });
}

_TierStyle _getTierStyle(int streak) {
  if (streak >= 30) {
    return const _TierStyle(
      label: 'PLATINUM',
      primaryColor: Color(0xFF8AC4FF),
      glowColor: Color(0xFF8AC4FF),
      flameColor: Color(0xFF8AC4FF),
      hasParticles: true,
      nextMilestone: 9999,
      prevMilestone: 30,
      nextLabel: 'LEGEND',
    );
  } else if (streak >= 7) {
    return const _TierStyle(
      label: 'GOLD',
      primaryColor: AppColors.accentGold,
      glowColor: Color(0xFFFFD700),
      flameColor: AppColors.accentGold,
      hasParticles: true,
      nextMilestone: 30,
      prevMilestone: 7,
      nextLabel: 'PLATINUM',
    );
  } else if (streak >= 3) {
    return const _TierStyle(
      label: 'SILVER',
      primaryColor: Color(0xFFD9D9D9),
      glowColor: Color(0xFFFFFFFF),
      flameColor: Color(0xFFD9D9D9),
      hasParticles: true,
      nextMilestone: 7,
      prevMilestone: 3,
      nextLabel: 'GOLD',
    );
  } else {
    return const _TierStyle(
      label: 'BRONZE',
      primaryColor: Color(0xFFCD7F32),
      glowColor: Color(0xFFCD7F32),
      flameColor: Color(0xFFCD7F32),
      hasParticles: false,
      nextMilestone: 3,
      prevMilestone: 1,
      nextLabel: 'SILVER',
    );
  }
}

// ── Particle Model ───────────────────────────────────────────────────────────

class _Particle {
  double x;
  double y;
  double speedY;
  double speedX;
  double size;
  double opacity;
  double opacityDelta;
  Color color;

  _Particle({
    required this.x,
    required this.y,
    required this.speedY,
    required this.speedX,
    required this.size,
    required this.opacity,
    required this.opacityDelta,
    required this.color,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;

  _ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()
        ..color = p.color.withValues(alpha: p.opacity.clamp(0, 1))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => true;
}

// ── Dialog Widget ────────────────────────────────────────────────────────────

/// 投稿完了時のお祝いダイアログ — V STREAK Dopamine Edition
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
      barrierColor: AppColors.black.withValues(alpha: 0.9),
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

  // Feature 1: Slot roll-up counter
  late AnimationController _counterController;
  late Animation<int> _countAnimation;

  // Feature 2: Stamp entry animation
  late AnimationController _entryController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  // Feature 3: Pulse glow
  late AnimationController _pulseController;
  late AnimationController _shimmerController;

  // Particles
  late AnimationController _particleController;
  final List<_Particle> _particles = [];
  final math.Random _rng = math.Random();

  Timer? _autoCloseTimer;
  bool _hapticFired = false;

  @override
  void initState() {
    super.initState();
    final tier = _getTierStyle(widget.streakDays);

    // ── Feature 2: Stamp Entry ──────────────────────────────────────────
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.4, end: 0.95)
            .chain(CurveTween(curve: Curves.easeOutQuart)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.95, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
    ]).animate(_entryController);
    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0, 0.3, curve: Curves.easeIn),
      ),
    );

    // ── Feature 1: Slot Roll-up ─────────────────────────────────────────
    _counterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _countAnimation = IntTween(
      begin: 0,
      end: widget.streakDays,
    ).animate(
      CurvedAnimation(
        parent: _counterController,
        curve: Curves.easeOutExpo,
      ),
    );
    _countAnimation.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_hapticFired) {
        _hapticFired = true;
        HapticFeedback.heavyImpact();
      }
    });

    // ── Feature 3: Pulse Glow ───────────────────────────────────────────
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    if (widget.isRecordUpdating) _shimmerController.repeat();

    // ── Feature 3: Particles ────────────────────────────────────────────
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    if (tier.hasParticles) {
      _initParticles(tier);
      _particleController.repeat();
    }

    // Start entry + counter with slight offset
    _entryController.forward().then((_) {
      if (mounted) {
        HapticFeedback.mediumImpact();
        _counterController.forward();
      }
    });

    _autoCloseTimer = Timer(const Duration(seconds: 7), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _initParticles(_TierStyle tier) {
    for (int i = 0; i < 18; i++) {
      _particles.add(_Particle(
        x: _rng.nextDouble(),
        y: _rng.nextDouble() * 0.5 + 0.5, // start in lower half
        speedY: _rng.nextDouble() * 0.004 + 0.002,
        speedX: (_rng.nextDouble() - 0.5) * 0.002,
        size: _rng.nextDouble() * 3 + 1.5,
        opacity: _rng.nextDouble() * 0.6 + 0.1,
        opacityDelta: _rng.nextDouble() * 0.015 + 0.005,
        color: tier.primaryColor,
      ));
    }

    _particleController.addListener(() {
      for (final p in _particles) {
        p.y -= p.speedY;
        p.x += p.speedX;
        p.opacity -= p.opacityDelta;
        if (p.y < -0.1 || p.opacity <= 0) {
          p.x = _rng.nextDouble();
          p.y = 1.1;
          p.speedY = _rng.nextDouble() * 0.004 + 0.002;
          p.speedX = (_rng.nextDouble() - 0.5) * 0.002;
          p.opacity = _rng.nextDouble() * 0.5 + 0.2;
          p.opacityDelta = _rng.nextDouble() * 0.015 + 0.005;
          p.size = _rng.nextDouble() * 3 + 1.5;
        }
      }
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _counterController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    _particleController.dispose();
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tier = _getTierStyle(widget.streakDays);

    return Center(
      child: AnimatedBuilder(
        animation: Listenable.merge([_entryController]),
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: child,
            ),
          );
        },
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 300,
            height: 460,
            decoration: BoxDecoration(
              color: AppColors.grey08,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: tier.primaryColor.withValues(alpha: 0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: tier.glowColor.withValues(alpha: 0.12),
                  blurRadius: 60,
                  spreadRadius: 8,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Shimmer for record-breaking
                if (widget.isRecordUpdating) _buildShimmerEffect(),

                // Particle layer
                if (tier.hasParticles) _buildParticleLayer(),

                // Main content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 44),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Tier label
                      _buildTierBadge(tier),
                      const SizedBox(height: 28),

                      // Flame icon with aura
                      _buildStreakIcon(tier),
                      const SizedBox(height: 28),

                      // Slot roll-up counter
                      _buildCounter(tier),
                      const SizedBox(height: 6),

                      // V STREAK label
                      _buildVStreakLabel(tier),
                      const SizedBox(height: 24),

                      // Status badge
                      _buildStatusBadge(tier),
                      const Spacer(),

                      // Feature 4: Progress bar
                      _buildProgressBar(tier),
                    ],
                  ),
                ),

                // Close button
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: AppColors.grey30, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTierBadge(_TierStyle tier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(
          color: tier.primaryColor.withValues(alpha: 0.35),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(30),
        color: tier.primaryColor.withValues(alpha: 0.05),
      ),
      child: Transform.translate(
        offset: const Offset(1.5, 0),
        child: Text(
          tier.label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: tier.primaryColor.withValues(alpha: 0.85),
            letterSpacing: 3,
          ),
        ),
      ),
    );
  }

  Widget _buildStreakIcon(_TierStyle tier) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = _pulseController.value;
        final glowAlpha = 0.08 + pulse * 0.16;
        final scale = 1.0 + pulse * 0.06;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.grey15,
              border: Border.all(
                color: tier.primaryColor.withValues(alpha: 0.3 + pulse * 0.2),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: tier.glowColor.withValues(alpha: glowAlpha),
                  blurRadius: 36,
                  spreadRadius: 6,
                ),
                BoxShadow(
                  color: tier.glowColor.withValues(alpha: glowAlpha * 0.4),
                  blurRadius: 80,
                  spreadRadius: 12,
                ),
              ],
            ),
            child: Icon(
              Icons.local_fire_department_rounded,
              size: 44,
              color: tier.flameColor.withValues(alpha: 0.7 + pulse * 0.3),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCounter(_TierStyle tier) {
    return AnimatedBuilder(
      animation: _countAnimation,
      builder: (context, _) {
        return ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              tier.primaryColor,
              tier.primaryColor.withValues(alpha: 0.7),
            ],
          ).createShader(bounds),
          child: Transform.translate(
            offset: const Offset(-1.5, 0),
            child: Text(
              '${_countAnimation.value}',
              style: GoogleFonts.outfit(
                fontSize: 72,
                fontWeight: FontWeight.w900,
                color: AppColors.white,
                letterSpacing: -3,
                height: 1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }

  Widget _buildVStreakLabel(_TierStyle tier) {
    return Transform.translate(
      offset: const Offset(2.0, 0),
      child: Text(
        'V STREAK',
        style: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: tier.primaryColor.withValues(alpha: 0.6),
          letterSpacing: 4,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(_TierStyle tier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      decoration: BoxDecoration(
        color: widget.isRecordUpdating
            ? tier.primaryColor.withValues(alpha: 0.12)
            : AppColors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isRecordUpdating
              ? tier.primaryColor.withValues(alpha: 0.3)
              : AppColors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Transform.translate(
        offset: const Offset(1.0, 0),
        child: Text(
          widget.isRecordUpdating ? '🏆  RECORD UPDATED' : '継続中',
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: widget.isRecordUpdating ? tier.primaryColor : AppColors.grey50,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(_TierStyle tier) {
    // If platinum (max), show a different message
    if (tier.nextMilestone >= 9999) {
      return Column(
        children: [
          Transform.translate(
            offset: const Offset(1.0, 0),
            child: Text(
              'LEGENDARY STREAK',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: tier.primaryColor.withValues(alpha: 0.6),
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      );
    }

    final streak = widget.streakDays;
    final prev = tier.prevMilestone;
    final next = tier.nextMilestone;
    final progress = ((streak - prev) / (next - prev)).clamp(0.0, 1.0);
    final daysLeft = next - streak;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              tier.label,
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: tier.primaryColor.withValues(alpha: 0.5),
                letterSpacing: 2,
              ),
            ),
            Text(
              '${tier.nextLabel} まで あと$daysLeft日',
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.grey30,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 4,
                child: Stack(
                  children: [
                    // Track
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.grey15,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    // Fill
                    FractionallySizedBox(
                      widthFactor: value,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: LinearGradient(
                            colors: [
                              tier.primaryColor.withValues(alpha: 0.5),
                              tier.primaryColor,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: tier.glowColor.withValues(alpha: 0.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildParticleLayer() {
    return AnimatedBuilder(
      animation: _particleController,
      builder: (context, _) {
        return Positioned.fill(
          child: CustomPaint(
            painter: _ParticlePainter(List.from(_particles)),
          ),
        );
      },
    );
  }

  Widget _buildShimmerEffect() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _shimmerController,
        builder: (context, _) {
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
                  AppColors.white.withValues(alpha: 0.05),
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
