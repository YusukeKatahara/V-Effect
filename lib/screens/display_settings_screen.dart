import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import '../config/app_colors.dart';
import '../providers/theme_provider.dart';
import '../widgets/responsive_container.dart';
import '../models/app_user.dart';

/// 表示とデザイン（テーマ切り替え）を行う画面
class DisplaySettingsScreen extends StatelessWidget {
  const DisplaySettingsScreen({super.key});

  /// プレビュー表示用およびデータ取得エラー時のフォールバック用ダミーユーザー情報
  static const AppUser _dummyUser = AppUser(
    uid: 'dummy',
    username: 'renn',
    userId: 'rennlikeu',
    streak: 40,
    following: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13'],
    followers: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13'],
    instagramId: 'rennlikeu',
  );

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

              // テーマの切り替えをリアルタイムで確認できるプロフィールプレビューカード
              StreamBuilder<DocumentSnapshot>(
                stream: () {
                  try {
                    // Firebaseが初期化されており、ログインユーザーが存在する場合のみストリームを取得します。
                    // テスト環境などで初期化されていない場合は、安全に空のストリームを返します。
                    if (Firebase.apps.isNotEmpty &&
                        FirebaseAuth.instance.currentUser?.uid != null) {
                      return FirebaseFirestore.instance
                          .collection('users')
                          .doc(FirebaseAuth.instance.currentUser!.uid)
                          .snapshots();
                    }
                  } catch (e) {
                    debugPrint('Firebase is not initialized or error occurred: $e');
                  }
                  return const Stream<DocumentSnapshot>.empty();
                }(),
                builder: (context, snapshot) {
                  AppUser user = _dummyUser;
                  if (snapshot.hasData && snapshot.data!.exists) {
                    try {
                      user = AppUser.fromFirestore(snapshot.data!);
                    } catch (e) {
                      debugPrint('Error parsing user data in preview: $e');
                    }
                  }
                  return _buildProfilePreview(context, user);
                },
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

  /// プレビュー用のプロフィールカード（ログインユーザーの情報またはダミー情報を動的に反映）を生成します
  Widget _buildProfilePreview(BuildContext context, AppUser user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        // テーマの切り替えを分かりやすくするため、セマンティックカラー（意味付けされた色）を使用します。
        color: AppColors.bgBase,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.5),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 上部：アバター、ユーザー情報、QRコード
          Row(
            children: [
              // --- プロフィール画像 (アバター)
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: user.photoUrl == null
                      ? AppColors.primaryGradient
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.white.withValues(alpha: 0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: user.photoUrl != null
                    ? CircleAvatar(
                        radius: 30,
                        backgroundImage: CachedNetworkImageProvider(user.photoUrl!),
                      )
                    : CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.transparent,
                        child: Icon(
                          Icons.person_rounded,
                          size: 30,
                          color: AppColors.black,
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              // --- ユーザー名とID
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.username ?? '',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis, // 文字あふれ時の三点リーダー (...) 表示
                          ),
                        ),
                        if (user.instagramId != null && user.instagramId!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          FaIcon(
                            FontAwesomeIcons.instagram,
                            color: AppColors.textPrimary,
                            size: 18,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${user.userId ?? ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // --- QRコードアイコン (プレビュー用・タップ不可)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.bgElevated.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.1),
                    width: 0.5,
                  ),
                ),
                child: Icon(
                  Icons.qr_code,
                  color: AppColors.textPrimary,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 下部：フォロー、フォロワー、ストリーク統計カード
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.bgElevated.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: IntrinsicHeight( // 子要素の高さを揃えるウィジェット
              child: Row(
                children: [
                  Expanded(
                    child: _buildPreviewFollowStat(
                      context,
                      AppLocalizations.of(context)!.profileScreenFollowing,
                      user.following.length,
                      isStreak: false,
                    ),
                  ),
                  VerticalDivider(
                    color: AppColors.border.withValues(alpha: 0.2),
                    thickness: 1,
                    width: 1,
                  ),
                  Expanded(
                    child: _buildPreviewFollowStat(
                      context,
                      AppLocalizations.of(context)!.profileScreenFollowers,
                      user.followers.length,
                      isStreak: false,
                    ),
                  ),
                  VerticalDivider(
                    color: AppColors.border.withValues(alpha: 0.2),
                    thickness: 1,
                    width: 1,
                  ),
                  Expanded(
                    child: _buildPreviewFollowStat(
                      context,
                      AppLocalizations.of(context)!.profileScreenStreak,
                      user.streak,
                      isStreak: true,
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

  /// プレビューカード内の統計情報（フォロー数・フォロワー数・ストリーク）を生成します
  Widget _buildPreviewFollowStat(
    BuildContext context,
    String label,
    int count, {
    required bool isStreak,
  }) {
    // ストリーク数（継続日数）に応じた色判定ロジック
    Color getStreakColor(int streak) {
      if (streak >= 365) return const Color(0xFFE0A33B); // Challenger
      if (streak >= 270) return const Color(0xFFB53030); // Grandmaster
      if (streak >= 180) return const Color(0xFF8D2D9E); // Master
      if (streak >= 100) return const Color(0xFF4A60AB); // Diamond
      if (streak >= 66) return const Color(0xFF10825B);  // Emerald
      if (streak >= 30) return const Color(0xFF327A8A);  // Platinum
      if (streak >= 14) return const Color(0xFFC89C3C);  // Gold
      if (streak >= 7) return const Color(0xFF8091A0);   // Silver
      if (streak >= 3) return const Color(0xFF8F5338);   // Bronze
      return const Color(0xFF5E4B43);                    // Iron
    }

    final streakColor = getStreakColor(count);
    final themeColor = isStreak ? streakColor : AppColors.textPrimary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isStreak) ...[
              Icon(Icons.local_fire_department_rounded, size: 16, color: themeColor),
              const SizedBox(width: 2),
            ],
            Text(
              '$count',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: themeColor,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.notoSansJp(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: isStreak ? themeColor : AppColors.textSecondary,
          ),
        ),
      ],
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
