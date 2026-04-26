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
import 'package:google_fonts/google_fonts.dart';
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
  List<Post> _imagePosts = [];
  int _currentStreak = 0;
  bool _isDataInitialized = false;
  int _selectedImageIndex = 0;

  late PageController _pageController;
  Timer? _autoTimer;
  final GlobalKey _summaryKey = GlobalKey();
  bool _isSharing = false;
  bool _isAnimating = false;

  // ひっぱり（Pull-to-dismiss）用の状態
  double _dragOffset = 0;
  late AnimationController _snapBackController;
  late Animation<double> _snapBackAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.posts != null && widget.currentStreak != null) {
      _posts = widget.posts!;
      _imagePosts = _posts.where((p) => p.imageUrl != null).toList();
      _currentStreak = widget.currentStreak!;
      _isDataInitialized = true;
      // 既にデータがある場合は即座に先読みを開始
      WidgetsBinding.instance.addPostFrameCallback((_) => _precacheImages());
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

  void _precacheImages() {
    if (!mounted || _posts.isEmpty) return;
    for (final post in _posts) {
      if (post.imageUrl != null) {
        precacheImage(
          CachedNetworkImageProvider(post.imageUrl!),
          context,
        );
      }
    }
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
      final totalPages = _posts.length + 1;
      final int current = _pageController.page?.round() ?? 0;
      final int next = current + 1;
      
      if (next < totalPages) {
        _pageController.jumpToPage(next);
      } else {
        _autoTimer?.cancel();
      }
    }
  }

  void _goPrev() {
    if (_pageController.hasClients) {
      final int current = _pageController.page?.round() ?? 0;
      final int prev = current - 1;
      
      if (prev >= 0) {
        _pageController.jumpToPage(prev);
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

      // Strava-style images are vertically long, so ensure we capture enough quality
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/v_effect_review_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(path);
      await file.writeAsBytes(pngBytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          text: '今週も${_posts.length}回のヒーロータスクを完遂！\n現在のストリーク: $_currentStreak日 🔥\n#VEffect',
        ),
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
          body: Center(child: Text('読み込みエラー: $err', style: const TextStyle(color: AppColors.white))),
        ),
        data: (data) {
          _posts = data.posts;
          _imagePosts = _posts.where((p) => p.imageUrl != null).toList();
          _currentStreak = data.streak;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_isDataInitialized) {
              _precacheImages(); // 全画像をバックグラウンドで先読み
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
      backgroundColor: AppColors.black,
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
                              child: GestureDetector(
                                onTap: () {
                                  _pageController.animateToPage(
                                    i,
                                    duration: const Duration(milliseconds: 400),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                child: Container(
                                  // Add vertical padding to increase hit target
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  color: Colors.transparent, 
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
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      // Main Content
                      Expanded(
                        child: Stack(
                          children: [
                            PageView.builder(
                              controller: _pageController,
                              itemCount: totalPages,
                              onPageChanged: (index) {
                                setState(() {
                                  _isAnimating = false; // Reset just in case
                                });
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
                            // Fixed Tap Zones (Only for Story Pages)
                            if (currentPage < _posts.length)
                              Row(
                                children: [
                                  // Left 30%: Prev
                                  Expanded(
                                    flex: 3,
                                    child: GestureDetector(
                                      onTap: _goPrev, 
                                      behavior: HitTestBehavior.translucent, 
                                      child: const SizedBox.expand(),
                                    ),
                                  ),
                                  // Right 70%: Next
                                  Expanded(
                                    flex: 7,
                                    child: GestureDetector(
                                      onTap: _goNext,
                                      behavior: HitTestBehavior.translucent, 
                                      child: const SizedBox.expand(),
                                    ),
                                  ),
                                ],
                              ),
                            // Global Close Button
                            Positioned(
                              top: 0,
                              right: 8,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: AppColors.white, size: 32),
                                onPressed: () => Navigator.pop(context),
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
            memCacheWidth: 1000, // メモリ負荷軽減と読み込み高速化
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
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: 10,
              color: AppColors.white,
              shadows: [
                Shadow(color: AppColors.black.withValues(alpha: 0.54), offset: Offset(0, 4), blurRadius: 12),
                Shadow(color: AppColors.black.withValues(alpha: 0.26), offset: Offset(0, 2), blurRadius: 4),
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
                  color: AppColors.black.withValues(alpha: 0.4),
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
      ],
    );
  }

  Widget _buildSummaryView() {
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Center(
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        child: RepaintBoundary(
                          key: _summaryKey,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Background Image or Gradient
                                if (_imagePosts.isNotEmpty && _selectedImageIndex < _imagePosts.length)
                                  CachedNetworkImage(
                                    imageUrl: _imagePosts[_selectedImageIndex].imageUrl!,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 800,
                                    placeholder: (ctx, url) => Container(color: AppColors.grey10),
                                  )
                                else
                                  Container(
                                    decoration: const BoxDecoration(
                                      gradient: AppColors.cardGradient,
                                    ),
                                  ),
                                
                                // Scrim/Overlay for readability
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        AppColors.black.withValues(alpha: 0.6),
                                        Colors.transparent,
                                        Colors.transparent,
                                        AppColors.black.withValues(alpha: 0.7),
                                      ],
                                      stops: const [0.0, 0.3, 0.6, 1.0],
                                    ),
                                  ),
                                ),

                                // Content
                                Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Logo centered horizontally
                                      Center(child: _buildLogo()),
                                      const Spacer(),
                                      // Stats (Normalized Data Fields)
                                      Row(
                                        children: [
                                          _buildStravaStat('WEEKLY COMPLETED', '${_posts.length}', 'TASKS'),
                                          const SizedBox(width: 32),
                                          _buildStravaStat('CURRENT STREAK', '$_currentStreak', 'DAYS'),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Controls Area (Not captured in share)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_imagePosts.length > 1) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          '背景カードを選ぶ',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 60,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _imagePosts.length,
                        itemBuilder: (context, index) {
                          final isSelected = _selectedImageIndex == index;
                          return GestureDetector(
                            onTap: () {
                              setState(() => _selectedImageIndex = index);
                              HapticFeedback.lightImpact();
                            },
                            child: Container(
                              width: 60,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? AppColors.accentGold : Colors.transparent,
                                  width: 2,
                                ),
                                image: DecorationImage(
                                  image: CachedNetworkImageProvider(_imagePosts[index].imageUrl!),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  ElevatedButton.icon(
                    onPressed: _isSharing ? null : _shareSummary,
                    icon: _isSharing 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bgBase))
                        : const Icon(Icons.share, color: AppColors.bgBase),
                    label: Text(_isSharing ? '準備中...' : 'SNSへシェア', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.bgBase)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentGold,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLogo() {
    return Text(
      'V EFFECT',
      style: GoogleFonts.outfit(
        color: AppColors.white,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: 4.0,
        shadows: [
          Shadow(offset: Offset(0, 2), blurRadius: 10, color: AppColors.black.withValues(alpha: 0.54)),
        ],
      ),
    );
  }

  Widget _buildStravaStat(String label, String value, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            color: AppColors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            shadows: const [Shadow(blurRadius: 4, color: AppColors.black)],
          ),
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: AppColors.white,
                height: 1.1,
                shadows: [Shadow(blurRadius: 12, color: AppColors.black.withValues(alpha: 0.54))],
              ),
            ),
            const SizedBox(width: 4),
            Text(
              unit,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.white,
                shadows: const [Shadow(blurRadius: 4, color: AppColors.black)],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
