import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_task.dart';
import 'hero_pick.dart';
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
  final List<HeroPick> heroPicks;
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
  final String? websiteUrl;
  final List<String> processedSeasonTaskIds;
  final bool totalPostsMigrated;
  final bool isRecommended;
  final Map<String, DateTime> mutualFires;

  // ── フィールド名定数 ──
  static const String fieldUid = 'uid';
  static const String fieldEmail = 'email';
  static const String fieldUsername = 'username';
  static const String fieldUsernameLower = 'usernameLower';
  static const String fieldUserId = 'userId';
  static const String fieldUserIdLower = 'userIdLower';
  static const String fieldDisplayName = 'displayName';
  static const String fieldBirthDate = 'birthDate';
  static const String fieldGender = 'gender';
  static const String fieldPhotoUrl = 'photoUrl';
  static const String fieldStreak = 'streak';
  static const String fieldStreakProtections = 'streakProtections';
  static const String fieldTotalPosts = 'totalPosts';
  static const String fieldLastPostedDate = 'lastPostedDate';
  static const String fieldFollowing = 'following';
  static const String fieldFollowers = 'followers';
  static const String fieldRecentPostDates = 'recentPostDates';
  static const String fieldTasks = 'tasks';
  static const String fieldHeroPicks = 'heroPicks';
  static const String fieldOccupation = 'occupation';

  static const String fieldProfileCompleted = 'profileCompleted';
  static const String fieldTemplateCompleted = 'templateCompleted';
  static const String fieldOnboardingCompleted = 'onboardingCompleted';
  static const String fieldLastProfileEditDate = 'lastProfileEditDate';
  static const String fieldPushNotifications = 'pushNotifications';
  static const String fieldFocusTimeNotifications = 'focusTimeNotifications';
  static const String fieldReactionNotifications = 'reactionNotifications';
  static const String fieldProtectionNotifications = 'protectionNotifications';
  static const String fieldVFireNotifications = 'vFireNotifications';
  static const String fieldIsPrivateAccount = 'isPrivateAccount';
  static const String fieldEquippedBadgeUrl = 'equippedBadgeUrl';
  static const String fieldEquippedBadgeAnimation = 'equippedBadgeAnimation';
  static const String fieldOwnedBadges = 'ownedBadges';
  static const String fieldInstagramId = 'instagramId';
  static const String fieldWebsiteUrl = 'websiteUrl';
  static const String fieldProcessedSeasonTaskIds = 'processedSeasonTaskIds';
  static const String fieldTotalPostsMigrated = 'totalPostsMigrated';
  static const String fieldIsRecommended = 'isRecommended';
  static const String fieldMaxStreak = 'maxStreak';
  static const String fieldFriends = 'friends';
  static const String fieldBlockedUsers = 'blockedUsers';
  static const String fieldStreakWarningNotifications = 'streakWarningNotifications';
  static const String fieldOnboardingStep = 'onboardingStep';
  static const String fieldMutualFires = 'mutualFires';

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
    this.heroPicks = const [],
    this.occupation,
    this.profileCompleted = false,
    this.templateCompleted = false,
    this.onboardingCompleted = false,
    this.lastProfileEditDate,
    this.pushNotifications = true,
    this.focusTimeNotifications = true,
    this.reactionNotifications = true,
    this.protectionNotifications = false,
    this.vFireNotifications = true,
    this.isPrivateAccount = false,
    this.equippedBadgeUrl,
    this.equippedBadgeAnimation,
    this.ownedBadges = const [],
    this.instagramId,
    this.websiteUrl,
    this.processedSeasonTaskIds = const [],
    this.totalPostsMigrated = false,
    this.isRecommended = false,
    this.mutualFires = const {},
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return AppUser.fromMap(doc.id, data ?? {});
  }

  factory AppUser.fromMap(String id, Map<String, dynamic> data) {
    try {
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

      Map<String, DateTime> extractMutualFires() {
        final raw = data[fieldMutualFires];
        if (raw is Map) {
          final map = <String, DateTime>{};
          for (final entry in raw.entries) {
            if (entry.value is Timestamp) {
              map[entry.key] = (entry.value as Timestamp).toDate();
            }
          }
          return map;
        }
        return {};
      }

      List<HeroPick> extractHeroPicks() {
        final raw = data[fieldHeroPicks];
        if (raw is List) {
          return raw
              .whereType<Map<String, dynamic>>()
              .map((item) => HeroPick.fromMap(item))
              .toList();
        }
        return [];
      }

      return AppUser(
        uid: id,
        email: safeString(data[fieldEmail]),
        username: safeString(data[fieldUsername]),
        userId: safeString(data[fieldUserId]),
        displayName: safeString(data[fieldDisplayName]),
        birthDate: safeString(data[fieldBirthDate]),
        gender: safeString(data[fieldGender]),
        photoUrl: safeString(data[fieldPhotoUrl]),
        streak: StreakService.calculateEffectiveStreak(
          streak: (data[fieldStreak] as num?)?.toInt() ?? 0,
          protections: (data[fieldStreakProtections] as num?)?.toInt() ?? 0,
          lastPostedDate: safeString(data[fieldLastPostedDate]),
        )['streak']!,
        streakProtections: StreakService.calculateEffectiveStreak(
          streak: (data[fieldStreak] as num?)?.toInt() ?? 0,
          protections: (data[fieldStreakProtections] as num?)?.toInt() ?? 0,
          lastPostedDate: safeString(data[fieldLastPostedDate]),
        )['streakProtections']!,
        totalPosts: data[fieldTotalPosts] != null
            ? (data[fieldTotalPosts] as num).toInt()
            : -1,
        lastPostedDate: safeString(data[fieldLastPostedDate]),
        following: extractUids(fieldFollowing, 'friends'),
        followers: extractUids(fieldFollowers, 'friends'),
        recentPostDates: (data[fieldRecentPostDates] as List?)?.map((e) => e.toString()).toList() ?? [],
        tasks: (data[fieldTasks] as List? ?? [])
            .map((item) => AppTask.fromFirestore(item))
            .toList(),
        heroPicks: extractHeroPicks(),
        occupation: safeString(data[fieldOccupation]),
        profileCompleted: data[fieldProfileCompleted] == true,
        templateCompleted: data[fieldTemplateCompleted] == true,
        onboardingCompleted: data[fieldOnboardingCompleted] == true,
        lastProfileEditDate: data[fieldLastProfileEditDate] is num
            ? (data[fieldLastProfileEditDate] as num).toInt()
            : null,
        pushNotifications: data[fieldPushNotifications] ?? true,
        focusTimeNotifications: data[fieldFocusTimeNotifications] ?? true,
        reactionNotifications: data[fieldReactionNotifications] ?? true,
        protectionNotifications: data[fieldProtectionNotifications] ?? false,
        vFireNotifications: data[fieldVFireNotifications] ?? true,
        isPrivateAccount: data[fieldIsPrivateAccount] == true,
        equippedBadgeUrl: safeString(data[fieldEquippedBadgeUrl]),
        equippedBadgeAnimation: safeString(data[fieldEquippedBadgeAnimation]),
        ownedBadges: (data[fieldOwnedBadges] as List?)?.map((e) => e.toString()).toList() ?? [],
        instagramId: safeString(data[fieldInstagramId]),
        websiteUrl: safeString(data[fieldWebsiteUrl]),
        processedSeasonTaskIds: (data[fieldProcessedSeasonTaskIds] as List?)?.map((e) => e.toString()).toList() ?? [],
        totalPostsMigrated: data[fieldTotalPostsMigrated] == true,
        isRecommended: data[fieldIsRecommended] == true,
        mutualFires: extractMutualFires(),
      );
    } catch (e) {
      debugPrint('Error parsing AppUser $id: $e');
      return AppUser(uid: id);
    }
  }

  /// Firestore 保存用の Map を生成します
  Map<String, dynamic> toFirestore() {
    return {
      fieldEmail: email,
      fieldUsername: username,
      fieldUserId: userId,
      fieldDisplayName: displayName,
      fieldBirthDate: birthDate,
      fieldGender: gender,
      fieldPhotoUrl: photoUrl,
      fieldStreak: streak,
      fieldStreakProtections: streakProtections,
      fieldTotalPosts: totalPosts,
      fieldLastPostedDate: lastPostedDate,
      fieldFollowing: following,
      fieldFollowers: followers,
      fieldRecentPostDates: recentPostDates,
      fieldTasks: tasks.map((t) => t.toFirestore()).toList(),
      fieldHeroPicks: heroPicks.map((p) => p.toMap()).toList(),
      fieldOccupation: occupation,
      fieldProfileCompleted: profileCompleted,
      fieldTemplateCompleted: templateCompleted,
      fieldOnboardingCompleted: onboardingCompleted,
      fieldLastProfileEditDate: lastProfileEditDate,
      fieldPushNotifications: pushNotifications,
      fieldFocusTimeNotifications: focusTimeNotifications,
      fieldReactionNotifications: reactionNotifications,
      fieldProtectionNotifications: protectionNotifications,
      fieldVFireNotifications: vFireNotifications,
      fieldIsPrivateAccount: isPrivateAccount,
      fieldEquippedBadgeUrl: equippedBadgeUrl,
      fieldEquippedBadgeAnimation: equippedBadgeAnimation,
      fieldOwnedBadges: ownedBadges,
      fieldInstagramId: instagramId,
      fieldWebsiteUrl: websiteUrl,
      fieldProcessedSeasonTaskIds: processedSeasonTaskIds,
      fieldTotalPostsMigrated: totalPostsMigrated,
      fieldIsRecommended: isRecommended,
      // mutualFires はクライアントから書き込まれる想定はないが、保存時のためにTimestampに変換する
      fieldMutualFires: mutualFires.map((key, value) => MapEntry(key, Timestamp.fromDate(value))),
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
    List<HeroPick>? heroPicks,
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
    String? websiteUrl,
    List<String>? processedSeasonTaskIds,
    bool? totalPostsMigrated,
    bool? isRecommended,
    Map<String, DateTime>? mutualFires,
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
      heroPicks: heroPicks ?? this.heroPicks,
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
      websiteUrl: websiteUrl ?? this.websiteUrl,
      processedSeasonTaskIds: processedSeasonTaskIds ?? this.processedSeasonTaskIds,
      totalPostsMigrated: totalPostsMigrated ?? this.totalPostsMigrated,
      isRecommended: isRecommended ?? this.isRecommended,
      mutualFires: mutualFires ?? this.mutualFires,
    );
  }
}

