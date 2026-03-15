import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';
import 'config/routes.dart';
import 'config/theme.dart';
import 'services/analytics_service.dart';
import 'services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Crashlytics 初期化（Web非対応のためスキップ）
    if (!kIsWeb) {
      // Flutter フレームワーク内のエラーを自動送信
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;

      // Flutter フレームワーク外の非同期エラーを自動送信
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }

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
    // 初回セッション開始を記録
    AnalyticsService.instance.onAppResumed();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// アプリのライフサイクルを監視してセッションを計測
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final analytics = AnalyticsService.instance;
    if (state == AppLifecycleState.resumed) {
      analytics.onAppResumed();
    } else if (state == AppLifecycleState.paused) {
      analytics.onAppPaused();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: VEffectApp.navigatorKey,
      title: 'V EFFECT',
      theme: AppTheme.dark,
      // 日本語ロケール設定（午前/午後表示などに必要）
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ja', 'JP')],
      locale: const Locale('ja', 'JP'),
      initialRoute: AppRoutes.wrapper,
      routes: AppRoutes.routes,
      // 画面遷移の自動トラッキング
      navigatorObservers: [AnalyticsService.instance.observer],
    );
  }
}
