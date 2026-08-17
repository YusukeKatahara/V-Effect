import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_colors.dart';
import '../widgets/notification_prompt_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/service_providers.dart';
import '../services/push_notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  bool _pushNotifications = true;
  bool _reactionNotifications = true;
  bool _vFireNotifications = true;
  bool _protectionNotifications = false;
  bool _streakWarningNotifications = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          if (mounted) {
            setState(() {
              _pushNotifications = data['pushNotifications'] ?? true;
              _reactionNotifications = data['reactionNotifications'] ?? true;
              _vFireNotifications = data['vFireNotifications'] ?? true;
              _protectionNotifications = data['protectionNotifications'] ?? false;
              _streakWarningNotifications = data['streakWarningNotifications'] ?? false;
              _isLoading = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.grey08,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.accentGold.withValues(alpha: 0.3)),
        ),
        title: Text(
          '通知がオフになっています',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Text(
          'アプリの通知を受け取るには、端末の「設定」で通知を許可してください。',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'キャンセル',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentGold,
              foregroundColor: AppColors.bgBase,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final url = Uri.parse('app-settings:');
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              }
            },
            child: const Text(
              '設定を開く',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateSetting(String key, bool value) async {
    // スイッチをONにしようとした際、OSの通知権限をチェック
    if (value) {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        // まだ一度もOSダイアログを出していない場合は、OS標準の通知ダイアログをトリガー
        final newSettings = await PushNotificationService().requestPermission();
        if (newSettings.authorizationStatus == AuthorizationStatus.denied) {
          if (mounted) {
            _showPermissionDeniedDialog();
          }
          return;
        }
      } else if (settings.authorizationStatus == AuthorizationStatus.denied) {
        // OS側で通知が拒否されている場合は、設定アプリへ誘導するダイアログを表示
        if (mounted) {
          _showPermissionDeniedDialog();
        }
        return;
      }
    }

    setState(() {
      switch (key) {
        case 'pushNotifications':
          _pushNotifications = value;
          _reactionNotifications = value;
          _vFireNotifications = value;
          _protectionNotifications = value;
          _streakWarningNotifications = value;
          break;
        case 'reactionNotifications': _reactionNotifications = value; break;
        case 'vFireNotifications': _vFireNotifications = value; break;
        case 'protectionNotifications': _protectionNotifications = value; break;
        case 'streakWarningNotifications': _streakWarningNotifications = value; break;
      }
    });

    try {
      if (key == 'pushNotifications') {
        // マスタースイッチ：全てを一括更新
        await ref.read(userServiceProvider).updateSettings(
          pushNotifications: value,
          reactionNotifications: value,
          vFireNotifications: value,
          protectionNotifications: value,
          streakWarningNotifications: value,
        );
      } else {
        // 個別スイッチ：その項目のみ更新
        await ref.read(userServiceProvider).updateSettings(
          reactionNotifications: key == 'reactionNotifications' ? value : null,
          vFireNotifications: key == 'vFireNotifications' ? value : null,
          protectionNotifications: key == 'protectionNotifications' ? value : null,
          streakWarningNotifications: key == 'streakWarningNotifications' ? value : null,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.notificationSettingsSaveFailed)));
        _loadSettings(); // Revert
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: AppColors.bgBase,
        title: Text(AppLocalizations.of(context)!.notificationSettingsTitle, style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            children: [
              _buildSwitch(
                AppLocalizations.of(context)!.notificationSettingsPush,
                AppLocalizations.of(context)!.notificationSettingsPushDesc,
                _pushNotifications,
                (v) => _updateSetting('pushNotifications', v),
              ),
              _buildSwitch(
                AppLocalizations.of(context)!.notificationSettingsReaction,
                AppLocalizations.of(context)!.notificationSettingsReactionDesc,
                _reactionNotifications,
                (v) => _updateSetting('reactionNotifications', v),
              ),
              _buildSwitch(
                AppLocalizations.of(context)!.notificationSettingsVFire,
                AppLocalizations.of(context)!.notificationSettingsVFireDesc,
                _vFireNotifications,
                (v) => _updateSetting('vFireNotifications', v),
              ),
              _buildSwitch(
                AppLocalizations.of(context)!.notificationSettingsShield,
                AppLocalizations.of(context)!.notificationSettingsShieldDesc,
                _protectionNotifications,
                (v) => _updateSetting('protectionNotifications', v),
              ),
              _buildSwitch(
                AppLocalizations.of(context)!.notificationSettingsStreakWarning,
                AppLocalizations.of(context)!.notificationSettingsStreakWarningDesc,
                _streakWarningNotifications,
                (v) => _updateSetting('streakWarningNotifications', v),
              ),
              if (kDebugMode) ...[
                Divider(color: AppColors.grey30, height: 40),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    AppLocalizations.of(context)!.notificationSettingsDebugTitle,
                    style: TextStyle(
                      color: AppColors.accentGold,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: Text(AppLocalizations.of(context)!.notificationSettingsDebugResetTitle, style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: Text(AppLocalizations.of(context)!.notificationSettingsDebugResetDesc, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  trailing: Icon(Icons.refresh, color: AppColors.textPrimary),
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    if (uid != null) {
                      await prefs.remove('notification_prompt_shown_$uid');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppLocalizations.of(context)!.notificationSettingsDebugResetDone)),
                        );
                      }
                    }
                  },
                ),
                ListTile(
                  title: Text(AppLocalizations.of(context)!.notificationSettingsDebugTestTitle, style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: Text(AppLocalizations.of(context)!.notificationSettingsDebugTestDesc, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  trailing: Icon(Icons.play_arrow, color: AppColors.textPrimary),
                  onTap: () {
                    NotificationPromptSheet.show(context);
                  },
                ),
              ],
            ],
          ),
    );
  }

  Widget _buildSwitch(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title, style: TextStyle(color: AppColors.textPrimary)),
      subtitle: Text(subtitle, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.white,
      activeTrackColor: AppColors.grey50,
    );
  }
}
