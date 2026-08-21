import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:v_effect/providers/theme_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_links/app_links.dart';
import 'package:home_widget/home_widget.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import 'firebase_options.dart';
import 'config/routes.dart';
import 'config/theme.dart';
import 'providers/language_provider.dart';
import 'services/analytics_service.dart';
import 'services/push_notification_service.dart';
import 'services/deep_link_service.dart';
import 'services/sound_service.dart';
import 'services/post_service.dart';
import 'utils/date_helper.dart';
import 'screens/weekly_review_screen.dart';
import 'widgets/global_error_widget.dart';
import 'widgets/splash_loading.dart';
import 'widgets/web_profile_wrapper.dart';
import 'screens/auth_wrapper.dart';
import 'screens/camera_screen.dart';
import 'screens/main_shell.dart';
import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/force_update_service.dart';
import 'screens/force_update_screen.dart';
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

    // App Check (リリースビルドでのみアクティブ化し、デバッグ時の403/400エラーログを防止)
    if (!kDebugMode && !kIsWeb && Firebase.apps.isNotEmpty) {
      try {
        await FirebaseAppCheck.instance.activate(
          providerAndroid: AndroidPlayIntegrityProvider(),
          providerApple: AppleAppAttestProvider(),
        );
      } catch (e) {
        debugPrint('App Check 初期化エラー (非致命的): $e');
      }
    }

    // Crashlytics
    if (!kIsWeb && Firebase.apps.isNotEmpty) {
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    }

    // Fast Boot: キャッシュ状況およびウィジェットからのダイレクト起動判定
    String initialRoute = AppRoutes.login;
    try {
      if (!kIsWeb) {
        await WidgetService.instance.initialize();
      }
      final appLinks = AppLinks();
      final initialUri = await appLinks.getInitialLink();
      final initialWidgetUri = kIsWeb ? null : await HomeWidget.initiallyLaunchedFromHomeWidget();
      final uriString = (initialUri ?? initialWidgetUri)?.toString() ?? '';

      // ウィジェット/コントロールセンターからveffect://cameraで起動され、
      // かつオンボーディング完了済みの場合はダイレクトでカメラ画面へ（ゼロ・ディレイ起動）
      final prefs = await SharedPreferences.getInstance();
      final user = FirebaseAuth.instance.currentUser;

      // 認証トークンのウォームアップ（Firestoreのpermission-denied防止）
      if (user != null) {
        try {
          await user.getIdToken(false).timeout(const Duration(milliseconds: 600));
        } catch (e) {
          debugPrint('Auth token warmup (non-fatal): $e');
        }
      }

      final isCompleted = user != null && (prefs.getBool('onboardingCompleted_${user.uid}') ?? true);

      if (user != null && (uriString.contains('veffect://camera') || uriString.contains('veffect:camera'))) {
        initialRoute = AppRoutes.camera;
        DeepLinkService().markInitialLinkHandled();
      } else if (user != null && isCompleted) {
        initialRoute = AppRoutes.home;
      } else {
        initialRoute = AppRoutes.wrapper;
      }
    } catch (e) {
      debugPrint('初期ルート判定エラー: $e');
    }

    // Fast Boot: 即座にアプリを起動
    runApp(
      ProviderScope(
        child: VEffectApp(initialRoute: initialRoute),
      ),
    );
  }, (error, stack) {
    if (!kIsWeb) {
      try {
        if (Firebase.apps.isNotEmpty) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        }
      } catch (_) {}
    }
    debugPrint('致命的なエラー: $error');
    runApp(GlobalErrorWidget(error: error.toString(), stackTrace: stack));
  });
}

/// Flutter Web はデフォルトでマウス/トラックパッドのドラッグによるスワイプが無効なため、
/// 全デバイスでドラッグ操作（PageView のスワイプ等）を有効にする
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.unknown,
      };
}

/// アプリの初期化状態を管理するラッパー
class AppInitializer extends StatefulWidget {
  final Widget child;
  const AppInitializer({super.key, required this.child});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isInitialized = false;
  bool _needsForceUpdate = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // DeepLink初期化を最優先で実行し、起動URL（veffect://cameraなど）を即時補足できるようにする
      unawaited(DeepLinkService().initialize().catchError((e) {
        debugPrint('DeepLink初期化エラー: $e');
      }));

      // 強制アップデートチェックはUI描画をブロックしないよう非同期で並列実行
      unawaited(ForceUpdateService.instance.checkForceUpdate().then((_) {
        if (ForceUpdateService.instance.needsForceUpdate && mounted) {
          setState(() {
            _needsForceUpdate = true;
          });
        }
      }).catchError((e) {
        debugPrint('強制アップデートチェックエラー: $e');
      }));

      // ── アプリ全体のオーディオセッションを強固に設定 ──
      // UIの描画をブロックさせないため、非同期で実行します（Fire-and-forget）
      Future(() async {
        try {
          final session = await AudioSession.instance;
          await session.configure(const AudioSessionConfiguration(
            avAudioSessionCategory: AVAudioSessionCategory.ambient,
            avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
            androidAudioAttributes: AndroidAudioAttributes(
              contentType: AndroidAudioContentType.sonification,
              usage: AndroidAudioUsage.assistanceSonification,
            ),
            androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
          ));
        } catch (e) {
          debugPrint('AudioSession初期化エラー: $e');
        }
      });

      // 非UIブロック項目の初期化
      if (!kIsWeb) {
        try {
          await MobileAds.instance.initialize();
        } catch (e) {
          debugPrint('AdMob初期化エラー: $e');
        }
      }
      PushNotificationService.onWeeklyReviewNotificationTap = () {
        final context = VEffectApp.navigatorKey.currentContext;
        if (context != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const WeeklyReviewScreen()),
          );
        }
      };
      PushNotificationService().initialize().catchError((e) => debugPrint('通知初期化エラー: $e'));
      SoundService.instance.init().catchError((e) => debugPrint('音声初期化エラー: $e'));
      WidgetService.instance.initialize().then((_) => _syncWidgetData()).catchError((e) => debugPrint('Widget初期化エラー: $e'));

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
        await WidgetService.instance.updateWidgetData();
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
      return const SplashLoading();
    }

    if (_needsForceUpdate) {
      return const ForceUpdateScreen();
    }

    return widget.child;
  }
}

class VEffectApp extends ConsumerStatefulWidget {
  final String initialRoute;
  const VEffectApp({super.key, required this.initialRoute});

  static final navigatorKey = GlobalKey<NavigatorState>();

  @override
  ConsumerState<VEffectApp> createState() => _VEffectAppState();
}

class _VEffectAppState extends ConsumerState<VEffectApp> with WidgetsBindingObserver {
  Timer? _midnightTimer;
  String _lastCheckedDate = '';
  // テーマ変更時に呼び出されるコールバック。
  // const指定されたウィジェットツリーも含めて、すべてのElementを強制的に再構築(rebuild)します。
  // これにより、画面遷移の履歴をリセット（再起動）することなく、テーマ切り替え時にconstウィジェットの配色が正しく即座に反映されます。
  void _onThemeChanged() {
    if (!mounted) return;
    void rebuildElement(Element element) {
      element.markNeedsBuild();
      element.visitChildren(rebuildElement);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        (context as Element).visitChildren(rebuildElement);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AnalyticsService.instance.onAppResumed();
    
    _lastCheckedDate = DateHelper.toDateString(DateTime.now());
    _scheduleMidnightTimer();

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
        WidgetService.instance.updateWidgetData();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      AnalyticsService.instance.onAppPaused();
      // バックグラウンド移行時にバッジを最新の未読件数に同期
      PushNotificationService().syncBadgeCount();
      // バックグラウンド移行時に、溜まった action_logs を確実に送信しきる
      AnalyticsService.instance.flushBatch();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ThemeMode>(themeProvider, (previous, next) {
      if (previous != next) {
        _onThemeChanged();
      }
    });

    final themeMode = ref.watch(themeProvider);
    final lang = ref.watch(languageProvider);
    return MaterialApp(
      navigatorKey: VEffectApp.navigatorKey,
      scrollBehavior: AppScrollBehavior(),
      title: 'V EFFECT',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja', 'JP'),
        Locale('en', 'US'),
      ],
      locale: Locale(lang),
      initialRoute: widget.initialRoute,
      // 🚀 【爆速化 & 競合解消】onGenerateInitialRoutes を明示定義
      // デフォルトでは '/camera' が ['/', '/camera'] に分割され、 AuthWrapper (/) が
      // カメラ画面を /home に強制置換してしまうため、ここで初期スタックを正確に構築する。
      onGenerateInitialRoutes: (initialRouteName) {
        if (initialRouteName == AppRoutes.camera) {
          return [
            MaterialPageRoute(
              settings: const RouteSettings(name: AppRoutes.home),
              builder: (context) => MainShell(initialIndex: 0),
            ),
            MaterialPageRoute(
              settings: const RouteSettings(name: AppRoutes.camera),
              builder: (context) => const CameraScreen(),
            ),
          ];
        } else if (initialRouteName == AppRoutes.home) {
          return [
            MaterialPageRoute(
              settings: const RouteSettings(name: AppRoutes.home),
              builder: (context) => MainShell(initialIndex: 0),
            ),
          ];
        }
        return [
          MaterialPageRoute(
            settings: const RouteSettings(name: AppRoutes.wrapper),
            builder: (context) => const AuthWrapper(),
          ),
        ];
      },
      routes: AppRoutes.routes,
      onGenerateRoute: (settings) {
        final name = settings.name ?? '';
        if (name.startsWith('/@')) {
          final username = name.substring(2);
          return MaterialPageRoute(
            settings: settings,
            builder: (context) => WebProfileWrapper(username: username),
          );
        }
        return null;
      },
      navigatorObservers: [AnalyticsService.instance.observer],
      builder: (context, child) {
        return AppInitializer(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
