import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import 'package:v_effect/screens/home/components/new_posts_button.dart';

void main() {
  testWidgets('NewPostsButton renders correctly and triggers onTap on tap', (WidgetTester tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: NewPostsButton(
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      ),
    );

    // アニメーション完了まで待機
    await tester.pumpAndSettle();

    // アイコンとテキストが存在することを確認
    expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    expect(find.text('新しい投稿があります'), findsOneWidget);

    // タップイベントを発火
    await tester.tap(find.byType(GestureDetector).last);
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });
}
