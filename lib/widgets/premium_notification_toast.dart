import 'dart:async';
import 'package:flutter/material.dart';
import '../config/app_colors.dart';

class PremiumNotificationToast extends StatefulWidget {
  final String title;
  final String body;
  final IconData icon;
  final VoidCallback? onTap;
  final List<ToastAction>? actions;

  const PremiumNotificationToast({
    super.key,
    required this.title,
    required this.body,
    required this.icon,
    this.onTap,
    this.actions,
  });

  static void show(
    BuildContext context, {
    required String title,
    required String body,
    required IconData icon,
    VoidCallback? onTap,
    List<ToastAction>? actions,
  }) {
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => PremiumNotificationToast(
        title: title,
        body: body,
        icon: icon,
        onTap: () {
          overlayEntry.remove();
          onTap?.call();
        },
        actions: actions?.map((a) => ToastAction(
          label: a.label,
          isPrimary: a.isPrimary,
          onPressed: () {
            overlayEntry.remove();
            a.onPressed();
          },
        )).toList(),
      ),
    );

    overlayState.insert(overlayEntry);

    // 自動で消えるタイマー（アクションがある場合は少し長めに設定）
    if (actions == null || actions.isEmpty) {
      Future.delayed(const Duration(seconds: 4), () {
        if (overlayEntry.mounted) {
          overlayEntry.remove();
        }
      });
    }
  }

  @override
  State<PremiumNotificationToast> createState() => _PremiumNotificationToastState();
}

class _PremiumNotificationToastState extends State<PremiumNotificationToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bgSurface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.accentGold.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.accentGold.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              widget.icon,
                              color: AppColors.accentGold,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.title,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.body,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.actions != null && widget.actions!.isNotEmpty)
                      Container(
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: AppColors.white.withValues(alpha: 0.1),
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: widget.actions!.map((action) {
                            return Expanded(
                              child: InkWell(
                                onTap: action.onPressed,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  alignment: Alignment.center,
                                  child: Text(
                                    action.label,
                                    style: TextStyle(
                                      color: action.isPrimary
                                          ? AppColors.white
                                          : AppColors.textMuted,
                                      fontSize: 13,
                                      fontWeight: action.isPrimary
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ToastAction {
  final String label;
  final bool isPrimary;
  final VoidCallback onPressed;

  ToastAction({
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
  });
}
