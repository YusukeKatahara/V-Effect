import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // 日本語ロケール用
import 'firebase_options.dart';
import 'config/routes.dart';
import 'config/theme.dart';
import 'services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // プッシュ通知の初期化
    await PushNotificationService().initialize();
  } catch (e) {
    debugPrint('Firebase連携エラー: $e');
  }

  runApp(const VEffectApp());
}

class VEffectApp extends StatefulWidget {
  const VEffectApp({super.key});

  /// アプリ内のどこからでも Navigator にアクセスするためのグローバルキー
  static final navigatorKey = GlobalKey<NavigatorState>();

  @override
  State<VEffectApp> createState() => _VEffectAppState();
}

class _VEffectAppState extends State<VEffectApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: VEffectApp.navigatorKey,
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
