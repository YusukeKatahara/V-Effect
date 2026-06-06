import 'dart:ui';
import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/routes.dart';
import '../../models/friend_request.dart';
import '../../models/app_user.dart';
import '../../services/friend_service.dart';

class FriendRequestBanner extends StatefulWidget {
  const FriendRequestBanner({super.key});

  @override
  State<FriendRequestBanner> createState() => _FriendRequestBannerState();
}

class _FriendRequestBannerState extends State<FriendRequestBanner> {
  final Set<String> _hiddenRequestIds = {};

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FriendRequest>>(
      stream: FriendService.instance.getReceivedRequests(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        // ローカルで非表示（処理中）にしたリクエストを除外
        final requests = snapshot.data!
            .where((req) => !_hiddenRequestIds.contains(req.id))
            .toList();
            
        if (requests.isEmpty) return const SizedBox.shrink();
        
        return AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: requests.length == 1
                ? SingleRequestCard(
                    request: requests.first,
                    onHide: (reqId) => setState(() => _hiddenRequestIds.add(reqId)),
                    onRestore: (reqId) => setState(() => _hiddenRequestIds.remove(reqId)),
                  )
                : MultipleRequestsCard(requests: requests),
          ),
        );
      },
    );
  }
}

class SingleRequestCard extends StatelessWidget {
  final FriendRequest request;
  final ValueChanged<String> onHide;
  final ValueChanged<String> onRestore;

  const SingleRequestCard({
    super.key,
    required this.request,
    required this.onHide,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppUser?>(
      future: FriendService.instance.getUserByUid(request.fromUid),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final photoUrl = user?.photoUrl;
        
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.white.withValues(alpha: 0.12),
              width: 0.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                color: AppColors.white.withValues(alpha: 0.05),
                child: Row(
                  children: [
                    // アバター部分（タップでプロフィール遷移）
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.userProfile,
                        arguments: {
                          'uid': request.fromUid,
                          'username': request.fromUsername,
                          'photoUrl': photoUrl,
                        },
                      ),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.grey10,
                        backgroundImage: photoUrl != null
                            ? NetworkImage(photoUrl)
                            : null,
                        child: photoUrl == null
                            ? const Icon(Icons.person, size: 20, color: AppColors.grey50)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 名前とID（タップでプロフィール遷移）
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.userProfile,
                          arguments: {
                            'uid': request.fromUid,
                            'username': request.fromUsername,
                            'photoUrl': photoUrl,
                          },
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              request.fromUsername,
                              style: const TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '@${request.fromUserId}',
                              style: const TextStyle(
                                color: AppColors.grey50,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 承認・拒否ボタン (丸いアイコンで誤タップ防止＆スタイリッシュに)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 承認ボタン (✓)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () async {
                            final reqId = request.id;
                            onHide(reqId);
                            try {
                              await FriendService.instance.acceptRequest(request);
                            } catch (e) {
                              if (context.mounted) {
                                onRestore(reqId);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('承認に失敗しました: $e')),
                                );
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Color(0xFF00E5FF),
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // 拒否ボタン (×)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () async {
                            final reqId = request.id;
                            onHide(reqId);
                            try {
                              await FriendService.instance.rejectRequest(request);
                            } catch (e) {
                              if (context.mounted) {
                                onRestore(reqId);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('処理に失敗しました: $e')),
                                );
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.grey50.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.white.withValues(alpha: 0.15),
                              ),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: AppColors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class MultipleRequestsCard extends StatelessWidget {
  final List<FriendRequest> requests;

  const MultipleRequestsCard({super.key, required this.requests});

  @override
  Widget build(BuildContext context) {
    final latestReq = requests.first;
    final otherCount = requests.length - 1;
    
    return FutureBuilder<AppUser?>(
      future: FriendService.instance.getUserByUid(latestReq.fromUid),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final photoUrl = user?.photoUrl;
        
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.white.withValues(alpha: 0.12),
              width: 0.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: InkWell(
                onTap: () => Navigator.pushNamed(context, '/pending-requests'),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: AppColors.white.withValues(alpha: 0.05),
                  child: Row(
                    children: [
                      // アバター
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.grey10,
                        backgroundImage: photoUrl != null
                            ? NetworkImage(photoUrl)
                            : null,
                        child: photoUrl == null
                            ? const Icon(Icons.person, size: 18, color: AppColors.grey50)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      // メッセージ
                      Expanded(
                        child: Text(
                          '${latestReq.fromUsername}さん他$otherCount名から申請が届いています',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.grey50,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
