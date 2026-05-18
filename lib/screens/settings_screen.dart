import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_colors.dart';
import '../config/routes.dart';
import '../widgets/responsive_container.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: AppColors.bgBase,
        title: const Text('設定', style: TextStyle(color: AppColors.textPrimary)),
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
