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

/// 今週の振り返りをVウォール形式で表示する画面
class WeeklyReviewScreen extends ConsumerStatefulWidget {
  final List<Post>? posts;
  final int? currentStreak;
  final int? totalVFire;
  final int? totalReactions;

  const WeeklyReviewScreen({
    super.key,
    this.posts,
    this.currentStreak,
    this.totalVFire,
    this.totalReactions,
  });

  @override
  ConsumerState<WeeklyReviewScreen> createState() => _WeeklyReviewScreenState();
}

class _WeeklyReviewScreenState extends ConsumerState<WeeklyReviewScreen> {
  // 表示用データ
  List<Post> _posts = [];
  List<Post> _imagePosts = [];
  int _currentStreak = 0;
  int _totalVFire = 0;
  int _totalReactions = 0;
  bool _isDataInitialized = false;

  final GlobalKey _summaryKey = GlobalKey();
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    if (widget.posts != null && widget.currentStreak != null && widget.totalVFire != null && widget.totalReactions != null) {
      _posts = widget.posts!;
      _imagePosts = _posts.where((p) => p.imageUrl != null).toList();
      _currentStreak = widget.currentStreak!;
      _totalVFire = widget.totalVFire!;
      _totalReactions = widget.totalReactions!;
      _isDataInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _precacheImages());
    }
  }

  void _precacheImages() {
    if (!mounted || _imagePosts.isEmpty) return;
    for (final post in _imagePosts) {
      precacheImage(
        CachedNetworkImageProvider(post.imageUrl!),
        context,
      );
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
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_isDataInitialized) {
              setState(() {
                _posts = data.posts;
                _imagePosts = _posts.where((p) => p.imageUrl != null).toList();
                _currentStreak = data.streak;
                _totalVFire = data.totalVFire;
                _totalReactions = data.totalReactions;
                _isDataInitialized = true;
              });
              _precacheImages();
            }
          });
          return const Scaffold(backgroundColor: AppColors.bgBase, body: Center(child: CircularProgressIndicator()));
        },
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: _buildLogo(),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: RepaintBoundary(
                    key: _summaryKey,
                    child: Container(
                      color: AppColors.bgBase,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSummaryCard(),
                          const SizedBox(height: 24),
                          _buildVWallGrid(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // コントロールエリア（シェアボタン等）
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              color: AppColors.bgBase,
              child: ElevatedButton.icon(
                onPressed: _isSharing ? null : _shareSummary,
                icon: _isSharing 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bgBase))
                    : const Icon(Icons.share, color: AppColors.bgBase),
                label: Text(_isSharing ? '準備中...' : 'VウォールをSNSへシェア', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.bgBase)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGold,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _buildStravaStat('WEEKLY COMPLETED', '${_posts.length}', 'TASKS')),
              Expanded(child: _buildStravaStat('CURRENT STREAK', '$_currentStreak', 'DAYS')),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildStravaStat('TOTAL VFIRE', '$_totalVFire', '🔥')),
              Expanded(child: _buildStravaStat('TOTAL REACTIONS', '$_totalReactions', '💬')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVWallGrid() {
    if (_imagePosts.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const Text('今週の投稿はまだありません', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'VICTORY WALL',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
              color: AppColors.white,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 9 / 16, // BeReal風の縦長比率
          ),
          itemCount: _imagePosts.length,
          itemBuilder: (context, index) {
            final post = _imagePosts[index];
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: post.imageUrl!,
                    fit: BoxFit.cover,
                    memCacheWidth: 400,
                    placeholder: (context, url) => Container(color: AppColors.grey10),
                    errorWidget: (context, url, error) => Container(color: AppColors.grey10, child: const Icon(Icons.broken_image, color: AppColors.white)),
                  ),
                  // 日付ラベル
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [AppColors.black.withValues(alpha: 0.8), Colors.transparent],
                        ),
                      ),
                      child: Text(
                        DateFormat('E').format(post.createdAt).toUpperCase(), // 例: MON
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
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
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
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
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: AppColors.white,
                height: 1.1,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              unit,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.accentGold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
