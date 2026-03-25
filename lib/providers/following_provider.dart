import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_user.dart';
import '../services/friend_service.dart';

/// ログインユーザーがフォローしているユーザーのリストをストリームで監視し、提供するProvider
final followingProvider = StreamProvider<List<AppUser>>((ref) {
  return FriendService.instance.getFollowing();
});
