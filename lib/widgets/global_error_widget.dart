import "package:v_effect/config/app_colors.dart";
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import '../main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide ChangeNotifierProvider;
import 'package:provider/provider.dart';
import 'package:v_effect/providers/theme_provider.dart';

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
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.redAccent,
                      size: 64,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n?.globalErrorTitle ?? 'エラーが発生しました',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n?.globalErrorDesc ?? '申し訳ありません。予期しない問題が発生したため、アプリを再起動してください。',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (kDebugMode || error != null) ...[
                      Text(
                        'エラー詳細:',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
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
                      ),
                    ],
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () {
                        // アプリの再起動を試みるため、rootAppを再度runAppする
                        runApp(
                          ProviderScope(
                            child: MultiProvider(
                              providers: [
                                ChangeNotifierProvider<ThemeProvider>(
                                  create: (_) => ThemeProvider(),
                                ),
                              ],
                              child: const VEffectApp(),
                            ),
                          ),
                        );
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
