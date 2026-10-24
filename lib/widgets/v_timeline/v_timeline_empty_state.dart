import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../config/routes.dart';
import '../../models/app_user.dart';
import '../../providers/ranking_provider.dart';

/// 全体タイムライン（Vタイムライン）が0件のときに表示するエンプティステート画面
///
/// 【目的】
/// 1. 過疎感を払拭し、「熱いコミュニティが存在する」ことを伝える（ストリーク/トータルVランキング）
/// 2. ユーザー自身が最初の投稿者（火種）になるよう促す（カメラ直結ボタン）
class VTimelineEmptyState extends ConsumerStatefulWidget {
  final Future<void> Function() onRefresh;

  const VTimelineEmptyState({
    super.key,
    required this.onRefresh,
  });

  @override
  ConsumerState<VTimelineEmptyState> createState() => _VTimelineEmptyStateState();
}

class _VTimelineEmptyStateState extends ConsumerState<VTimelineEmptyState> {
  // 0: ストリークランキング, 1: トータルVランキング
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final streakRankingAsync = ref.watch(streakRankingProvider);
    final totalVRankingAsync = ref.watch(totalVRankingProvider);
    final myStatsAsync = ref.watch(myRankingStatsProvider);

    return RefreshIndicator(
      color: AppColors.accentGold,
      backgroundColor: AppColors.grey10,
      onRefresh: () async {
        // ランキングのキャッシュを破棄して再フェッチ
        ref.invalidate(streakRankingProvider);
        ref.invalidate(totalVRankingProvider);
        ref.invalidate(myRankingStatsProvider);
        await widget.onRefresh();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            // 上部ヘッダー（VEffectHeader）との重なりを回避するための余白
            const SizedBox(height: 100),

            // ── 1. ヒーローセクション（火種・投稿CTA） ──
            _buildHeroCallToAction(context),

            const SizedBox(height: 36),

            // ── 2. セクション区切り＆ランキングヘッダー ──
            _buildLeaderboardHeader(),

            const SizedBox(height: 16),

            // ── 3. 切り替えタブ（ストリーク / トータルV） ──
            _buildSegmentedTab(),

            const SizedBox(height: 20),

            // ── 4. ランキングリスト ──
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _selectedTabIndex == 0
                  ? _buildRankingList(
                      key: const ValueKey('streak_list'),
                      rankingAsync: streakRankingAsync,
                      isStreak: true,
                    )
                  : _buildRankingList(
                      key: const ValueKey('total_v_list'),
                      rankingAsync: totalVRankingAsync,
                      isStreak: false,
                    ),
            ),

            const SizedBox(height: 24),

            // ── 5. あなたの現在地（My Status） ──
            _buildMyStatusCard(myStatsAsync),

            // ボトムナビゲーションバーと被らないための余白
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  /// ヒーローセクション（「まだ誰も火をつけていません」＋カメラ起動ボタン）
  Widget _buildHeroCallToAction(BuildContext context) {
    final isDark = AppColors.isDark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.grey08 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.grey15 : AppColors.grey20,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // 燃える炎アイコン
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF6D00).withValues(alpha: 0.15),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6D00).withValues(alpha: 0.25),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: Color(0xFFFF9100),
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'まだ誰も火をつけていません',
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSansJp(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.pureWhite : AppColors.pureBlack,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'あなたが今日の最初の1人になって\nタイムラインに火を灯そう！🔥',
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSansJp(
              fontSize: 13,
              color: isDark ? AppColors.grey50 : AppColors.grey70,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          // カメラ起動（投稿）ボタン
          InkWell(
            onTap: () => Navigator.pushNamed(context, AppRoutes.camera),
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFFB300), // ゴールド
                    Color(0xFFFF8F00), // アンバー
                  ],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF9100).withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.camera_alt_rounded,
                    color: AppColors.pureBlack,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '今日の努力を記録する',
                    style: GoogleFonts.notoSansJp(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.pureBlack,
                      letterSpacing: 0.5,
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

  /// ランキングセクションの見出し
  Widget _buildLeaderboardHeader() {
    final isDark = AppColors.isDark;

    return Row(
      children: [
        const Icon(
          Icons.emoji_events_rounded,
          color: Color(0xFFFFD700),
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          'ランキング',
          style: GoogleFonts.notoSansJp(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.pureWhite : AppColors.pureBlack,
            letterSpacing: 0.5,
          ),
        ),
        const Spacer(),
        Text(
          'TOP 5',
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.grey50 : AppColors.grey70,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  /// 切り替えタブ（ストリーク vs トータルV）
  Widget _buildSegmentedTab() {
    final isDark = AppColors.isDark;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.grey10 : const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.grey15 : AppColors.grey20,
        ),
      ),
      child: Row(
        children: [
          // ストリークタブ
          Expanded(
            child: _buildTabButton(
              title: '🔥 ストリーク',
              subtitle: '連続達成日数',
              isSelected: _selectedTabIndex == 0,
              activeColor: const Color(0xFFFF6D00),
              onTap: () => setState(() => _selectedTabIndex = 0),
            ),
          ),
          const SizedBox(width: 4),
          // トータルVタブ
          Expanded(
            child: _buildTabButton(
              title: '🏆 トータルV',
              subtitle: '累計達成回数',
              isSelected: _selectedTabIndex == 1,
              activeColor: const Color(0xFFFFD700),
              onTap: () => setState(() => _selectedTabIndex = 1),
            ),
          ),
        ],
      ),
    );
  }

  /// 各タブボタン
  Widget _buildTabButton({
    required String title,
    required String subtitle,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    final isDark = AppColors.isDark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.grey15 : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: activeColor.withValues(alpha: 0.6), width: 1)
              : null,
          boxShadow: (isSelected && !isDark)
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Text(
              title,
              style: GoogleFonts.notoSansJp(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? AppColors.pureWhite : AppColors.pureBlack)
                    : (isDark ? AppColors.grey50 : AppColors.grey70),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.notoSansJp(
                fontSize: 10,
                color: isSelected
                    ? (isDark ? AppColors.grey70 : AppColors.grey70)
                    : (isDark ? AppColors.grey30 : AppColors.grey50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ランキングリスト（1〜5位のカード一覧）
  Widget _buildRankingList({
    required Key key,
    required AsyncValue<List<RankingUser>> rankingAsync,
    required bool isStreak,
  }) {
    final isDark = AppColors.isDark;

    return KeyedSubtree(
      key: key,
      child: rankingAsync.when(
        loading: () => Container(
          height: 240,
          alignment: Alignment.center,
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppColors.grey50),
            ),
          ),
        ),
      error: (e, _) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        alignment: Alignment.center,
        child: Text(
          'ランキングの取得に失敗しました',
          style: GoogleFonts.notoSansJp(
            color: isDark ? AppColors.grey50 : AppColors.grey70,
            fontSize: 13,
          ),
        ),
      ),
      data: (users) {
        if (users.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.grey08 : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.grey15 : AppColors.grey20,
              ),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFFFFD700),
                  size: 28,
                ),
                const SizedBox(height: 10),
                Text(
                  'まだランカーがいません',
                  style: GoogleFonts.notoSansJp(
                    color: isDark ? AppColors.pureWhite : AppColors.pureBlack,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '毎日投稿を続けて、最初の1位を目指そう！',
                  style: GoogleFonts.notoSansJp(
                    color: isDark ? AppColors.grey50 : AppColors.grey70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.grey08 : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.grey15 : AppColors.grey20,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: users.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: isDark ? AppColors.grey15 : const Color(0xFFEEEEEE),
              indent: 16,
              endIndent: 16,
            ),
            itemBuilder: (context, index) {
              final rank = index + 1;
              final user = users[index];
              return _buildRankingRow(
                context: context,
                rank: rank,
                user: user,
                isStreak: isStreak,
              );
            },
          ),
        );
      },
    ),
  );
}

  /// ランキングの1行
  Widget _buildRankingRow({
    required BuildContext context,
    required int rank,
    required RankingUser user,
    required bool isStreak,
  }) {
    final isDark = AppColors.isDark;

    // 順位メダルのデザイン設定
    Color badgeColor;
    IconData? medalIcon;

    if (rank == 1) {
      badgeColor = const Color(0xFFFFD700); // 🥇 ゴールド
      medalIcon = Icons.military_tech_rounded;
    } else if (rank == 2) {
      badgeColor = isDark ? const Color(0xFFC0C0C0) : const Color(0xFF9E9E9E); // 🥈 シルバー
      medalIcon = Icons.military_tech_rounded;
    } else if (rank == 3) {
      badgeColor = const Color(0xFFCD7F32); // 🥉 ブロンズ
      medalIcon = Icons.military_tech_rounded;
    } else {
      badgeColor = isDark ? AppColors.grey50 : AppColors.grey70;
      medalIcon = null;
    }

    return InkWell(
      onTap: () {
        // 相手のプロフィールへ遷移
        Navigator.pushNamed(
          context,
          AppRoutes.userProfile,
          arguments: user.uid,
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 順位バッジ
            SizedBox(
              width: 32,
              child: medalIcon != null
                  ? Icon(medalIcon, color: badgeColor, size: 24)
                  : Text(
                      '#$rank',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: badgeColor,
                      ),
                    ),
            ),
            const SizedBox(width: 8),

            // アバター画像
            CircleAvatar(
              radius: 18,
              backgroundColor: isDark ? AppColors.grey20 : const Color(0xFFE5E7EB),
              backgroundImage: user.photoUrl != null && user.photoUrl!.isNotEmpty
                  ? NetworkImage(user.photoUrl!)
                  : null,
              child: user.photoUrl == null || user.photoUrl!.isEmpty
                  ? Text(
                      user.username.isNotEmpty ? user.username[0] : '?',
                      style: GoogleFonts.notoSansJp(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.pureWhite : AppColors.pureBlack,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),

            // ユーザー名（シンプルに1行表示）
            Expanded(
              child: Text(
                user.username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.notoSansJp(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.pureWhite : AppColors.pureBlack,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // スコア表示（ストリーク or トータルV）
            if (isStreak)
              _buildStreakBadge(user)
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFFFFD700).withValues(alpha: 0.12)
                      : const Color(0xFFFFD700).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFFFFD700).withValues(alpha: 0.3)
                        : const Color(0xFFFFB300).withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.emoji_events_rounded,
                      color: isDark ? const Color(0xFFFFD700) : const Color(0xFFD97706),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${user.totalPosts}回',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.pureWhite : const Color(0xFF9A6B00),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// ストリークバッジ（現在ストリーク＋最高ストリーク併記）
  Widget _buildStreakBadge(RankingUser user) {
    final isDark = AppColors.isDark;
    final bool hasPastBest = user.maxStreak > user.streak;
    final bool isBestRecord = user.maxStreak <= user.streak && user.streak > 1;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10,
        vertical: (hasPastBest || isBestRecord) ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFFFF6D00).withValues(alpha: 0.12)
            : const Color(0xFFFF6D00).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular((hasPastBest || isBestRecord) ? 10 : 20),
        border: Border.all(
          color: isDark
              ? const Color(0xFFFF6D00).withValues(alpha: 0.3)
              : const Color(0xFFFF6D00).withValues(alpha: 0.45),
          width: 0.8,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                color: Color(0xFFFF9100),
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                '${user.streak}日',
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.pureWhite : const Color(0xFFD84315),
                ),
              ),
            ],
          ),
          if (hasPastBest) ...[
            const SizedBox(height: 1),
            Text(
              'BEST ${user.maxStreak}日',
              style: GoogleFonts.montserrat(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFFFB300) : const Color(0xFFE65100),
                letterSpacing: 0.3,
              ),
            ),
          ] else if (isBestRecord) ...[
            const SizedBox(height: 1),
            Text(
              'RECORD ✨',
              style: GoogleFonts.montserrat(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                color: isDark ? const Color(0xFFFFD700) : const Color(0xFFE65100),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// あなたの現在地（My Status）カード
  Widget _buildMyStatusCard(AsyncValue<dynamic> myStatsAsync) {
    final isDark = AppColors.isDark;

    return myStatsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (user) {
        if (user == null) return const SizedBox.shrink();

        final streak = user.streak ?? 0;
        final maxStreak = (user is AppUser) ? user.maxStreak : (user.maxStreak ?? streak);
        final totalPosts = user.totalPosts ?? 0;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          decoration: BoxDecoration(
            color: isDark ? AppColors.grey10 : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.accentGold.withValues(alpha: isDark ? 0.3 : 0.4),
              width: 1,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: AppColors.accentGold.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentGold.withValues(alpha: isDark ? 0.15 : 0.12),
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: isDark ? AppColors.accentGold : const Color(0xFFB8860B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'あなたの現在の記録',
                      style: GoogleFonts.notoSansJp(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.grey50 : AppColors.grey70,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '🔥 $streak日連続',
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.pureWhite : AppColors.pureBlack,
                              ),
                            ),
                            if (maxStreak > streak) ...[
                              const SizedBox(width: 6),
                              Text(
                                '(最高 $maxStreak日)',
                                style: GoogleFonts.notoSansJp(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFFFFB300) : const Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '🏆 トータルV $totalPosts回',
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.grey70 : AppColors.grey70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
