import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_colors.dart';
import '../config/routes.dart';
import '../providers/direct_chat_provider.dart';
import '../services/sound_service.dart';

/// 未読バッジ付きのDM（吹き出し）アイコン。
/// 炎ページ（HeroTasksScreen）のヘッダー右上に配置されます。
class DirectChatIcon extends ConsumerWidget {
  const DirectChatIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCountAsync = ref.watch(directChatTotalUnreadCountProvider);
    final count = unreadCountAsync.when(
      data: (c) => c,
      loading: () => 0,
      error: (e, _) {
        debugPrint('DirectChatIcon unread count error (fallback to 0): $e');
        return 0;
      },
    );

    return IconButton(
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(
          '$count',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.error,
        child: Icon(
          Icons.chat_bubble_outline_rounded,
          color: AppColors.white,
          size: 22,
        ),
      ),
      onPressed: () {
        SoundService.instance.stopBgm();
        Navigator.pushNamed(context, AppRoutes.directChatList);
      },
    );
  }
}
