import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_colors.dart';
import '../services/force_update_service.dart';
import '../l10n/app_localizations.dart';

/// アプリの動作に必要なアップデートを促し、操作を完全にブロックする画面
class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key});

  // ストアURL（本番公開時に適切なURLに変更してください）
  static const String _appStoreUrl = 'https://apps.apple.com/app/id6503923769';
  static const String _playStoreUrl = 'https://play.google.com/store/apps/details?id=com.veffect.app';

  Future<void> _launchStore() async {
    final String urlStr = Platform.isIOS ? _appStoreUrl : _playStoreUrl;
    final Uri url = Uri.parse(urlStr);
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
      } else {
        debugPrint('[ForceUpdate] ストアURLを開くことができません: $urlStr');
      }
    } catch (e) {
      debugPrint('[ForceUpdate] ストア遷移中にエラーが発生しました: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = ForceUpdateService.instance.forceUpdateMessage;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              
              // V EFFECT ゴールドロゴ
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentGold.withValues(alpha: 0.3),
                      blurRadius: 30,
                      spreadRadius: 3,
                    ),
                  ],
                  border: Border.all(
                    color: AppColors.accentGold,
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/icon/splash_logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              
              const SizedBox(height: 48),
              
              // メインタイトル
              Text(
                l10n.forceUpdateTitle.toUpperCase(),
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                  letterSpacing: 2,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // 説明メッセージ
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSansJp(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.grey50,
                  height: 1.6,
                ),
              ),
              
              const Spacer(),
              
              // アップデートボタン
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _launchStore,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentGold,
                    foregroundColor: AppColors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(27),
                    ),
                  ),
                  child: Text(
                    l10n.forceUpdateBtn,
                    style: GoogleFonts.notoSansJp(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
