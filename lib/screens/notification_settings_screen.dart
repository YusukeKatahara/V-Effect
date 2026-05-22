import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_colors.dart';
import '../services/user_service.dart';
import '../widgets/notification_prompt_sheet.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _pushNotifications = true;
  bool _reactionNotifications = true;
  bool _focusTimeNotifications = true;
  bool _vFireNotifications = true;
  bool _protectionNotifications = true;
  bool _streakCelebrationNotifications = true;
  bool _streakWarningNotifications = true;
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
              _focusTimeNotifications = data['focusTimeNotifications'] ?? true;
              _vFireNotifications = data['vFireNotifications'] ?? true;
              _protectionNotifications = data['protectionNotifications'] ?? true;
              _streakCelebrationNotifications = data['streakCelebrationNotifications'] ?? true;
              _streakWarningNotifications = data['streakWarningNotifications'] ?? true;
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

  Future<void> _updateSetting(String key, bool value) async {
    setState(() {
      switch (key) {
        case 'pushNotifications':
          _pushNotifications = value;
          _reactionNotifications = value;
          _focusTimeNotifications = value;
          _vFireNotifications = value;
          _protectionNotifications = value;
          _streakCelebrationNotifications = value;
          _streakWarningNotifications = value;
          break;
        case 'reactionNotifications': _reactionNotifications = value; break;
        case 'focusTimeNotifications': _focusTimeNotifications = value; break;
        case 'vFireNotifications': _vFireNotifications = value; break;
        case 'protectionNotifications': _protectionNotifications = value; break;
        case 'streakCelebrationNotifications': _streakCelebrationNotifications = value; break;
        case 'streakWarningNotifications': _streakWarningNotifications = value; break;
      }
    });

    try {
      if (key == 'pushNotifications') {
        // マスタースイッチ：全てを一括更新
        await UserService.instance.updateSettings(
          pushNotifications: value,
          reactionNotifications: value,
          focusTimeNotifications: value,
          vFireNotifications: value,
          protectionNotifications: value,
          streakCelebrationNotifications: value,
          streakWarningNotifications: value,
        );
      } else {
        // 個別スイッチ：その項目のみ更新
        await UserService.instance.updateSettings(
          reactionNotifications: key == 'reactionNotifications' ? value : null,
          focusTimeNotifications: key == 'focusTimeNotifications' ? value : null,
          vFireNotifications: key == 'vFireNotifications' ? value : null,
          protectionNotifications: key == 'protectionNotifications' ? value : null,
          streakCelebrationNotifications: key == 'streakCelebrationNotifications' ? value : null,
          streakWarningNotifications: key == 'streakWarningNotifications' ? value : null,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('設定の保存に失敗しました')));
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
        title: const Text('通知設定', style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            children: [
              _buildSwitch(
                'プッシュ通知を許可',
                'フォローや仲間の新しい投稿のお知らせ',
                _pushNotifications,
                (v) => _updateSetting('pushNotifications', v),
              ),
              _buildSwitch(
                'リアクション通知を許可',
                '投稿にリアクションが届いたとき',
                _reactionNotifications,
                (v) => _updateSetting('reactionNotifications', v),
              ),
              _buildSwitch(
                'V Alert 通知を許可',
                '設定した時間のタスクリマインダー',
                _focusTimeNotifications,
                (v) => _updateSetting('focusTimeNotifications', v),
              ),
              _buildSwitch(
                'V FIRE通知を許可',
                '投稿にV FIREが届いたとき',
                _vFireNotifications,
                (v) => _updateSetting('vFireNotifications', v),
              ),
              _buildSwitch(
                '保護シールド通知を許可',
                'シールドによるストリーク維持のお知らせ',
                _protectionNotifications,
                (v) => _updateSetting('protectionNotifications', v),
              ),
              _buildSwitch(
                'ストリーク達成祝いを許可',
                '30日や100日などの大きな節目のお知らせ',
                _streakCelebrationNotifications,
                (v) => _updateSetting('streakCelebrationNotifications', v),
              ),
              _buildSwitch(
                'ストリーク危機通知を許可',
                '夜になってもタスクが完了していない時のリマインダー',
                _streakWarningNotifications,
                (v) => _updateSetting('streakWarningNotifications', v),
              ),
              if (kDebugMode) ...[
                const Divider(color: AppColors.grey30, height: 40),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '開発者向けデバッグ機能',
                    style: TextStyle(
                      color: AppColors.accentGold,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: const Text('通知プレ・ダイアログの表示フラグをリセット', style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: const Text('「一度のみ表示」の制限フラグを消去します', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  trailing: const Icon(Icons.refresh, color: AppColors.textPrimary),
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    if (uid != null) {
                      await prefs.remove('notification_prompt_shown_$uid');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('通知ダイアログ表示フラグをリセットしました。')),
                        );
                      }
                    }
                  },
                ),
                ListTile(
                  title: const Text('通知プレ・ダイアログをテスト表示', style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: const Text('現在の通知許可状態に関わらずモーダルを表示します', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  trailing: const Icon(Icons.play_arrow, color: AppColors.textPrimary),
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
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.white,
      activeTrackColor: AppColors.grey50,
    );
  }
}
