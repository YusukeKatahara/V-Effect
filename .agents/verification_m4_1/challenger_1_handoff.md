# Role Model Feature Verification Handoff — Challenger 1

## 1. Observation

- **Implementation Location**:
  - Service: `lib/services/role_model_service.dart`
  - Model: `lib/models/role_model.dart`
  - StreamProvider: `lib/providers/role_model_provider.dart`
  - Screen: `lib/screens/role_model/role_model_list_screen.dart`

- **Command and Results**:
  I ran `flutter test test/role_model_service_test.dart` and it completed successfully:
  ```
  00:00 +0: loading /Users/rennlikeu/development/V-Effect/test/role_model_service_test.dart
  00:00 +9: All tests passed!
  ```
  And ran the entire test suite `flutter test`:
  ```
  00:02 +19: All tests passed!
  ```

- **Added Code in `test/role_model_service_test.dart` (lines 405-450)**:
  ```dart
  test('streams are isolated between different authenticated users', () async {
    // User 1 のストリームを取得
    final stream1 = service.getRoleModelsStream();
    final emissions1 = <List<RoleModel>>[];
    final sub1 = stream1.listen(emissions1.add);

    await Future.delayed(Duration.zero);

    // User 2 に切り替えてストリームを取得
    final user2Auth = FakeFirebaseAuth(mockUid: 'user_456');
    service.configure(db: fakeDb, auth: user2Auth);
    
    final stream2 = service.getRoleModelsStream();
    final emissions2 = <List<RoleModel>>[];
    final sub2 = stream2.listen(emissions2.add);

    await Future.delayed(Duration.zero);

    // User 2 で targetUser2 を登録
    final targetUser2 = AppUser(
      uid: 'target_user_789',
      displayName: 'John Smith',
      username: 'johnsmith',
    );
    await service.registerRoleModel(targetUser2);
    await Future.delayed(Duration.zero);

    // User 1 に切り替え、targetUser を登録
    service.configure(db: fakeDb, auth: fakeAuth);
    await service.registerRoleModel(targetUser);
    await Future.delayed(Duration.zero);

    await sub1.cancel();
    await sub2.cancel();

    // 検証：
    // User 1 のストリームは targetUser2 を含まず、targetUser のみを含むべき
    expect(emissions1.any((list) => list.any((r) => r.targetUid == targetUser.uid)), isTrue);
    expect(emissions1.any((list) => list.any((r) => r.targetUid == targetUser2.uid)), isFalse);

    // User 2 のストリームは targetUser を含まず、targetUser2 のみを含むべき
    expect(emissions2.any((list) => list.any((r) => r.targetUid == targetUser2.uid)), isTrue);
    expect(emissions2.any((list) => list.any((r) => r.targetUid == targetUser.uid)), isFalse);
  });
  ```

## 2. Logic Chain

- **Step 1**: The design of the `RoleModel` feature isolates role model listings on a per-user basis by saving them under `users/{myUid}/role_models/{targetUid}` (Observation 1).
- **Step 2**: The service fetches the stream by reading the currently logged-in user's UID via `_auth.currentUser?.uid` (Observation 1).
- **Step 3**: To verify that multiple concurrent users' streams do not leak or cross-talk (e.g. User B receiving updates meant for User A), we registered listeners for User A and User B concurrently and mutated their role models (Observation 3).
- **Step 4**: The test verified that User A's stream only contained User A's targets, and User B's stream only contained User B's targets. The test successfully passed (Observation 1).
- **Conclusion**: The current database structure and `getRoleModelsStream` query implementation are correct and successfully enforce multi-user stream isolation.

## 3. Caveats

- **Mock dependency limitation**: The tests rely on `FakeFirebaseFirestore` and `FakeFirebaseAuth` classes to simulate database reads/writes/streams. Real Firestore network conditions, offline cache synchronization, latency, or permission/security rules errors were not tested.
- **Unimplemented Design Features**: As noted by other reviewers, several core parts of the design (such as the `getWeeklyCompletionRate` service method and the weekly completion rate graph / posts history detail UI) are completely missing from the codebase. Since this is a "Review-only" verification, these missing components were not implemented or tested.

## 4. Conclusion

The current implementation of the Role Model service (registration, unregistration, checking status, and real-time streaming) is **correct, functional, and secure under mock conditions**.
However, the feature is **incomplete** with respect to the design document (missing the weekly completion rate calculation logic and the detailed activity screen).

## 5. Verification Method

To verify the test execution:
1. Run the following command in the project root:
   ```bash
   flutter test test/role_model_service_test.dart
   ```
2. Run the entire test suite:
   ```bash
   flutter test
   ```
3. Inspect `test/role_model_service_test.dart` to verify the presence of the `streams are isolated between different authenticated users` test.

---

# Adversarial Challenge Report

## Challenge Summary

- **Overall risk assessment**: MEDIUM

## Challenges

### [Medium] Challenge 1: Dynamic Client-Side DB Reading Cost (O(N) reads)
- **Assumption challenged**: Dynamic client-side calculation of the weekly completion rate (Section 4.1, Mode 1) is cost-effective and scalable.
- **Attack scenario**: A user registers 10-20 role models. The application UI tries to display a dashboard of all role models' weekly completion rate graph. For each role model, the app must load their weekly posts.
- **Blast radius**: High read counts on Firestore, resulting in high API costs and slower loading times.
- **Mitigation**: Strictly paginate or query with strict limit/date filters. Alternatively, use Mode 2 (daily pre-calculated statistics saved in a collection).

### [Low] Challenge 2: Cache Profile Desynchronization
- **Assumption challenged**: Caching display name and photoUrl in `role_models` subcollection is safe.
- **Attack scenario**: A target user updates their photoUrl or displayName. The user who registered them still sees the old data in their Role Model list because there is no automatic cache invalidation or update listener.
- **Blast radius**: Low/Medium UI inconsistency (stale name or photo URL).
- **Mitigation**: Run a periodic update trigger on the backend, or fetch user profiles dynamically from the main collection.

### [Low] Challenge 3: Registration of Non-existent UIDs
- **Assumption challenged**: `AppUser` passed to `registerRoleModel` is always valid.
- **Attack scenario**: The UI or a custom client payload calls `registerRoleModel` with an empty or non-existent UID.
- **Blast radius**: Low. A corrupt document is written.
- **Mitigation**: Add basic string check `if (targetUser.uid.isEmpty) throw ArgumentError('UID cannot be empty');`.
