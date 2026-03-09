import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/routes.dart';
import 'login_screen.dart';

/// 認証状態とプロフィール完了状態を監視し、適切な画面へルーティングするラッパー
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. まだ判定中
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. ログインしていない ➔ ログイン画面へ
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginScreen();
        }

        final user = snapshot.data!;

        // 3. ログイン済み ➔ Firestoreのデータを確認して分岐
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
          builder: (context, docSnapshot) {
            if (docSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // ドキュメントが存在しない or profileCompletedがtrueでない ➔ プロフィール設定へ
            if (!docSnapshot.hasData || !docSnapshot.data!.exists) {
              // 少し遅延を入れてルーティング（build中のエラーを防ぐため）
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pushReplacementNamed(context, AppRoutes.profileSetup);
              });
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final data = docSnapshot.data!.data() as Map<String, dynamic>?;
            final isProfileCompleted = data?['profileCompleted'] == true;
            final isOnboardingCompleted = data?['onboardingCompleted'] == true;

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!isProfileCompleted) {
                // Step 1: プロフィール基本情報が未入力
                Navigator.pushReplacementNamed(context, AppRoutes.profileSetup);
              } else if (!isOnboardingCompleted) {
                // Step 2: タスク設定が未入力
                Navigator.pushReplacementNamed(context, AppRoutes.taskSetup);
              } else {
                // 全て完了 ➔ ホーム画面へ
                Navigator.pushReplacementNamed(context, AppRoutes.home);
              }
            });

            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          },
        );
      },
    );
  }
}
