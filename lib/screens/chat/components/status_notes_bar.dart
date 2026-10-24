import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/app_user.dart';
import '../../../models/direct_chat.dart';
import '../../../providers/direct_chat_provider.dart';
import '../../../providers/service_providers.dart';
import '../../../utils/date_helper.dart';

/// Instagramの「ノート（一言欄）」に相当する、DM画面上部の24時間限定ステータスバー。
/// 自分およびフォロー中の仲間の「今の一言（最大60文字）」を吹き出し形式で横スクロール表示します。
class StatusNotesBar extends ConsumerWidget {
  /// 友達との個別チャット画面を開くためのコールバック関数
  final void Function({
    required String otherUid,
    required String otherName,
    String? otherPhotoUrl,
    int? otherStreak,
    String? replyNoteText,
  }) onOpenChat;

  const StatusNotesBar({
    super.key,
    required this.onOpenChat,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final myUserAsync = ref.watch(currentUserStreamProvider);
    final followingUsersAsync = ref.watch(statusNoteUsersProvider);

    final myUser = myUserAsync.valueOrNull;
    final followingUsers = followingUsersAsync.valueOrNull ?? [];
    final today = DateHelper.toDateString(DateTime.now());

    return SizedBox(
      height: 138,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        itemCount: 1 + followingUsers.length,
        itemBuilder: (context, index) {
          // 一番左（index == 0）は「自分の一言」枠
          if (index == 0) {
            final myNote = myUser?.activeStatusNote;
            final myDoneToday = myUser?.lastPostedDate == today;
            final myDisplayName = myUser?.displayName?.isNotEmpty == true
                ? myUser!.displayName!
                : (myUser?.username?.isNotEmpty == true ? myUser!.username! : 'Me');

            return _StatusNoteItem(
              nameLabel: l10n.statusNoteYourNote,
              fallbackInitial: myDisplayName,
              photoUrl: myUser?.photoUrl,
              noteText: myNote ?? l10n.statusNotePlaceholder,
              isPlaceholder: myNote == null,
              isMe: true,
              isCompletedToday: myDoneToday,
              onTap: () => _showEditMyNoteSheet(context, ref, myUser),
            );
          }

          // index >= 1 はフォロー中のユーザー枠
          final friend = followingUsers[index - 1];
          final friendNote = friend.activeStatusNote;
          final friendDoneToday = friend.lastPostedDate == today;
          final friendName = friend.displayName?.isNotEmpty == true
              ? friend.displayName!
              : (friend.username?.isNotEmpty == true ? friend.username! : 'User');

          return _StatusNoteItem(
            nameLabel: friendName,
            fallbackInitial: friendName,
            photoUrl: friend.photoUrl,
            noteText: friendNote,
            isPlaceholder: false,
            isMe: false,
            isCompletedToday: friendDoneToday,
            onTap: () {
              HapticFeedback.lightImpact();
              if (friendNote != null && friendNote.isNotEmpty) {
                // 一言が設定されている場合は、インスタのノートと同じくクイック返信シートを表示
                _showFriendNoteReplySheet(
                  context: context,
                  ref: ref,
                  friend: friend,
                  friendName: friendName,
                  noteText: friendNote,
                  myUser: myUser,
                );
              } else {
                // 一言が未設定の友達をタップした場合はそのまま個別チャットへ遷移
                onOpenChat(
                  otherUid: friend.uid,
                  otherName: friendName,
                  otherPhotoUrl: friend.photoUrl,
                  otherStreak: friend.streak,
                );
              }
            },
          );
        },
      ),
    );
  }

  /// 自分の一言（V-Note）を作成・編集・削除するボトムシートを表示します
  void _showEditMyNoteSheet(BuildContext context, WidgetRef ref, AppUser? myUser) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => _EditMyStatusNoteSheet(
        myUser: myUser,
        onSaved: (newNote) async {
          await ref.read(userServiceProvider).updateStatusNote(newNote);
          ref.invalidate(currentUserStreamProvider);
        },
      ),
    );
  }

  /// 友達の一言（V-Note）をタップした際のクイック返信ボトムシートを表示します
  void _showFriendNoteReplySheet({
    required BuildContext context,
    required WidgetRef ref,
    required AppUser friend,
    required String friendName,
    required String noteText,
    required AppUser? myUser,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => _FriendNoteQuickReplySheet(
        friend: friend,
        friendName: friendName,
        noteText: noteText,
        onSendReply: (replyText) async {
          final currentUid = ref.read(currentAuthUidProvider);
          if (currentUid == null || currentUid.isEmpty) return;

          final myName = myUser?.displayName?.isNotEmpty == true
              ? myUser!.displayName!
              : (myUser?.username?.isNotEmpty == true ? myUser!.username! : 'User');
          final chatId = DirectChatRoom.generateRoomId(currentUid, friend.uid);

          // 一言（V-Note）を引用した状態でDMメッセージを送信
          await ref.read(directChatServiceProvider).sendMessage(
                chatId: chatId,
                senderId: currentUid,
                otherUid: friend.uid,
                text: replyText,
                senderInfo: DirectChatParticipant(
                  uid: currentUid,
                  name: myName,
                  photoUrl: myUser?.photoUrl,
                ),
                receiverInfo: DirectChatParticipant(
                  uid: friend.uid,
                  name: friendName,
                  photoUrl: friend.photoUrl,
                ),
                replyNoteText: noteText,
              );

          if (context.mounted) {
            final l10n = AppLocalizations.of(context)!;
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: AppColors.accentGold, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.statusNoteReplySent(friendName),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppColors.isDark ? AppColors.grey20 : AppColors.grey85,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        },
        onOpenFullChat: () {
          onOpenChat(
            otherUid: friend.uid,
            otherName: friendName,
            otherPhotoUrl: friend.photoUrl,
            otherStreak: friend.streak,
            replyNoteText: noteText,
          );
        },
      ),
    );
  }
}

/// 一言レーン内の1人分のアイテム（吹き出し＋丸アイコン＋名前ラベル）
class _StatusNoteItem extends StatelessWidget {
  final String nameLabel;
  final String fallbackInitial;
  final String? photoUrl;
  final String? noteText;
  final bool isPlaceholder;
  final bool isMe;
  final bool isCompletedToday;
  final VoidCallback onTap;

  const _StatusNoteItem({
    required this.nameLabel,
    required this.fallbackInitial,
    this.photoUrl,
    this.noteText,
    required this.isPlaceholder,
    required this.isMe,
    required this.isCompletedToday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasBubble = noteText != null && noteText!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 88,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // 吹き出し＋アバターの重なり領域（Stackでアイコン上部に吹き出しを重ねる）
            SizedBox(
              width: 88,
              height: 102,
              child: Stack(
                alignment: Alignment.bottomCenter,
                clipBehavior: Clip.none,
                children: [
                  // 1. 丸いユーザーアイコン（下部中央）
                  Positioned(
                    bottom: 2,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2.2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: isCompletedToday
                                ? Border.all(color: AppColors.accentGold, width: 2.0)
                                : Border.all(
                                    color: AppColors.border,
                                    width: 1.0,
                                  ),
                            boxShadow: isCompletedToday
                                ? [
                                    BoxShadow(
                                      color: AppColors.accentGold.withValues(alpha: 0.28),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: CircleAvatar(
                            radius: 29,
                            backgroundColor: AppColors.grey20,
                            backgroundImage: photoUrl != null && photoUrl!.isNotEmpty
                                ? CachedNetworkImageProvider(photoUrl!)
                                : null,
                            child: (photoUrl == null || photoUrl!.isEmpty)
                                ? Text(
                                    fallbackInitial.isNotEmpty
                                        ? fallbackInitial[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      color: AppColors.pureWhite,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  )
                                : null,
                          ),
                        ),

                        // 自分のアイコン右下の「＋」追加バッジ
                        if (isMe)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: AppColors.accentGold,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.bgBase,
                                  width: 2.0,
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.add_rounded,
                                  size: 14,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // 2. アイコン上部に浮かぶ一言吹き出し（Instagramノート風）
                  if (hasBubble)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _NoteSpeechBubble(
                        text: noteText!,
                        isPlaceholder: isPlaceholder,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 5),

            // 3. ユーザー名ラベル
            Text(
              nameLabel,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isMe ? FontWeight.w500 : FontWeight.w600,
                color: isMe ? AppColors.textSecondary : AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// 吹き出し（思考バブル）ウィジェット（下部に2段階の小さな丸ポインター付き）
class _NoteSpeechBubble extends StatelessWidget {
  final String text;
  final bool isPlaceholder;

  const _NoteSpeechBubble({
    required this.text,
    required this.isPlaceholder,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;
    final bubbleBg = isDark ? const Color(0xFF262629) : AppColors.pureWhite;
    final borderColor = isPlaceholder
        ? (isDark ? AppColors.white.withValues(alpha: 0.1) : AppColors.border)
        : (isDark ? AppColors.white.withValues(alpha: 0.18) : AppColors.grey30);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(
            minWidth: 56,
            maxWidth: 88,
            minHeight: 34,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: bubbleBg,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: borderColor,
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.10),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            widthFactor: 1.0,
            heightFactor: 1.0,
            child: Text(
              text,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.22,
                fontWeight: isPlaceholder ? FontWeight.w400 : FontWeight.w600,
                color: isPlaceholder ? AppColors.textMuted : AppColors.textPrimary,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        // 思考バブルの小さな丸しっぽ（2段階）
        Transform.translate(
          offset: const Offset(-10, -2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: bubbleBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 0.6),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 3, top: 1),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: bubbleBg,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 自分の一言を入力・更新・削除するためのボトムシート
class _EditMyStatusNoteSheet extends StatefulWidget {
  final AppUser? myUser;
  final Future<void> Function(String? note) onSaved;

  const _EditMyStatusNoteSheet({
    required this.myUser,
    required this.onSaved,
  });

  @override
  State<_EditMyStatusNoteSheet> createState() => _EditMyStatusNoteSheetState();
}

class _EditMyStatusNoteSheetState extends State<_EditMyStatusNoteSheet> {
  late final TextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.myUser?.activeStatusNote ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave(String? text) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();
    try {
      await widget.onSaved(text);
      if (mounted) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final hasExistingNote = widget.myUser?.hasActiveStatusNote == true;
    final myDisplayName = widget.myUser?.displayName?.isNotEmpty == true
        ? widget.myUser!.displayName!
        : (widget.myUser?.username?.isNotEmpty == true ? widget.myUser!.username! : 'Me');

    final presets = [
      l10n.statusNoteQuickPreset1,
      l10n.statusNoteQuickPreset2,
      l10n.statusNoteQuickPreset3,
      l10n.statusNoteQuickPreset4,
    ];

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: bottomInset + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 上部ドラッグハンドル
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),

            // ヘッダー（タイトル＋シェアボタン）
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
                Text(
                  l10n.statusNoteSheetTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (context, value, _) {
                    final canSubmit = value.text.trim().isNotEmpty && !_isSaving;
                    return TextButton(
                      onPressed: canSubmit ? () => _handleSave(value.text) : null,
                      child: Text(
                        l10n.statusNoteShare,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: canSubmit ? AppColors.accentGold : AppColors.textMuted,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // リアルタイム吹き出しプレビュー＋自分のアイコン
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                final previewText = value.text.trim().isEmpty
                    ? l10n.statusNotePlaceholder
                    : value.text.trim();
                final isPlaceholder = value.text.trim().isEmpty;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: _NoteSpeechBubble(
                        text: previewText,
                        isPlaceholder: isPlaceholder,
                      ),
                    ),
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.grey20,
                      backgroundImage: widget.myUser?.photoUrl != null
                          ? CachedNetworkImageProvider(widget.myUser!.photoUrl!)
                          : null,
                      child: widget.myUser?.photoUrl == null
                          ? Text(
                              myDisplayName[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            )
                          : null,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),

            // テキスト入力欄（最大60文字）
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: 60,
              maxLines: 2,
              minLines: 1,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: l10n.statusNoteInputHint,
                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
                filled: true,
                fillColor: AppColors.grey10,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.accentGold, width: 1.4),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ワンタップ定型フレーズチップ
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: presets.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final preset = presets[idx];
                  return ActionChip(
                    label: Text(
                      preset,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    backgroundColor: AppColors.grey10,
                    side: BorderSide(color: AppColors.border, width: 0.8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _controller.text = preset;
                      _controller.selection = TextSelection.fromPosition(
                        TextPosition(offset: _controller.text.length),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            Text(
              l10n.statusNoteSheetDesc,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),

            // すでに一言を設定中の場合は削除ボタンを表示
            if (hasExistingNote) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _isSaving ? null : () => _handleSave(null),
                icon: Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                label: Text(
                  l10n.statusNoteDelete,
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 友達の一言をタップした際に開くクイック返信シート（Instagramノート返信スタイル）
class _FriendNoteQuickReplySheet extends StatefulWidget {
  final AppUser friend;
  final String friendName;
  final String noteText;
  final Future<void> Function(String replyText) onSendReply;
  final VoidCallback onOpenFullChat;

  const _FriendNoteQuickReplySheet({
    required this.friend,
    required this.friendName,
    required this.noteText,
    required this.onSendReply,
    required this.onOpenFullChat,
  });

  @override
  State<_FriendNoteQuickReplySheet> createState() => _FriendNoteQuickReplySheetState();
}

class _FriendNoteQuickReplySheetState extends State<_FriendNoteQuickReplySheet> {
  final TextEditingController _replyController = TextEditingController();
  bool _isSending = false;

  static const List<String> _quickEmojis = ['🔥', '👏', '💪', '✨', '👑', '🤝'];

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _submitReply(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    HapticFeedback.mediumImpact();
    try {
      await widget.onSendReply(trimmed);
      if (mounted) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: bottomInset + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),

            // 友達の一言バブル＋アイコン表示
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: _NoteSpeechBubble(
                text: widget.noteText,
                isPlaceholder: false,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                widget.onOpenFullChat();
              },
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: AppColors.grey20,
                    backgroundImage: widget.friend.photoUrl != null
                        ? CachedNetworkImageProvider(widget.friend.photoUrl!)
                        : null,
                    child: widget.friend.photoUrl == null
                        ? Text(
                            widget.friendName.isNotEmpty
                                ? widget.friendName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.friendName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ワンタップ称賛絵文字バー
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _quickEmojis.map((emoji) {
                return GestureDetector(
                  onTap: () => _submitReply(emoji),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.grey10,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border, width: 0.8),
                    ),
                    child: Center(
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // メッセージ入力＆送信行
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    autofocus: true,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _submitReply,
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 14.5),
                    decoration: InputDecoration(
                      hintText: l10n.statusNoteReplyHint(widget.friendName),
                      hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13.5),
                      filled: true,
                      fillColor: AppColors.grey10,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: AppColors.accentGold, width: 1.2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _replyController,
                  builder: (context, value, _) {
                    final canSend = value.text.trim().isNotEmpty && !_isSending;
                    return GestureDetector(
                      onTap: canSend ? () => _submitReply(value.text) : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: canSend
                              ? AppColors.accentGold
                              : AppColors.grey20,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.send_rounded,
                          size: 18,
                          color: canSend ? Colors.black : AppColors.textMuted,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
