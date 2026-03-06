import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // 日本語ロケール用
import 'firebase_options.dart';
import 'config/routes.dart';
import 'config/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase連携エラー: $e');
  }

  runApp(const VEffectApp());
}

class VEffectApp extends StatelessWidget {
  const VEffectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'V-Effect',
      theme: AppTheme.dark,
      // 日本語ロケール設定（午前/午後表示などに必要）
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja', 'JP'), // 日本語
      ],
      locale: const Locale('ja', 'JP'), // デフォルトを日本語に固定
      initialRoute: AppRoutes.login,
      routes: AppRoutes.routes,
    );
  }
}
