import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/routes.dart';
import '../services/analytics_service.dart';
import '../widgets/splash_loading.dart';
import 'login_screen.dart';

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
          return const SplashLoading();
        }

        // 2. ログインしていない → ログイン画面へ
        if (!snapshot.hasData || snapshot.data == null) {
          _navigating = false;
          _userDocFuture = null;
          _lastUid = null;
          return const LoginScreen();
        }

        final user = snapshot.data!;

        // UID が変わったら future を再作成（ログインユーザー切り替え対応）
        if (_lastUid != user.uid) {
          _lastUid = user.uid;
          _navigating = false;
          // Analytics にユーザーIDを設定
          AnalyticsService.instance.setUserId(user.uid);
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
              return const SplashLoading();
            }

            // ドキュメントが存在しない → プロフィール設定へ
            if (!docSnapshot.hasData || !docSnapshot.data!.exists) {
              _navigateTo(AppRoutes.profileSetup);
              return const SplashLoading();
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

            return const SplashLoading();
          },
        );
      },
    );
  }
}
