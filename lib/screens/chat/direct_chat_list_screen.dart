import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/app_colors.dart';
import '../../config/routes.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/direct_chat_provider.dart';
import '../../providers/service_providers.dart';
import 'direct_chat_screen.dart';

/// チャット一覧画面
class DirectChatListScreen extends ConsumerStatefulWidget {
  const DirectChatListScreen({super.key});

  @override
  ConsumerState<DirectChatListScreen> createState() => _DirectChatListScreenState();
}

class _DirectChatListScreenState extends ConsumerState<DirectChatListScreen> {
  void _openChat({
    required String otherUid,
    required String otherName,
    String? otherPhotoUrl,
    int? otherStreak,
    String? chatId,
  }) {
    Navigator.pushNamed(
      context,
      AppRoutes.directChat,
      arguments: DirectChatScreenArgs(
        chatId: chatId,
        otherUid: otherUid,
        otherName: otherName,
        otherPhotoUrl: otherPhotoUrl,
        otherStreak: otherStreak,
      ),
    );
  }

  void _showNewChatSheet(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final currentUid = ref.read(currentAuthUidProvider);
    if (currentUid == null) return;

    // 相互フォローの友達を取得
    final friendService = ref.read(friendServiceProvider);
    final mutualFriends = await friendService.getMutualFriends(currentUid);

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (sheetCtx, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.grey30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.directChatSelectFriend,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 20),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: AppColors.border),
                Expanded(
                  child: mutualFriends.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              l10n.directChatNoMutualFriends,
                              style: TextStyle(color: AppColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: mutualFriends.length,
                          separatorBuilder: (_, __) => Divider(height: 1, indent: 68, color: AppColors.border),
                          itemBuilder: (context, index) {
                            final friend = mutualFriends[index];
                            final displayName = friend.displayName?.isNotEmpty == true
                                ? friend.displayName!
                                : (friend.username?.isNotEmpty == true ? friend.username! : 'User');
                            return ListTile(
                              leading: CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.grey20,
                                backgroundImage: friend.photoUrl != null
                                    ? CachedNetworkImageProvider(friend.photoUrl!)
                                    : null,
                                child: friend.photoUrl == null
                                    ? Text(
                                        displayName.isNotEmpty
                                            ? displayName[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                              title: Text(
                                displayName,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: friend.username != null && friend.username!.isNotEmpty
                                  ? Text(
                                      '@${friend.username}',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    )
                                  : null,
                              onTap: () {
                                Navigator.pop(sheetCtx);
                                _openChat(
                                  otherUid: friend.uid,
                                  otherName: displayName,
                                  otherPhotoUrl: friend.photoUrl,
                                  otherStreak: friend.streak,
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatTimestamp(DateTime dateTime, BuildContext context) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return AppLocalizations.of(context)!.directChatSentNow;
    } else if (difference.inHours < 24 && dateTime.day == now.day) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (difference.inDays < 7) {
      return DateFormat('E', Localizations.localeOf(context).languageCode).format(dateTime);
    } else {
      return DateFormat('M/d').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentUid = ref.watch(currentAuthUidProvider) ?? '';
    final roomsAsync = ref.watch(directChatRoomsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: AppColors.bgElevated,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.directChatTitle,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_square, color: AppColors.accentGold, size: 22),
            onPressed: () => _showNewChatSheet(context),
          ),
        ],
      ),
      body: roomsAsync.when(
        data: (rooms) {
          if (rooms.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.accentGold.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: AppColors.accentGold,
                          size: 36,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.directChatEmptyTitle,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.directChatEmptyDesc,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentGold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      icon: const Icon(Icons.edit, size: 18),
                      label: Text(
                        l10n.directChatNewChat,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _showNewChatSheet(context),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: rooms.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              indent: 76,
              color: AppColors.isDark ? AppColors.grey15 : AppColors.grey85,
            ),
            itemBuilder: (context, index) {
              final room = rooms[index];
              final otherParticipant = room.getOtherParticipant(currentUid);
              final unreadCount = room.getUnreadCount(currentUid);
              final lastMsg = room.lastMessage;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.grey20,
                  backgroundImage: otherParticipant?.photoUrl != null
                      ? CachedNetworkImageProvider(otherParticipant!.photoUrl!)
                      : null,
                  child: otherParticipant?.photoUrl == null
                      ? Text(
                          otherParticipant?.name.isNotEmpty == true
                              ? otherParticipant!.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: AppColors.pureWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        )
                      : null,
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        otherParticipant?.name ?? 'Unknown',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (lastMsg != null)
                      Text(
                        _formatTimestamp(lastMsg.createdAt, context),
                        style: TextStyle(
                          color: unreadCount > 0 ? AppColors.accentGold : AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                  ],
                ),
                subtitle: Row(
                  children: [
                    Expanded(
                      child: Text(
                        lastMsg?.text ?? '',
                        style: TextStyle(
                          color: unreadCount > 0 ? AppColors.textPrimary : AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (unreadCount > 0)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentGold,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                onTap: () {
                  if (otherParticipant != null) {
                    _openChat(
                      chatId: room.id,
                      otherUid: otherParticipant.uid,
                      otherName: otherParticipant.name,
                      otherPhotoUrl: otherParticipant.photoUrl,
                    );
                  }
                },
              );
            },
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: AppColors.accentGold, strokeWidth: 2),
        ),
        error: (e, _) => Center(
          child: Text(
            e.toString(),
            style: TextStyle(color: AppColors.error),
          ),
        ),
      ),
    );
  }
}
