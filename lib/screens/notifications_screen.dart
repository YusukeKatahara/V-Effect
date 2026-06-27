import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import '../config/app_colors.dart';
import '../config/routes.dart';
import '../models/app_user.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';
import '../services/friend_service.dart';
import '../services/user_service.dart';
import '../utils/date_helper.dart';
import '../widgets/swipe_back_gate.dart';
import '../widgets/shimmer_container.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/service_providers.dart';
import '../providers/dev_blog_provider.dart';
import '../providers/language_provider.dart';
import '../models/dev_blog_post.dart';

/// 通知画面
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  late NotificationService _notificationService;
  late FriendService _friendService;
  late final Stream<List<AppNotification>> _notificationsStream;
  bool _isProcessing = false;
  final Set<String> _initialUnreadIds = {};
  bool _hasMarkedRead = false;
  final Map<String, bool> _followingStatusCache = {};

  Future<bool> _checkIsFollowing(String targetUid) async {
    if (_followingStatusCache.containsKey(targetUid)) {
      return _followingStatusCache[targetUid]!;
    }
    final isFollowing = await _friendService.isFollowing(targetUid);
    if (mounted) {
      setState(() {
        _followingStatusCache[targetUid] = isFollowing;
      });
    }
    return isFollowing;
  }

  Future<void> _followBack(String targetUid) async {
    setState(() => _isProcessing = true);
    try {
      await _friendService.followUser(targetUid);
      setState(() {
        _followingStatusCache[targetUid] = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.notificationsFollowed)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.notificationsFollowFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _notificationService = ref.read(notificationServiceProvider);
    _friendService = ref.read(friendServiceProvider);
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
      case NotificationType.streakCelebration:
        return Icons.workspace_premium;
      case NotificationType.streakWarning:
        return Icons.warning_amber_rounded;
      case NotificationType.badgeAcquired:
        return Icons.military_tech;
      case NotificationType.seasonTaskDistributed:
      case NotificationType.seasonTaskReceived:
      case NotificationType.seasonTaskPushOnly:
        return Icons.event_available;
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
      case NotificationType.streakCelebration:
        return AppColors.accentGold;
      case NotificationType.streakWarning:
        return AppColors.error;
      case NotificationType.badgeAcquired:
        return AppColors.accentGold;
      case NotificationType.seasonTaskDistributed:
      case NotificationType.seasonTaskReceived:
      case NotificationType.seasonTaskPushOnly:
        return AppColors.accentGold;
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
    } else if (notif.type == NotificationType.streakCelebration) {
      badge = _buildBadge('🎉');
    } else if (notif.type == NotificationType.streakWarning) {
      badge = _buildBadge('⚠️');
    } else if (notif.type == NotificationType.badgeAcquired) {
      badge = _buildBadge('🏅');
    } else if (notif.type == NotificationType.seasonTaskDistributed) {
      badge = _buildBadge('🎁');
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
        decoration: BoxDecoration(
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
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.notificationsDeleteFailed)));
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
            title: Text(
              AppLocalizations.of(context)!.notificationsDeleteAllTitle,
              style: TextStyle(color: AppColors.textPrimary),
            ),
            content: Text(
              AppLocalizations.of(context)!.notificationsDeleteAllMessage,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  AppLocalizations.of(context)!.notificationsDeleteAllCancel,
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  AppLocalizations.of(context)!.notificationsDeleteAllButton,
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
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.notificationsDeleteFailed)));
      }
    }
  }

  Future<void> _handleFriendRequest(AppNotification notif, bool accept) async {
    if (notif.relatedId == null) {
      // 古いデータなどで relatedId が無い場合、処理しようがないので通知だけ削除する
      await _notificationService.deleteNotification(notif.id);
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final request = await _friendService.getRequestById(notif.relatedId!);
      
      if (request != null) {
        if (accept) {
          await _friendService.acceptRequest(request);
        } else {
          await _friendService.rejectRequest(request);
        }
      } else {
        if (notif.relatedId != null) {
          await _notificationService.markNotificationAsProcessedByRelatedId(notif.relatedId!);
        }
      }

      if (mounted && request != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept ? AppLocalizations.of(context)!.notificationsApproveRequest : AppLocalizations.of(context)!.notificationsRejectRequest),
          ),
        );
      }
    } catch (e) {
      debugPrint('承認エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.notificationsApproveFailed)));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleSeasonTaskDetails(AppNotification notif) async {
    if (notif.relatedId == null) return;
    
    setState(() => _isProcessing = true);
    try {
      // 🚀 【動的マージ対応】シーズンタスクを処理済み（非表示）にマークします
      await ref.read(userServiceProvider).markSeasonTaskAsProcessed(notif.relatedId!);
      
      if (mounted) {
        setState(() {});
        // 🚀 開発ブログ詳細画面（お知らせページ）へ遷移します
        Navigator.pushNamed(
          context,
          AppRoutes.blogPostDetail,
          arguments: notif.relatedId,
        );
      }
    } catch (e) {
      debugPrint('Season Task Details Process Error: $e');
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
                : BorderSide(color: AppColors.grey10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
  Widget _buildFriendRequestTrailing(AppNotification notif) {
    if (notif.isProcessed) {
      return FutureBuilder<bool>(
        future: _checkIsFollowing(notif.fromUid!),
        builder: (context, snapshot) {
          final isFollowing = snapshot.data ?? false;
          if (isFollowing) {
            return ElevatedButton(
              onPressed: null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.bgSurface,
                disabledBackgroundColor: AppColors.bgSurface,
                disabledForegroundColor: AppColors.textPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(AppLocalizations.of(context)!.notificationsFollowing, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            );
          } else {
            return ElevatedButton(
              onPressed: () => _followBack(notif.fromUid!),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.bgSurface,
                foregroundColor: AppColors.textPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(AppLocalizations.of(context)!.notificationsFollowBack, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            );
          }
        },
      );
    } else {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: () => _handleFriendRequest(notif, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.white,
              foregroundColor: AppColors.black,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: const Size(80, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(AppLocalizations.of(context)!.notificationsApprove, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _handleFriendRequest(notif, false),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: AppColors.textSecondary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: const Size(80, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(AppLocalizations.of(context)!.notificationsDelete, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildSeasonTaskTrailing(AppNotification notif) {
    if (notif.isProcessed) {
      return const SizedBox.shrink();
    } else {
      final locale = Localizations.localeOf(context).languageCode;
      final btnText = locale == 'ja' ? '詳細を見る' : 'View Details';

      return ElevatedButton(
        onPressed: () => _handleSeasonTaskDetails(notif),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          minimumSize: const Size(80, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          btnText,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      );
    }
  }


  Widget _buildNotificationSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 6, // 骨組みアイテムを6個表示
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // アバター用の丸型シマー
              const ShimmerContainer.circular(size: 40),
              const SizedBox(width: 16),
              // メッセージ等の内容を模したシマー
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ShimmerContainer(
                      width: double.infinity,
                      height: 14,
                      borderRadius: 4,
                    ),
                    const SizedBox(height: 8),
                    ShimmerContainer(
                      width: MediaQuery.sizeOf(context).width * 0.25,
                      height: 10,
                      borderRadius: 4,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SwipeBackGate(
      child: Scaffold(
        backgroundColor: AppColors.bgBase,
        appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.notificationsTitle),
        backgroundColor: AppColors.bgBase,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _deleteAll,
            tooltip: AppLocalizations.of(context)!.notificationsDeleteAll,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildAnnouncementBanner(),
          Expanded(
            child: StreamBuilder<List<AppNotification>>(
              stream: _notificationsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      AppLocalizations.of(context)!.notificationsError(snapshot.error ?? ''),
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildNotificationSkeleton();
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
                                color: AppColors.white.withValues(alpha: 0.08),
                                blurRadius: 24,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.notifications_off_outlined,
                            size: 32,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context)!.notificationsEmpty,
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
                        child: Icon(Icons.delete_outline, color: AppColors.white),
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
                              crossAxisAlignment: CrossAxisAlignment.center,
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
                                            style: TextStyle(
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
                                              decoration: BoxDecoration(
                                                color: AppColors.accentGold,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (notif.type == NotificationType.friendRequestReceived || notif.type == NotificationType.seasonTaskDistributed) ...[
                                  const SizedBox(width: 12),
                                  if (notif.type == NotificationType.friendRequestReceived)
                                    _buildFriendRequestTrailing(notif)
                                  else
                                    _buildSeasonTaskTrailing(notif),
                                ],
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
        ],
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
        style: TextStyle(
          fontSize: 14,
          color: AppColors.textSecondary,
          height: 1.4,
          fontFamily: 'Outfit',
        ),
        children: spans,
      ),
    );
  }

  /// 最新のお知らせバナーを構築する
  Widget _buildAnnouncementBanner() {
    final blogPostsAsync = ref.watch(publishedBlogPostsProvider);
    return blogPostsAsync.when(
      data: (posts) {
        if (posts.isEmpty) return const SizedBox.shrink();

        // ピン留めされているものを最優先、なければ最新の1件を取得
        final post = posts.firstWhere(
          (p) => p.isPinned,
          orElse: () => posts.first,
        );

        final lang = ref.watch(languageProvider);
        final isEnglish = lang == 'en';
        final title = isEnglish && post.titleEn != null && post.titleEn!.isNotEmpty
            ? post.titleEn!
            : post.title;

        // この特定のポストが未読かどうか判定する
        final lastViewedAsync = ref.watch(lastViewedDevBlogAtProvider);
        final isUnread = lastViewedAsync.when(
          data: (lastViewed) {
            if (lastViewed == null) return true;
            return post.createdAt.isAfter(lastViewed);
          },
          loading: () => false,
          error: (_, __) => false,
        );

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          decoration: BoxDecoration(
            color: AppColors.grey10,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.grey20, width: 0.5),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                // 既読にする
                markDevBlogAsRead(ref);
                // 詳細画面へ遷移
                Navigator.pushNamed(
                  context,
                  AppRoutes.blogPostDetail,
                  arguments: post,
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    // メガホンアイコンと未読ドット
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          Icons.campaign_rounded,
                          color: isUnread ? AppColors.accentGold : AppColors.grey50,
                          size: 24,
                        ),
                        if (isUnread)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.accentGold,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    // カテゴリバッジとタイトル
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.grey15,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.grey20, width: 0.5),
                                ),
                                child: Text(
                                  post.category.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.grey70,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (post.isPinned) ...[
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.push_pin_rounded,
                                  size: 10,
                                  color: AppColors.accentGold,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.grey50,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
