import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/push_notification_service.dart';
import '../utils/date_helper.dart';
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
  String? _mostSentToUid;
  String? _mostSentToName;
  int _mostSentToCount = 0;
  String? _mostReceivedFromUid;
  String? _mostReceivedFromName;
  int _mostReceivedFromCount = 0;
  int _mostActiveDayOfWeek = 0;
  int _mostActiveDayCount = 0;
  String? _goldenTimeRange;
  String? _buddyTaskName;
  int _buddyTaskCount = 0;

  bool _sentSentToThanks = false;
  bool _sentReceivedFromThanks = false;

  bool _isDataInitialized = false;

  final GlobalKey _summaryKey = GlobalKey();

  Future<void> _checkThanksStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final mondayStr = DateHelper.getMondayOfWeekString(DateTime.now());
    if (mounted) {
      setState(() {
        if (_mostSentToUid != null) {
          _sentSentToThanks = prefs.getBool('thanks_sent_to_${_mostSentToUid}_$mondayStr') ?? false;
        }
        if (_mostReceivedFromUid != null) {
          _sentReceivedFromThanks = prefs.getBool('thanks_sent_from_${_mostReceivedFromUid}_$mondayStr') ?? false;
        }
      });
    }
  }

  Future<void> _handleSendThanks({
    required String targetUid,
    required String targetName,
    required bool isMostSentTo,
    required int count,
  }) async {
    if (targetUid.isEmpty) return;

    final myUserSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser?.uid)
        .get();
    final myName = myUserSnap.data()?['displayName'] ?? myUserSnap.data()?['username'] ?? 'フレンド';

    await PushNotificationService.instance.sendWeeklyThanksNotification(
      toUid: targetUid,
      fromUsername: myName,
      isMostSentTo: isMostSentTo,
      count: count,
    );

    final prefs = await SharedPreferences.getInstance();
    final mondayStr = DateHelper.getMondayOfWeekString(DateTime.now());
    final key = isMostSentTo
        ? 'thanks_sent_to_${targetUid}_$mondayStr'
        : 'thanks_sent_from_${targetUid}_$mondayStr';
    await prefs.setBool(key, true);

    HapticFeedback.mediumImpact();

    if (mounted) {
      setState(() {
        if (isMostSentTo) {
          _sentSentToThanks = true;
        } else {
          _sentReceivedFromThanks = true;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.favorite_rounded, color: Colors.pinkAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$targetName さんへ感謝を届けました！💌',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.grey15,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

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
                _mostSentToUid = data.mostSentToUid;
                _mostSentToName = data.mostSentToName;
                _mostSentToCount = data.mostSentToCount;
                _mostReceivedFromUid = data.mostReceivedFromUid;
                _mostReceivedFromName = data.mostReceivedFromName;
                _mostReceivedFromCount = data.mostReceivedFromCount;
                _mostActiveDayOfWeek = data.mostActiveDayOfWeek;
                _mostActiveDayCount = data.mostActiveDayCount;
                _goldenTimeRange = data.goldenTimeRange;
                _buddyTaskName = data.buddyTaskName;
                _buddyTaskCount = data.buddyTaskCount;
                _aiAdvice = data.aiAdvice;
                _isDataInitialized = true;
              });
              _checkThanksStatus();
              _checkAiActionStatus();
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
    if (_mostSentToCount > 0 && _mostSentToName != null && _mostSentToUid != null) {
      highlights.add(
        _buildHighlightCard(
          icon: '🔥',
          message: localizations.weeklyReviewMostSentTo(_mostSentToName!, _mostSentToCount),
          color: Colors.orangeAccent.withValues(alpha: 0.15),
          borderColor: Colors.orangeAccent.withValues(alpha: 0.3),
          isActionable: true,
          isSent: _sentSentToThanks,
          actionHint: _sentSentToThanks ? '感謝送信済み 💌' : 'タップで感謝を送る 💌',
          onTap: _sentSentToThanks
              ? null
              : () => _handleSendThanks(
                    targetUid: _mostSentToUid!,
                    targetName: _mostSentToName!,
                    isMostSentTo: true,
                    count: _mostSentToCount,
                  ),
        ),
      );
    }

    // 2. 最もV FIREを受け取った相手 (被社交度)
    if (_mostReceivedFromCount > 0 && _mostReceivedFromName != null && _mostReceivedFromUid != null) {
      highlights.add(
        _buildHighlightCard(
          icon: '✨',
          message: localizations.weeklyReviewMostReceivedFrom(_mostReceivedFromName!, _mostReceivedFromCount),
          color: Colors.purpleAccent.withValues(alpha: 0.15),
          borderColor: Colors.purpleAccent.withValues(alpha: 0.3),
          isActionable: true,
          isSent: _sentReceivedFromThanks,
          actionHint: _sentReceivedFromThanks ? '感謝送信済み 💌' : 'タップで感謝を送る 💌',
          onTap: _sentReceivedFromThanks
              ? null
              : () => _handleSendThanks(
                    targetUid: _mostReceivedFromUid!,
                    targetName: _mostReceivedFromName!,
                    isMostSentTo: false,
                    count: _mostReceivedFromCount,
                  ),
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

    // 6. AIデータアナリティクス (3大ブラインドスポットPDCA)
    if (_aiAdvice != null) {
      highlights.add(
        _buildAiAdviceCard(_aiAdvice!),
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
    VoidCallback? onTap,
    bool isActionable = false,
    bool isSent = false,
    String? actionHint,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSent ? AppColors.grey50.withValues(alpha: 0.3) : borderColor,
            width: isActionable ? 1.8 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
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
            if (isActionable && actionHint != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSent
                      ? AppColors.grey50.withValues(alpha: 0.2)
                      : AppColors.accentGold.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSent
                        ? AppColors.grey50.withValues(alpha: 0.4)
                        : AppColors.accentGold,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSent ? Icons.check_circle_rounded : Icons.send_rounded,
                      size: 12,
                      color: isSent ? AppColors.grey50 : AppColors.accentGold,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      actionHint,
                      style: GoogleFonts.notoSansJp(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSent ? AppColors.grey50 : AppColors.accentGold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  WeeklyReviewAiAdvice? _aiAdvice;
  bool _isAiActionApplied = false;

  Future<void> _checkAiActionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final mondayStr = DateHelper.getMondayOfWeekString(DateTime.now());
    if (mounted) {
      setState(() {
        _isAiActionApplied = prefs.getBool('ai_action_applied_$mondayStr') ?? false;
      });
    }
  }

  Future<void> _handleApplyAiAction(WeeklyReviewAiAdvice advice) async {
    if (_isAiActionApplied) return;

    HapticFeedback.mediumImpact();

    final prefs = await SharedPreferences.getInstance();
    final mondayStr = DateHelper.getMondayOfWeekString(DateTime.now());
    await prefs.setBool('ai_action_applied_$mondayStr', true);

    if (mounted) {
      setState(() {
        _isAiActionApplied = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.bolt_rounded, color: AppColors.accentGold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '⚡️ 来週の目標時間を自動最適化しました！',
                  style: GoogleFonts.notoSansJp(fontWeight: FontWeight.bold, color: AppColors.white),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.black.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildAiAdviceCard(WeeklyReviewAiAdvice advice) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.cyanAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.cyanAccent.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🧠', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AIデータアナリティクス',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.cyanAccent,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      advice.headline,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // 比較数値バッジ
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.5)),
                ),
                child: Text(
                  advice.badgeText,
                  style: GoogleFonts.notoSansJp(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.cyanAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 3大インサイト箇条書きリスト
          ...advice.insights.map((insight) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(insight.icon, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          insight.title,
                          style: GoogleFonts.notoSansJp(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.cyanAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      insight.detail,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.white.withValues(alpha: 0.9),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 6),
          // 1タップ改善アクションボタン
          GestureDetector(
            onTap: () => _handleApplyAiAction(advice),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: _isAiActionApplied
                    ? AppColors.grey50.withValues(alpha: 0.2)
                    : Colors.cyanAccent.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isAiActionApplied
                      ? AppColors.grey50.withValues(alpha: 0.4)
                      : Colors.cyanAccent,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isAiActionApplied ? Icons.check_circle_rounded : Icons.bolt_rounded,
                    size: 16,
                    color: _isAiActionApplied ? AppColors.grey50 : Colors.cyanAccent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isAiActionApplied ? '✨ 設定を変更完了' : advice.actionLabel,
                    style: GoogleFonts.notoSansJp(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _isAiActionApplied ? AppColors.grey50 : Colors.cyanAccent,
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
