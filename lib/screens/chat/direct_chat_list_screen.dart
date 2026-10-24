import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/app_colors.dart';
import '../../config/routes.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/direct_chat_provider.dart';
import '../../providers/service_providers.dart';
import 'components/status_notes_bar.dart';
import 'direct_chat_screen.dart';

/// チャット一覧画面（下部ピルバーのDMタブ・およびプッシュ遷移の両対応）
class DirectChatListScreen extends ConsumerStatefulWidget {
  /// メインシェルのタブとして表示されているかどうか
  final bool isTab;

  const DirectChatListScreen({
    super.key,
    this.isTab = false,
  });

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
    String? replyNoteText,
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
        replyNoteText: replyNoteText,
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
    final myUserAsync = ref.watch(currentUserStreamProvider);
    final myUser = myUserAsync.valueOrNull;

    // ヘッダー中央にはInstagram風に自分のユーザーIDまたは表示名を表示（未取得時は「メッセージ」）
    final headerTitle = (myUser?.userId?.isNotEmpty == true)
        ? myUser!.userId!
        : (myUser?.username?.isNotEmpty == true
            ? myUser!.username!
            : l10n.directChatTitle);

    final showBackButton = !widget.isTab && Navigator.canPop(context);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: AppColors.bgBase,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: showBackButton
            ? IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        centerTitle: true,
        title: Text(
          headerTitle,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_square, color: AppColors.textPrimary, size: 22),
            onPressed: () => _showNewChatSheet(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.accentGold,
        backgroundColor: AppColors.bgElevated,
        onRefresh: () async {
          ref.invalidate(statusNoteUsersProvider);
          ref.invalidate(currentUserStreamProvider);
          ref.invalidate(directChatRoomsStreamProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── 1. 上部「一言欄（V-Note）」横スクロールレーン ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: StatusNotesBar(
                  onOpenChat: ({
                    required otherUid,
                    required otherName,
                    otherPhotoUrl,
                    otherStreak,
                    replyNoteText,
                  }) {
                    _openChat(
                      otherUid: otherUid,
                      otherName: otherName,
                      otherPhotoUrl: otherPhotoUrl,
                      otherStreak: otherStreak,
                      replyNoteText: replyNoteText,
                    );
                  },
                ),
              ),
            ),

            // ── 2. 「メッセージ」セクション見出し ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.directChatTitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── 3. チャットルーム一覧 または 空状態表示 ──
            ...roomsAsync.when(
              data: (rooms) {
                if (rooms.isEmpty) {
                  return [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(32, 24, 32, 80),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  color: AppColors.accentGold.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    color: AppColors.accentGold,
                                    size: 32,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.directChatEmptyTitle,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                l10n.directChatEmptyDesc,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accentGold,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                icon: const Icon(Icons.edit, size: 17),
                                label: Text(
                                  l10n.directChatNewChat,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                onPressed: () => _showNewChatSheet(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ];
                }

                return [
                  SliverPadding(
                    padding: const EdgeInsets.only(bottom: 90),
                    sliver: SliverList.separated(
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
                            radius: 26,
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
                    ),
                  ),
                ];
              },
              loading: () => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.accentGold, strokeWidth: 2),
                  ),
                ),
              ],
              error: (e, _) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      e.toString(),
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
