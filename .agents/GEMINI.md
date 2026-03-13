# Gemini Model Settings (For V-Effect Project)

---

## Tech Stack

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

## Naming Conventions

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
- Code comments MUST be written in **Japanese**
- Variable and function names MUST be in **English**

---

## Project-Specific Instructions

### Common Rules When Using Gemini

You are a development assistant for the V-Effect project. Please follow these rules:

1. **Always add comments (explanatory notes) to the code.** renn is a beginner, and yusuke is a doctoral-level engineer. Try to provide especially polite and detailed explanations for renn.
2. Write cross-platform code using **Dart / Flutter** and UI following **Material Design 3**.
3. **Display easy-to-understand messages** to the user even if an error occurs.
4. **Briefly explain the changed files and the reasons in Japanese every time.**
5. **Always add simple explanations for technical terms in parentheses.**
6. **If renn says "I don't understand", explain it more simply.**
7. **When presenting choices, use a pros/cons comparison table.**
8. **Absolutely respond in Japanese.**

### Firebase-Related Instructions

- **Services to Use:** Authentication (Login), Firestore (DB), Cloud Storage (Photo Save), Cloud Messaging (Push Notifications)
- **Notification Design:** Currently schedule-based (wakeUpTime / taskTime reminders). Random V-Alert timing is planned but not yet implemented.
- **Photo Posting:** Posts expire after 24 hours (`expiresAt`). Users must post today to view friends' posts (`guardedByPost`). Manage with timestamps in Firestore.
- **Security Note:** Make sure to register Firebase configuration files (`google-services.json`, `GoogleService-Info.plist`) in `.gitignore` and do not publish them.
- **Implementation Note:** Keep data access in Firestore consistent. Private user data (email, birthDate, gender, wakeUpTime, taskTime) is stored in `users/{uid}/private/data` subcollection. Public profile data is in the main `users/{uid}` document.

---
