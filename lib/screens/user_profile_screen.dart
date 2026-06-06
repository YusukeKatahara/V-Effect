import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:v_effect/l10n/app_localizations.dart';

import '../config/app_colors.dart';
import '../models/app_user.dart';
import '../services/block_service.dart';
import '../services/friend_service.dart';
import '../widgets/swipe_back_gate.dart';
import '../widgets/full_screen_image_viewer.dart';
import '../widgets/v_badge_widget.dart';
/// 他ユーザーのプロフィール閲覧画面
///
/// 引数（ModalRoute.settings.arguments）: String uid
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final FriendService _friendService = FriendService.instance;
  final String _myUid = FirebaseAuth.instance.currentUser!.uid;

  String? _targetUid;
  String? _initialUsername;
  String? _initialPhotoUrl;

  AppUser? _user;
  bool _loading = true;
  bool _isFollowing = false;
  bool _isMyFollower = false;
  bool _isPending = false;
  bool _isProcessing = false;
  bool _isBlocked = false;
  bool _isBlockProcessing = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && !_initialized) {
      _initialized = true;
      if (args is String) {
        _targetUid = args;
      } else if (args is Map) {
        _targetUid = args['uid'] as String?;
        _initialUsername = args['username'] as String?;
        _initialPhotoUrl = args['photoUrl'] as String?;
      }
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    // データがある場合はフルスクリーンローディングを出さない
    if (_user == null) {
      setState(() => _loading = true);
    }

    try {
      final results = await Future.wait([
        _friendService.getUserByUid(_targetUid!),
        _friendService.isFollowing(_targetUid!),
        BlockService.instance.isBlocked(_targetUid!),
      ]);

      // friend_requests コレクションへのアクセスが失敗しても他の処理を妨げない
      bool isPending = false;
      try {
        isPending = await _friendService.hasPendingRequest(_targetUid!);
      } catch (_) {}

      if (!mounted) return;
      final loadedUser = results[0] as AppUser?;
      setState(() {
        _user = loadedUser;
        _isFollowing = results[1] as bool;
        // _user.following にyusukeのUIDが含まれる = renがyusukeをフォローしている = renはyusukeのフォロワー
        _isMyFollower = loadedUser?.following.contains(_myUid) ?? false;
        _isPending = isPending;
        _isBlocked = results[2] as bool;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (_targetUid == null) return;
    if (_isProcessing) return; // 連打防止

    // Optimistic UI Update: サーバーの応答を待たずにUIを切り替える
    final oldFollowing = _isFollowing;
    final oldPending = _isPending;

    setState(() {
      _isProcessing = true;
      if (_isFollowing) {
        _isFollowing = false;
      } else if (_isPending) {
        _isPending = false;
      } else {
        _isPending = true; // とりあえず申請中にする
      }
    });

    try {
      if (oldFollowing) {
        await _friendService.unfollowUser(_targetUid!);
      } else if (oldPending) {
        await _friendService.cancelRequest(_targetUid!);
      } else {
        await _friendService.sendRequest(_targetUid!);
      }
      // 最新の状態を再取得
      await _loadProfile();
    } catch (e) {
      // 失敗した場合は元に戻す
      if (mounted) {
        setState(() {
          _isFollowing = oldFollowing;
          _isPending = oldPending;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.userProfileFollowFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _openFollowList({required bool isFollowing}) {
    if (_user == null) return;
    Navigator.pushNamed(
      context,
      '/follow-list',
      arguments: {
        'uid': _targetUid,
        'isFollowing': isFollowing,
        'title': isFollowing ? AppLocalizations.of(context)!.userProfileFollowing : AppLocalizations.of(context)!.userProfileFollowers,
      },
    );
  }

  // ── ブロック・通報 ────────────────────────────────────

  void _showOptionsMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  _isBlocked
                      ? Icons.lock_open_rounded
                      : Icons.block_rounded,
                  color: _isBlocked ? AppColors.textPrimary : AppColors.error,
                ),
                title: Text(
                  _isBlocked ? AppLocalizations.of(context)!.userProfileUnblock : AppLocalizations.of(context)!.userProfileBlock,
                  style: TextStyle(
                    color: _isBlocked
                        ? AppColors.textPrimary
                        : AppColors.error,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _handleBlock();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.flag_rounded,
                  color: AppColors.textSecondary,
                ),
                title: Text(
                  AppLocalizations.of(context)!.userProfileReport,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showReportDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleBlock() {
    if (_isBlocked) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.bgSurface,
          title: Text(
            AppLocalizations.of(context)!.userProfileUnblockConfirmTitle,
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          content: Text(
            AppLocalizations.of(context)!.userProfileUnblockConfirmDesc,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                AppLocalizations.of(context)!.userProfileUnblockCancel,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _performUnblock();
              },
              child: Text(
                AppLocalizations.of(context)!.userProfileUnblockButton,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      );
    } else {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.bgSurface,
          title: Text(
            AppLocalizations.of(context)!.userProfileBlockConfirmTitle,
            style: const TextStyle(color: AppColors.error),
          ),
          content: Text(
            AppLocalizations.of(context)!.userProfileBlockConfirmDesc,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                AppLocalizations.of(context)!.userProfileBlockCancel,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _performBlock();
              },
              child: Text(
                AppLocalizations.of(context)!.userProfileBlockButton,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _performBlock() async {
    if (_targetUid == null) return;
    setState(() => _isBlockProcessing = true);
    try {
      await BlockService.instance.blockUser(_targetUid!);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.userProfileBlockFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _isBlockProcessing = false);
    }
  }

  Future<void> _performUnblock() async {
    if (_targetUid == null) return;
    setState(() => _isBlockProcessing = true);
    try {
      await BlockService.instance.unblockUser(_targetUid!);
      if (mounted) setState(() => _isBlocked = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.userProfileUnblockFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _isBlockProcessing = false);
    }
  }

  void _showReportDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: Text(
          AppLocalizations.of(context)!.userProfileReportTitle,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _reportOption(ctx, AppLocalizations.of(context)!.userProfileReportSpam, 'spam'),
            _reportOption(ctx, AppLocalizations.of(context)!.userProfileReportHarassment, 'harassment'),
            _reportOption(ctx, AppLocalizations.of(context)!.userProfileReportInappropriate, 'inappropriate'),
            _reportOption(ctx, AppLocalizations.of(context)!.userProfileReportOther, 'other'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              AppLocalizations.of(context)!.userProfileReportCancel,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportOption(BuildContext ctx, String label, String reason) {
    return ListTile(
      title: Text(label, style: const TextStyle(color: AppColors.textPrimary)),
      onTap: () {
        Navigator.pop(ctx);
        _performReport(reason);
      },
    );
  }

  Future<void> _performReport(String reason) async {
    if (_targetUid == null) return;
    try {
      await BlockService.instance.reportUser(_targetUid!, reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.userProfileReportDone)),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('already_reported')
            ? AppLocalizations.of(context)!.userProfileReportAlready
            : AppLocalizations.of(context)!.userProfileReportFailed;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    }
  }

  // ── Build ────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final title = _user?.username ?? _initialUsername ?? '';
    final isOtherUser = _targetUid != _myUid && _targetUid != null;

    return SwipeBackGate(
      child: Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: AppColors.bgBase,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        title: Text(
          title,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          if (isOtherUser)
            _isBlockProcessing
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: _showOptionsMenu,
                  ),
        ],
      ),
      body: _user == null && _loading
          ? _buildSkeleton()
          : _user == null && !_loading
              ? Center(
                  child: Text(
                    AppLocalizations.of(context)!.userProfileNotFound,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadProfile,
                  color: AppColors.primary,
                  backgroundColor: AppColors.bgSurface,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildStats(),
                      if (_targetUid != _myUid) ...[
                        const SizedBox(height: 24),
                        _buildFollowButton(),
                      ],
                      if (_user!.tasks.isNotEmpty) ...[
                        const SizedBox(height: 32),
                        _buildTasksSection(),
                      ],
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // アバターのプレースホルダ（渡されている場合は画像を表示）
              _initialPhotoUrl != null
                  ? CircleAvatar(
                      radius: 40,
                      backgroundImage: ResizeImage(
                        CachedNetworkImageProvider(_initialPhotoUrl!),
                        width: 240,
                      ),
                    )
                  : Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.grey10,
                      ),
                    ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _initialUsername != null
                      ? Text(
                          _initialUsername!,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        )
                      : Container(
                          width: 120,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.grey10,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                  const SizedBox(height: 8),
                  Container(
                    width: 80,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.grey10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              3,
              (i) => Column(
                children: [
                  Container(
                    width: 40,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.grey10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 60,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.grey10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final photoUrl = _user?.photoUrl ?? _initialPhotoUrl;
    final username = _user?.username ?? _initialUsername ?? '';

    return Row(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: photoUrl == null ? AppColors.primaryGradient : null,
          ),
          child: photoUrl != null
              ? GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        opaque: false,
                        barrierColor: Colors.black.withValues(alpha: 0.9),
                        pageBuilder: (context, _, __) => FullScreenImageViewer(
                          imageUrl: photoUrl,
                          heroTag: 'profile_image_$_targetUid',
                        ),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          return FadeTransition(opacity: animation, child: child);
                        },
                      ),
                    );
                  },
                  child: Hero(
                    tag: 'profile_image_$_targetUid',
                    child: CircleAvatar(
                      radius: 40,
                      backgroundImage: ResizeImage(
                        CachedNetworkImageProvider(photoUrl),
                        width: 240,
                      ),
                    ),
                  ),
                )
              : const CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.transparent,
                  child: Icon(
                    Icons.person_rounded,
                    size: 40,
                    color: AppColors.black,
                  ),
                ),

        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      username,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (_user != null &&
                      _user!.equippedBadgeUrl != null &&
                      _user!.equippedBadgeUrl!.isNotEmpty) ...[
                    VBadgeWidget(
                      imageUrl: _user!.equippedBadgeUrl,
                      animationType: _user!.equippedBadgeAnimation ?? 'none',
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (_user != null &&
                      _user!.instagramId != null &&
                      _user!.instagramId!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () async {
                        final instagramId = _user!.instagramId!;
                        final appUri = Uri.parse('instagram://user?username=$instagramId');
                        final webUri = Uri.parse('https://instagram.com/$instagramId');
                        try {
                          if (await canLaunchUrl(appUri)) {
                            await launchUrl(appUri);
                          } else {
                            await launchUrl(webUri, mode: LaunchMode.externalApplication);
                          }
                        } catch (e) {
                          debugPrint('Could not launch instagram: $e');
                        }
                      },
                      child: const FaIcon(
                        FontAwesomeIcons.instagram,
                        color: AppColors.white,
                        size: 22,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                _user != null ? '@${_user!.userId}' : '...',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStats() {
    // フォロー/フォロワーリストは自分自身・自分のフォロワーのみ閲覧可能
    final canViewList = _targetUid == _myUid || _isMyFollower;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem(
          AppLocalizations.of(context)!.userProfileFollowing,
          _user!.following.length,
          onTap: canViewList ? () => _openFollowList(isFollowing: true) : null,
        ),
        _buildStatItem(
          AppLocalizations.of(context)!.userProfileFollowers,
          _user!.followers.length,
          onTap: canViewList ? () => _openFollowList(isFollowing: false) : null,
        ),
        _buildStatItem(
          AppLocalizations.of(context)!.userProfileStreak,
          _user!.streak,
          icon: Icons.local_fire_department_rounded,
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, int count, {IconData? icon, VoidCallback? onTap}) {
    final content = Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: AppColors.accentGold),
              const SizedBox(width: 4),
            ],
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        if (onTap != null)
          const SizedBox(height: 2),
        if (onTap != null)
          Container(
            width: 24,
            height: 1,
            color: AppColors.grey20,
          ),
      ],
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: content,
        ),
      );
    }
    return content;
  }

  Widget _buildFollowButton() {
    final String label;
    final Color bgColor;
    final Color fgColor;
    final BorderSide border;

    if (_isFollowing) {
      label = AppLocalizations.of(context)!.userProfileFollowing;
      bgColor = AppColors.bgSurface;
      fgColor = AppColors.textPrimary;
      border = const BorderSide(color: AppColors.border);
    } else if (_isPending) {
      label = AppLocalizations.of(context)!.userProfilePending;
      bgColor = AppColors.bgSurface;
      fgColor = AppColors.textSecondary;
      border = const BorderSide(color: AppColors.border);
    } else {
      label = AppLocalizations.of(context)!.userProfileFollowRequest;
      bgColor = AppColors.white;
      fgColor = AppColors.black;
      border = BorderSide.none;
    }

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _toggleFollow, // 無効化による色の変化やくるくる表示をなくす
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: border,
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            height: 1.1,
          ),
        ),
      ),
    );
  }

  Widget _buildTasksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.accentGold,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context)!.userProfileHeroTasks,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: List.generate(_user!.tasks.length, (i) {
              final isLast = i == _user!.tasks.length - 1;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.grey10,
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _user!.tasks[i].title,
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast) const Divider(height: 1, indent: 52),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}
