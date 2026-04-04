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


/// 今週の振り返りをストーリー形式で表示する画面
class WeeklyReviewScreen extends StatefulWidget {
  final List<Post> posts;
  final int currentStreak;

  const WeeklyReviewScreen({
    super.key,
    required this.posts,
    required this.currentStreak,
  });

  @override
  State<WeeklyReviewScreen> createState() => _WeeklyReviewScreenState();
}

class _WeeklyReviewScreenState extends State<WeeklyReviewScreen> {
  int _currentPostIndex = 0;
  bool _showSummary = false;
  Timer? _autoTimer;
  
  final GlobalKey _summaryKey = GlobalKey();
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    if (widget.posts.isNotEmpty) {
      _startAutoTimer();
    } else {
      _showSummary = true;
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
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
    if (_currentPostIndex < widget.posts.length - 1) {
      setState(() => _currentPostIndex++);
      _resetAutoTimer();
    } else {
      _autoTimer?.cancel();
      setState(() => _showSummary = true);
      HapticFeedback.mediumImpact(); // サマリー表示時にブルッとさせる
    }
  }

  void _goPrev() {
    if (_showSummary) {
      setState(() {
        _showSummary = false;
        _currentPostIndex = widget.posts.length - 1;
      });
      _resetAutoTimer();
    } else if (_currentPostIndex > 0) {
      setState(() => _currentPostIndex--);
      _resetAutoTimer();
    } else {
      // 最初の投稿で左タップしたら閉じる
      Navigator.pop(context);
    }
  }

  Future<void> _shareSummary() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    
    try {
      // RepaintBoundaryから画像を生成
      final boundary = _summaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      // 一時フォルダに保存
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/weekly_review.png';
      final file = File(path);
      await file.writeAsBytes(pngBytes);

      // share_plusでシェア
      await Share.shareXFiles(
        [XFile(path)],
        text: '今週も${widget.posts.length}回のヒーロータスクを完遂！\n現在のストリーク: ${widget.currentStreak}日 🔥\n#VEffect',
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
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            // ── Progress bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: List.generate(widget.posts.length + 1, (i) {
                  // 最後の一つはサマリー画面用
                  final bool isPassed = _showSummary
                      ? true
                      : (i <= _currentPostIndex);

                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      height: 3,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: isPassed
                            ? AppColors.textPrimary
                            : AppColors.textPrimary.withValues(alpha: 0.24),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // ── Main Content ──
            Expanded(
              child: _showSummary ? _buildSummaryView() : _buildStoryView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryView() {
    if (widget.posts.isEmpty) return const SizedBox.shrink();
    
    final post = widget.posts[_currentPostIndex];
    final weekdayStr = DateFormat('EEEE').format(post.createdAt).toUpperCase();

    return Stack(
      fit: StackFit.expand,
      children: [
        // Photo Background
        if (post.imageUrl != null)
          CachedNetworkImage(
            imageUrl: post.imageUrl!,
            fit: BoxFit.cover,
            placeholder: (ctx, url) => const Center(child: CircularProgressIndicator()),
            errorWidget: (ctx, url, err) => const Center(child: Icon(Icons.broken_image)),
          ),

        // グラデーションオーバーレイ（下部と上部）
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

        // 曜日タイポグラフィ
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
              letterSpacing: 8,
              color: AppColors.white,
            ),
          ),
        ),

        // タスク名と日付
        Positioned(
          bottom: 40,
          left: 24,
          right: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                post.taskName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accentGold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('MM/dd').format(post.createdAt),
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),

        // Tap zones
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _goPrev,
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand(),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: _goNext,
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),

        // 閉じるボタン
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
        // サマリー用の背景（シェア時にキャプチャされる部分）
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
                  // 背景の装飾
                  Positioned(
                    top: -50,
                    right: -50,
                    child: Icon(Icons.workspace_premium, size: 200, color: AppColors.white.withValues(alpha: 0.05)),
                  ),
                  
                  // メインコンテンツ
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
                        
                        // 実績データ
                        _buildStatCard('🔥 今週の完了数', '${widget.posts.length}', 'TASKS'),
                        const SizedBox(height: 16),
                        _buildStatCard('👑 現在のストリーク', '${widget.currentStreak}', 'DAYS'),
                        
                        const Spacer(),
                        
                        // アピールテキスト
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

        // Tap zones (to go back only)
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _goPrev,
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand(),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {}, // 最後のページでは右タップは無効（閉じるボタンかシェアボタンを押させる）
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),

        // ボタン類（UIの一部。シェア時にはキャプチャされないように外に置く）
        Positioned(
          bottom: 32,
          left: 32,
          right: 32,
          child: ElevatedButton.icon(
            onPressed: _isSharing ? null : _shareSummary,
            icon: _isSharing 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bgBase))
                : const Icon(Icons.share, color: AppColors.bgBase),
            label: Text(
              _isSharing ? '準備中...' : 'SNSへシェア',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.bgBase),
            ),
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
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppColors.white,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentGold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
