import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore の users コレクションに対応するデータモデル
class AppUser {
  final String uid;
  final String? email;
  final String? username;
  final String? userId;
  final String? displayName;
  final int streak;
  final String? lastPostedDate;
  final List<String> friends;
  final List<String> tasks;
  final String? wakeUpTime;
  final String? taskTime;
  final bool profileCompleted;
  final bool onboardingCompleted;

  const AppUser({
    required this.uid,
    this.email,
    this.username,
    this.userId,
    this.displayName,
    this.streak = 0,
    this.lastPostedDate,
    this.friends = const [],
    this.tasks = const [],
    this.wakeUpTime,
    this.taskTime,
    this.profileCompleted = false,
    this.onboardingCompleted = false,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      email: data['email'],
      username: data['username'],
      userId: data['userId'],
      displayName: data['displayName'],
      streak: (data['streak'] as num?)?.toInt() ?? 0,
      lastPostedDate: data['lastPostedDate'],
      friends: List<String>.from(data['friends'] ?? []),
      tasks: List<String>.from(data['tasks'] ?? []),
      wakeUpTime: data['wakeUpTime'],
      taskTime: data['taskTime'],
      profileCompleted: data['profileCompleted'] ?? false,
      onboardingCompleted: data['onboardingCompleted'] ?? false,
    );
  }
}
