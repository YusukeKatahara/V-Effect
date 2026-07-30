# Claude Model Settings (For V EFFECT Project)

> **⚠️ Maintenance Rule**: この技術スタック表は `pubspec.yaml` / `functions/package.json` と常に同期させること。依存関係やアーキテクチャを変更したら、このファイルも同じコミットで更新する（AIが古い情報を参照する事故を防ぐため）。

---

## Tech Stack

### Frontend
| Technology | Version | Purpose |
|------------|---------|---------|
| **Flutter** | SDK ^3.7.0 | Cross-platform UI framework (Android / iOS / Web) |
| **Dart** | SDK ^3.7.0 | Programming language |
| **flutter_riverpod** | ^2.5.1 | State management (`ConsumerWidget` / `AsyncValue`。旧Providerパッケージからは移行完了済み) |
| **intl** | any (flutter_localizations準拠) | Internationalization / date formatting |

### Backend (Firebase)
| Technology | Version | Purpose |
|------------|---------|---------|
| **Firebase Core** | ^4.5.0 | Firebase initialization |
| **Firebase Auth** | ^6.2.0 | Authentication (Email, Google, Apple) |
| **Cloud Firestore** | ^6.1.3 | NoSQL database |
| **Firebase Storage** | ^13.1.0 | Photo / image storage |
| **Firebase Messaging** | ^16.1.2 | Push notifications (FCM) |
| **Cloud Functions** | ^6.0.7 | Server-side logic (Node.js 20) |
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
| **Node.js** | 20 | Runtime |
| **firebase-admin** | ^13.7.0 | Admin SDK |
| **firebase-functions** | ^7.2.2 | Cloud Functions framework |

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
| `lib/services/` | `*_service.dart` | Business logic & Firebase communication (Singleton `instance`) |
| `lib/providers/` | `*_provider.dart` | Riverpod providers (`AsyncValue` / `FutureProvider`) |
| `lib/widgets/` | Descriptive name | Reusable UI components (screen-independent) |
| `lib/models/` | Noun (singular) `.dart` | Data models (`app_user.dart`, `post.dart`) |
| `lib/utils/` | `*_helper.dart` or descriptive | Utility functions |
| `lib/config/` | Descriptive name | App configuration (`theme.dart`, `routes.dart`) |
| `lib/l10n/` | `app_ja.arb` / `app_en.arb` | Localization sources (`flutter gen-l10n` で再生成) |
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
| `docs:` | Documentations | `docs: add screen transition diagram` |
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
   - **Hero Task (V-Quest) Logic**: Check if daily quests (challenges) are properly recorded and managed per user (`postedToday` 判定、日付リセット処理を含む).
   - **V-Feed Gating**: Is the rule "today's friend posts become visible only after you complete your own post" correctly enforced in app logic (`postedToday` in `post_service.dart` / `home_provider.dart`)? Note: Firestore rules側は認証済みユーザーの read を許可するシンプルな構成（2026-07-23変更）のため、この閲覧制限は主にアプリロジックで担保されている。
   - **Streak & Rescue System**: Streak計算・シールド付与（7日ごと最大2個）・24時間救済フラグ（`isRescueActive`）・150 VFIREでの復活処理の整合性.
   - **Push Notification Reliability**: FCMトークンの `onTokenRefresh` 同期、セルフヒーリング関数（`healUnprocessedPostNotifications`）、通知の重複・欠落.
   - **Firebase Security**: Appropriateness of read/write permissions in Firestore Security Rules (e.g., whether someone else's data can be illegally rewritten). ルール変更後は必ず `firebase deploy --only firestore:rules` を実行する.
   - **Personal Information Protection**: Protection of user photos and profiles in Authentication and Storage.
   - **Performance**: Load of image upload/retrieval processing, excessive FCM push notifications, Firestore read quota (`.agents/rules/firebase_quota_rules.md` 参照).

> **廃止済み用語に注意**: 「V-Alert」は初期企画時の名称で、現在のアプリには存在しない（写真投稿・閲覧制限の概念は V-Feed に統合済み）。古い資料でこの名称を見ても新規実装・レビューの前提にしないこと。

## Basic Approach for Claude
- **When requesting code generation or modification**: Implement according to the above technical stack and naming conventions
- **When requesting code review**: Review based on the rules in Project-Specific Instructions

---
*Last applied: 2026-07-31*