import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../config/app_colors.dart';
import '../config/routes.dart';
import '../providers/language_provider.dart';
import '../widgets/responsive_container.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = '${info.version} (${info.buildNumber})';
        });
      }
    } catch (e) {
      debugPrint('Failed to load version: $e');
    }
  }

  Future<void> _launchURL(String urlString) async {
    final url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.inAppBrowserView)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('リンクを開けませんでした')));
      }
    }
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        // ダイアログ内でも現在の設定を反映させるために Consumer を使用
        return Consumer(
          builder: (context, ref, child) {
            final currentLang = ref.watch(languageProvider);
            return AlertDialog(
              backgroundColor: AppColors.grey15,
              title: Text(
                AppLocalizations.of(context)!.languageSetting,
                style: const TextStyle(color: AppColors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    title: Text(AppLocalizations.of(context)!.languageJapanese, style: const TextStyle(color: AppColors.white)),
                    value: 'ja',
                    groupValue: currentLang,
                    activeColor: AppColors.accentGold,
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(languageProvider.notifier).setLanguage(val);
                        Navigator.pop(context);
                      }
                    },
                  ),
                  RadioListTile<String>(
                    title: Text(AppLocalizations.of(context)!.languageEnglish, style: const TextStyle(color: AppColors.white)),
                    value: 'en',
                    groupValue: currentLang,
                    activeColor: AppColors.accentGold,
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(languageProvider.notifier).setLanguage(val);
                        Navigator.pop(context);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: AppColors.bgBase,
        title: Text(AppLocalizations.of(context)!.settingsTitle, style: const TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: ResponsiveContainer(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 60, top: 8),
          children: [
            ListTile(
              title: const Text(
                '通知',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.textMuted,
              ),
              onTap: () => Navigator.pushNamed(context, AppRoutes.notificationSettings),
            ),
            ListTile(
              title: Text(
                AppLocalizations.of(context)!.languageSetting,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              trailing: Text(
                ref.watch(languageProvider) == 'en' ? 'ENGLISH' : '日本語',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
              onTap: () => _showLanguageDialog(context, ref),
            ),
            ListTile(
              title: const Text(
                'パスワードとセキュリティ',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.textMuted,
              ),
              onTap: () => Navigator.pushNamed(context, AppRoutes.securitySettings),
            ),
            
            _buildSectionHeader('サポート・法的情報'),
            ListTile(
              title: const Text(
                'お問い合わせ / バグ報告',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              trailing: const Icon(
                Icons.open_in_new,
                color: AppColors.textMuted,
                size: 16,
              ),
              onTap: () => _launchURL('https://veffect.web.app/support/'),
            ),
            ListTile(
              title: const Text(
                '利用規約',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.textMuted,
              ),
              onTap: () => Navigator.pushNamed(context, AppRoutes.terms),
            ),
            ListTile(
              title: const Text(
                'プライバシーポリシー',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.textMuted,
              ),
              onTap: () => Navigator.pushNamed(context, AppRoutes.privacyPolicy),
            ),
            ListTile(
              title: const Text(
                'バージョン情報',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              trailing: Text(
                _appVersion,
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
  
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
