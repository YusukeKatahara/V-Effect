import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  bool _navigating = false;
  // FutureBuilder の再ビルドで同じ future が再利用されるようキャッシュ
  Future<DocumentSnapshot>? _userDocFuture;
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
          return const LoginScreen();
        }

        final user = snapshot.data!;

        // メール未認証（メール/パスワード登録のみ対象）
        if (!user.emailVerified &&
            user.providerData.any((p) => p.providerId == 'password') &&
            !kDebugMode) {
          _navigating = false;
          _userDocFuture = null;
          _lastUid = null;
          _navigateTo(AppRoutes.emailVerification);
          return const _SplashWithTimeout();
        }

        // UID が変わったら future を再作成
        if (_lastUid != user.uid) {
          _lastUid = user.uid;
          _navigating = false;
          AnalyticsService.instance.setUserId(user.uid);
          // タイムアウト付きで取得を試みる（Firestore自体のタイムアウト設定は難しいため、FutureBuilder側で明示的にはしないが、
          // _SplashWithTimeout が背後で動くようにする）
          _userDocFuture =
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get();
        }

        // 3. ログイン済み → Firestore のデータを確認して分岐
        return FutureBuilder<DocumentSnapshot>(
          future: _userDocFuture,
          builder: (context, docSnapshot) {
            if (docSnapshot.connectionState == ConnectionState.waiting) {
              return const _SplashWithTimeout();
            }

            if (docSnapshot.hasError) {
              return GlobalErrorWidget(error: 'Firestore読み込みエラー: ${docSnapshot.error}');
            }

            // ドキュメントが存在しない → プロフィール設定へ
            if (!docSnapshot.hasData || !docSnapshot.data!.exists) {
              _navigateTo(AppRoutes.profileSetup);
              return const _SplashWithTimeout();
            }

            final data = docSnapshot.data!.data() as Map<String, dynamic>?;
            final isProfileCompleted = data?['profileCompleted'] == true;
            final isTemplateCompleted = data?['templateCompleted'] == true;
            final isOnboardingCompleted = data?['onboardingCompleted'] == true;

            if (!isProfileCompleted) {
              _navigateTo(AppRoutes.profileSetup);
            } else if (!isTemplateCompleted) {
              _navigateTo(AppRoutes.taskTemplate);
            } else if (!isOnboardingCompleted) {
              _navigateTo(AppRoutes.taskSetup);
            } else {
              _navigateTo(AppRoutes.home);
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
