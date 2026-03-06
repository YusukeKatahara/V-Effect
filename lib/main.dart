import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'config/routes.dart';
import 'config/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase連携エラー: $e');
  }

  runApp(const VEffectApp());
}

class VEffectApp extends StatelessWidget {
  const VEffectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'V-Effect',
      theme: AppTheme.dark,
      initialRoute: AppRoutes.login,
      routes: AppRoutes.routes,
    );
  }
}
