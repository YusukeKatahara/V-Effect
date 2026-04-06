import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_task.dart';

/// Firestore の users コレクションに対応するデータモデル
class AppUser {
  final String uid;
  final String? email;
  final String? username;
  final String? userId;
  final String? displayName;
  final String? birthDate;
  final String? gender;
  final String? photoUrl;
  final int streak;
  final String? lastPostedDate;
  final List<String> following;
  final List<String> followers;
  final List<AppTask> tasks;
  final String? wakeUpTime;
  final String? taskTime;
  final String? occupation;
  final bool profileCompleted;
  final bool templateCompleted;
  final bool onboardingCompleted;
  final int? lastProfileEditDate;
  final bool pushNotifications;
  final bool focusTimeNotifications;
  final bool isPrivateAccount;

  const AppUser({
    required this.uid,
    this.email,
    this.username,
    this.userId,
    this.displayName,
    this.birthDate,
    this.gender,
    this.photoUrl,
    this.streak = 0,
    this.lastPostedDate,
    this.following = const [],
    this.followers = const [],
    this.tasks = const [],
    this.wakeUpTime,
    this.taskTime,
    this.occupation,
    this.profileCompleted = false,
    this.templateCompleted = false,
    this.onboardingCompleted = false,
    this.lastProfileEditDate,
    this.pushNotifications = true,
    this.focusTimeNotifications = true,
    this.isPrivateAccount = false,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    String? safeString(dynamic value) {
      if (value == null) return null;
      if (value is String) return value;
      return value.toString();
    }

    // Helper to extract UIDs from either a List or a Map (legacy format support)
    List<String> extractUids(String fieldName1, [String? fieldName2]) {
      final raw = data[fieldName1] ?? (fieldName2 != null ? data[fieldName2] : null);
      if (raw == null) return [];
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      if (raw is Map) {
        // Legacy format: { "uid1": true, "uid2": true }
        return raw.keys.map((k) => k.toString()).toList();
      }
      return [];
    }

    return AppUser(
      uid: doc.id,
      email: safeString(data['email']),
      username: safeString(data['username']),
      userId: safeString(data['userId']),
      displayName: safeString(data['displayName']),
      birthDate: safeString(data['birthDate']),
      gender: safeString(data['gender']),
      photoUrl: safeString(data['photoUrl']),
      streak: (data['streak'] as num?)?.toInt() ?? 0,
      lastPostedDate: safeString(data['lastPostedDate']),
      following: extractUids('following', 'friends'),
      followers: extractUids('followers', 'friends'),
      tasks: (data['tasks'] as List? ?? [])
          .map((item) => AppTask.fromFirestore(item))
          .toList(),
      wakeUpTime: safeString(data['wakeUpTime']),
      taskTime: safeString(data['taskTime']),
      occupation: safeString(data['occupation']),
      profileCompleted: data['profileCompleted'] ?? false,
      templateCompleted: data['templateCompleted'] ?? false,
      onboardingCompleted: data['onboardingCompleted'] ?? false,
      lastProfileEditDate: data['lastProfileEditDate'] is num
          ? (data['lastProfileEditDate'] as num).toInt()
          : null,

      pushNotifications: data['pushNotifications'] ?? true,
      focusTimeNotifications: data['focusTimeNotifications'] ?? true,
      isPrivateAccount: data['isPrivateAccount'] ?? false,
    );
  }

  /// Firestore 保存用の Map を生成します
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'username': username,
      'userId': userId,
      'displayName': displayName,
      'birthDate': birthDate,
      'gender': gender,
      'photoUrl': photoUrl,
      'streak': streak,
      'lastPostedDate': lastPostedDate,
      'following': following,
      'followers': followers,
      'tasks': tasks.map((t) => t.toFirestore()).toList(),
      'wakeUpTime': wakeUpTime,
      'taskTime': taskTime,
      'occupation': occupation,
      'profileCompleted': profileCompleted,
      'templateCompleted': templateCompleted,
      'onboardingCompleted': onboardingCompleted,
      'lastProfileEditDate': lastProfileEditDate,
      'pushNotifications': pushNotifications,
      'isPrivateAccount': isPrivateAccount,
    };
  }
}
