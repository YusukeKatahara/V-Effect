import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// 長押し時に表示される絵文字リアクション＆アクションパレット
class ReactionPickerSheet extends StatelessWidget {
  /// 現在自分が付けているリアクション（付いていなければ null）
  final String? myCurrentReaction;

  /// 絵文字が選ばれたときのコールバック
  final ValueChanged<String> onReactionSelected;

  /// 「コピー」が選ばれたときのコールバック
  final VoidCallback onCopy;

  const ReactionPickerSheet({
    super.key,
    this.myCurrentReaction,
    required this.onReactionSelected,
    required this.onCopy,
  });

  /// V EFFECT 専用の6大称賛絵文字リスト
  static const List<String> praiseEmojis = [
    '🔥', // V-FIRE（熱い情熱）
    '👏', // 拍手（ナイス！）
    '👑', // 王冠（継続の鬼）
    '💪', // 力こぶ（ファイト！）
    '✨', // 輝き（最高！）
    '🤝', // 絆（感謝・仲間）
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = AppColors.isDark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 上部ドラッグバー
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.grey30 : AppColors.grey70,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // 絵文字クイックパレット（フローティングピル型）
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.grey10 : AppColors.grey05,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: isDark ? AppColors.grey20 : AppColors.grey70,
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: praiseEmojis.map((emoji) {
                  final isSelected = myCurrentReaction == emoji;
                  return _buildEmojiButton(context, emoji, isSelected);
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // アクションリスト（コピーなど）
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.grey10 : AppColors.pureWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.grey20 : AppColors.grey70,
                  width: 0.8,
                ),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.copy_rounded,
                  color: AppColors.textPrimary,
                  size: 20,
                ),
                title: Text(
                  l10n.directChatCopy,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onTap: () {
                  Navigator.pop(context);
                  onCopy();
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 各絵文字リアクションボタン
  Widget _buildEmojiButton(BuildContext context, String emoji, bool isSelected) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          Navigator.pop(context);
          onReactionSelected(emoji);
        },
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accentGold.withValues(alpha: 0.25)
                : Colors.transparent,
            shape: BoxShape.circle,
            border: isSelected
                ? Border.all(color: AppColors.accentGold, width: 1.5)
                : null,
          ),
          child: Text(
            emoji,
            style: TextStyle(
              fontSize: isSelected ? 28 : 25,
            ),
          ),
        ),
      ),
    );
  }
}
