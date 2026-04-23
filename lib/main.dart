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
import 'widgets/global_error_widget.dart';
import 'widgets/splash_loading.dart';
import 'dart:async';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 描画エラー時のガードレール
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return GlobalErrorWidget(details: details);
    };

    // Firebase 初期化を最優先で実行（バックグラウンド初期化による重複を防ぐため）
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).timeout(const Duration(seconds: 10));
      }
    } catch (e) {
      if (e.toString().contains('duplicate-app')) {
        debugPrint('Firebase already initialized (duplicate-app ignored)');
      } else {
        debugPrint('Firebase初期化エラー (非致命的): $e');
      }
    }

    // Step2: Firebase 設定（初期化成功時のみ）
    if (!kIsWeb && Firebase.apps.isNotEmpty) {
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    }

    // Fast Boot: 即座にアプリを起動
    runApp(const ProviderScope(child: AppInitializer()));
  }, (error, stack) {
    if (!kIsWeb) {
      try {
        if (Firebase.apps.isNotEmpty) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        }
      } catch (_) {}
    }
    debugPrint('致命的なエラー: $error');
    runApp(GlobalErrorWidget(error: error.toString()));
  });
}

/// アプリの初期化状態を管理するラッパー
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isInitialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // 非UIブロック項目の初期化
      PushNotificationService().initialize().catchError((e) => debugPrint('通知初期化エラー: $e'));
      DeepLinkService().initialize().catchError((e) => debugPrint('DeepLink初期化エラー: $e'));

      final prefs = await SharedPreferences.getInstance();

      // テーマ設定
      final isDarkMode = prefs.getBool('isDarkMode') ?? true;
      VEffectApp.themeNotifier.value =
          isDarkMode ? ThemeMode.dark : ThemeMode.light;

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e, stack) {
      debugPrint('初期化中の致命的エラー: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return GlobalErrorWidget(error: _error);
    }

    if (!_isInitialized) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SplashLoading(),
      );
    }

    return const VEffectApp();
  }
}

class VEffectApp extends StatefulWidget {
  const VEffectApp({super.key});

  static final navigatorKey = GlobalKey<NavigatorState>();
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

  @override
  State<VEffectApp> createState() => _VEffectAppState();
}

class _VEffectAppState extends State<VEffectApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AnalyticsService.instance.onAppResumed();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DeepLinkService().dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AnalyticsService.instance.onAppResumed();
      // フォアグラウンド復帰時にバッジをリセット
      PushNotificationService().resetBadge();
    } else if (state == AppLifecycleState.paused) {
      AnalyticsService.instance.onAppPaused();
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
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ja', 'JP')],
          locale: const Locale('ja', 'JP'),
          initialRoute: AppRoutes.wrapper,
          routes: AppRoutes.routes,
          navigatorObservers: [AnalyticsService.instance.observer],
        );
      },
    );
  }
}
