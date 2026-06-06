import "package:v_effect/config/app_colors.dart";
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import '../main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// アプリ全体で共有するエラー表示用ウィジェット
class GlobalErrorWidget extends StatelessWidget {
  final FlutterErrorDetails? details;
  final String? error;

  const GlobalErrorWidget({super.key, this.details, this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        backgroundColor: AppColors.black,
        body: Builder(
          builder: (innerContext) {
            final l10n = AppLocalizations.of(innerContext);
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      l10n?.globalErrorTitle ?? '申し訳ありません',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n?.globalErrorDesc ?? 'アプリの起動中に問題が発生しました。',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
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
                            details?.exceptionAsString() ?? error ?? (l10n?.globalErrorUnknown ?? '未知のエラー'),
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
                        // アプリの再起動を試みるため、AppInitializerを再度runAppする
                        runApp(const ProviderScope(child: AppInitializer()));
                      },
                      child: Text(l10n?.globalErrorRetry ?? '再試行'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
