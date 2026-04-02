import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_colors.dart';

class VictoryOverlay extends StatefulWidget {
  final VoidCallback onComplete;

  const VictoryOverlay({super.key, required this.onComplete});

  static Future<void> show(BuildContext context) async {
    await showGeneralDialog(
      context: context,
      barrierColor: Colors.transparent,
      transitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) {
        return VictoryOverlay(
          onComplete: () {
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  @override
  State<VictoryOverlay> createState() => _VictoryOverlayState();
}

class _VictoryOverlayState extends State<VictoryOverlay> with TickerProviderStateMixin {
  late AnimationController _flashController;
  late Animation<double> _flashOpacity;

  late AnimationController _textController;
  late Animation<double> _textScale;
  late Animation<double> _textOpacity;

  @override
  void initState() {
    super.initState();

    // Flash animation (Invert colors effect simulation with white flash)
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _flashOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 80),
    ]).animate(_flashController);

    // Text "VICTORY" animation
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _textScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.2, end: 1.2).chain(CurveTween(curve: Curves.easeOutBack)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
    ]).animate(_textController);
    
    _textOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_textController);

    _playAnimation();
  }

  Future<void> _playAnimation() async {
    // Initial impact
    HapticFeedback.heavyImpact();
    _flashController.forward();
    _textController.forward();

    // Multiple haptic feedbacks for "weight"
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 150));
    HapticFeedback.mediumImpact();

    await Future.delayed(const Duration(milliseconds: 1250));
    widget.onComplete();
  }

  @override
  void dispose() {
    _flashController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // White flash for inversion-like effect
          AnimatedBuilder(
            animation: _flashOpacity,
            builder: (context, child) {
              return IgnorePointer(
                child: Container(
                  color: Colors.white.withValues(alpha: _flashOpacity.value),
                ),
              );
            },
          ),
          
          // Victory Text
          AnimatedBuilder(
            animation: _textController,
            builder: (context, child) {
              return Transform.scale(
                scale: _textScale.value,
                child: Opacity(
                  opacity: _textOpacity.value,
                  child: Text(
                    'VICTORY',
                    style: GoogleFonts.outfit(
                      fontSize: 64,
                      fontWeight: FontWeight.w900,
                      color: AppColors.accentGold,
                      letterSpacing: 8.0,
                      shadows: [
                        Shadow(
                          color: AppColors.accentGold.withValues(alpha: 0.5),
                          blurRadius: 30,
                        ),
                        Shadow(
                          color: Colors.white.withValues(alpha: 0.8),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
