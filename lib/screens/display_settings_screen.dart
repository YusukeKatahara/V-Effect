import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import '../config/app_colors.dart';
import '../providers/theme_provider.dart';
import '../widgets/responsive_container.dart';

/// 表示とデザイン（テーマ切り替え）を行う画面
class DisplaySettingsScreen extends StatelessWidget {
  const DisplaySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final currentMode = themeProvider.themeMode;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: AppColors.bgBase,
        title: Text(
          l10n.themeSetting,
          style: TextStyle(color: AppColors.textPrimary),
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: ResponsiveContainer(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // プレビュー表示セクション
              // 多言語対応（ローカライズ）されたテキストキー `l10n.previewLabel` を使用します。
              // これにより、言語設定（日本語・英語など）に応じて自動的に適切な文言（「プレビュー」や「Preview」）に切り替わります。
              Text(
                l10n.previewLabel,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // テーマの切り替えをリアルタイムで確認できるモックカード
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.5),
                    width: 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.accentGold,
                          child: Icon(
                            Icons.person,
                            color: AppColors.bgBase,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "V-Hero (You)",
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                "@v_hero_official",
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accentGold.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.accentGold,
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.local_fire_department,
                                color: AppColors.accentGold,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "5 Streak",
                                style: TextStyle(
                                  color: AppColors.accentGold,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "今日も朝活達成！30分読書と筋トレ完了。毎日少しずつの積み重ねが勝利へのロードマップ！🔥",
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: AppColors.bgElevated,
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.emoji_events,
                            color: AppColors.accentGold,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Quest: Read 30 Minutes",
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  "Daily Habit • Completed",
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            "+15 XP",
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // テーマ設定セクション
              Text(
                l10n.themeDescription,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),

              // X風のテーマ切り替え用カード群（横並び）
              Row(
                children: [
                  Expanded(
                    child: _ThemeOptionCard(
                      label: l10n.themeLight,
                      icon: Icons.light_mode,
                      isSelected: currentMode == ThemeMode.light,
                      mode: ThemeMode.light,
                      onTap: () => themeProvider.setThemeMode(ThemeMode.light),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ThemeOptionCard(
                      label: l10n.themeDark,
                      icon: Icons.dark_mode,
                      isSelected: currentMode == ThemeMode.dark,
                      mode: ThemeMode.dark,
                      onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ThemeOptionCard(
                      label: l10n.themeSystem,
                      icon: Icons.brightness_auto,
                      isSelected: currentMode == ThemeMode.system,
                      mode: ThemeMode.system,
                      onTap: () => themeProvider.setThemeMode(ThemeMode.system),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// テーマ選択肢を表すカードウィジェット
class _ThemeOptionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final ThemeMode mode;
  final VoidCallback onTap;

  const _ThemeOptionCard({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.mode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color cardBg;
    final Color contentColor;
    final Color borderColor;

    switch (mode) {
      case ThemeMode.light:
        cardBg = const Color(0xFFFFFFFF);
        contentColor = const Color(0xFF000000);
        borderColor = isSelected ? const Color(0xFFD4AF37) : const Color(0xFFD9D9D9);
        break;
      case ThemeMode.dark:
        cardBg = const Color(0xFF000000);
        contentColor = const Color(0xFFFFFFFF);
        borderColor = isSelected ? const Color(0xFFD4AF37) : const Color(0xFF333333);
        break;
      case ThemeMode.system:
        cardBg = AppColors.bgSurface;
        contentColor = AppColors.textPrimary;
        borderColor = isSelected ? const Color(0xFFD4AF37) : AppColors.border;
        break;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        // テキストスケーリングによるレイアウト崩れ・はみ出し（overflow）を防ぐため、
        // 固定の高さではなく、最小の高さ（minHeight: 100）を指定して動的拡張をサポートします。
        constraints: const BoxConstraints(minHeight: 100),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: contentColor,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: contentColor,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
