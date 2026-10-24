import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import '../models/direct_chat.dart';
import '../utils/date_helper.dart';
import 'service_providers.dart';

/// 認証状態のリアルタイムストリーム
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// 現在ログイン中のユーザーIDを提供するプロバイダー（認証状態と完全同期）
final currentAuthUidProvider = Provider<String?>((ref) {
  final authUser = ref.watch(authStateProvider).value;
  return authUser?.uid ?? FirebaseAuth.instance.currentUser?.uid;
});

/// 現在ログイン中のユーザー情報（自分の一言・アイコン等）をリアルタイム購読するプロバイダー
final currentUserStreamProvider = StreamProvider.autoDispose<AppUser?>((ref) {
  final uid = ref.watch(currentAuthUidProvider);
  if (uid == null || uid.isEmpty) {
    return Stream.value(null);
  }
  final userService = ref.watch(userServiceProvider);
  return userService.watchUser(uid);
});

/// DM画面上部の「一言欄（V-Note）」に表示するフォロー中ユーザー一覧プロバイダー
/// （24時間以内に一言を設定中のユーザーを最優先で左側に並べ、次に今日達成済み・ストリーク順でソート）
final statusNoteUsersProvider = StreamProvider.autoDispose<List<AppUser>>((ref) {
  final uid = ref.watch(currentAuthUidProvider);
  if (uid == null || uid.isEmpty) {
    return Stream.value([]);
  }
  final friendService = ref.watch(friendServiceProvider);
  return friendService.getFollowing().map((users) {
    final today = DateHelper.toDateString(DateTime.now());
    final sorted = List<AppUser>.from(users);
    sorted.sort((a, b) {
      final aHasNote = a.hasActiveStatusNote;
      final bHasNote = b.hasActiveStatusNote;
      if (aHasNote != bHasNote) {
        return aHasNote ? -1 : 1;
      }
      if (aHasNote && bHasNote) {
        final aTime = a.statusNoteUpdatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.statusNoteUpdatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      }
      final aDoneToday = a.lastPostedDate == today;
      final bDoneToday = b.lastPostedDate == today;
      if (aDoneToday != bDoneToday) {
        return aDoneToday ? -1 : 1;
      }
      return b.streak.compareTo(a.streak);
    });
    return sorted;
  });
});

/// チャットルーム一覧のリアルタイム購読プロバイダー
final directChatRoomsStreamProvider = StreamProvider.autoDispose<List<DirectChatRoom>>((ref) {
  final uid = ref.watch(currentAuthUidProvider);
  if (uid == null) {
    return Stream.value([]);
  }
  final chatService = ref.watch(directChatServiceProvider);
  return chatService.getRoomsStream(uid);
});

/// 指定チャットルームのメッセージ一覧購読プロバイダー
final directChatMessagesStreamProvider =
    StreamProvider.autoDispose.family<List<DirectChatMessage>, String>((ref, chatId) {
  final chatService = ref.watch(directChatServiceProvider);
  return chatService.getMessagesStream(chatId);
});

/// ダイレクトメッセージの未読合計数を購読するプロバイダー
final directChatTotalUnreadCountProvider = StreamProvider.autoDispose<int>((ref) {
  final uid = ref.watch(currentAuthUidProvider);
  if (uid == null) {
    return Stream.value(0);
  }
  final chatService = ref.watch(directChatServiceProvider);
  return chatService.getTotalUnreadCountStream(uid);
});
