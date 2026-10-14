import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import '../../../config/app_colors.dart';

/// 新着投稿がある場合に画面上部に表示されるピル型のフローティングボタンコンポーネント
class NewPostsButton extends StatefulWidget {
  final VoidCallback onTap;

  const NewPostsButton({
    super.key,
    required this.onTap,
  });

  @override
  State<NewPostsButton> createState() => _NewPostsButtonState();
}

class _NewPostsButtonState extends State<NewPostsButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    ));
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onTap();
          },
          child: AnimatedScale(
            scale: _isPressed ? 0.94 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFFE599),
                    AppColors.accentGold,
                    const Color(0xFFC89C3C),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.6),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentGold.withValues(alpha: 0.4),
                    blurRadius: 18,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_upward_rounded,
                      color: AppColors.black,
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!.homeNewPostsAvailable,
                    style: GoogleFonts.outfit(
                      color: AppColors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
