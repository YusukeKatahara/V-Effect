# Claude Model Settings (For V-Effect Project)

---

## 📊 Progress Status

### Current Phase: Phase 3（本開発）

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

#### Direction Changes

1. **V-Alert: Random → Scheduled notifications**
   - Plan: BeReal-style random simultaneous notifications to all users
   - Actual: User-configured fixed-time reminders (wakeUpTime / taskTime)
   - Impact: Lost "spontaneity" element; gained predictable habit-building UX
   - Random notification Cloud Function (`randomAlertNotification`) not implemented

2. **V-Quest: Dynamic quests → Static task list**
   - Plan: Daily "accept a new quest" with game-like ceremony
   - Actual: Fixed tasks registered at setup; no daily renewal or difficulty system
   - Impact: Simpler UX but reduced gamification feel

3. **Notification system: Separated → Unified**
   - Plan: V-Alert (random) and V-Feed (reactions) as independent systems
   - Actual: Single `NotificationService` handling 6 notification types
   - Types: wakeUpReminder, taskReminder, friendRequestReceived, friendRequestAccepted, reactionReceived, newPostFromFriend

#### Added Beyond Original Plan

| Feature | Notes |
|---------|-------|
| Streak system | Not in original plan; drives daily engagement |
| Google / Apple Sign-In | Plan assumed Email only |
| Dopamine-driven UX | Flame animations, haptic feedback, varied notification messages |
| 90-day profile edit lock | Anti-abuse measure |
| Password reset flow | ForgotPassword → Cloud Functions → ResetPassword |
| Friend request workflow | 3-step: send → accept → become friends |
| Profile image upload | Required for SNS but not in original spec |

#### Deferred as Planned

- Skill Tree ("体" / "頭" / "心" growth visualization) — Phase 2+
- XP / Level-up system — Phase 2+
- No code references to XP, level, or skill tree exist

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

### Dev Tools
| Tool | Purpose |
|------|---------|
| **flutter_lints** | Static analysis / lint rules |
| **flutter_test** | Unit & widget testing |
| **Git / GitHub** | Source code management |
| **Antigravity** | AI-assisted development IDE |

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

### Common Rules When Using Claude

You are a Senior Reviewer (Advanced Check Lead) for the V-Effect project. Please follow these rules:

1. **When analyzing code, perform a comprehensive check from the following perspectives:**
   - Are there any bugs (programming errors)?
   - Are there any security (safety) issues?
   - Are there any performance (processing speed) issues?
   - Readability and maintainability (is it easy to modify in the future?)

2. **If you find an issue, report it in the following format:**
   - 🔴 **Critical (Needs immediate fix)**: Security holes, bugs that cause data loss, etc.
   - 🟡 **Warning (Recommended to fix soon)**: Performance issues, areas that might become bugs in the future.
   - 🟢 **Suggestion (Improve if you have time)**: Better ways to write the code, readability improvements.

3. **Explanations should be written politely and carefully in Japanese so that even a beginner (renn) can understand.** Specifically indicate why the problem is important and how it should be fixed.

4. **Check whether the code follows Dart / Flutter specific best practices** (state management, Widget design, asynchronous processing, etc.).

5. **App-specific important check perspectives:**
   - **V-Quest Logic**: Check if daily quests (challenges) are properly recorded and managed per user.
   - **V-Alert (Photo Posting) Security**: Is the rule "can only be viewed the day after posting (or after completing V-Quest)" correctly implemented in Firestore Security Rules?
   - **V-Feed (Reaction Feature)**: Is there a system in place that prevents negative content from being posted? Is the timeline strictly limited to those who accomplished their V-Quest?
   - **Firebase Security**: Appropriateness of read/write permissions in Firestore Security Rules (e.g., whether someone else's data can be illegally rewritten).
   - **Personal Information Protection**: Protection of user photos and profiles in Authentication and Storage.
   - **Performance**: Load of image upload/retrieval processing, excessive notifications of Cloud Messaging (V-Alert notifications).

## Basic Approach for Claude
- **When requesting code generation or modification**: Implement according to the above technical stack and naming conventions
- **When requesting code review**: Review based on the rules in Project-Specific Instructions
---