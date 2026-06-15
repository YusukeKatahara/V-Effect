import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_effect/models/post.dart';
import 'package:v_effect/screens/home/components/feed_card.dart';

void main() {
  testWidgets('FeedCard should crash with RangeError when username is empty and userPhotoUrl is null', (WidgetTester tester) async {
    final post = Post(
      id: 'test_post_id',
      userId: 'test_user_id',
      taskName: 'Task Name',
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
    );

    // Build the FeedCard with an empty username and null photo URL
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FeedCard(
            post: post,
            username: '',
            userPhotoUrl: null,
            dimAlpha: 0.0,
            onReaction: ({emoji}) {},
            isTop: true,
            tierColor: Colors.yellow,
          ),
        ),
      ),
    );

    // Expecting a RangeError/FlutterError due to empty string index access
    final exception = tester.takeException();
    expect(exception, isNotNull);
    expect(exception.toString(), contains('RangeError'));
  });
}
