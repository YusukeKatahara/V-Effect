import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/direct_chat.dart';
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
