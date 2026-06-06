import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import '../config/routes.dart';
import '../services/analytics_service.dart';
import '../widgets/splash_loading.dart';
import '../widgets/global_error_widget.dart';
import 'login_screen.dart';
import 'dart:async';

/// 認証状態とプロフィール完了状態を監視し、適切な画面へルーティングするラッパー
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  // アプリ起動後に AuthWrapper が初めて評価されるタイミングだけ true。
  // cold-start + オンボーディング未完了の組み合わせで「サイレントログアウト」を発火させるためのゲート。
  static bool _isFirstLaunch = true;
  bool _navigating = false;
  // FutureBuilder の再ビルドで同じ future が再利用されるようキャッシュ
  Future<DocumentSnapshot?>? _userDocFuture;
  String? _lastUid;

  void _navigateTo(String route) {
    if (_navigating) return;
    _navigating = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, route);
      }
    });
  }

  /// 🚀 【爆速化 1】ローカルキャッシュを利用したゼロ・ディレイルーティング
  Future<DocumentSnapshot?> _fetchUserDocWithCacheBypass(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final isCompleted = prefs.getBool('onboardingCompleted_$uid') ?? false;
    
    if (isCompleted) {
      // キャッシュ上でオンボーディング完了済みと判定できれば、Firestoreの取得を待たずに即時 Home へルーティング！
      _isFirstLaunch = false;
      _navigateTo(AppRoutes.home);
      return null;
    }
    
    // キャッシュがない場合、または未完了の場合は通常通りFirestoreから状態を取得
    return FirebaseFirestore.instance.collection('users').doc(uid).get();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. まだ判定中
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashWithTimeout();
        }

        // 2. ログインしていない → ログイン画面へ
        if (!snapshot.hasData || snapshot.data == null) {
          _navigating = false;
          _userDocFuture = null;
          _lastUid = null;
          _isFirstLaunch = false;
          return const LoginScreen();
        }

        final user = snapshot.data!;

        // UID が変わったら future を再作成
        if (_lastUid != user.uid) {
          _lastUid = user.uid;
          _navigating = false;
          AnalyticsService.instance.setUserId(user.uid);
          
          _userDocFuture = _fetchUserDocWithCacheBypass(user.uid);
        }

        // メールアドレス認証の強制（2026-05-27以降の新規登録ユーザーのみ）
        final creationTime = user.metadata.creationTime;
        final cutoff = DateTime(2026, 5, 27);
        final isNewUser = creationTime != null && creationTime.isAfter(cutoff);
        if (!user.emailVerified &&
            isNewUser &&
            user.providerData.any((p) => p.providerId == 'password')) {
          _navigateTo(AppRoutes.emailVerification);
          return const _SplashWithTimeout();
        }

        // 3. ログイン済み → Firestore のデータを確認して分岐
        return FutureBuilder<DocumentSnapshot?>(
          future: _userDocFuture,
          builder: (context, docSnapshot) {
            if (docSnapshot.connectionState == ConnectionState.waiting) {
              return const _SplashWithTimeout();
            }

            if (docSnapshot.hasError) {
              final l10n = AppLocalizations.of(context)!;
              return GlobalErrorWidget(error: l10n.firestoreReadError(docSnapshot.error ?? ''));
            }

            // docSnapshot.data が null の場合は、キャッシュによる早期ルーティング中
            if (docSnapshot.data == null) {
              return const _SplashWithTimeout();
            }

            final actualDoc = docSnapshot.data!;

            // ドキュメントが存在しない or オンボーディング未完了 のまま cold-start で
            // 戻ってきた場合は、データを破壊せず<b>サイレントログアウト</b>して LoginScreen に戻す。
            // （以前はここで AuthService.deleteAccount() を呼んで全データを消していたが、
            //   Firestore の一時的取得失敗でも誤発火する致命的リスクがあったため廃止。
            //   オンボーディングは短く、cold-start で中断再開するケースは事実上ないとの判断。）
            void signOutAndBail(String reason) {
              _isFirstLaunch = false;
              FirebaseAuth.instance.signOut().catchError((e) {
                debugPrint('Auto sign-out failed ($reason): $e');
              });
            }

            if (!actualDoc.exists) {
              if (_isFirstLaunch) {
                signOutAndBail('no-user-doc');
                return const _SplashWithTimeout();
              }
              // 同一セッション中（新規登録直後など）はオンボーディングへ流す。
              _navigateTo(AppRoutes.onboardingVEffect);
              return const _SplashWithTimeout();
            }

            final data = actualDoc.data() as Map<String, dynamic>?;

            final isOnboardingCompleted = data?['onboardingCompleted'] == true;

            // 取得した最新状態が「完了」なら、次回のゼロ・ディレイルーティングのためにキャッシュに保存！
            if (isOnboardingCompleted) {
              SharedPreferences.getInstance().then((prefs) {
                prefs.setBool('onboardingCompleted_${user.uid}', true);
              });
            }

            // cold-start でオンボーディング未完了の場合はサイレントログアウト。
            // 同一セッション中（onboardingStep を逐次更新しながら進行中）の再構築では
            // 下の step 分岐で適切な画面に再開する。
            if (_isFirstLaunch && !isOnboardingCompleted) {
              signOutAndBail('onboarding-incomplete');
              return const _SplashWithTimeout();
            }
            _isFirstLaunch = false;

            if (isOnboardingCompleted) {
              _navigateTo(AppRoutes.home);
            } else {
              // onboardingStep を唯一の進捗ソースとして使う
              final step = data?['onboardingStep'] as String?;
              if (step == 'core_feature') {
                _navigateTo(AppRoutes.onboardingVEffect);
              } else if (step == 'profile_settings') {
                _navigateTo(AppRoutes.onboardingProfile);
              } else if (step == 'first_v_quest') {
                _navigateTo(AppRoutes.onboardingFirstQuest);
              } else {
                // null（新規ユーザー）/ 'v_effect' / 不明な値 → Screen 1 から開始
                _navigateTo(AppRoutes.onboardingVEffect);
              }
            }

            return const _SplashWithTimeout();
          },
        );
      },
    );
  }
}

/// タイムアウトメッセージを表示する拡張スプラッシュ
class _SplashWithTimeout extends StatefulWidget {
  const _SplashWithTimeout();

  @override
  State<_SplashWithTimeout> createState() => _SplashWithTimeoutState();
}

class _SplashWithTimeoutState extends State<_SplashWithTimeout> {
  bool _showTimeoutMessage = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _showTimeoutMessage = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const SplashLoading(),
        if (_showTimeoutMessage)
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  Text(
                    AppLocalizations.of(context)!.authWrapperConnecting,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      // 再読み込みを促す
                      Navigator.of(context).pushReplacementNamed(AppRoutes.wrapper);
                    },
                    child: Text(AppLocalizations.of(context)!.authWrapperRetry),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
