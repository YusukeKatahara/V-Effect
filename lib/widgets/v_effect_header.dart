import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_colors.dart';
import '../services/notification_service.dart';
import '../config/app_colors.dart';
import '../services/notification_service.dart';

/// アプリ共通ヘッダー (V EFFECT)
class VEffectHeader extends StatelessWidget {
  const VEffectHeader({
    super.key,
    this.leading,
    this.trailing,
  });

  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Left
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: leading ?? const SizedBox(width: 48),
            ),
          ),

          // Center logo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'V EFFECT',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.white,
                letterSpacing: 4.0,
              ),
            ),
          ),

          // Right
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: trailing ?? const SizedBox(width: 48),
            ),
          ),
        ],
      ),
    );
  }
}

/// ヘッダー用の小サイズアバター
class UserAvatarHeader extends StatelessWidget {
  const UserAvatarHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final photoUrl = data?['photoUrl'] as String?;

        return GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/profile'),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.grey10,
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null
                ? const Icon(Icons.person, size: 18, color: AppColors.grey50)
                : null,
          ),
        );
      },
    );
  }
}

/// 通知バッジ付きのベルアイコン。HomeScreenやHeroTasksScreenで共有。
class NotificationBellIcon extends StatelessWidget {
  const NotificationBellIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: NotificationService.instance.getNotificationCount(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return IconButton(
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text('$count'),
            child: const Icon(
              Icons.notifications_outlined,
              color: AppColors.white,
            ),
          ),
          onPressed: () => Navigator.pushNamed(context, '/notifications'),
        );
      },
    );
  }
}
