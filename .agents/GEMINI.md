# Gemini Model Settings (For V-Effect Project)

---

## 📊 Progress Status

### Current Phase: Phase 3（本開発）— 主要機能の実装中

| Category | Status | Details |
|----------|--------|---------|
| Authentication | ✅ Done | Email/Password, Google Sign-In, Apple Sign-In, Password Reset |
| Profile Setup | ✅ Done | ProfileSetupScreen, TaskSetupScreen, 90-day edit restriction |
| Home Screen | ✅ Done | Streak display, task status, friend feed (Stories-style viewer) |
| Camera / Photo Posting | ✅ Done | Camera capture, timestamp sticker, Web photo upload |
| Friends Feature | ✅ Done | Friend requests, friend list, initial friend screen |
| Notifications | ✅ Done | In-app notifications, push notification foundation (FCM + Cloud Functions) |
| Dopamine UX | ✅ Done | Haptic feedback, flame animation, social notification cues |
| V-Quest (Daily Quest) | 🔧 ~40% | Static task management only; no dynamic quest cycle or difficulty system |
| V-Alert (Notification + Photo) | 🔧 ~35% | Schedule-based reminders only; random timing not implemented |
| V-Feed (Reaction Timeline) | ✅ ~85% | Stories viewer, 🔥 reaction, post-to-view gating implemented |
| Skill Tree / XP System | ⬜ Not Started | Post-MVP feature (Phase 2+) |
| Testing & QA | ⬜ Not Started | Phase 4 |
| Release Prep | ⬜ Not Started | Phase 5 |

### Implemented Screens (15 screens)

LoginScreen, RegisterScreen, ForgotPasswordScreen, ResetPasswordScreen,
ProfileSetupScreen, TaskSetupScreen, InitialFriendScreen,
MainShell (BottomNavigationBar), HomeScreen, ProfileScreen, EditProfileScreen,
CameraScreen, FriendsScreen, NotificationsScreen, FriendFeedScreen

### Plan vs Implementation Deviations

#### Direction Changes (計画から方向転換した要素)

1. **V-Alert: Random → Scheduled notifications**
   - Plan: BeReal-style random simultaneous notifications to all users
   - Actual: User-configured fixed-time reminders (wakeUpTime / taskTime)
   - Impact: Lost "spontaneity" element; gained predictable habit-building UX

2. **V-Quest: Dynamic quests → Static task list**
   - Plan: Daily "accept a new quest" with game-like ceremony
   - Actual: Fixed tasks registered at setup; no daily renewal or difficulty system

3. **Notification system: Separated → Unified**
   - Plan: V-Alert (random) and V-Feed (reactions) as independent systems
   - Actual: Single `NotificationService` handling 6 notification types

#### Added Beyond Original Plan (計画外の追加機能)

| Feature | Notes |
|---------|-------|
| Streak system | Not in original plan; drives daily engagement |
| Google / Apple Sign-In | Plan assumed Email only |
| Dopamine-driven UX | Flame animations, haptic feedback, varied notification messages |
| 90-day profile edit lock | Anti-abuse measure |
| Password reset flow | ForgotPassword → Cloud Functions → ResetPassword |
| Friend request workflow | 3-step: send → accept → become friends |
| Profile image upload | Required for SNS but not in original spec |

#### Deferred as Planned (予定通り未実装)

- Skill Tree ("体" / "頭" / "心" growth visualization) — Phase 2+
- XP / Level-up system — Phase 2+

---

## 🛠 Tech Stack

### Frontend
| Technology | Version | Purpose |
|------------|---------|---------|
| **Flutter** | SDK ^3.7.0 | Cross-platform UI framework (Android / iOS / Web) |
| **Dart** | SDK ^3.7.0 | Programming language |
| **Provider** | ^6.1.5+1 | State management |
| **intl** | ^0.20.2 | Internationalization / date formatting |

### Backend (Firebase)
| Technology | Version | Purpose |
|------------|---------|---------|
| **Firebase Core** | ^4.5.0 | Firebase initialization |
| **Firebase Auth** | ^6.2.0 | Authentication (Email, Google, Apple) |
| **Cloud Firestore** | ^6.1.3 | NoSQL database |
| **Firebase Storage** | ^13.1.0 | Photo / image storage |
| **Firebase Messaging** | ^16.1.2 | Push notifications (FCM) |
| **Cloud Functions** | ^6.0.7 | Server-side logic (Node.js 18) |
| **flutter_local_notifications** | ^18.0.1 | Local notification display |

### Auth Providers
| Technology | Version | Purpose |
|------------|---------|---------|
| **google_sign_in** | ^6.2.1 | Google Sign-In |
| **sign_in_with_apple** | ^7.0.1 | Apple Sign-In |
| **crypto** | ^3.0.7 | Hashing for Apple Sign-In nonce |

### Cloud Functions (Server-side)
| Technology | Version | Purpose |
|------------|---------|---------|
| **Node.js** | 18 | Runtime |
| **firebase-admin** | ^12.0.0 | Admin SDK |
| **firebase-functions** | ^5.0.0 | Cloud Functions framework |

### Implemented Cloud Functions
| Function | Trigger | Purpose |
|----------|---------|---------|
| `sendPushNotification` | Firestore `notifications` onCreate | Send FCM push to target user |
| `sendPasswordReset` | HttpsCallable | Verify userId + email, send reset link |

---

## 📏 Naming Conventions

### Dart / Flutter

| Element | Convention | Example |
|---------|-----------|---------|
| **File names** | `snake_case.dart` | `login_screen.dart`, `auth_service.dart` |
| **Class names** | `UpperCamelCase` | `LoginScreen`, `AuthService`, `AppUser` |
| **Variables / Functions** | `lowerCamelCase` | `getUserAge()`, `isLoggedIn` |
| **Constants** | `lowerCamelCase` | `defaultPadding`, `maxRetryCount` |
| **Private members** | `_lowerCamelCase` | `_currentUser`, `_handleSubmit()` |
| **Enums** | `UpperCamelCase` (type), `lowerCamelCase` (values) | `enum Status { active, inactive }` |

### Project Directory Structure

| Directory | Naming Rule | Content |
|-----------|------------|---------|
| `lib/screens/` | `*_screen.dart` | One Widget (screen) per file |
| `lib/services/` | `*_service.dart` | Business logic & Firebase communication |
| `lib/models/` | Noun (singular) `.dart` | Data models (`app_user.dart`, `post.dart`) |
| `lib/utils/` | `*_helper.dart` or descriptive | Utility functions |
| `lib/config/` | Descriptive name | App configuration (`theme.dart`, `routes.dart`) |
| `functions/` | `index.js` | Cloud Functions entry point |

### Route Names
| Convention | Example |
|-----------|---------|
| `kebab-case` with leading `/` | `/login`, `/profile-setup`, `/task-setup`, `/forgot-password` |
| Defined in `AppRoutes` class (`lib/config/routes.dart`) | `AppRoutes.login`, `AppRoutes.home` |

### Commit Messages
| Prefix | Usage | Example |
|--------|-------|---------|
| `feat:` | New feature | `feat: implement push notification foundation` |
| `fix:` | Bug fix | `fix: resolve compile errors in test` |
| `docs:` | Documentation | `docs: add screen transition diagram` |
| `chore:` | Maintenance / config | `chore: apply setup_guide configurations` |

### Comments
- Code comments may be written in **Japanese**
- Variable and function names must be in **English**

---

## 📝 Project-Specific Instructions

### Common Rules When Using Gemini

You are a development assistant for the V-Effect project. Please follow these rules:

1. **Always add comments (explanatory notes) to the code.** renn is a beginner, and yusuke is a doctoral-level engineer. Try to provide especially polite and detailed explanations for renn.
2. Write cross-platform code using **Dart / Flutter** and UI following **Material Design 3**.
3. **Display easy-to-understand messages** to the user even if an error occurs.
4. **Briefly explain the changed files and the reasons in Japanese every time.**
5. **Always add simple explanations for technical terms in parentheses.**
6. **If renn says "I don't understand", explain it more simply.**
7. **When presenting choices, use a pros/cons comparison table.**

### Firebase-Related Instructions

- **Services to Use:** Authentication (Login), Firestore (DB), Cloud Storage (Photo Save), Cloud Messaging (Push Notifications)
- **Notification Design:** Currently schedule-based (wakeUpTime / taskTime reminders). Random V-Alert timing is planned but not yet implemented.
- **Photo Posting:** Posts expire after 24 hours (`expiresAt`). Users must post today to view friends' posts (`guardedByPost`). Manage with timestamps in Firestore.
- **Security Note:** Make sure to register Firebase configuration files (`google-services.json`, `GoogleService-Info.plist`) in `.gitignore` and do not publish them.
- **Implementation Note:** Keep data access in Firestore consistent. Private user data (email, birthDate, gender, wakeUpTime, taskTime) is stored in `users/{uid}/private/data` subcollection. Public profile data is in the main `users/{uid}` document.

---
