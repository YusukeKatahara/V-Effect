import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_links/app_links.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'firebase_options.dart';
import 'config/routes.dart';
import 'config/theme.dart';
import 'services/analytics_service.dart';
import 'services/push_notification_service.dart';
import 'services/deep_link_service.dart';
import 'services/sound_service.dart';
import 'services/post_service.dart';
import 'utils/date_helper.dart';
import 'widgets/global_error_widget.dart';
import 'widgets/splash_loading.dart';
import 'dart:async';
import 'services/widget_service.dart';
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

    // App Check: 改造クライアントや外部スクリプトからの直接 API 叩きを抑止する。
    // 失敗してもアプリ自体は動かしたいので catch して握りつぶす。
    // 本番では Android=Play Integrity / iOS=App Attest、デバッグ時はデバッグプロバイダーを使う。
    if (Firebase.apps.isNotEmpty) {
      try {
        await FirebaseAppCheck.instance.activate(
          providerAndroid: kDebugMode
              ? AndroidDebugProvider()
              : AndroidPlayIntegrityProvider(),
          providerApple: kDebugMode
              ? AppleDebugProvider()
              : AppleAppAttestProvider(),
        );
      } catch (e) {
        debugPrint('App Check 初期化エラー (非致命的): $e');
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
      try {
        await MobileAds.instance.initialize();
      } catch (e) {
        debugPrint('AdMob初期化エラー: $e');
      }
      PushNotificationService().initialize().catchError((e) => debugPrint('通知初期化エラー: $e'));
      DeepLinkService().initialize().catchError((e) => debugPrint('DeepLink初期化エラー: $e'));
      SoundService.instance.init().catchError((e) => debugPrint('音声初期化エラー: $e'));
      WidgetService.instance.initialize().then((_) => _syncWidgetData()).catchError((e) => debugPrint('Widget初期化エラー: $e'));

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
    } catch (e) {
      debugPrint('初期化中の致命的エラー: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _syncWidgetData() async {
    try {
      if (FirebaseAuth.instance.currentUser != null) {
        final isCompleted = await PostService.instance.hasPostedToday();
        final streak = await PostService.instance.getStreak();
        await WidgetService.instance.updateWidgetData(
          isCompleted: isCompleted,
          streakCount: streak,
        );
      }
    } catch (e) {
      debugPrint('WidgetSync Error: $e');
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
  final _appLinks = AppLinks();
  Timer? _midnightTimer;
  String _lastCheckedDate = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AnalyticsService.instance.onAppResumed();
    
    _lastCheckedDate = DateHelper.toDateString(DateTime.now());
    _scheduleMidnightTimer();

    // メール認証 Deep Link の受信を開始
    _initDeepLinks();

    // Navigatorの準備が完了したタイミングでDeepLinkServiceに通知し、溜まっていたリンクを処理させる
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinkService().onNavigatorReady();
    });
  }

  void _scheduleMidnightTimer() {
    _midnightTimer?.cancel();
    
    final now = DateTime.now();
    // 翌日の0時0分0秒を取得します
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    // 0時までの残り時間を計算（安全のため+1秒します）
    final difference = tomorrow.difference(now) + const Duration(seconds: 1);
    
    _midnightTimer = Timer(difference, () {
      _onDateChanged();
      _scheduleMidnightTimer();
    });
  }

  void _onDateChanged() {
    final today = DateHelper.toDateString(DateTime.now());
    if (_lastCheckedDate != today) {
      _lastCheckedDate = today;
      // 日付が変わったら、PostServiceを通じてアプリ全体に更新を通知
      PostService.instance.notifyUpdate();
      debugPrint('Date changed to $today. Triggered app-wide refresh.');
    }
  }

  /// メール認証リンクをアプリで受け取って処理する
  void _initDeepLinks() {
    _appLinks.uriLinkStream.listen((uri) async {
      await _handleEmailVerificationLink(uri.toString());
    });

    // アプリを閉じた状態からリンクで起動したケース
    _appLinks.getInitialLink().then((uri) async {
      if (uri != null) {
        await _handleEmailVerificationLink(uri.toString());
      }
    });
  }

  Future<void> _handleEmailVerificationLink(String link) async {
    final auth = FirebaseAuth.instance;
    if (!auth.isSignInWithEmailLink(link)) return;
    try {
      final user = auth.currentUser;
      if (user == null) return;
      // メール認証コードを適用
      await auth.applyActionCode(
        Uri.parse(link).queryParameters['oobCode'] ?? '',
      );
      await user.reload();
      // 認証完了 → ホーム画面へ
      final navigator = VEffectApp.navigatorKey.currentState;
      if (navigator != null && user.emailVerified) {
        navigator.pushNamedAndRemoveUntil(AppRoutes.wrapper, (r) => false);
      }
    } catch (e) {
      debugPrint('Deep link email verification error: $e');
    }
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
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
      
      // フォアグラウンド復帰時に日付が変わっていないかチェック
      _onDateChanged();
      
      // ウィジェットを最新状態に同期
      if (FirebaseAuth.instance.currentUser != null) {
        PostService.instance.hasPostedToday().then((isCompleted) {
          PostService.instance.getStreak().then((streak) {
            WidgetService.instance.updateWidgetData(isCompleted: isCompleted, streakCount: streak);
          });
        }).catchError((_) {});
      }
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
