import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/app_colors.dart';
import '../../config/routes.dart';
import '../../l10n/app_localizations.dart';
import '../../models/direct_chat.dart';
import '../../providers/direct_chat_provider.dart';
import '../../providers/service_providers.dart';

/// 個別チャット画面の起動パラメータ
class DirectChatScreenArgs {
  final String? chatId;
  final String otherUid;
  final String otherName;
  final String? otherPhotoUrl;
  final int? otherStreak;
  /// 言及・引用元の投稿ID（Instagramストーリーズ返信風UI用）
  final String? replyPostId;
  /// 言及・引用元の投稿画像URL
  final String? replyPostImageUrl;
  /// 言及・引用元のタスク名
  final String? replyPostTaskName;

  const DirectChatScreenArgs({
    this.chatId,
    required this.otherUid,
    required this.otherName,
    this.otherPhotoUrl,
    this.otherStreak,
    this.replyPostId,
    this.replyPostImageUrl,
    this.replyPostTaskName,
  });
}

/// 1対1のテキストチャット画面（最高峰DM UI/UX）
class DirectChatScreen extends ConsumerStatefulWidget {
  final DirectChatScreenArgs args;

  const DirectChatScreen({
    super.key,
    required this.args,
  });

  @override
  ConsumerState<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends ConsumerState<DirectChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  late String _chatId;
  bool _isSending = false;

  /// 現在返信対象となっている投稿の情報
  String? _replyPostId;
  String? _replyPostImageUrl;
  String? _replyPostTaskName;

  @override
  void initState() {
    super.initState();
    final currentUid = ref.read(currentAuthUidProvider) ?? '';
    _chatId = widget.args.chatId ??
        DirectChatRoom.generateRoomId(currentUid, widget.args.otherUid);

    // 引数から投稿返信情報を受け取る
    _replyPostId = widget.args.replyPostId;
    _replyPostImageUrl = widget.args.replyPostImageUrl;
    _replyPostTaskName = widget.args.replyPostTaskName;

    // 画面を開いたときに既読処理とフォーカスを実行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markRead();
      // 投稿からの返信として開かれた場合は自動で入力欄にフォーカス
      if (_replyPostImageUrl != null && _replyPostImageUrl!.isNotEmpty) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _markRead() {
    final currentUid = ref.read(currentAuthUidProvider);
    if (currentUid == null || currentUid.isEmpty) return;
    ref.read(directChatServiceProvider).markAsRead(
          chatId: _chatId,
          currentUid: currentUid,
        );
  }

  /// メッセージを送信する内部処理
  Future<void> _sendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isSending) return;

    final currentUid = ref.read(currentAuthUidProvider);
    if (currentUid == null || currentUid.isEmpty) return;

    final userDoc = await ref.read(friendServiceProvider).getUserByUid(currentUid);
    final myName = userDoc?.displayName?.isNotEmpty == true
        ? userDoc!.displayName!
        : (userDoc?.username?.isNotEmpty == true ? userDoc!.username! : 'User');
    final myPhoto = userDoc?.photoUrl;

    final currentReplyId = _replyPostId;
    final currentReplyImageUrl = _replyPostImageUrl;
    final currentReplyTaskName = _replyPostTaskName;

    setState(() {
      _isSending = true;
      // 送信開始時に返信プレビューをクリア
      _replyPostId = null;
      _replyPostImageUrl = null;
      _replyPostTaskName = null;
    });
    _textController.clear();
    HapticFeedback.lightImpact();

    try {
      await ref.read(directChatServiceProvider).sendMessage(
            chatId: _chatId,
            senderId: currentUid,
            otherUid: widget.args.otherUid,
            text: trimmed,
            senderInfo: DirectChatParticipant(
              uid: currentUid,
              name: myName,
              photoUrl: myPhoto,
            ),
            receiverInfo: DirectChatParticipant(
              uid: widget.args.otherUid,
              name: widget.args.otherName,
              photoUrl: widget.args.otherPhotoUrl,
            ),
            replyPostId: currentReplyId,
            replyPostImageUrl: currentReplyImageUrl,
            replyPostTaskName: currentReplyTaskName,
          );
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  /// テキスト入力欄からの送信
  Future<void> _sendMessage() async {
    await _sendText(_textController.text);
  }

  /// クイックエール（ワンタップ送信）
  Future<void> _sendQuickCheer(String text) async {
    await _sendText(text);
  }

  /// メッセージ長押しでのコピー処理
  void _copyMessage(BuildContext context, String text) {
    HapticFeedback.mediumImpact();
    Clipboard.setData(ClipboardData(text: text));
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.accentGold, size: 18),
            const SizedBox(width: 10),
            Text(
              l10n.directChatCopied,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.isDark ? AppColors.grey20 : AppColors.grey85,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  /// 日付セパレーターの表示文字列生成
  String _formatDateSeparator(DateTime date, BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final targetDate = DateTime(date.year, date.month, date.day);

    if (targetDate == today) {
      return l10n.directChatToday;
    } else if (targetDate == yesterday) {
      return l10n.directChatYesterday;
    } else if (targetDate.year == now.year) {
      return DateFormat('M月d日 (E)', Localizations.localeOf(context).languageCode).format(date);
    } else {
      return DateFormat('yyyy年M月d日', Localizations.localeOf(context).languageCode).format(date);
    }
  }

  /// 同一日付かどうかの判定
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _showOptionsMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              ListTile(
                leading: Icon(Icons.report_problem_outlined, color: AppColors.error),
                title: Text(
                  l10n.directChatReport,
                  style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref.read(blockServiceProvider).reportUser(
                        widget.args.otherUid,
                        'Direct Message Report',
                      );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.directChatReportSuccess),
                        backgroundColor: AppColors.bgSurface,
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.block_rounded, color: AppColors.error),
                title: Text(
                  l10n.directChatBlock,
                  style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmBlock(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: AppColors.textSecondary),
                title: Text(
                  l10n.directChatDeleteRoom,
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteRoom(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _confirmBlock(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: Text(
          l10n.directChatBlockConfirmTitle,
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          l10n.directChatBlockConfirmDesc,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.directChatCancel, style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(blockServiceProvider).blockUser(widget.args.otherUid);
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: Text(l10n.directChatBlock, style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteRoom(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: Text(
          l10n.directChatDeleteRoomConfirm,
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.directChatCancel, style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(directChatServiceProvider).deleteRoom(_chatId);
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: Text(l10n.directChatDelete, style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentUid = ref.watch(currentAuthUidProvider) ?? '';
    final messagesAsync = ref.watch(directChatMessagesStreamProvider(_chatId));

    // 画面全体のタップでキーボードを閉じる GestureDetector
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: AppColors.bgBase,
        appBar: AppBar(
          backgroundColor: AppColors.bgElevated,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          titleSpacing: 0,
          title: InkWell(
            onTap: () {
              // 相手のプロフィール画面へ遷移
              Navigator.pushNamed(
                context,
                AppRoutes.userProfile,
                arguments: widget.args.otherUid,
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.grey20,
                    backgroundImage: widget.args.otherPhotoUrl != null
                        ? CachedNetworkImageProvider(widget.args.otherPhotoUrl!)
                        : null,
                    child: widget.args.otherPhotoUrl == null
                        ? Text(
                            widget.args.otherName.isNotEmpty
                                ? widget.args.otherName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: AppColors.pureWhite,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.args.otherName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.more_vert_rounded, color: AppColors.textPrimary),
              onPressed: () => _showOptionsMenu(context),
            ),
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // メッセージ一覧リスト
              Expanded(
                child: messagesAsync.when(
                  data: (messages) {
                    if (messages.isEmpty) {
                      return _buildEmptyState(context, l10n);
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      // スクロール時に自動でキーボードを閉じる
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe = message.senderId == currentUid;

                        // 前後のメッセージとの関係（reverse: true のため index + 1 が時間的に前のメッセージ）
                        final prevMessage = (index + 1 < messages.length) ? messages[index + 1] : null;
                        final nextMessage = (index - 1 >= 0) ? messages[index - 1] : null;

                        // 日付セパレーターの判定（前のメッセージと日付が異なるか、または最も古いメッセージの場合）
                        final showDateSeparator = prevMessage == null ||
                            !_isSameDay(message.createdAt, prevMessage.createdAt);

                        // メッセージのグループ化判定
                        final isFirstInGroup = prevMessage == null ||
                            prevMessage.senderId != message.senderId ||
                            !_isSameDay(prevMessage.createdAt, message.createdAt);
                        final isLastInGroup = nextMessage == null ||
                            nextMessage.senderId != message.senderId ||
                            !_isSameDay(nextMessage.createdAt, message.createdAt);

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (showDateSeparator)
                              _buildDateSeparator(message.createdAt, context),
                            _buildMessageBubble(
                              context: context,
                              message: message,
                              isMe: isMe,
                              isFirstInGroup: isFirstInGroup,
                              isLastInGroup: isLastInGroup,
                            ),
                          ],
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
              ),

              // 下部テキスト入力バー（Composer）
              _buildMessageComposer(context, l10n),
            ],
          ),
        ),
      ),
    );
  }

  /// 空状態（Empty State）のUI
  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 相手のラージアバター
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accentGold.withValues(alpha: 0.3),
                        AppColors.accentGold.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.grey20,
                  backgroundImage: widget.args.otherPhotoUrl != null
                      ? CachedNetworkImageProvider(widget.args.otherPhotoUrl!)
                      : null,
                  child: widget.args.otherPhotoUrl == null
                      ? Text(
                          widget.args.otherName.isNotEmpty
                              ? widget.args.otherName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: AppColors.pureWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                          ),
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              widget.args.otherName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.directChatEmptyDesc,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),

            // クイックエール（「いつもありがとう」「一緒に頑張ろう」の2種類）
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _buildQuickCheerChip(
                  label: l10n.directChatQuickThanks, // 「いつもありがとう」
                  icon: Icons.favorite_rounded,
                  iconColor: const Color(0xFFFF5252),
                  onTap: () => _sendQuickCheer(l10n.directChatQuickThanks),
                ),
                _buildQuickCheerChip(
                  label: l10n.directChatQuickTogether, // 「一緒に頑張ろう」
                  icon: Icons.local_fire_department_rounded,
                  iconColor: AppColors.accentGold,
                  onTap: () => _sendQuickCheer(l10n.directChatQuickTogether),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// クイックエール用チップボタン
  Widget _buildQuickCheerChip({
    required String label,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isSending ? null : onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.isDark ? AppColors.grey15 : AppColors.pureWhite,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.isDark ? AppColors.grey20 : AppColors.grey70,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: AppColors.isDark ? 0.2 : 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 日付セパレーターのUI
  Widget _buildDateSeparator(DateTime date, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.isDark ? AppColors.grey15 : AppColors.grey10,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.isDark ? AppColors.grey20 : AppColors.grey70,
              width: 0.5,
            ),
          ),
          child: Text(
            _formatDateSeparator(date, context),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  /// 投稿画像の全画面プレビューモーダル
  void _showFullImageModal(BuildContext context, String imageUrl, String? taskName) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (ctx) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // ピンチズーム可能な画像ビューアー
            Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accentGold,
                      strokeWidth: 2,
                    ),
                  ),
                  errorWidget: (context, url, error) => Icon(
                    Icons.broken_image_rounded,
                    color: AppColors.textMuted,
                    size: 48,
                  ),
                ),
              ),
            ),

            // 上部ヘッダー（閉じるボタン & タスク名）
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ),
                      if (taskName != null && taskName.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.accentGold.withValues(alpha: 0.5),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.accentGold,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    taskName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 個別のメッセージ吹き出し（Bubble - Instagramストーリーズ返信対応）
  Widget _buildMessageBubble({
    required BuildContext context,
    required DirectChatMessage message,
    required bool isMe,
    required bool isFirstInGroup,
    required bool isLastInGroup,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final timeStr = DateFormat('HH:mm').format(message.createdAt);
    final hasReplyPost = message.replyPostImageUrl != null && message.replyPostImageUrl!.isNotEmpty;

    // 連続メッセージに応じた吹き出し角丸の計算
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(isMe ? 18 : (isFirstInGroup ? 18 : 6)),
      topRight: Radius.circular(isMe ? (isFirstInGroup ? 18 : 6) : 18),
      bottomLeft: Radius.circular(isMe ? 18 : (isLastInGroup ? 6 : 6)),
      bottomRight: Radius.circular(isMe ? (isLastInGroup ? 6 : 6) : 18),
    );

    // 吹き出しの中身ウィジェット
    Widget bubbleContent;
    if (hasReplyPost) {
      bubbleContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. ストーリーズ返信コンテキストラベル
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_stories_rounded,
                  size: 13,
                  color: isMe
                      ? Colors.black.withValues(alpha: 0.7)
                      : AppColors.accentGold,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    isMe
                        ? l10n.directChatRepliedTo(widget.args.otherName)
                        : l10n.directChatRepliedToYou,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isMe
                          ? Colors.black.withValues(alpha: 0.75)
                          : AppColors.accentGold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // 2. 投稿写真の角丸サムネイルカード（タップで全画面プレビュー）
          GestureDetector(
            onTap: () => _showFullImageModal(
              context,
              message.replyPostImageUrl!,
              message.replyPostTaskName,
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    color: Colors.black26,
                    child: CachedNetworkImage(
                      imageUrl: message.replyPostImageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: AppColors.isDark ? AppColors.grey20 : AppColors.grey85,
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.isDark ? AppColors.grey20 : AppColors.grey85,
                        child: Icon(
                          Icons.broken_image_rounded,
                          color: AppColors.textMuted,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),

                // 写真上のタスク名バッジ
                if (message.replyPostTaskName != null &&
                    message.replyPostTaskName!.isNotEmpty)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.accentGold.withValues(alpha: 0.6),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 11,
                            color: AppColors.accentGold,
                          ),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: Text(
                              message.replyPostTaskName!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 右下の全画面拡大ヒントアイコン
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.fullscreen_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. 返信メッセージテキスト
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              message.text,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.4,
                color: isMe
                    ? Colors.black
                    : (AppColors.isDark ? AppColors.pureWhite : Colors.black87),
                fontWeight: isMe ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ],
      );
    } else {
      bubbleContent = Text(
        message.text,
        style: TextStyle(
          fontSize: 14.5,
          height: 1.4,
          color: isMe
              ? Colors.black
              : (AppColors.isDark ? AppColors.pureWhite : Colors.black87),
          fontWeight: isMe ? FontWeight.w600 : FontWeight.w400,
          letterSpacing: -0.1,
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        top: isFirstInGroup ? 6 : 2,
        bottom: isLastInGroup ? 6 : 2,
      ),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 相手側のアバター表示（グループの最後のメッセージのみ）
          if (!isMe) ...[
            if (isLastInGroup)
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.grey20,
                backgroundImage: widget.args.otherPhotoUrl != null
                    ? CachedNetworkImageProvider(widget.args.otherPhotoUrl!)
                    : null,
                child: widget.args.otherPhotoUrl == null
                    ? Text(
                        widget.args.otherName.isNotEmpty
                            ? widget.args.otherName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: AppColors.pureWhite,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      )
                    : null,
              )
            else
              const SizedBox(width: 28),
            const SizedBox(width: 8),
          ],

          // 自分側の既読 & 送信時間表示
          if (isMe) ...[
            Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.isRead)
                    Text(
                      l10n.directChatRead,
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentGold,
                      ),
                    ),
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // メッセージ吹き出し本体（長押しでコピー可能）
          Flexible(
            child: GestureDetector(
              onLongPress: () => _copyMessage(context, message.text),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * (hasReplyPost ? 0.76 : 0.72),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe
                      ? AppColors.accentGold
                      : (AppColors.isDark ? AppColors.grey15 : AppColors.grey10),
                  borderRadius: borderRadius,
                  border: isMe
                      ? null
                      : Border.all(
                          color: AppColors.isDark ? AppColors.grey20 : AppColors.grey70,
                          width: 0.5,
                        ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isMe ? 0.1 : 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: bubbleContent,
              ),
            ),
          ),

          // 相手側の送信時間表示
          if (!isMe) ...[
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 2),
              child: Text(
                timeStr,
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 「投稿への返信」プレビューバー（Instagramストーリーズ返信風）
  Widget _buildReplyBar(BuildContext context, AppLocalizations l10n) {
    if (_replyPostImageUrl == null || _replyPostImageUrl!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.isDark ? AppColors.grey15 : AppColors.grey10,
        border: Border(
          bottom: BorderSide(
            color: AppColors.isDark ? AppColors.grey20 : AppColors.grey70,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // 小さな投稿サムネイル
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: _replyPostImageUrl!,
              width: 38,
              height: 38,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 38,
                height: 38,
                color: AppColors.grey20,
              ),
              errorWidget: (context, url, error) => Container(
                width: 38,
                height: 38,
                color: AppColors.grey20,
                child: const Icon(Icons.image_not_supported_rounded, size: 18, color: Colors.white54),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // 返信コンテキスト情報
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_stories_rounded,
                      size: 13,
                      color: AppColors.accentGold,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        l10n.directChatReplyingTo(widget.args.otherName),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentGold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (_replyPostTaskName != null && _replyPostTaskName!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _replyPostTaskName!,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),

          // 返信キャンセルボタン
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
            tooltip: l10n.directChatCancelReply,
            onPressed: () {
              setState(() {
                _replyPostId = null;
                _replyPostImageUrl = null;
                _replyPostTaskName = null;
              });
            },
          ),
        ],
      ),
    );
  }

  /// 下部テキスト入力バー（Composer）
  Widget _buildMessageComposer(BuildContext context, AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        border: Border(
          top: BorderSide(
            color: AppColors.isDark ? AppColors.grey20 : AppColors.grey85,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 返信中の投稿プレビューバー
            _buildReplyBar(context, l10n),

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // テキスト入力欄
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.isDark ? AppColors.grey10 : AppColors.grey05,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: AppColors.isDark ? AppColors.grey20 : AppColors.grey70,
                          width: 0.8,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        maxLength: 500,
                        maxLines: 4,
                        minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(
                          fontSize: 14.5,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: l10n.directChatInputHint,
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: AppColors.textMuted,
                          ),
                          filled: false,
                          fillColor: Colors.transparent,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          isDense: true,
                          counterText: '',
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 送信ボタン（入力文字の有無で動的にスタイル変化）
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _textController,
                      builder: (context, value, child) {
                        final hasText = value.text.trim().isNotEmpty;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: hasText
                                ? AppColors.accentGold
                                : (AppColors.isDark ? AppColors.grey20 : AppColors.grey20),
                            shape: BoxShape.circle,
                            boxShadow: hasText
                                ? [
                                    BoxShadow(
                                      color: AppColors.accentGold.withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.arrow_upward_rounded,
                              color: hasText
                                  ? Colors.black
                                  : (AppColors.isDark ? AppColors.grey50 : AppColors.grey50),
                              size: 20,
                            ),
                            onPressed: (_isSending || !hasText) ? null : _sendMessage,
                            padding: EdgeInsets.zero,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
