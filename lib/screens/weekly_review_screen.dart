import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../config/app_colors.dart';
import '../models/post.dart';
import '../providers/weekly_review_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 今週の振り返りをストーリー形式で表示する画面
class WeeklyReviewScreen extends ConsumerStatefulWidget {
  final List<Post>? posts;
  final int? currentStreak;

  const WeeklyReviewScreen({
    super.key,
    this.posts,
    this.currentStreak,
  });

  @override
  ConsumerState<WeeklyReviewScreen> createState() => _WeeklyReviewScreenState();
}

class _WeeklyReviewScreenState extends ConsumerState<WeeklyReviewScreen>
    with SingleTickerProviderStateMixin {
  // 表示用データ
  List<Post> _posts = [];
  int _currentStreak = 0;
  bool _isDataInitialized = false;

  late PageController _pageController;
  Timer? _autoTimer;
  final GlobalKey _summaryKey = GlobalKey();
  bool _isSharing = false;

  // ひっぱり（Pull-to-dismiss）用の状態
  double _dragOffset = 0;
  late AnimationController _snapBackController;
  late Animation<double> _snapBackAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.posts != null && widget.currentStreak != null) {
      _posts = widget.posts!;
      _currentStreak = widget.currentStreak!;
      _isDataInitialized = true;
    }
    _pageController = PageController(initialPage: 0);
    if (_isDataInitialized && _posts.isNotEmpty) {
      _startAutoTimer();
    }

    _snapBackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _snapBackAnimation = _snapBackController.drive(Tween<double>(begin: 0, end: 0));
    _snapBackController.addListener(() {
      setState(() => _dragOffset = _snapBackAnimation.value);
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageController.dispose();
    _snapBackController.dispose();
    super.dispose();
  }

  void _startAutoTimer() {
    _autoTimer?.cancel();
    _autoTimer = Timer(const Duration(seconds: 4), _goNext);
  }

  void _resetAutoTimer() {
    _startAutoTimer();
  }

  void _goNext() {
    if (_pageController.hasClients) {
      final nextPage = _pageController.page!.round() + 1;
      final totalPages = _posts.length + 1;
      if (nextPage < totalPages) {
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      } else {
        _autoTimer?.cancel();
      }
    }
  }

  void _goPrev() {
    if (_pageController.hasClients) {
      final prevPage = _pageController.page!.round() - 1;
      if (prevPage >= 0) {
        _pageController.animateToPage(
          prevPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      } else {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _shareSummary() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final boundary = _summaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/weekly_review.png';
      final file = File(path);
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(path)],
        text: '今週も${_posts.length}回のヒーロータスクを完遂！\n現在のストリーク: $_currentStreak日 🔥\n#VEffect',
      );
    } catch (e) {
      debugPrint('Share error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('シェアに失敗しました。もう一度お試しください。')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDataInitialized) {
      final reviewAsync = ref.watch(weeklyReviewProvider);
      return reviewAsync.when(
        loading: () => const Scaffold(backgroundColor: AppColors.bgBase, body: Center(child: CircularProgressIndicator())),
        error: (err, stack) => Scaffold(
          backgroundColor: AppColors.bgBase,
          body: Center(child: Text('読み込みエラー: $err', style: const TextStyle(color: Colors.white))),
        ),
        data: (data) {
          _posts = data.posts;
          _currentStreak = data.streak;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_isDataInitialized) {
              setState(() {
                _isDataInitialized = true;
                if (_posts.isNotEmpty) {
                  _startAutoTimer();
                }
              });
            }
          });
          return const Scaffold(backgroundColor: AppColors.bgBase, body: Center(child: CircularProgressIndicator()));
        },
      );
    }

    final int currentPage = _pageController.hasClients ? _pageController.page?.round() ?? 0 : 0;
    final int totalPages = _posts.length + 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onVerticalDragUpdate: (details) {
            if (_snapBackController.isAnimating) return;
            setState(() {
              _dragOffset = (_dragOffset + details.delta.dy).clamp(0, 500);
            });
          },
          onVerticalDragEnd: (details) {
            if (_dragOffset > 150 || (details.primaryVelocity != null && details.primaryVelocity! > 1000)) {
              Navigator.pop(context);
            } else {
              _snapBackAnimation = _snapBackController.drive(
                Tween<double>(begin: _dragOffset, end: 0).chain(CurveTween(curve: Curves.easeOutBack)),
              );
              _snapBackController.forward(from: 0);
            }
          },
          child: Transform.translate(
            offset: Offset(0, _dragOffset),
            child: Transform.scale(
              scale: (1.0 - (_dragOffset / 2000)).clamp(0.85, 1.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_dragOffset > 10 ? 32 : 0),
                child: Container(
                  color: AppColors.bgBase,
                  child: Column(
                    children: [
                      // Progress bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: Row(
                          children: List.generate(totalPages, (i) {
                            final bool isPassed = i < currentPage;
                            final bool isCurrent = i == currentPage;

                            return Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                height: isCurrent ? 4 : 3,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  color: isCurrent
                                      ? AppColors.accentGold
                                      : (isPassed
                                          ? AppColors.white
                                          : AppColors.white.withValues(alpha: 0.2)),
                                  boxShadow: isCurrent
                                      ? [
                                          BoxShadow(
                                            color: AppColors.accentGold.withValues(alpha: 0.6),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                          )
                                        ]
                                      : null,
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      // Main Content
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: totalPages,
                          onPageChanged: (index) {
                            setState(() {});
                            if (index >= _posts.length) {
                              _autoTimer?.cancel();
                              HapticFeedback.mediumImpact();
                            } else {
                              _resetAutoTimer();
                            }
                          },
                          itemBuilder: (context, index) {
                            if (index < _posts.length) {
                              return _buildStoryView(_posts[index]);
                            } else {
                              return _buildSummaryView();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStoryView(Post post) {
    final weekdayStr = DateFormat('EEEE').format(post.createdAt).toUpperCase();
    return Stack(
      fit: StackFit.expand,
      children: [
        if (post.imageUrl != null)
          CachedNetworkImage(
            imageUrl: post.imageUrl!,
            fit: BoxFit.cover,
            placeholder: (ctx, url) => const Center(child: CircularProgressIndicator()),
            errorWidget: (ctx, url, err) => const Center(child: Icon(Icons.broken_image)),
          ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.bgBase.withValues(alpha: 0.8),
                Colors.transparent,
                Colors.transparent,
                AppColors.bgBase.withValues(alpha: 0.9),
              ],
              stops: const [0.0, 0.2, 0.7, 1.0],
            ),
          ),
        ),
        Positioned(
          top: 40,
          left: 20,
          right: 20,
          child: Text(
            weekdayStr,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              letterSpacing: 10,
              color: AppColors.white,
              shadows: [
                Shadow(color: Colors.black54, offset: Offset(0, 4), blurRadius: 12),
                Shadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          left: 24,
          right: 24,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.white.withValues(alpha: 0.15), width: 0.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.local_fire_department_rounded, color: AppColors.accentGold, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            post.taskName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(height: 1, width: 40, color: AppColors.accentGold.withValues(alpha: 0.4)),
                    const SizedBox(height: 12),
                    Text(
                      DateFormat('MMM dd').format(post.createdAt).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accentGold,
                        letterSpacing: 4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Tap zones
        Row(
          children: [
            Expanded(child: GestureDetector(onTap: _goPrev, behavior: HitTestBehavior.translucent, child: const SizedBox.expand())),
            Expanded(child: GestureDetector(onTap: _goNext, behavior: HitTestBehavior.translucent, child: const SizedBox.expand())),
          ],
        ),
        Positioned(
          top: 0,
          right: 8,
          child: IconButton(
            icon: const Icon(Icons.close, color: AppColors.white, size: 32),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryView() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: RepaintBoundary(
            key: _summaryKey,
            child: Container(
              width: MediaQuery.sizeOf(context).width,
              height: MediaQuery.sizeOf(context).height * 0.8,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.3), width: 2),
                boxShadow: [
                  BoxShadow(color: AppColors.accentGold.withValues(alpha: 0.1), blurRadius: 40, spreadRadius: 10),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -50,
                    right: -50,
                    child: Icon(Icons.workspace_premium, size: 200, color: AppColors.white.withValues(alpha: 0.05)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'WEEKLY\nREVIEW',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                            color: AppColors.white,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 48),
                        _buildStatCard('🔥 今週の完了数', '${_posts.length}', 'TASKS'),
                        const SizedBox(height: 16),
                        _buildStatCard('👑 現在のストリーク', '$_currentStreak', 'DAYS'),
                        const Spacer(),
                        const Text(
                          'Keep the winning streak alive.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accentGold,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '#VEffect',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textMuted,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Row(
          children: [
            Expanded(child: GestureDetector(onTap: _goPrev, behavior: HitTestBehavior.translucent, child: const SizedBox.expand())),
            Expanded(child: GestureDetector(onTap: () {}, behavior: HitTestBehavior.translucent, child: const SizedBox.expand())),
          ],
        ),
        Positioned(
          bottom: 32,
          left: 32,
          right: 32,
          child: ElevatedButton.icon(
            onPressed: _isSharing ? null : _shareSummary,
            icon: _isSharing 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bgBase))
                : const Icon(Icons.share, color: AppColors.bgBase),
            label: Text(_isSharing ? '準備中...' : 'SNSへシェア', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.bgBase)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentGold,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 8,
          child: IconButton(
            icon: const Icon(Icons.close, color: AppColors.white, size: 32),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, String unit) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.bgBase.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.white, height: 1.0)),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(unit, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accentGold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
