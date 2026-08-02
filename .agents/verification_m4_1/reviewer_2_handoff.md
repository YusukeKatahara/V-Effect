# Role Model Feature Review Report

This report provides the verification findings, quality review, and adversarial analysis of the Role Model feature implementation for the V EFFECT project.

---

# 1. Quality Review Report

## Review Summary

**Verdict**: REQUEST_CHANGES (FAIL)

The core data model, registration and removal services, list screen layout, and route registration are correctly implemented and integrated with the main profile screens. However, there are significant gaps between the implementation and the design document (`docs/role_model_design.md`), specifically the omission of the weekly completion rate calculation logic and the Role Model activity detail screen.

## Findings

### [Critical] Finding 1: Missing Core Method `getWeeklyCompletionRate`
- **What**: The method `getWeeklyCompletionRate` is completely missing from the service layer implementation.
- **Where**: `lib/services/role_model_service.dart`
- **Why**: Section 5.1 of `docs/role_model_design.md` explicitly lists `getWeeklyCompletionRate` as part of the service interface, and Section 4 details the calculation logic. Without this method, the weekly completion rate cannot be calculated.
- **Suggestion**: Implement the method in `RoleModelService` following the logic outlined in Section 4 of the design doc.

### [Critical] Finding 2: Missing Role Model Detail / Activity Screen
- **What**: The "ロールモデル詳細・アクティビティ画面" (Role Model Activity Detail screen) is not implemented.
- **Where**: `lib/screens/role_model/role_model_list_screen.dart` lines 93-99
- **Why**: In `RoleModelListScreen`, tapping a role model tile navigates directly to the target user's standard profile (`AppRoutes.userProfile`), which does not contain the weekly completion rate graph or past post history specified in the design.
- **Suggestion**: Create a dedicated screen or expand `UserProfileScreen` to display the weekly completion rate (past 7 days graph) and post history when the target user is registered as a role model.

### [Minor] Finding 3: Return Type Discrepancy in `getRoleModelsStream`
- **What**: The stream return type differs from the design contract.
- **Where**: `lib/services/role_model_service.dart` line 75
- **Why**: The design lists `Stream<List<Map<String, dynamic>>> getRoleModelsStream()`, whereas the implementation returns `Stream<List<RoleModel>>`.
- **Suggestion**: Keep the current implementation as it is cleaner and type-safe (returning `RoleModel` models), but update the design document to match this interface.

## Verified Claims

- **Firebase Collection Path matches design** → Verified via `view_file` on `lib/services/role_model_service.dart` (lines 25-35) → **PASS** (uses `users/{myUid}/role_models/{targetUid}`)
- **Cache fields match design** → Verified via `view_file` on `lib/models/role_model.dart` (lines 21-34) → **PASS** (saves `targetUid`, `displayName`, `username`, `photoUrl`, and `createdAt`)
- **Robust parsing of models** → Verified via `view_file` on `lib/models/role_model.dart` (lines 42-75) → **PASS** (handles `Timestamp`, `DateTime`, `String`, and returns default fallback on parsing error)
- **Unit tests run and pass successfully** → Verified via `run_command` (`flutter test`) → **PASS** (all tests in `test/role_model_service_test.dart` and other suites pass)

## Coverage Gaps

- **Weekly completion rate logic** — risk level: **HIGH** — recommendation: **Investigate/Implement** (must implement calculations and verify correctness via tests)
- **Role Model Detail / Activity UI** — risk level: **HIGH** — recommendation: **Investigate/Implement** (must implement the graph/timeline components)

## Unverified Items

- None (all implemented items have been inspected and verified).

---

# 2. Adversarial Review Report

## Challenge Summary

**Overall risk assessment**: HIGH (due to cache synchronization and client-side database scaling concerns)

## Challenges

### [High] Challenge 1: Profile Information Desynchronization (Cache Invalidation)
- **Assumption challenged**: The cached profile fields (`displayName`, `username`, `photoUrl`) remain accurate over time.
- **Attack scenario**: A user registers user B as a role model. User B later changes their display name or photo URL.
- **Blast radius**: The user's role model list screen will show outdated (stale) cache information for user B indefinitely because there is no mechanism to propagate profile updates to the subcollections of users who registered them.
- **Mitigation**: Implement a Cloud Function trigger on `users/{uid}` updates that updates all matching `role_models` subcollections via a collection group query, or resolve user profiles dynamically on the client side (at the cost of extra reads), or schedule a periodic client-side sync.

### [Medium] Challenge 2: Firestore Read Load Escalation (Client-Side Computation)
- **Assumption challenged**: Dynamic client-side calculation of the weekly completion rate is efficient.
- **Attack scenario**: A user registers 10 role models. The UI displays their weekly task completion graphs on a single dashboard.
- **Blast radius**: For each role model, the app must load their entire 7-day post history. If each role model posts 2-3 times daily, this translates to downloading hundreds of post documents on the client side. This causes high network consumption, slow load times, and high Firestore billing costs.
- **Mitigation**: Implement a daily snapshot document (`users/{uid}/daily_stats/{date}`) as described in "方式2" (Section 4.1 of the design doc), or add strict pagination/limits on the number of posts fetched.

### [Low] Challenge 3: Dangling References on User Deletion
- **Assumption challenged**: Users remain in the database forever.
- **Attack scenario**: A user deletes their account.
- **Blast radius**: The role model references pointing to the deleted user remain in their followers' `role_models` subcollections, leading to broken avatars and empty UI cards.
- **Mitigation**: Implement a cleanup script or Cloud Function on user deletion (`auth.user().onDelete()`) to purge all references in `role_models` collections.

## Stress Test Results

- **Parse malformed data maps** → `RoleModel.fromMap` is fed dynamic data types and null values → Parser handles it gracefully and falls back to safe values → **PASS**
- **Offline / Firestore failure behavior** → User toggles registration when network is offline → OutlinedButton displays errors gracefully in SnackBar → **PASS**

## Unchallenged Areas

- **FCM Push Notification on registration** — reason not challenged: The feature does not currently support push notifications for role model events.

---

# 3. Handoff Report (5-Component)

### 1. Observation
- Files viewed:
  - `docs/role_model_design.md`
  - `lib/models/role_model.dart`
  - `lib/services/role_model_service.dart`
  - `lib/providers/role_model_provider.dart`
  - `lib/screens/role_model/role_model_list_screen.dart`
  - `lib/config/routes.dart`
  - `lib/screens/profile_screen.dart`
  - `lib/screens/user_profile_screen.dart`
  - `test/role_model_service_test.dart`
- Commands executed:
  - `flutter analyze`: Failed with exit code 1 due to 34 issues, all of which are confined to files in the `scratch/` directory. Zero issues found in `lib/` or `test/`.
  - `flutter test`: Completed successfully, all tests passed (including `test/role_model_service_test.dart`).

### 2. Logic Chain
1. I checked the design doc `docs/role_model_design.md` which requires a "ロールモデル詳細・アクティビティ画面" (activity detail screen) displaying weekly task completion rate and past posts list.
2. I inspected `lib/services/role_model_service.dart` and found that the `getWeeklyCompletionRate` method (defined in Section 5.1 of the design) is missing.
3. I inspected `lib/screens/role_model/role_model_list_screen.dart` and found that tapping a tile navigates to `AppRoutes.userProfile` (i.e. `UserProfileScreen`), rather than a dedicated detail/activity screen.
4. I checked `lib/screens/user_profile_screen.dart` and verified that it has no code/UI representing a weekly completion rate graph or history of posts for role models.
5. Therefore, the implementation does not fully match the design and is functionally incomplete.

### 3. Caveats
- I assumed that the "ロールモデル詳細・アクティビティ画面" was intended to be part of the current milestone deliverables, as it is fully detailed in the design document sections 2.1, 2.2, 4.1, and 5.1.
- No other external APIs were tested.

### 4. Conclusion
The Role Model feature implementation is incomplete. The data model, list screen, and basic registration functionality are robust and well-written with proper Japanese comments and style, but the **weekly task completion rate calculation** and the **activity detail screen** are missing.
- **Review Verdict**: **REQUEST_CHANGES (FAIL)**

### 5. Verification Method
- Execute the test suite using `flutter test test/role_model_service_test.dart` to verify existing functionality.
- Run `flutter analyze` to check static analysis (ignoring the `scratch/` directory).
- Check `lib/services/role_model_service.dart` and `lib/screens/role_model/role_model_list_screen.dart` to inspect the missing parts.
