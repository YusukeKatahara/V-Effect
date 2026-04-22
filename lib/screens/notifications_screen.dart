import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/app_colors.dart';
import '../models/app_notification.dart';
import '../models/app_user.dart';
import '../services/notification_service.dart';
import '../services/friend_service.dart';
import '../utils/date_helper.dart';
import '../widgets/swipe_back_gate.dart';

/// 通知画面
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService.instance;
  final FriendService _friendService = FriendService.instance;
  late final Stream<List<AppNotification>> _notificationsStream;
  bool _isProcessing = false;
  final Set<String> _initialUnreadIds = {};
  bool _hasMarkedRead = false;

  @override
  void initState() {
    super.initState();
    _notificationsStream = _notificationService.getMyNotifications();
    // 画面を開いた瞬間の既読化は build 内のデータ受信時に遅延実行する
  }

  IconData _iconForType(NotificationType type) {
    switch (type) {
      case NotificationType.friendRequestReceived:
        return Icons.person_add;
      case NotificationType.friendRequestAccepted:
        return Icons.how_to_reg;
      case NotificationType.taskReminder:
        return Icons.schedule;
      case NotificationType.reactionReceived:
        return Icons.whatshot;
      case NotificationType.friendTaskCompleted:
        return Icons.emoji_events;
    }
  }

  Color _colorForType(NotificationType type) {
    switch (type) {
      case NotificationType.friendRequestReceived:
        return AppColors.grey70;
      case NotificationType.friendRequestAccepted:
        return AppColors.white;
      case NotificationType.taskReminder:
        return AppColors.white;
      case NotificationType.reactionReceived:
        return AppColors.grey95;
      case NotificationType.friendTaskCompleted:
        return AppColors.grey85;
    }
  }

  Widget _buildAvatar(AppNotification notif) {
    Widget avatarBody;
    if (notif.fromUid == null) {
      avatarBody = _buildDefaultAvatar(notif);
    } else {
      avatarBody = FutureBuilder<AppUser?>(
        future: _friendService.getUserByUid(notif.fromUid!),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data?.photoUrl == null) {
            return _buildDefaultAvatar(notif);
          }
          return CircleAvatar(
            backgroundImage: CachedNetworkImageProvider(
              snapshot.data!.photoUrl!,
            ),
          );
        },
      );
    }

    // 右下の小さなバッジを構築
    Widget? badge;
    if (notif.emoji != null) {
      badge = _buildBadge(notif.emoji!);
    } else if (notif.type == NotificationType.reactionReceived) {
      badge = _buildBadge('🔥');
    } else if (notif.type == NotificationType.friendRequestReceived) {
      badge = _buildBadge('👤+');
    } else if (notif.type == NotificationType.friendTaskCompleted) {
      badge = _buildBadge('🏆');
    }

    if (badge == null) return avatarBody;

    return Stack(
      children: [avatarBody, Positioned(right: -2, bottom: -2, child: badge)],
    );
  }

  Widget _buildBadge(String content) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.black,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.black, width: 1),
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          color: AppColors.grey10,
          shape: BoxShape.circle,
        ),
        child: Text(content, style: const TextStyle(fontSize: 10)),
      ),
    );
  }

  Widget _buildDefaultAvatar(AppNotification notif) {
    return CircleAvatar(
      backgroundColor: _colorForType(notif.type).withValues(alpha: 0.2),
      child: Icon(
        _iconForType(notif.type),
        color: _colorForType(notif.type),
        size: 20,
      ),
    );
  }

  Future<void> _deleteNotification(String id) async {
    try {
      await _notificationService.deleteNotification(id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('削除に失敗しました。もう一度お試しください。')));
      }
    }
  }

  Future<void> _deleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppColors.bgElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              '通知を全て削除',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            content: const Text(
              '全ての通知を削除しますか？',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'キャンセル',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  '削除',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    try {
      await _notificationService.deleteAllNotifications();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('削除に失敗しました。もう一度お試しください。')));
      }
    }
  }

  Future<void> _handleFriendRequest(AppNotification notif, bool accept) async {
    if (notif.relatedId == null) return;

    setState(() => _isProcessing = true);
    try {
      final request = await _friendService.getRequestById(notif.relatedId!);
      if (request == null) {
        throw Exception('リクエストが見つかりませんでした。すでに処理されている可能性があります。');
      }

      if (accept) {
        await _friendService.acceptRequest(request);
      } else {
        await _friendService.rejectRequest(request);
      }

      // 完了したら通知を削除
      await _notificationService.deleteNotification(notif.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept ? 'フォローリクエストを承認しました！' : 'フォローリクエストを拒否しました。'),
          ),
        );
      }
    } catch (e) {
      debugPrint('承認エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('承認に失敗しました。もう一度お試しください。')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Widget _buildCompactButton({
    required String label,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    return ElevatedButton(
      onPressed: _isProcessing ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? AppColors.white : Colors.transparent,
        foregroundColor: isPrimary ? AppColors.black : AppColors.textSecondary,
        elevation: 0,
        minimumSize: const Size(80, 32),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        side:
            isPrimary
                ? BorderSide.none
                : const BorderSide(color: AppColors.grey10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SwipeBackGate(
      child: Scaffold(
        backgroundColor: AppColors.bgBase,
        appBar: AppBar(
        title: const Text('通知'),
        backgroundColor: AppColors.bgBase,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _deleteAll,
            tooltip: '全て削除',
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: _notificationsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'エラーが発生しました: ${snapshot.error}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data ?? [];

          // データ受信時に一度だけ既読処理を行う（初期の未読状態をキャッシュ）
          if (!_hasMarkedRead && notifications.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!_hasMarkedRead) {
                _hasMarkedRead = true;
                for (final n in notifications) {
                  if (!n.isRead) _initialUnreadIds.add(n.id);
                }
                _notificationService.markAllAsRead().catchError((_) {});
                if (mounted) setState(() {});
              }
            });
          }

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.bgSurface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.08),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.notifications_off_outlined,
                      size: 32,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '通知はありません',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];
              final isUnread =
                  _initialUnreadIds.contains(notif.id) || !notif.isRead;

              return Dismissible(
                key: Key(notif.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: AppColors.error.withValues(alpha: 0.8),
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                onDismissed: (_) => _deleteNotification(notif.id),
                child: Material(
                  color:
                      isUnread
                          ? AppColors.accentGold.withValues(alpha: 0.05)
                          : Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      if (notif.fromUid != null) {
                        Navigator.pushNamed(
                          context,
                          '/user-profile',
                          arguments: notif.fromUid,
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // アバター
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: _buildAvatar(notif),
                          ),
                          const SizedBox(width: 14),

                          // コンテンツ
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildNotificationBody(notif, isUnread),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Text(
                                      DateHelper.timeAgo(notif.createdAt),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (isUnread) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 4,
                                        height: 4,
                                        decoration: const BoxDecoration(
                                          color: AppColors.accentGold,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),

                                // フレンド申請ボタン (プレミアム化)
                                if (notif.type ==
                                    NotificationType.friendRequestReceived) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      _buildCompactButton(
                                        label: '承認',
                                        onPressed:
                                            () => _handleFriendRequest(
                                              notif,
                                              true,
                                            ),
                                        isPrimary: true,
                                      ),
                                      const SizedBox(width: 10),
                                      _buildCompactButton(
                                        label: 'あとで',
                                        onPressed:
                                            () => _handleFriendRequest(
                                              notif,
                                              false,
                                            ),
                                        isPrimary: false,
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    ),
    );
  }

  /// 通知本文をリッチテキストで構築（特定のキーワードを太字やゴールドにする）
  Widget _buildNotificationBody(AppNotification notif, bool isUnread) {
    final body = notif.body;
    List<TextSpan> spans = [];

    // 特定のキーワード（ユーザー名や「タスク名」など）を抽出してスタイルを分ける
    final regExp = RegExp(r'([^\s「」]+(?:さん|くん|ちゃん)|「[^」]+」)');
    int lastMatchEnd = 0;

    for (final match in regExp.allMatches(body)) {
      // マッチ前の通常テキスト
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: body.substring(lastMatchEnd, match.start)));
      }
      // 強調テキスト
      final matchText = match.group(0)!;
      final isEntity =
          matchText.contains('さん') ||
          matchText.contains('くん') ||
          matchText.contains('ちゃん');
      spans.add(
        TextSpan(
          text: matchText,
          style: TextStyle(
            color: isEntity ? AppColors.white : AppColors.accentGold,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      lastMatchEnd = match.end;
    }

    // 残りのテキスト
    if (lastMatchEnd < body.length) {
      spans.add(TextSpan(text: body.substring(lastMatchEnd)));
    }

    return RichText(
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.textSecondary,
          height: 1.4,
          fontFamily: 'Outfit',
        ),
        children: spans,
      ),
    );
  }
}
