import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// フレンドリクエストの状態
enum FriendRequestStatus { pending, accepted, rejected }

/// Firestore の friend_requests コレクションに対応するデータモデル
class FriendRequest {
  final String id;
  final String fromUid;
  final String toUid;
  final String fromUserId;
  final String fromUsername;
  final String toUserId;
  final String toUsername;
  final FriendRequestStatus status;
  final DateTime createdAt;

  // ── フィールド名定数 ──
  static const String fieldFromUid = 'fromUid';
  static const String fieldToUid = 'toUid';
  static const String fieldFromUserId = 'fromUserId';
  static const String fieldFromUsername = 'fromUsername';
  static const String fieldToUserId = 'toUserId';
  static const String fieldToUsername = 'toUsername';
  static const String fieldStatus = 'status';
  static const String fieldCreatedAt = 'createdAt';

  const FriendRequest({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.fromUserId,
    required this.fromUsername,
    required this.toUserId,
    required this.toUsername,
    required this.status,
    required this.createdAt,
  });

  factory FriendRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return FriendRequest.fromMap(doc.id, data ?? {});
  }

  factory FriendRequest.fromMap(String id, Map<String, dynamic> data) {
    try {
      return FriendRequest(
        id: id,
        fromUid: data[fieldFromUid]?.toString() ?? '',
        toUid: data[fieldToUid]?.toString() ?? '',
        fromUserId: data[fieldFromUserId]?.toString() ?? '',
        fromUsername: data[fieldFromUsername]?.toString() ?? '',
        toUserId: data[fieldToUserId]?.toString() ?? '',
        toUsername: data[fieldToUsername]?.toString() ?? '',
        status: FriendRequestStatus.values.firstWhere(
          (e) => e.name == data[fieldStatus],
          orElse: () => FriendRequestStatus.pending,
        ),
        createdAt: (data[fieldCreatedAt] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error parsing FriendRequest $id: $e');
      return FriendRequest(
        id: id,
        fromUid: '',
        toUid: '',
        fromUserId: '',
        fromUsername: '',
        toUserId: '',
        toUsername: '',
        status: FriendRequestStatus.pending,
        createdAt: DateTime.now(),
      );
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      fieldFromUid: fromUid,
      fieldToUid: toUid,
      fieldFromUserId: fromUserId,
      fieldFromUsername: fromUsername,
      fieldToUserId: toUserId,
      fieldToUsername: toUsername,
      fieldStatus: status.name,
      fieldCreatedAt: FieldValue.serverTimestamp(),
    };
  }
}
