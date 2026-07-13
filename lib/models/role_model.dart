import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// 他のユーザーをロールモデル（目標とする人）として登録した際の関係を表すデータモデル
class RoleModel {
  /// 対象ユーザーのUID（ユーザー識別ID）
  final String targetUid;

  /// 対象ユーザーの表示名（画面表示の高速化のためのキャッシュ）
  final String displayName;

  /// 対象ユーザーのユーザー名（画面表示の高速化のためのキャッシュ）
  final String username;

  /// 対象ユーザーのプロフィール画像URL（未設定時はnull）
  final String? photoUrl;

  /// ロールモデルに登録した日時
  final DateTime createdAt;

  // ── フィールド名定数 ──
  static const String fieldTargetUid = 'targetUid';
  static const String fieldDisplayName = 'displayName';
  static const String fieldUsername = 'username';
  static const String fieldPhotoUrl = 'photoUrl';
  static const String fieldCreatedAt = 'createdAt';

  const RoleModel({
    required this.targetUid,
    required this.displayName,
    required this.username,
    this.photoUrl,
    required this.createdAt,
  });

  /// FirestoreのDocumentSnapshotからRoleModelインスタンスを生成します
  factory RoleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return RoleModel.fromMap(data ?? {});
  }

  /// MapからRoleModelインスタンスを復元します（堅牢なパース処理）
  factory RoleModel.fromMap(Map<String, dynamic> data) {
    try {
      DateTime parseCreatedAt() {
        final val = data[fieldCreatedAt];
        if (val is Timestamp) {
          return val.toDate();
        }
        if (val is DateTime) {
          return val;
        }
        if (val is String) {
          return DateTime.tryParse(val) ?? DateTime.now();
        }
        return DateTime.now();
      }

      return RoleModel(
        targetUid: data[fieldTargetUid]?.toString() ?? '',
        displayName: data[fieldDisplayName]?.toString() ?? '',
        username: data[fieldUsername]?.toString() ?? '',
        photoUrl: data[fieldPhotoUrl]?.toString(),
        createdAt: parseCreatedAt(),
      );
    } catch (e) {
      debugPrint('Error parsing RoleModel: $e');
      return RoleModel(
        targetUid: '',
        displayName: '',
        username: '',
        createdAt: DateTime.now(),
      );
    }
  }

  /// Firestore保存用のMapを生成します
  Map<String, dynamic> toFirestore() {
    return {
      fieldTargetUid: targetUid,
      fieldDisplayName: displayName,
      fieldUsername: username,
      fieldPhotoUrl: photoUrl,
      fieldCreatedAt: Timestamp.fromDate(createdAt),
    };
  }

  /// 一般的なMap（JSON等）への変換を行います
  Map<String, dynamic> toMap() {
    return {
      fieldTargetUid: targetUid,
      fieldDisplayName: displayName,
      fieldUsername: username,
      fieldPhotoUrl: photoUrl,
      fieldCreatedAt: createdAt.toIso8601String(),
    };
  }

  /// 一部のフィールドのみを更新した新しいRoleModelインスタンスを生成します
  RoleModel copyWith({
    String? targetUid,
    String? displayName,
    String? username,
    String? photoUrl,
    DateTime? createdAt,
  }) {
    return RoleModel(
      targetUid: targetUid ?? this.targetUid,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
