import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../main.dart'; // To access ThemeMode changing logic if we put it there
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = true;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? true;
    });
  }

  Future<void> _toggleTheme(bool value) async {
    setState(() {
      _isDarkMode = value;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
    
    // アプリ全体のテーマを変更するロジック（VEffectApp.themeNotifier.value = ...）
    VEffectApp.themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
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
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              '外観',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('ダークモード', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: const Text('（※完全なライトモード対応は今後のアップデートで提供されます）', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            value: _isDarkMode,
            onChanged: _toggleTheme,
            activeColor: AppColors.white,
            activeTrackColor: AppColors.grey50,
          ),
        ],
      ),
    );
  }
}
