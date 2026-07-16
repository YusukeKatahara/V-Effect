import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:v_effect/l10n/app_localizations.dart';

import '../../../config/app_colors.dart';
import '../../../models/post.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/service_providers.dart';
import '../../../widgets/reaction_avatars.dart';
import 'auto_size_text.dart';
import 'hero_task_item.dart';
import 'pulse_camera_button.dart';
import '../../../providers/upload_provider.dart';
import '../../../providers/vfire_provider.dart';

class TaskCard extends ConsumerStatefulWidget {
  final HeroTaskItem item;
  final int index;
  final int total;
  final int depth;
  final bool showCamera;
  final Color tierColor;
  final bool isExpanded;
  final Map<String, String?> userPhotos;
  final VoidCallback? onDelete;
  final String? myPhotoUrl;
  final String myUsername;
  final String? myBadgeUrl;
  final String? myBadgeAnimation;

  const TaskCard({
    super.key,
    required this.item,
    required this.index,
    required this.total,
    required this.depth,
    required this.showCamera,
    required this.tierColor,
    required this.isExpanded,
    required this.userPhotos,
    this.onDelete,
    required this.myPhotoUrl,
    required this.myUsername,
    required this.myBadgeUrl,
    required this.myBadgeAnimation,
  });

  @override
  ConsumerState<TaskCard> createState() => TaskCardState();
}

class TaskCardState extends ConsumerState<TaskCard> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(covariant TaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isExpanded && oldWidget.isExpanded) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      _currentPage = 0;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildHabitStepSequence({
    required HeroTaskItem item,
    required bool isCompleted,
    required int depth,
  }) {
    final hasTrigger = item.trigger != null && item.trigger!.isNotEmpty;
    final isTop = depth == 0;

    // トリガーがない場合は、単にタスク名を表示する
    if (!hasTrigger) {
      final textStyle = GoogleFonts.notoSerifJp(
        fontSize: isTop ? 22 : 16,
        fontWeight: FontWeight.w600,
        color: isTop ? AppColors.pureWhite : Colors.white70,
        height: 1.4,
        letterSpacing: 1.5,
        shadows: isTop
            ? [
                Shadow(
                  color: AppColors.pureBlack.withValues(alpha: 0.8),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      );

      if (isTop) {
        return AutoSizeText(
          item.name,
          style: textStyle,
        );
      } else {
        return Text(
          item.name,
          style: textStyle,
        );
      }
    }

    // 奥のカード（depth > 0）の場合は簡略化して1行で表示する
    if (!isTop) {
      final sb = StringBuffer();
      if (hasTrigger) sb.write('${item.trigger} ➜ ');
      sb.write(item.name);
      return Text(
        sb.toString(),
        style: GoogleFonts.notoSansJp(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.grey50,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    // 手前のカード（depth == 0）の場合は美麗なステップUIを表示する
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasTrigger) ...[
          Text(
            item.trigger!,
            style: GoogleFonts.notoSansJp(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.pureWhite,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
        ],
        AutoSizeText(
          item.name,
          style: GoogleFonts.notoSerifJp(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.pureWhite,
            height: 1.3,
            letterSpacing: 1.5,
            shadows: [
              Shadow(
                color: AppColors.pureBlack.withValues(alpha: 0.8),
                blurRadius: 10,
                offset: const Offset(0, 2),
              )
            ],
          ),
        ),
      ],
    );
  }

  List<Post> get _sortedPosts {
    final posts = List<Post>.from(widget.item.completedPosts);
    posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return posts;
  }

  Widget _buildBackgroundImage(String? imageUrl, bool isExpanded, bool isTop) {
    if (imageUrl == null) return const SizedBox.shrink();
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        AppColors.pureBlack.withValues(
          alpha: isExpanded ? 0.1 : (isTop ? 0.3 : 0.6),
        ),
        BlendMode.darken,
      ),
      child: Image(
        image: ResizeImage(
          CachedNetworkImageProvider(imageUrl),
          width: 540,
        ),
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildLocalBackgroundImage(Uint8List? imageBytes, bool isExpanded, bool isTop) {
    if (imageBytes == null) return const SizedBox.shrink();
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        AppColors.pureBlack.withValues(
          alpha: isExpanded ? 0.1 : (isTop ? 0.3 : 0.6),
        ),
        BlendMode.darken,
      ),
      child: Image.memory(
        imageBytes,
        fit: BoxFit.cover,
        cacheWidth: 540,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final depth = widget.depth;
    final tierColor = widget.tierColor;
    final isExpanded = widget.isExpanded;
    final showCamera = widget.showCamera;
    final userPhotos = widget.userPhotos;

    final uploadState = ref.watch(uploadProvider);
    final isUploadingThisTask = uploadState.status == UploadStatus.uploading &&
        uploadState.taskName == item.name;
    final isUploadSuccessThisTask = uploadState.status == UploadStatus.success &&
        uploadState.taskName == item.name;

    final isTop = depth == 0;
    final isCompleted = item.isCompleted || isUploadingThisTask || isUploadSuccessThisTask;
    final sortedPosts = _sortedPosts;
    final postCount = sortedPosts.length;
    final currentPost = (isExpanded && postCount > 1) 
        ? sortedPosts[_currentPage] 
        : (sortedPosts.isNotEmpty ? sortedPosts.first : null);

    int totalReactionCount = 0;
    final Map<String, String> totalUserReactions = {};
    final Set<String> totalEmojiReactedUserIds = {};

    for (final post in sortedPosts) {
      final localInc = ref.watch(vfireProvider.select((state) => state.localIncrements[post.id] ?? 0));
      totalReactionCount += post.reactionCount + localInc;
      totalUserReactions.addAll(post.userReactions);
      totalEmojiReactedUserIds.addAll(post.emojiReactedUserIds);
    }

    const bgColorTop = Color(0xFF1C1D21);
    const bgColorBottom = Color(0xFF121316);

    final bool isSeason = item.isSeason;

    // ダークテーマでは黒背景に奥のカードが溶けて見えなくなるため、
    // 奥のカード（depth > 0）のボーダーを明るめに立たせて輪郭を出す
    final bool isDarkTheme = AppColors.isDark;
    final borderColor = isCompleted
        ? (isTop
            ? (postCount >= 2 ? AppColors.accentGold : AppColors.accentGold.withValues(alpha: 0.8))
            : tierColor.withValues(alpha: isDarkTheme ? 0.3 : 0.1))
        : (isSeason
            ? (isTop ? AppColors.accentGold.withValues(alpha: 0.6) : AppColors.accentGold.withValues(alpha: isDarkTheme ? 0.35 : 0.2))
            : (isTop
                ? AppColors.pureWhite.withValues(alpha: 0.12)
                : AppColors.pureWhite.withValues(alpha: isDarkTheme ? 0.18 : 0.05)));

    final borderWidth = isCompleted
        ? (isTop ? (postCount >= 2 ? 2.5 : 1.5) : (isDarkTheme ? 1.0 : 0.5))
        : (isSeason && isTop ? 1.5 : (isDarkTheme && !isTop ? 1.0 : 0.8));

    final blurRadius = isTop ? (postCount >= 2 ? 40.0 : 30.0) : 10.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: bgColorBottom,
        gradient: isCompleted
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  // ダークテーマの奥カードは透過を弱め、黒背景から面を浮かせる
                  bgColorTop.withValues(alpha: isTop ? 0.95 : (isDarkTheme ? 0.9 : 0.4)),
                  bgColorTop.withValues(alpha: isTop ? 0.65 : (isDarkTheme ? 0.7 : 0.3)),
                  bgColorBottom.withValues(alpha: isTop ? 0.85 : (isDarkTheme ? 0.8 : 0.2)),
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: isTop ? 0.6 : 0.2),
            blurRadius: isTop ? 20 : 10,
            offset: Offset(0, isTop ? 10 : 5),
            spreadRadius: -2,
          ),
          if (isTop)
            BoxShadow(
              color: isCompleted
                  ? AppColors.accentGold.withValues(alpha: postCount >= 2 ? 0.6 : 0.3)
                  : (isSeason 
                      ? AppColors.accentGold.withValues(alpha: 0.2) 
                      : tierColor.withValues(alpha: 0.04)),
              blurRadius: blurRadius,
              spreadRadius: isCompleted && postCount >= 2 ? 4 : 2,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isCompleted)
              if (isExpanded && postCount > 1)
                PageView.builder(
                  controller: _pageController,
                  onPageChanged: (idx) {
                    setState(() {
                      _currentPage = idx;
                    });
                  },
                  itemCount: postCount,
                  itemBuilder: (context, i) {
                    final p = sortedPosts[i];
                    return _buildBackgroundImage(p.imageUrl, isExpanded, isTop);
                  },
                )
              else if (sortedPosts.isNotEmpty)
                _buildBackgroundImage(sortedPosts.first.imageUrl, isExpanded, isTop)
              else if (isUploadingThisTask || isUploadSuccessThisTask)
                _buildLocalBackgroundImage(uploadState.imageBytes, isExpanded, isTop),

            _buildStack(
              item,
              isCompleted,
              postCount,
              isTop,
              depth,
              isExpanded,
              showCamera,
              tierColor,
              totalReactionCount,
              totalUserReactions,
              totalEmojiReactedUserIds.toList(),
              userPhotos,
              currentPost,
              widget.myPhotoUrl,
              widget.myUsername,
              widget.myBadgeUrl,
              widget.myBadgeAnimation,
              isUploadingThisTask: isUploadingThisTask,
              isUploadSuccessThisTask: isUploadSuccessThisTask,
              uploadProgress: uploadState.progress,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStack(
    HeroTaskItem item,
    bool isCompleted,
    int postCount,
    bool isTop,
    int depth,
    bool isExpanded,
    bool showCamera,
    Color tierColor,
    int totalReactionCount,
    Map<String, String> totalUserReactions,
    List<String> totalEmojiReactedUserIds,
    Map<String, String?> userPhotos,
    Post? currentPost,
    String? myPhotoUrl,
    String myUsername,
    String? myBadgeUrl,
    String? myBadgeAnimation, {
    required bool isUploadingThisTask,
    required bool isUploadSuccessThisTask,
    required double uploadProgress,
  }) {
    final caption = currentPost?.caption;
    return Stack(
      children: [
        // テキスト上部エリア（カメラは別レイヤー）
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isCompleted && depth == 0) ...[
                _buildHabitStepSequence(item: item, isCompleted: true, depth: depth),
                const SizedBox(height: 8),
                if (item.isSeason) ...[
                  Row(
                    children: [
                      Text(
                        'Season ${item.currentSeasonCount}/${item.season?.requiredPostsCount ?? 12}',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          color: AppColors.accentGold,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final requiredCount = item.season?.requiredPostsCount ?? 12;
                            final progress = (item.currentSeasonCount / requiredCount).clamp(0.0, 1.0);
                            return Stack(
                              children: [
                                Container(
                                  height: 2,
                                  decoration: BoxDecoration(
                                    color: (isCompleted ? AppColors.pureWhite : AppColors.white).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 800),
                                  curve: Curves.easeOutCubic,
                                  height: 2,
                                  width: constraints.maxWidth * progress,
                                  decoration: BoxDecoration(
                                    color: AppColors.accentGold,
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      Container(width: 16, height: 1, color: AppColors.accentGold),
                      const SizedBox(width: 8),
                      Text(
                        postCount >= 2 ? 'VICTORY x$postCount' : 'DONE',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          color: AppColors.accentGold,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                ],
                if (currentPost != null && currentPost.bgmTitle != null && depth == 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          await ref.read(soundServiceProvider).toggleBgmMute(currentPost.bgmUrl);
                          setState(() {}); // ミュートアイコンの更新
                        },
                        child: currentPost.bgmArtworkUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      CachedNetworkImage(
                                        imageUrl: currentPost.bgmArtworkUrl!,
                                        fit: BoxFit.cover,
                                      ),
                                      if (ref.read(soundServiceProvider).isBgmMuted)
                                        Container(
                                          color: AppColors.pureBlack.withValues(alpha: 0.5),
                                          child: Icon(
                                            Icons.music_off_rounded,
                                            color: AppColors.pureWhite,
                                            size: 16,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.pureBlack.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  ref.read(soundServiceProvider).isBgmMuted
                                      ? Icons.music_off_rounded
                                      : Icons.music_note_rounded,
                                  color: ref.read(soundServiceProvider).isBgmMuted
                                      ? (isCompleted ? Colors.white54 : AppColors.grey50)
                                      : (isCompleted ? AppColors.pureWhite : AppColors.white),
                                  size: 16,
                                ),
                              ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentPost.bgmTitle!,
                              style: TextStyle(
                                color: isCompleted ? AppColors.pureWhite : AppColors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (currentPost.bgmArtist != null)
                              Text(
                                currentPost.bgmArtist!,
                                style: TextStyle(
                                  color: isCompleted ? AppColors.pureWhite : AppColors.white, // 背景画像の上でも見えやすくなるよう、タイトルと同じ白に統一
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ] else ...[
                _buildHabitStepSequence(item: item, isCompleted: false, depth: depth),
                if (depth == 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 16,
                        height: 1,
                        color: AppColors.accentGold.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.isSeason
                            ? '${AppLocalizations.of(context)!.heroTaskSeasonDaysLeft(item.season != null ? item.season!.endDate.difference(DateTime.now()).inDays.clamp(0, 999) : 0)} (${item.currentSeasonCount}/${item.season?.requiredPostsCount ?? 12})'
                            : item.isOneTime
                                ? 'ONE-TIME'
                                : 'READY',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          color: AppColors.accentGold,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                ],
                if (currentPost?.bgmTitle != null && depth == 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          await ref.read(soundServiceProvider).toggleBgmMute(currentPost?.bgmUrl);
                          setState(() {}); // ミュートアイコンの更新
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.pureBlack.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            ref.read(soundServiceProvider).isBgmMuted
                                ? Icons.music_off_rounded
                                : Icons.music_note_rounded,
                            color: ref.read(soundServiceProvider).isBgmMuted
                                ? Colors.white54
                                : AppColors.pureWhite,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentPost!.bgmTitle!,
                              style: TextStyle(
                                color: AppColors.pureWhite,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (currentPost.bgmArtist != null)
                              Text(
                                currentPost.bgmArtist!,
                                style: const TextStyle(
                                  color: AppColors.pureWhite, // 背景画像の上でも見えやすくなるよう、タイトルと同じ白に統一
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),

        if (isCompleted && postCount > 1 && depth == 0)
          Positioned(
            top: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accentGold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.accentGold,
                  width: 1.5,
                ),
              ),
              child: Text(
                'x$postCount',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accentGold,
                ),
              ),
            ),
          ),

        // カメラボタン：ど真ん中に絶対配置
        if (!isCompleted && showCamera && depth == 0 && !isUploadingThisTask)
          Positioned.fill(
            child: Center(
              child: PulseCameraButton(tierColor: tierColor),
            ),
          ),

        // アップロード中の進捗表示
        if (isUploadingThisTask && showCamera && depth == 0)
          Positioned.fill(
            child: Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.black.withValues(alpha: 0.6),
                  border: Border.all(
                    color: AppColors.accentGold.withValues(alpha: 0.8),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          value: uploadProgress,
                          color: AppColors.accentGold,
                          strokeWidth: 2.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${(uploadProgress * 100).toInt()}%',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentGold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // アップロード成功時のDONE表示
        if (isUploadSuccessThisTask && showCamera && depth == 0)
          Positioned.fill(
            child: Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.black.withValues(alpha: 0.6),
                  border: Border.all(
                    color: AppColors.accentGold,
                    width: 2.5,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.accentGold,
                        size: 28,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'DONE',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentGold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // 達成済みの場合の「追いV」カメラアイコン（中央）
        if (isCompleted && showCamera && depth == 0 && !isExpanded && !isUploadingThisTask && !isUploadSuccessThisTask)
          Positioned.fill(
            child: Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.black.withValues(alpha: 0.4),
                  border: Border.all(
                    color: AppColors.white.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.white,
                  size: 28,
                ),
              ),
            ),
          ),

        // depth!=0 の場合の小さいカメラアイコン（中央）
        if (!isCompleted && showCamera && depth != 0 && !isUploadingThisTask)
          Positioned.fill(
            child: Center(
              child: Icon(
                Icons.camera_alt_outlined,
                color: AppColors.grey30,
                size: 20,
              ),
            ),
          ),

        // ──── ホーム画面と同じ配置 (固定座標方式に変更) ────
        if (isCompleted && depth == 0) ...[
          Positioned(
            bottom: 32,
            left: 20,
            right: 20,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 自分のキャプションとユーザー情報 (IG Reels style)
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (caption != null && caption.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        // Caption
                        Text(
                          caption,
                          style: TextStyle(
                            color: AppColors.pureWhite,
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            height: 1.3,
                            shadows: const [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                
                // 右側 (他人のリアクションアバター + V FIREボタン)
                IgnorePointer(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center, // アイコンの縦中央をきっちり揃える
                        children: [
                          if (totalReactionCount > 0) ...[
                            ReactionAvatarsStack(
                              userReactions: totalUserReactions,
                              reactorUids: totalEmojiReactedUserIds,
                              userPhotos: userPhotos,
                              reactionCount: totalReactionCount,
                              avatarSize: 36,      // VFIREボタン(56)に合わせたバランスの良いサイズ
                              overlapOffset: 24,   // 重なりのオフセット
                            ),
                            const SizedBox(width: 12),
                          ],
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppColors.pureWhite.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.pureWhite.withValues(alpha: 0.1), width: 1),
                            ),
                            child: Icon(Icons.local_fire_department, color: AppColors.accentGold, size: 32),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // VFIREボタンの真下に数字をセンタリングするために、幅56のSizedBoxで囲む
                      SizedBox(
                        width: 56,
                        height: 16,
                        child: Center(
                          child: Text(
                            '$totalReactionCount',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.pureWhite,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // ドットインジケーター
        if (isExpanded && postCount > 1 && depth == 0)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(postCount, (i) {
                final isActive = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isActive ? 12 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.accentGold : AppColors.pureWhite.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}
