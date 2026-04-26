import "package:v_effect/config/app_colors.dart";
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../config/routes.dart';

/// アプリ全体で共有するエラー表示用ウィジェット
class GlobalErrorWidget extends StatelessWidget {
  final FlutterErrorDetails? details;
  final String? error;

  const GlobalErrorWidget({super.key, this.details, this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.black,
        body: Builder(
          builder: (context) => Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    '申し訳ありません',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'アプリの起動中に問題が発生しました。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  if (kDebugMode && (details != null || error != null)) ...[
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 200),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          details?.exceptionAsString() ?? error ?? '未知のエラー',
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      // アプリの再起動を試みるため、wrapperへ戻る
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        AppRoutes.wrapper,
                        (route) => false,
                      );
                    },
                    child: const Text('再試行'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
