import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_effect/providers/theme_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('ThemeProvider defaults to dark mode and then loads', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Should be dark mode initially
    expect(container.read(themeProvider), ThemeMode.dark);

    // Wait for load to finish
    await container.read(themeProvider.notifier).loadFuture;

    // After load (empty preferences), defaults to system
    expect(container.read(themeProvider), ThemeMode.system);
  });

  test('ThemeProvider can change theme mode', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(themeProvider.notifier).loadFuture;

    await container.read(themeProvider.notifier).setThemeMode(ThemeMode.light);
    expect(container.read(themeProvider), ThemeMode.light);

    await container.read(themeProvider.notifier).setThemeMode(ThemeMode.dark);
    expect(container.read(themeProvider), ThemeMode.dark);
  });
}
