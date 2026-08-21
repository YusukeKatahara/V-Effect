import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/direct_chat.dart';

/// ダイレクトメッセージの送受信・Firestore通信を担当するサービスクラス
class DirectChatService {
  DirectChatService._();
  static final DirectChatService instance = DirectChatService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _chatsCollection =>
      _firestore.collection('direct_chats');

  /// 自分が参加しているチャットルーム一覧をリアルタイム購読（クライアント側ソートでインデックス依存を排除）
  Stream<List<DirectChatRoom>> getRoomsStream(String currentUid) {
    if (currentUid.isEmpty) return Stream.value([]);
    return _chatsCollection
        .where('participants', arrayContains: currentUid)
        .snapshots()
        .map((snapshot) {
      final rooms = snapshot.docs
          .map((doc) => DirectChatRoom.fromFirestore(doc))
          .toList();
      rooms.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return rooms;
    }).handleError((error) {
      debugPrint('DirectChatService getRoomsStream error (suppressed): $error');
      return <DirectChatRoom>[];
    });
  }

  /// 指定したチャットルームのメッセージ一覧をリアルタイム購読（最新順）
  Stream<List<DirectChatMessage>> getMessagesStream(String chatId, {int limit = 50}) {
    if (chatId.isEmpty) return Stream.value([]);
    return _chatsCollection
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => DirectChatMessage.fromFirestore(doc))
          .toList();
    }).handleError((error) {
      debugPrint('DirectChatService getMessagesStream error (suppressed): $error');
      return <DirectChatMessage>[];
    });
  }

  /// 全チャットの自分宛ての未読合計件数をリアルタイム購読
  Stream<int> getTotalUnreadCountStream(String currentUid) {
    if (currentUid.isEmpty) return Stream.value(0);
    return _chatsCollection
        .where('participants', arrayContains: currentUid)
        .snapshots()
        .map((snapshot) {
      int total = 0;
      for (final doc in snapshot.docs) {
        final room = DirectChatRoom.fromFirestore(doc);
        total += room.getUnreadCount(currentUid);
      }
      return total;
    }).handleError((error) {
      debugPrint('DirectChatService getTotalUnreadCountStream error (suppressed): $error');
      return 0;
    });
  }

  /// チャットルームを取得または初期化
  Future<DirectChatRoom> getOrCreateRoom({
    required String currentUid,
    required String otherUid,
    required String currentUserName,
    String? currentUserPhoto,
    required String otherUserName,
    String? otherUserPhoto,
  }) async {
    final roomId = DirectChatRoom.generateRoomId(currentUid, otherUid);
    final roomDoc = await _chatsCollection.doc(roomId).get();

    if (roomDoc.exists) {
      return DirectChatRoom.fromFirestore(roomDoc);
    }

    final newRoom = DirectChatRoom(
      id: roomId,
      participants: [currentUid, otherUid],
      participantDetails: {
        currentUid: DirectChatParticipant(
          uid: currentUid,
          name: currentUserName,
          photoUrl: currentUserPhoto,
        ),
        otherUid: DirectChatParticipant(
          uid: otherUid,
          name: otherUserName,
          photoUrl: otherUserPhoto,
        ),
      },
      unreadCounts: {
        currentUid: 0,
        otherUid: 0,
      },
      updatedAt: DateTime.now(),
    );

    await _chatsCollection.doc(roomId).set(newRoom.toFirestore());
    return newRoom;
  }

  /// メッセージを送信
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String otherUid,
    required String text,
    required DirectChatParticipant senderInfo,
    required DirectChatParticipant receiverInfo,
  }) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return;
    if (trimmedText.length > 500) {
      throw ArgumentError('Message must be 500 characters or less.');
    }

    final now = DateTime.now();
    final messageRef = _chatsCollection.doc(chatId).collection('messages').doc();

    final messageData = DirectChatMessage(
      id: messageRef.id,
      senderId: senderId,
      text: trimmedText,
      createdAt: now,
      isRead: false,
    );

    final batch = _firestore.batch();

    // 1. メッセージドキュメントの作成
    batch.set(messageRef, messageData.toFirestore());

    // 2. チャットルームのメタデータ更新（最終メッセージ、未読インクリメント、更新日時）
    final roomRef = _chatsCollection.doc(chatId);
    batch.set(
      roomRef,
      {
        'participants': [senderId, otherUid],
        'participantDetails': {
          senderId: senderInfo.toMap(),
          otherUid: receiverInfo.toMap(),
        },
        'lastMessage': {
          'text': trimmedText,
          'senderId': senderId,
          'createdAt': FieldValue.serverTimestamp(),
        },
        'unreadCounts.$otherUid': FieldValue.increment(1),
        'unreadCounts.$senderId': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  /// 未読メッセージを既読にする
  Future<void> markAsRead({
    required String chatId,
    required String currentUid,
  }) async {
    if (chatId.isEmpty || currentUid.isEmpty) return;
    try {
      final roomRef = _chatsCollection.doc(chatId);
      final roomSnap = await roomRef.get();
      if (!roomSnap.exists) {
        // まだメッセージが送信されていない新規チャットの場合は何もしない
        return;
      }

      // 未読数を0にリセット
      await roomRef.update({
        'unreadCounts.$currentUid': 0,
      });

      // 相手が送信した未読メッセージを既読に更新（直近20件）
      final unreadMessages = await roomRef
          .collection('messages')
          .where('senderId', isNotEqualTo: currentUid)
          .where('isRead', isEqualTo: false)
          .limit(20)
          .get();

      if (unreadMessages.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in unreadMessages.docs) {
          batch.update(doc.reference, {'isRead': true});
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('DirectChatService markAsRead error (suppressed): $e');
    }
  }

  /// チャット履歴の削除（ルームとメッセージの削除）
  Future<void> deleteRoom(String chatId) async {
    final roomRef = _chatsCollection.doc(chatId);
    final messages = await roomRef.collection('messages').limit(100).get();
    final batch = _firestore.batch();
    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(roomRef);
    await batch.commit();
  }
}
