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
  // ガードレール1: エラー時の最終防衛ライン
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();

    // 描画エラー時のガードレール
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return GlobalErrorWidget(details: details);
    };

    // Fast Boot: 即座にアプリを起動し、初期化は内部で行う
    runApp(const ProviderScope(child: AppInitializer()));
  }, (error, stack) {
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
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
      // Step1: Firebase の初期化（5秒タイムアウト）
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          ).timeout(const Duration(seconds: 5));
        }
      } catch (e) {
        debugPrint('Firebase初期化エラー: $e');
        // Firebaseが必須な場合はここでエラーにしても良いが、
        // 続行できる可能性にかけてここでは握り潰しすぎない
      }

      // Step2: Firebase 設定
      if (!kIsWeb && Firebase.apps.isNotEmpty) {
        FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      }

      // Step3: 各種サービスの初期化
      final prefs = await SharedPreferences.getInstance();
      
      await Future.wait([
        PushNotificationService().initialize().timeout(const Duration(seconds: 5)),
        DeepLinkService().initialize().timeout(const Duration(seconds: 3)),
      ]).catchError((e) {
        debugPrint('サービス初期化警告: $e');
        return <void>[];
      });

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
