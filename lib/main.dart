import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/camera_screen.dart';

/// 【rennさんへ】
/// この main.dart はアプリの「玄関」です。
/// アプリが起動した時に一番最初に読み込まれる重要なファイルです。
void main() async {
  // Flutterのエンジンが完全に準備されるまで待つおまじないです。
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase（データベースや認証機能）を初期化します。
  try {
    await Firebase.initializeApp();
  } catch (e) {
    // もしFirebaseの設定ファイルがない場合はここでエラーがキャッチされます。
    // 後で flutterfire configure コマンドを実行して設定ファイルを作りましょう。
    debugPrint('Firebase連携エラー: $e');
  }

  // アプリ全体を起動します。
  runApp(const VEffectApp());
}

/// 【rennさんへ】
/// VEffectAppクラスはアプリ全体のデザインや画面構成（ルーティング）を定義しています。
/// StatelessWidget は「状態を持たない（画面自体が変化しない）」基本の枠組みです。
class VEffectApp extends StatelessWidget {
  const VEffectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'V-Effect',
      // Material 3 という最新のデザインガイドラインを使います。
      // テーマカラーは深い紫色（deepPurple）をベースにしたダークモード（暗い背景）です。
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      // 最初に表示される画面をログイン画面に設定しています。
      initialRoute: '/login',
      // 画面の「住所（URLのようなもの）」を定義しています。
      // これにより、 Navigator.pushNamed(context, '/home') のようにして画面移動ができます。
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/feed': (context) => const FeedScreen(),
        '/camera': (context) => const CameraScreen(),
      },
    );
  }
}
