import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../config/app_colors.dart';
import '../models/post.dart';
import '../providers/weekly_review_provider.dart';
import 'share_preview_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import '../widgets/branded_loading.dart';

/// 今週の振り返りをVウォール形式で表示する画面
class WeeklyReviewScreen extends ConsumerStatefulWidget {
  const WeeklyReviewScreen({super.key});

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

  // 新しく追加されたパーソナライズ統計
  String? _mostSentToName;
  int _mostSentToCount = 0;
  String? _mostReceivedFromName;
  int _mostReceivedFromCount = 0;
  int _mostActiveDayOfWeek = 0;
  int _mostActiveDayCount = 0;
  String? _goldenTimeRange;
  String? _buddyTaskName;
  int _buddyTaskCount = 0;

  bool _isDataInitialized = false;

  final GlobalKey _summaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
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

  void _showShareImageSelection() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.weeklyReviewSelectBackground,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.white),
                ),
                const SizedBox(height: 16),
                if (_imagePosts.isEmpty)
                  Container(
                    height: 100,
                    alignment: Alignment.center,
                    child: Text(AppLocalizations.of(context)!.weeklyReviewNoPostsDefault, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
                  )
                else
                  SizedBox(
                    height: 140, // 横スクロールの高さ
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _imagePosts.length,
                      itemBuilder: (context, index) {
                        final post = _imagePosts[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(context); // ボトムシートを閉じる
                            _navigateToPreview(post.imageUrl);
                          },
                          child: Container(
                            width: 100,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: CachedNetworkImageProvider(post.imageUrl!),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _navigateToPreview(null);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.white,
                      side: BorderSide(color: AppColors.white.withValues(alpha: 0.2)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(AppLocalizations.of(context)!.weeklyReviewShareWithoutBackground),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateToPreview(String? imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SharePreviewScreen(
          imageUrl: imageUrl,
          postsCount: _posts.length,
          currentStreak: _currentStreak,
          totalVFire: _totalVFire,
          totalReactions: _totalReactions,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDataInitialized) {
      final reviewAsync = ref.watch(weeklyReviewProvider);
      return reviewAsync.when(
        loading: () => const BrandedFullPageLoading(),
        error: (err, stack) => Scaffold(
          backgroundColor: AppColors.bgBase,
          body: Center(child: Text(AppLocalizations.of(context)!.weeklyReviewLoadError(err), style: TextStyle(color: AppColors.white))),
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
                _mostSentToName = data.mostSentToName;
                _mostSentToCount = data.mostSentToCount;
                _mostReceivedFromName = data.mostReceivedFromName;
                _mostReceivedFromCount = data.mostReceivedFromCount;
                _mostActiveDayOfWeek = data.mostActiveDayOfWeek;
                _mostActiveDayCount = data.mostActiveDayCount;
                _goldenTimeRange = data.goldenTimeRange;
                _buddyTaskName = data.buddyTaskName;
                _buddyTaskCount = data.buddyTaskCount;
                _isDataInitialized = true;
              });
              _precacheImages();
            }
          });
          return const BrandedFullPageLoading();
        },
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: AppColors.white, size: 28),
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
                          _buildHighlightSection(),
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
                onPressed: _showShareImageSelection,
                icon: Icon(Icons.share, color: AppColors.bgBase),
                label: Text(AppLocalizations.of(context)!.weeklyReviewShareToSns, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.bgBase)),
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
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStatRow(AppLocalizations.of(context)!.weeklyReviewStatTasks, '${_posts.length}'),
          Divider(color: AppColors.white.withValues(alpha: 0.1), height: 1, indent: 16),
          _buildStatRow(AppLocalizations.of(context)!.weeklyReviewStatStreak, '$_currentStreak'),
          Divider(color: AppColors.white.withValues(alpha: 0.1), height: 1, indent: 16),
          _buildStatRow(AppLocalizations.of(context)!.weeklyReviewStatVFire, '$_totalVFire'),
          Divider(color: AppColors.white.withValues(alpha: 0.1), height: 1, indent: 16),
          _buildStatRow(AppLocalizations.of(context)!.weeklyReviewStatReactions, '$_totalReactions'),
        ],
      ),
    );
  }

  Widget _buildVWallGrid() {
    if (_imagePosts.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Text(AppLocalizations.of(context)!.weeklyReviewNoPosts, style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                    errorWidget: (context, url, error) => Container(color: AppColors.grey10, child: Icon(Icons.broken_image, color: AppColors.white)),
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

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightSection() {
    final localizations = AppLocalizations.of(context)!;
    final highlights = <Widget>[];

    // 1. 最もV FIREを送った相手 (社交度)
    if (_mostSentToCount > 0 && _mostSentToName != null) {
      highlights.add(
        _buildHighlightCard(
          icon: '🔥',
          message: localizations.weeklyReviewMostSentTo(_mostSentToName!, _mostSentToCount),
          color: Colors.orangeAccent.withValues(alpha: 0.15),
          borderColor: Colors.orangeAccent.withValues(alpha: 0.3),
        ),
      );
    }

    // 2. 最もV FIREを受け取った相手 (被社交度)
    if (_mostReceivedFromCount > 0 && _mostReceivedFromName != null) {
      highlights.add(
        _buildHighlightCard(
          icon: '✨',
          message: localizations.weeklyReviewMostReceivedFrom(_mostReceivedFromName!, _mostReceivedFromCount),
          color: Colors.purpleAccent.withValues(alpha: 0.15),
          borderColor: Colors.purpleAccent.withValues(alpha: 0.3),
        ),
      );
    }

    // 3. 最もモチベーションの高かった曜日 (活動パターン)
    if (_mostActiveDayCount > 0 && _mostActiveDayOfWeek > 0) {
      final dayStr = _getWeekdayName(_mostActiveDayOfWeek);
      highlights.add(
        _buildHighlightCard(
          icon: '📅',
          message: localizations.weeklyReviewMostActiveDay(dayStr, _mostActiveDayCount),
          color: Colors.blueAccent.withValues(alpha: 0.15),
          borderColor: Colors.blueAccent.withValues(alpha: 0.3),
        ),
      );
    }

    // 4. 集中ゴールデンタイム (時間分析)
    if (_goldenTimeRange != null) {
      final rangeStr = _getTimeRangeName(_goldenTimeRange!);
      highlights.add(
        _buildHighlightCard(
          icon: '⚡️',
          message: localizations.weeklyReviewGoldenTime(rangeStr),
          color: Colors.amber.withValues(alpha: 0.15),
          borderColor: Colors.amber.withValues(alpha: 0.3),
        ),
      );
    }

    // 5. 今週の相棒タスク (習慣)
    if (_buddyTaskCount > 0 && _buddyTaskName != null) {
      highlights.add(
        _buildHighlightCard(
          icon: '🤝',
          message: localizations.weeklyReviewBuddyTask(_buddyTaskName!, _buddyTaskCount),
          color: Colors.greenAccent.withValues(alpha: 0.15),
          borderColor: Colors.greenAccent.withValues(alpha: 0.3),
        ),
      );
    }

    if (highlights.isEmpty) {
      highlights.add(
        _buildHighlightCard(
          icon: '💪',
          message: localizations.weeklyReviewNoInteractions,
          color: AppColors.white.withValues(alpha: 0.05),
          borderColor: AppColors.white.withValues(alpha: 0.1),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            localizations.weeklyReviewTitle,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.white,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...highlights.map((h) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: h,
            )),
      ],
    );
  }

  Widget _buildHighlightCard({
    required String icon,
    required String message,
    required Color color,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            icon,
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.white,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getWeekdayName(int weekday) {
    final localizations = AppLocalizations.of(context)!;
    switch (weekday) {
      case 1:
        return localizations.weekdayMonday;
      case 2:
        return localizations.weekdayTuesday;
      case 3:
        return localizations.weekdayWednesday;
      case 4:
        return localizations.weekdayThursday;
      case 5:
        return localizations.weekdayFriday;
      case 6:
        return localizations.weekdaySaturday;
      case 7:
        return localizations.weekdaySunday;
      default:
        return '';
    }
  }

  String _getTimeRangeName(String range) {
    final localizations = AppLocalizations.of(context)!;
    switch (range) {
      case 'morning':
        return localizations.timeRangeMorning;
      case 'afternoon':
        return localizations.timeRangeAfternoon;
      case 'evening':
        return localizations.timeRangeEvening;
      case 'lateNight':
        return localizations.timeRangeLateNight;
      default:
        return '';
    }
  }
}
