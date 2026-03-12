import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// Icon inside a gradient circle with glow shadow, plus optional subtitle.
class PremiumIconHeader extends StatelessWidget {
  const PremiumIconHeader({
    super.key,
    required this.icon,
    this.size = 88,
    this.iconSize = 52,
    this.subtitle,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.primaryGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 32,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Icon(icon, size: iconSize, color: const Color(0xFF1A1000)),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 12),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }
}
