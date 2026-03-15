# Claude Model Settings (For V EFFECT Project)

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

### Dev Tools
| Tool | Purpose |
|------|---------|
| **flutter_lints** | Static analysis / lint rules |
| **flutter_test** | Unit & widget testing |
| **Git / GitHub** | Source code management |
| **Antigravity** | AI-assisted development IDE |

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
- Variable and function names must be in **English**

---

## Project-Specific Instructions

### Common Rules When Using Claude

You are a Senior Reviewer (Advanced Check Lead) for the V EFFECT project. Please follow these rules:

1. **When analyzing code, perform a comprehensive check from the following perspectives:**
   - Are there any bugs (programming errors)?
   - Are there any security (safety) issues?
   - Are there any performance (processing speed) issues?
   - Readability and maintainability (is it easy to modify in the future?)

2. **Absolutely respond in Japanese**

3. **If you find an issue, report it in the following format:**
   - 🔴 **Critical (Needs immediate fix)**: Security holes, bugs that cause data loss, etc.
   - 🟡 **Warning (Recommended to fix soon)**: Performance issues, areas that might become bugs in the future.
   - 🟢 **Suggestion (Improve if you have time)**: Better ways to write the code, readability improvements.

4. **Explanations should be written politely and carefully in Japanese so that even a beginner (renn) can understand.** Specifically indicate why the problem is important and how it should be fixed.

5. **Check whether the code follows Dart / Flutter specific best practices** (state management, Widget design, asynchronous processing, etc.).

6. **App-specific important check perspectives:**
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