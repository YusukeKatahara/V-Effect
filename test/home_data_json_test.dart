import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_effect/models/app_user.dart';
import 'package:v_effect/models/app_task.dart';
import 'package:v_effect/providers/home_provider.dart';

void main() {
  test('HomeData.toJson with AppUser containing task with completedAt throws or serializes', () {
    final user = AppUser(
      uid: 'u1',
      username: 'user1',
      tasks: [
        AppTask(
          title: 'task1',
          completedAt: DateTime.now(),
        ),
      ],
      mutualFires: {
        'f1': DateTime.now(),
      },
    );

    final homeData = HomeData(
      streak: 5,
      postedToday: true,
      isAllTasksCompleted: false,
      username: 'user1',
      tasks: [],
      followingUids: [],
      feedPosts: [],
      postedFriends: [],
      userNames: {},
      userPhotos: {},
      userStreaks: {},
      userBadgeUrls: {},
      userBadgeAnimations: {},
      isRecommended: false,
      totalPosts: 0,
      user: user,
    );

    final jsonMap = homeData.toJson();
    final jsonStr = jsonEncode(jsonMap);
    final decodedMap = jsonDecode(jsonStr) as Map<String, dynamic>;
    final restoredHomeData = HomeData.fromJson(decodedMap);

    expect(restoredHomeData.user, isNotNull);
    expect(restoredHomeData.user!.username, equals('user1'));
    expect(restoredHomeData.user!.tasks.first.title, equals('task1'));
    expect(restoredHomeData.user!.tasks.first.completedAt, isNotNull);
    expect(restoredHomeData.user!.mutualFires['f1'], isNotNull);
  });
}
