import 'package:cloud_firestore/cloud_firestore.dart';

/// チャット参加者の簡易プロフィール情報（非正規化データ）
class DirectChatParticipant {
  final String uid;
  final String name;
  final String? photoUrl;

  const DirectChatParticipant({
    required this.uid,
    required this.name,
    this.photoUrl,
  });

  factory DirectChatParticipant.fromMap(String uid, Map<String, dynamic>? data) {
    if (data == null) {
      return DirectChatParticipant(uid: uid, name: 'Unknown');
    }
    return DirectChatParticipant(
      uid: uid,
      name: (data['name'] as String?)?.isNotEmpty == true
          ? data['name'] as String
          : 'Unknown',
      photoUrl: data['photoUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'photoUrl': photoUrl,
    };
  }
}

/// 最後のメッセージ情報
class DirectChatLastMessage {
  final String text;
  final String senderId;
  final DateTime createdAt;

  const DirectChatLastMessage({
    required this.text,
    required this.senderId,
    required this.createdAt,
  });

  factory DirectChatLastMessage.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return DirectChatLastMessage(
        text: '',
        senderId: '',
        createdAt: DateTime.now(),
      );
    }
    DateTime parsedDate = DateTime.now();
    final rawDate = data['createdAt'];
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    }

    return DirectChatLastMessage(
      text: (data['text'] as String?) ?? '',
      senderId: (data['senderId'] as String?) ?? '',
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'senderId': senderId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// 1対1のダイレクトチャットルーム
class DirectChatRoom {
  final String id;
  final List<String> participants;
  final Map<String, DirectChatParticipant> participantDetails;
  final DirectChatLastMessage? lastMessage;
  final Map<String, int> unreadCounts;
  final DateTime updatedAt;

  const DirectChatRoom({
    required this.id,
    required this.participants,
    required this.participantDetails,
    this.lastMessage,
    this.unreadCounts = const {},
    required this.updatedAt,
  });

  /// ルームIDの生成ヘルパー（2人のUIDをソートして結合し重複を防ぐ）
  static String generateRoomId(String uidA, String uidB) {
    final sorted = [uidA, uidB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  /// 相手のユーザー情報を取得するヘルパー
  DirectChatParticipant? getOtherParticipant(String currentUid) {
    for (final p in participants) {
      if (p != currentUid) {
        return participantDetails[p] ?? DirectChatParticipant(uid: p, name: 'Unknown');
      }
    }
    return null;
  }

  /// 自分の未読件数を取得するヘルパー
  int getUnreadCount(String currentUid) {
    return unreadCounts[currentUid] ?? 0;
  }

  factory DirectChatRoom.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final participantsList = (data['participants'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final detailsMap = <String, DirectChatParticipant>{};
    final rawDetails = data['participantDetails'] as Map<String, dynamic>?;
    if (rawDetails != null) {
      rawDetails.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          detailsMap[key] = DirectChatParticipant.fromMap(key, value);
        }
      });
    }

    final rawUnread = data['unreadCounts'] as Map<String, dynamic>?;
    final unreadMap = <String, int>{};
    if (rawUnread != null) {
      rawUnread.forEach((key, value) {
        if (value is num) {
          unreadMap[key] = value.toInt();
        }
      });
    }

    DateTime parsedUpdated = DateTime.now();
    final rawUpdated = data['updatedAt'];
    if (rawUpdated is Timestamp) {
      parsedUpdated = rawUpdated.toDate();
    } else if (rawUpdated is String) {
      parsedUpdated = DateTime.tryParse(rawUpdated) ?? DateTime.now();
    }

    return DirectChatRoom(
      id: doc.id,
      participants: participantsList,
      participantDetails: detailsMap,
      lastMessage: data['lastMessage'] != null
          ? DirectChatLastMessage.fromMap(data['lastMessage'] as Map<String, dynamic>?)
          : null,
      unreadCounts: unreadMap,
      updatedAt: parsedUpdated,
    );
  }

  Map<String, dynamic> toFirestore() {
    final detailsData = <String, dynamic>{};
    participantDetails.forEach((key, value) {
      detailsData[key] = value.toMap();
    });

    return {
      'participants': participants,
      'participantDetails': detailsData,
      'lastMessage': lastMessage?.toMap(),
      'unreadCounts': unreadCounts,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

/// チャット内の個別メッセージ
class DirectChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;
  final bool isRead;

  const DirectChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.isRead = false,
  });

  factory DirectChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime parsedDate = DateTime.now();
    final rawDate = data['createdAt'];
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    }

    return DirectChatMessage(
      id: doc.id,
      senderId: (data['senderId'] as String?) ?? '',
      text: (data['text'] as String?) ?? '',
      createdAt: parsedDate,
      isRead: (data['isRead'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
    };
  }
}
