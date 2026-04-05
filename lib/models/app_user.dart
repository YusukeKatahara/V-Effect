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
    return AppUser(
      uid: doc.id,
      email: data['email'],
      username: data['username'],
      userId: data['userId'],
      displayName: data['displayName'],
      birthDate: data['birthDate'],
      gender: data['gender'],
      photoUrl: data['photoUrl'],
      streak: (data['streak'] as num?)?.toInt() ?? 0,
      lastPostedDate: data['lastPostedDate'],
      following: List<String>.from(data['following'] ?? data['friends'] ?? []),
      followers: List<String>.from(data['followers'] ?? data['friends'] ?? []),
      tasks: (data['tasks'] as List? ?? [])
          .map((item) => AppTask.fromFirestore(item))
          .toList(),
      wakeUpTime: data['wakeUpTime'],
      taskTime: data['taskTime'],
      occupation: data['occupation'],
      profileCompleted: data['profileCompleted'] ?? false,
      templateCompleted: data['templateCompleted'] ?? false,
      onboardingCompleted: data['onboardingCompleted'] ?? false,
      lastProfileEditDate: data['lastProfileEditDate'],
      pushNotifications: data['pushNotifications'] ?? true,
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
