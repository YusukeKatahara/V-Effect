import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import '../config/app_colors.dart';
import '../models/friend_request.dart';
import '../providers/service_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/swipe_back_gate.dart';
import '../widgets/shimmer_container.dart';

/// 届いているフォロー申請一覧画面
class PendingRequestsScreen extends ConsumerWidget {
  const PendingRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendService = ref.read(friendServiceProvider);

    return SwipeBackGate(
      child: Scaffold(
        backgroundColor: AppColors.bgBase,
        appBar: AppBar(
          backgroundColor: AppColors.bgBase,
          surfaceTintColor: Colors.transparent,
          foregroundColor: AppColors.textPrimary,
          title: Text(
            AppLocalizations.of(context)!.pendingRequestsTitle,
            style: TextStyle(color: AppColors.textPrimary),
          ),
        ),
        body: StreamBuilder<List<FriendRequest>>(
          stream: friendService.getReceivedRequests(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildShimmerList();
            }
            final requests = snapshot.data ?? [];
            if (requests.isEmpty) {
              return Center(
                child: Text(
                  AppLocalizations.of(context)!.pendingRequestsEmpty,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: requests.length,
              separatorBuilder: (_, __) => Divider(
                color: AppColors.border,
                height: 1,
                indent: 72,
              ),
              itemBuilder: (context, index) =>
                  _RequestTile(request: requests[index]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const ShimmerContainer.circular(size: 44),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ShimmerContainer(width: 120, height: 16, borderRadius: 4),
                    const SizedBox(height: 6),
                    const ShimmerContainer(width: 80, height: 12, borderRadius: 4),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const ShimmerContainer(width: 60, height: 28, borderRadius: 14),
              const SizedBox(width: 8),
              const ShimmerContainer(width: 60, height: 28, borderRadius: 14),
            ],
          ),
        );
      },
    );
  }
}

class _RequestTile extends ConsumerStatefulWidget {
  final FriendRequest request;
  const _RequestTile({required this.request});

  @override
  ConsumerState<_RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends ConsumerState<_RequestTile> {
  bool _loading = false;

  Future<void> _accept() async {
    setState(() => _loading = true);
    try {
      await ref.read(friendServiceProvider).acceptRequest(widget.request);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.pendingRequestsAcceptFailed(e))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reject() async {
    setState(() => _loading = true);
    try {
      await ref.read(friendServiceProvider).rejectRequest(widget.request);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.pendingRequestsRejectFailed(e))));
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
      onTap:
          () => Navigator.pushNamed(
            context,
            '/user-profile',
            arguments: req.fromUid,
          ),
      leading: _Avatar(uid: req.fromUid),
      title: Text(
        req.fromUsername,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        '@${req.fromUserId}',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      trailing:
          _loading
              ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionButton(label: AppLocalizations.of(context)!.pendingRequestsAccept, filled: true, onTap: _accept),
                  const SizedBox(width: 8),
                  _ActionButton(label: AppLocalizations.of(context)!.pendingRequestsReject, filled: false, onTap: _reject),
                ],
              ),
    );
  }
}

class _Avatar extends ConsumerWidget {
  final String uid;
  const _Avatar({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref.read(friendServiceProvider).getUserByUid(uid),
      builder: (context, snapshot) {
        final photoUrl = snapshot.data?.photoUrl;
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.bgElevated,
            image:
                photoUrl != null
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
          child:
              photoUrl == null
                  ? Icon(
                    Icons.person,
                    color: AppColors.textMuted,
                    size: 22,
                  )
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
