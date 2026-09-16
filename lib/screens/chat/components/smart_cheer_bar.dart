import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// 1タップで相手に温かい称賛やエールを送信できるスマート・エールバー
class SmartCheerBar extends StatelessWidget {
  /// エールがタップされた時のコールバック（即時送信または挿入）
  final ValueChanged<String> onCheerSelected;

  /// 投稿への引用返信中かどうか（文脈に応じてエールを切り替え）
  final bool isReplying;

  const SmartCheerBar({
    super.key,
    required this.onCheerSelected,
    this.isReplying = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // 投稿への返信中か通常チャットかでエールの内容を文脈適応
    final List<String> cheers = isReplying
        ? [
            l10n.directChatCheerNiceFight,     // 「ナイスファイト！🔥」
            l10n.directChatCheerInspired,      // 「さすが！刺激もらった👏」
            l10n.directChatCheerLookingGood,   // 「今日も最高にかっこいい✨」
            l10n.directChatCheerKeepGoing,     // 「この調子で突っ走ろう🚀」
          ]
        : [
            l10n.directChatCheerLetsDoThis,          // 「今日も頑張ろう🔥」
            l10n.directChatCheerAlwaysSupporting,    // 「いつも応援してるよ！💪」
            l10n.directChatCheerStreakMaster,        // 「継続の鬼だね👑」
            l10n.directChatCheerGrateful,            // 「感謝！いつもありがとう🤝」
          ];

    return Container(
      height: 40,
      margin: const EdgeInsets.only(top: 4, bottom: 2),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        physics: const BouncingScrollPhysics(),
        itemCount: cheers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cheer = cheers[index];
          return _buildCheerChip(context, cheer);
        },
      ),
    );
  }

  /// 各エールチップのUI生成
  Widget _buildCheerChip(BuildContext context, String cheer) {
    final isDark = AppColors.isDark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // 触覚フィードバック（タップした心地よい振動）
          HapticFeedback.lightImpact();
          onCheerSelected(cheer);
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.grey15 : AppColors.pureWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.grey20 : AppColors.grey70,
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: Text(
              cheer,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
