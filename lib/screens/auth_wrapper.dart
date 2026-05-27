import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/routes.dart';
import '../services/analytics_service.dart';
import '../widgets/splash_loading.dart';
import '../widgets/global_error_widget.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'dart:async';

/// 認証状態とプロフィール完了状態を監視し、適切な画面へルーティングするラッパー
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
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

        // 🚨 【追加】メールアドレス認証の強制（Apple/Google等以外）
        if (!user.emailVerified && user.providerData.any((p) => p.providerId == 'password')) {
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
              return GlobalErrorWidget(error: 'Firestore読み込みエラー: ${docSnapshot.error}');
            }

            // docSnapshot.data が null の場合は、キャッシュによる早期ルーティング中
            if (docSnapshot.data == null) {
              return const _SplashWithTimeout();
            }

            final actualDoc = docSnapshot.data!;

            // ドキュメントが存在しない → オンボーディング開始
            if (!actualDoc.exists) {
              if (_isFirstLaunch) {
                _isFirstLaunch = false;
                AuthService().deleteAccount().catchError((e) {
                  debugPrint('Incomplete account delete error: $e');
                  FirebaseAuth.instance.signOut();
                });
                return const _SplashWithTimeout();
              }
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

            // アプリ起動時にオンボーディング未完了ならアカウントを削除してやり直させる
            if (_isFirstLaunch && !isOnboardingCompleted) {
              _isFirstLaunch = false;
              AuthService().deleteAccount().catchError((e) {
                debugPrint('Incomplete account delete error: $e');
                FirebaseAuth.instance.signOut();
              });
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
                  const Text(
                    '接続に時間がかかっています...',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      // 再読み込みを促す
                      Navigator.of(context).pushReplacementNamed(AppRoutes.wrapper);
                    },
                    child: const Text('再試行'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
