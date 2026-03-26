import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/app_colors.dart';
import '../models/friend_request.dart';
import '../services/friend_service.dart';

/// 届いているフォロー申請一覧画面
class PendingRequestsScreen extends StatelessWidget {
  const PendingRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final friendService = FriendService.instance;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: AppColors.bgBase,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        title: const Text(
          'フォロー申請',
          style: TextStyle(color: AppColors.textPrimary),
        ),
      ),
      body: StreamBuilder<List<FriendRequest>>(
        stream: friendService.getReceivedRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final requests = snapshot.data ?? [];
          if (requests.isEmpty) {
            return const Center(
              child: Text(
                '申請はありません',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const Divider(
              color: AppColors.border,
              height: 1,
              indent: 72,
            ),
            itemBuilder: (context, index) =>
                _RequestTile(request: requests[index]),
          );
        },
      ),
    );
  }
}

class _RequestTile extends StatefulWidget {
  final FriendRequest request;
  const _RequestTile({required this.request});

  @override
  State<_RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends State<_RequestTile> {
  bool _loading = false;

  Future<void> _accept() async {
    setState(() => _loading = true);
    try {
      await FriendService.instance.acceptRequest(widget.request);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('承認に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reject() async {
    setState(() => _loading = true);
    try {
      await FriendService.instance.rejectRequest(widget.request);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拒否に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onTap: () => Navigator.pushNamed(
        context,
        '/user-profile',
        arguments: req.fromUid,
      ),
      leading: _Avatar(uid: req.fromUid),
      title: Text(
        req.fromUsername,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        '@${req.fromUserId}',
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      trailing: _loading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActionButton(
                  label: '承認',
                  filled: true,
                  onTap: _accept,
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  label: '拒否',
                  filled: false,
                  onTap: _reject,
                ),
              ],
            ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String uid;
  const _Avatar({required this.uid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: FriendService.instance.getUserByUid(uid),
      builder: (context, snapshot) {
        final photoUrl = snapshot.data?.photoUrl;
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.bgElevated,
            image: photoUrl != null
                ? DecorationImage(
                    image: ResizeImage(
                      CachedNetworkImageProvider(photoUrl),
                      width: 100,
                      height: 100,
                    ),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: photoUrl == null
              ? const Icon(Icons.person, color: AppColors.textMuted, size: 22)
              : null,
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: filled ? AppColors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: filled ? AppColors.white : AppColors.grey30,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: filled ? AppColors.black : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
