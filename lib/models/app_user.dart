import 'package:cloud_firestore/cloud_firestore.dart';

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
  final List<String> tasks;
  final String? wakeUpTime;
  final String? taskTime;
  final String? occupation;
  final bool profileCompleted;
  final bool templateCompleted;
  final bool onboardingCompleted;
  final int? lastProfileEditDate;
  final bool pushNotifications;
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
    this.isPrivateAccount = false,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Helper to safely get String from potential Map or non-string (avoid crash if Firestore has dirty data)
    String? _safeString(dynamic value) {
      if (value == null) return null;
      if (value is String) return value;
      return value.toString();
    }

    // Helper to extract UIDs from either a List or a Map (legacy format support)
    List<String> _extractUids(String fieldName1, [String? fieldName2]) {
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
      email: _safeString(data['email']),
      username: _safeString(data['username']),
      userId: _safeString(data['userId']),
      displayName: _safeString(data['displayName']),
      birthDate: _safeString(data['birthDate']),
      gender: _safeString(data['gender']),
      photoUrl: _safeString(data['photoUrl']),
      streak: (data['streak'] as num?)?.toInt() ?? 0,
      lastPostedDate: _safeString(data['lastPostedDate']),
      following: _extractUids('following', 'friends'),
      followers: _extractUids('followers', 'friends'),
      tasks: _extractUids('tasks'),
      wakeUpTime: _safeString(data['wakeUpTime']),
      taskTime: _safeString(data['taskTime']),
      occupation: _safeString(data['occupation']),
      profileCompleted: data['profileCompleted'] ?? false,
      templateCompleted: data['templateCompleted'] ?? false,
      onboardingCompleted: data['onboardingCompleted'] ?? false,
      lastProfileEditDate: data['lastProfileEditDate'] is num
          ? (data['lastProfileEditDate'] as num).toInt()
          : null,

      pushNotifications: data['pushNotifications'] ?? true,
      isPrivateAccount: data['isPrivateAccount'] ?? false,
    );
  }
}
