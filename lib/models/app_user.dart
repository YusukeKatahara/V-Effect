import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_task.dart';
import '../services/streak_service.dart';

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
  final int streakProtections;
  final int totalPosts;
  final String? lastPostedDate;
  final List<String> following;
  final List<String> followers;
  final List<String> recentPostDates;
  final List<AppTask> tasks;
  final String? occupation;
  final bool profileCompleted;
  final bool templateCompleted;
  final bool onboardingCompleted;
  final int? lastProfileEditDate;
  final bool pushNotifications;
  final bool focusTimeNotifications;
  final bool reactionNotifications;
  final bool protectionNotifications;
  final bool vFireNotifications;
  final bool isPrivateAccount;
  final String? equippedBadgeUrl;
  final String? equippedBadgeAnimation;
  final List<String> ownedBadges;
  final String? instagramId;
  final List<String> processedSeasonTaskIds;
  final bool totalPostsMigrated;

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
    this.streakProtections = 0,
    this.totalPosts = -1,
    this.lastPostedDate,
    this.following = const [],
    this.followers = const [],
    this.recentPostDates = const [],
    this.tasks = const [],
    this.occupation,
    this.profileCompleted = false,
    this.templateCompleted = false,
    this.onboardingCompleted = false,
    this.lastProfileEditDate,
    this.pushNotifications = true,
    this.focusTimeNotifications = true,
    this.reactionNotifications = true,
    this.protectionNotifications = true,
    this.vFireNotifications = true,
    this.isPrivateAccount = false,
    this.equippedBadgeUrl,
    this.equippedBadgeAnimation,
    this.ownedBadges = const [],
    this.instagramId,
    this.processedSeasonTaskIds = const [],
    this.totalPostsMigrated = false,
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
      streak: StreakService.calculateEffectiveStreak(
        streak: (data['streak'] as num?)?.toInt() ?? 0,
        protections: (data['streakProtections'] as num?)?.toInt() ?? 0,
        lastPostedDate: safeString(data['lastPostedDate']),
      )['streak']!,
      streakProtections: StreakService.calculateEffectiveStreak(
        streak: (data['streak'] as num?)?.toInt() ?? 0,
        protections: (data['streakProtections'] as num?)?.toInt() ?? 0,
        lastPostedDate: safeString(data['lastPostedDate']),
      )['streakProtections']!,
      totalPosts: data['totalPosts'] != null
          ? (data['totalPosts'] as num).toInt()
          : -1,
      lastPostedDate: safeString(data['lastPostedDate']),
      following: extractUids('following', 'friends'),
      followers: extractUids('followers', 'friends'),
      recentPostDates: (data['recentPostDates'] as List?)?.map((e) => e.toString()).toList() ?? [],
      tasks: (data['tasks'] as List? ?? [])
          .map((item) => AppTask.fromFirestore(item))
          .toList(),
      occupation: data['occupation'],
      profileCompleted: data['profileCompleted'] ?? false,
      templateCompleted: data['templateCompleted'] ?? false,
      onboardingCompleted: data['onboardingCompleted'] ?? false,
      lastProfileEditDate: data['lastProfileEditDate'] is num
          ? (data['lastProfileEditDate'] as num).toInt()
          : null,

      pushNotifications: data['pushNotifications'] ?? true,
      focusTimeNotifications: data['focusTimeNotifications'] ?? true,
      reactionNotifications: data['reactionNotifications'] ?? true,
      protectionNotifications: data['protectionNotifications'] ?? true,
      vFireNotifications: data['vFireNotifications'] ?? true,
      isPrivateAccount: data['isPrivateAccount'] ?? false,
      equippedBadgeUrl: safeString(data['equippedBadgeUrl']),
      equippedBadgeAnimation: safeString(data['equippedBadgeAnimation']),
      ownedBadges: (data['ownedBadges'] as List?)?.map((e) => e.toString()).toList() ?? [],
      instagramId: safeString(data['instagramId']),
      processedSeasonTaskIds: (data['processedSeasonTaskIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      totalPostsMigrated: data['totalPostsMigrated'] ?? false,
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
      'streakProtections': streakProtections,
      'totalPosts': totalPosts,
      'lastPostedDate': lastPostedDate,
      'following': following,
      'followers': followers,
      'recentPostDates': recentPostDates,
      'tasks': tasks.map((t) => t.toFirestore()).toList(),
      'occupation': occupation,
      'profileCompleted': profileCompleted,
      'templateCompleted': templateCompleted,
      'onboardingCompleted': onboardingCompleted,
      'lastProfileEditDate': lastProfileEditDate,
      'pushNotifications': pushNotifications,
      'focusTimeNotifications': focusTimeNotifications,
      'reactionNotifications': reactionNotifications,
      'protectionNotifications': protectionNotifications,
      'vFireNotifications': vFireNotifications,
      'isPrivateAccount': isPrivateAccount,
      'equippedBadgeUrl': equippedBadgeUrl,
      'equippedBadgeAnimation': equippedBadgeAnimation,
      'ownedBadges': ownedBadges,
      'instagramId': instagramId,
      'processedSeasonTaskIds': processedSeasonTaskIds,
      'totalPostsMigrated': totalPostsMigrated,
    };
  }

  /// 一部のフィールドのみを更新した新しい AppUser インスタンスを生成します。
  AppUser copyWith({
    String? uid,
    String? email,
    String? username,
    String? userId,
    String? displayName,
    String? birthDate,
    String? gender,
    String? photoUrl,
    int? streak,
    int? streakProtections,
    int? totalPosts,
    String? lastPostedDate,
    List<String>? following,
    List<String>? followers,
    List<String>? recentPostDates,
    List<AppTask>? tasks,
    String? occupation,
    bool? profileCompleted,
    bool? templateCompleted,
    bool? onboardingCompleted,
    int? lastProfileEditDate,
    bool? pushNotifications,
    bool? focusTimeNotifications,
    bool? reactionNotifications,
    bool? protectionNotifications,
    bool? vFireNotifications,
    bool? isPrivateAccount,
    String? equippedBadgeUrl,
    String? equippedBadgeAnimation,
    List<String>? ownedBadges,
    String? instagramId,
    List<String>? processedSeasonTaskIds,
    bool? totalPostsMigrated,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      username: username ?? this.username,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      photoUrl: photoUrl ?? this.photoUrl,
      streak: streak ?? this.streak,
      streakProtections: streakProtections ?? this.streakProtections,
      totalPosts: totalPosts ?? this.totalPosts,
      lastPostedDate: lastPostedDate ?? this.lastPostedDate,
      following: following ?? this.following,
      followers: followers ?? this.followers,
      recentPostDates: recentPostDates ?? this.recentPostDates,
      tasks: tasks ?? this.tasks,
      occupation: occupation ?? this.occupation,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      templateCompleted: templateCompleted ?? this.templateCompleted,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      lastProfileEditDate: lastProfileEditDate ?? this.lastProfileEditDate,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      focusTimeNotifications: focusTimeNotifications ?? this.focusTimeNotifications,
      reactionNotifications: reactionNotifications ?? this.reactionNotifications,
      protectionNotifications: protectionNotifications ?? this.protectionNotifications,
      vFireNotifications: vFireNotifications ?? this.vFireNotifications,
      isPrivateAccount: isPrivateAccount ?? this.isPrivateAccount,
      equippedBadgeUrl: equippedBadgeUrl ?? this.equippedBadgeUrl,
      equippedBadgeAnimation: equippedBadgeAnimation ?? this.equippedBadgeAnimation,
      ownedBadges: ownedBadges ?? this.ownedBadges,
      instagramId: instagramId ?? this.instagramId,
      processedSeasonTaskIds: processedSeasonTaskIds ?? this.processedSeasonTaskIds,
      totalPostsMigrated: totalPostsMigrated ?? this.totalPostsMigrated,
    );
  }
}
