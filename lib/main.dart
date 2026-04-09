import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'config/routes.dart';
import 'config/theme.dart';
import 'services/analytics_service.dart';
import 'services/push_notification_service.dart';
import 'services/deep_link_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 起動時の初期化を並列実行
    final results = await Future.wait([
      Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ),
      SharedPreferences.getInstance(),
    ]);

    final prefs = results[1] as SharedPreferences;

    // Firebase 初期化直後に必要な設定
    if (!kIsWeb) {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }

    // 他のサービス初期化（FirebaseAppが必要なもの）
    await PushNotificationService().initialize();
    await DeepLinkService().initialize();

    // テーマ設定の反映
    final isDarkMode = prefs.getBool('isDarkMode') ?? true;
    VEffectApp.themeNotifier.value =
        isDarkMode ? ThemeMode.dark : ThemeMode.light;

  } catch (e) {
    debugPrint('Firebase連携エラー: $e');
  }

  runApp(const ProviderScope(child: VEffectApp()));
}

class VEffectApp extends StatefulWidget {
  const VEffectApp({super.key});

  /// アプリ内のどこからでも Navigator にアクセスするためのグローバルキー
  static final navigatorKey = GlobalKey<NavigatorState>();

  /// テーマ変更用のNotifier
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

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
    DeepLinkService().dispose();
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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: VEffectApp.themeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          navigatorKey: VEffectApp.navigatorKey,
          title: 'V EFFECT',
          theme: AppTheme.light, // ライトモード用のテーマ（後で拡張予定）
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
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
      },
    );
  }
}
