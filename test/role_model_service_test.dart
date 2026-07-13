// ignore_for_file: subtype_of_sealed_class

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_effect/models/app_user.dart';
import 'package:v_effect/models/role_model.dart';
import 'package:v_effect/services/role_model_service.dart';
import 'package:v_effect/models/app_task.dart';

// ─── Fake / Mock Classes For Firestore and Auth (No external dependency required) ───

class FakeUserCredential extends Fake implements UserCredential {
  final User? _user;
  FakeUserCredential(this._user);
  @override
  User? get user => _user;
}

class FakeUserInstance extends Fake implements User {
  final String _uid;
  FakeUserInstance(this._uid);
  @override
  String get uid => _uid;
}

class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  User? _currentUser;
  
  FakeFirebaseAuth({String? mockUid}) {
    if (mockUid != null) {
      _currentUser = FakeUserInstance(mockUid);
    }
  }

  @override
  User? get currentUser => _currentUser;
}

class FakeFirebaseFirestore extends Fake implements FirebaseFirestore {
  // Storage structure: myUid -> { targetUid -> dataMap }
  final Map<String, Map<String, Map<String, dynamic>>> _storage = {};
  
  // Storage for users: uid -> dataMap
  final Map<String, Map<String, dynamic>> _usersStorage = {};

  // Storage for posts: list of post maps
  final List<Map<String, dynamic>> _postsStorage = [];
  
  // Stream controllers to push real-time updates for snapshots()
  // myUid -> StreamController<QuerySnapshot<RoleModel>>
  final Map<String, StreamController<QuerySnapshot<RoleModel>>> _streamControllers = {};

  StreamController<QuerySnapshot<RoleModel>> _getOrCreateController(String myUid) {
    return _streamControllers.putIfAbsent(myUid, () => StreamController<QuerySnapshot<RoleModel>>.broadcast());
  }

  void _triggerUpdate(String myUid) {
    if (_streamControllers.containsKey(myUid)) {
      final controller = _streamControllers[myUid]!;
      final docsList = <QueryDocumentSnapshot<RoleModel>>[];
      final userStore = _storage[myUid] ?? {};
      
      userStore.forEach((targetUid, data) {
        docsList.add(FakeQueryDocumentSnapshot<RoleModel>(
          targetUid,
          RoleModel.fromMap(data),
        ));
      });
      
      controller.add(FakeQuerySnapshot<RoleModel>(docsList));
    }
  }

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    if (collectionPath == 'users') {
      return FakeUsersCollectionReference(this);
    }
    if (collectionPath == 'posts') {
      return FakePostsCollectionReference(this);
    }
    throw UnimplementedError('Collection path $collectionPath not supported in fake');
  }
}

class FakeUsersCollectionReference extends Fake implements CollectionReference<Map<String, dynamic>> {
  final FakeFirebaseFirestore _firestore;
  FakeUsersCollectionReference(this._firestore);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return FakeUserDocumentReference(_firestore, path ?? '');
  }
}

class FakeDocumentSnapshotForUsers extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  final String _id;
  final Map<String, dynamic>? _map;
  final bool _exists;

  FakeDocumentSnapshotForUsers(this._id, this._map, this._exists);

  @override
  String get id => _id;

  @override
  bool get exists => _exists;

  @override
  Map<String, dynamic>? data({SnapshotOptions? options}) => _map;
}

class FakeUserDocumentReference extends Fake implements DocumentReference<Map<String, dynamic>> {
  final FakeFirebaseFirestore _firestore;
  final String _myUid;
  FakeUserDocumentReference(this._firestore, this._myUid);

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    if (collectionPath == 'role_models') {
      return FakeRoleModelsCollectionReference(_firestore, _myUid);
    }
    throw UnimplementedError('Subcollection $collectionPath not supported on users doc');
  }

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    final exists = _firestore._usersStorage.containsKey(_myUid);
    final map = exists ? _firestore._usersStorage[_myUid] : null;
    return FakeDocumentSnapshotForUsers(_myUid, map, exists);
  }
}

class FakeRoleModelsCollectionReference extends Fake implements CollectionReference<Map<String, dynamic>> {
  final FakeFirebaseFirestore _firestore;
  final String _myUid;
  FakeRoleModelsCollectionReference(this._firestore, this._myUid);

  @override
  CollectionReference<R> withConverter<R>({
    required FromFirestore<R> fromFirestore,
    required ToFirestore<R> toFirestore,
  }) {
    return FakeRoleModelsConvertedCollectionReference<R>(_firestore, _myUid, fromFirestore, toFirestore);
  }
}

class FakeRoleModelsConvertedCollectionReference<R> extends Fake implements CollectionReference<R> {
  final FakeFirebaseFirestore _firestore;
  final String _myUid;
  final FromFirestore<R> _fromFirestore;
  final ToFirestore<R> _toFirestore;

  FakeRoleModelsConvertedCollectionReference(
    this._firestore,
    this._myUid,
    this._fromFirestore,
    this._toFirestore,
  );

  @override
  DocumentReference<R> doc([String? path]) {
    return FakeRoleModelDocumentReference<R>(_firestore, _myUid, path ?? '', _fromFirestore, _toFirestore);
  }

  @override
  Stream<QuerySnapshot<R>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    if (R == RoleModel) {
      final controller = _firestore._getOrCreateController(_myUid);
      // Push initial values asynchronously to match Firestore Stream behavior
      scheduleMicrotask(() {
        _firestore._triggerUpdate(_myUid);
      });
      return controller.stream as Stream<QuerySnapshot<R>>;
    }
    throw UnimplementedError('Only snapshots of RoleModel are supported');
  }
}

class FakePostsCollectionReference extends Fake implements CollectionReference<Map<String, dynamic>> {
  final FakeFirebaseFirestore _firestore;
  FakePostsCollectionReference(this._firestore);

  @override
  CollectionReference<R> withConverter<R>({
    required FromFirestore<R> fromFirestore,
    required ToFirestore<R> toFirestore,
  }) {
    return FakePostsConvertedCollectionReference<R>(_firestore, fromFirestore, toFirestore);
  }
}

class FakePostsConvertedCollectionReference<R> extends Fake implements CollectionReference<R> {
  final FakeFirebaseFirestore _firestore;
  final FromFirestore<R> _fromFirestore;

  FakePostsConvertedCollectionReference(
    this._firestore,
    this._fromFirestore,
    ToFirestore<R> toFirestore,
  );

  @override
  Query<R> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    return FakePostsQuery<R>(
      _firestore,
      _fromFirestore,
      filters: [
        QueryFilter(
          field: field as String,
          isEqualTo: isEqualTo,
          isGreaterThanOrEqualTo: isGreaterThanOrEqualTo,
        )
      ],
    );
  }
}

class QueryFilter {
  final String field;
  final Object? isEqualTo;
  final Object? isGreaterThanOrEqualTo;

  QueryFilter({
    required this.field,
    this.isEqualTo,
    this.isGreaterThanOrEqualTo,
  });
}

class FakePostsQuery<R> extends Fake implements Query<R> {
  final FakeFirebaseFirestore _firestore;
  final FromFirestore<R> _fromFirestore;
  final List<QueryFilter> filters;

  FakePostsQuery(this._firestore, this._fromFirestore, {required this.filters});

  @override
  Query<R> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    return FakePostsQuery<R>(
      _firestore,
      _fromFirestore,
      filters: List.from(filters)
        ..add(
          QueryFilter(
            field: field as String,
            isEqualTo: isEqualTo,
            isGreaterThanOrEqualTo: isGreaterThanOrEqualTo,
          ),
        ),
    );
  }

  @override
  Future<QuerySnapshot<R>> get([GetOptions? options]) async {
    var matchedPosts = _firestore._postsStorage;

    for (final filter in filters) {
      if (filter.field == 'userId') {
        if (filter.isEqualTo != null) {
          matchedPosts = matchedPosts.where((p) => p['userId'] == filter.isEqualTo).toList();
        }
      } else if (filter.field == 'createdAt') {
        if (filter.isGreaterThanOrEqualTo != null) {
          final threshold = filter.isGreaterThanOrEqualTo;
          matchedPosts = matchedPosts.where((p) {
            final pCreated = p['createdAt'];
            if (pCreated is Timestamp) {
              if (threshold is Timestamp) {
                return pCreated.compareTo(threshold) >= 0;
              } else if (threshold is DateTime) {
                return pCreated.toDate().isAfter(threshold) || pCreated.toDate().isAtSameMomentAs(threshold);
              }
            } else if (pCreated is DateTime) {
              if (threshold is Timestamp) {
                return pCreated.isAfter(threshold.toDate()) || pCreated.isAtSameMomentAs(threshold.toDate());
              } else if (threshold is DateTime) {
                return pCreated.isAfter(threshold) || pCreated.isAtSameMomentAs(threshold);
              }
            }
            return false;
          }).toList();
        }
      }
    }

    final docs = matchedPosts.map((map) {
      final docId = map['id'] ?? 'doc_id';
      final snapshot = FakeSnapshotForConverter(docId, map);
      final dataObj = _fromFirestore(snapshot, null);
      return FakeQueryDocumentSnapshot<R>(docId, dataObj);
    }).toList();

    return FakeQuerySnapshot<R>(docs);
  }
}

class FakeRoleModelDocumentReference<R> extends Fake implements DocumentReference<R> {
  final FakeFirebaseFirestore _firestore;
  final String _myUid;
  final String _targetUid;
  final FromFirestore<R> _fromFirestore;
  final ToFirestore<R> _toFirestore;

  FakeRoleModelDocumentReference(
    this._firestore,
    this._myUid,
    this._targetUid,
    this._fromFirestore,
    this._toFirestore,
  );

  @override
  Future<void> set(R data, [SetOptions? options]) async {
    final map = _toFirestore(data, null);
    final userStore = _firestore._storage.putIfAbsent(_myUid, () => {});
    userStore[_targetUid] = map;
    _firestore._triggerUpdate(_myUid);
  }

  @override
  Future<void> delete() async {
    final userStore = _firestore._storage[_myUid];
    if (userStore != null) {
      userStore.remove(_targetUid);
      _firestore._triggerUpdate(_myUid);
    }
  }

  @override
  Future<DocumentSnapshot<R>> get([GetOptions? options]) async {
    final userStore = _firestore._storage[_myUid];
    final exists = userStore != null && userStore.containsKey(_targetUid);
    final map = exists ? userStore[_targetUid] : null;
    return FakeDocumentSnapshot<R>(_targetUid, map, exists, _fromFirestore);
  }
}

class FakeDocumentSnapshot<R> extends Fake implements DocumentSnapshot<R> {
  final String _id;
  final Map<String, dynamic>? _map;
  final bool _exists;
  final FromFirestore<R> _fromFirestore;

  FakeDocumentSnapshot(this._id, this._map, this._exists, this._fromFirestore);

  @override
  String get id => _id;

  @override
  bool get exists => _exists;

  @override
  R? data() {
    if (!_exists || _map == null) return null;
    final mockSnapshot = FakeSnapshotForConverter(_id, _map);
    return _fromFirestore(mockSnapshot, null);
  }
}

class FakeSnapshotForConverter extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  final String _id;
  final Map<String, dynamic> _map;
  FakeSnapshotForConverter(this._id, this._map);

  @override
  String get id => _id;

  @override
  Map<String, dynamic> data({SnapshotOptions? options}) => _map;
}

class FakeQuerySnapshot<R> extends Fake implements QuerySnapshot<R> {
  final List<QueryDocumentSnapshot<R>> _docs;
  FakeQuerySnapshot(this._docs);

  @override
  List<QueryDocumentSnapshot<R>> get docs => _docs;
}

class FakeQueryDocumentSnapshot<R> extends Fake implements QueryDocumentSnapshot<R> {
  final String _id;
  final R _data;
  FakeQueryDocumentSnapshot(this._id, this._data);

  @override
  String get id => _id;

  @override
  R data() => _data;
}

// ─── Unit Tests ───

void main() {
  group('RoleModelService Unit Tests', () {
    late FakeFirebaseFirestore fakeDb;
    late FakeFirebaseAuth fakeAuth;
    late RoleModelService service;

    const myUid = 'current_user_123';
    final targetUser = AppUser(
      uid: 'target_user_456',
      displayName: 'Jane Doe',
      username: 'janedoe',
      photoUrl: 'https://example.com/jane.jpg',
    );

    setUp(() {
      fakeDb = FakeFirebaseFirestore();
      fakeAuth = FakeFirebaseAuth(mockUid: myUid);
      service = RoleModelService.instance;
      service.configure(db: fakeDb, auth: fakeAuth);
    });

    test('registerRoleModel saves role model details to Firestore subcollection', () async {
      // Targetをロールモデルとして登録
      await service.registerRoleModel(targetUser);

      // 登録されたことを検証
      final isReg = await service.isRoleModel(targetUser.uid);
      expect(isReg, isTrue);

      // Firestoreストレージ内の特定フィールドのデータを直接検証
      final userStore = fakeDb._storage[myUid];
      expect(userStore, isNotNull);
      final roleModelData = userStore![targetUser.uid];
      expect(roleModelData, isNotNull);
      expect(roleModelData!['targetUid'], targetUser.uid);
      expect(roleModelData['displayName'], targetUser.displayName);
      expect(roleModelData['username'], targetUser.username);
      expect(roleModelData['photoUrl'], targetUser.photoUrl);
      expect(roleModelData['createdAt'], isA<Timestamp>());
    });

    test('removeRoleModel deletes role model from subcollection', () async {
      // 登録する
      await service.registerRoleModel(targetUser);
      expect(await service.isRoleModel(targetUser.uid), isTrue);

      // 削除（解除）する
      await service.removeRoleModel(targetUser.uid);

      // 削除されたことを検証
      expect(await service.isRoleModel(targetUser.uid), isFalse);
    });

    test('isRoleModel returns false for unregistered users', () async {
      final isReg = await service.isRoleModel('some_unregistered_uid');
      expect(isReg, isFalse);
    });

    test('getRoleModelsStream yields real-time updates when role models are registered or removed', () async {
      final stream = service.getRoleModelsStream();

      // ストリームの購読を開始
      final emissions = <List<RoleModel>>[];
      final subscription = stream.listen(emissions.add);

      // 初回の空ストリーム放出を待つ
      await Future.delayed(Duration.zero);

      // 1人目のターゲットを登録
      await service.registerRoleModel(targetUser);
      await Future.delayed(Duration.zero);

      // 2人目のターゲットを登録
      final targetUser2 = AppUser(
        uid: 'target_user_789',
        displayName: 'John Smith',
        username: 'johnsmith',
        photoUrl: null,
      );
      await service.registerRoleModel(targetUser2);
      await Future.delayed(Duration.zero);

      // 1人目を削除
      await service.removeRoleModel(targetUser.uid);
      await Future.delayed(Duration.zero);

      // 購読を終了
      await subscription.cancel();

      // 受信データを検証
      expect(emissions.length, greaterThanOrEqualTo(4));
      // 初回状態：空
      expect(emissions[0], isEmpty);
      // 1人目登録後
      expect(emissions[1].length, 1);
      expect(emissions[1][0].targetUid, targetUser.uid);
      // 2人目登録後
      expect(emissions[2].length, 2);
      expect(emissions[2].any((r) => r.targetUid == targetUser2.uid), isTrue);
      // 1人目削除後
      expect(emissions[3].length, 1);
      expect(emissions[3][0].targetUid, targetUser2.uid);
    });

    test('registerRoleModel throws exception when not authenticated', () async {
      service.configure(db: fakeDb, auth: FakeFirebaseAuth(mockUid: null));
      expect(
        () => service.registerRoleModel(targetUser),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('User not authenticated'))),
      );
    });

    test('removeRoleModel throws exception when not authenticated', () async {
      service.configure(db: fakeDb, auth: FakeFirebaseAuth(mockUid: null));
      expect(
        () => service.removeRoleModel(targetUser.uid),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('User not authenticated'))),
      );
    });

    test('removeRoleModel of an unregistered user is a no-op and does not throw', () async {
      // 登録されていないことを確認
      expect(await service.isRoleModel(targetUser.uid), isFalse);

      // 削除処理が例外を出さずに終了することを確認
      await expectLater(service.removeRoleModel(targetUser.uid), completes);

      // 引き続き登録されていないことを確認
      expect(await service.isRoleModel(targetUser.uid), isFalse);
    });

    test('role models are isolated between different authenticated users (multi-user)', () async {
      // User 1 で targetUser を登録
      await service.registerRoleModel(targetUser);
      expect(await service.isRoleModel(targetUser.uid), isTrue);

      // User 2 に切り替え
      final user2Auth = FakeFirebaseAuth(mockUid: 'user_456');
      service.configure(db: fakeDb, auth: user2Auth);

      // User 2 では targetUser が登録されていないことを検証
      expect(await service.isRoleModel(targetUser.uid), isFalse);

      // User 2 で targetUser2 を登録
      final targetUser2 = AppUser(
        uid: 'target_user_789',
        displayName: 'John Smith',
        username: 'johnsmith',
      );
      await service.registerRoleModel(targetUser2);
      expect(await service.isRoleModel(targetUser2.uid), isTrue);
      expect(await service.isRoleModel(targetUser.uid), isFalse);

      // 再び User 1 に切り替え
      service.configure(db: fakeDb, auth: fakeAuth);
      expect(await service.isRoleModel(targetUser.uid), isTrue);
      expect(await service.isRoleModel(targetUser2.uid), isFalse);
    });

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

    test('getWeeklyCompletionRate calculates correct completion rates', () async {
      // 1. Setup target user who has 3 tasks
      final userWithTasks = AppUser(
        uid: 'target_user_456',
        displayName: 'Jane Doe',
        username: 'janedoe',
        tasks: const [
          AppTask(id: 'task1', title: 'Running'),
          AppTask(id: 'task2', title: 'Reading'),
          AppTask(id: 'task3', title: 'Coding'),
        ],
      );
      fakeDb._usersStorage[userWithTasks.uid] = userWithTasks.toFirestore();

      // 2. Setup some posts
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      
      fakeDb._postsStorage.addAll([
        // Today
        {
          'id': 'post_today_1',
          'userId': userWithTasks.uid,
          'taskName': 'Running',
          'createdAt': Timestamp.fromDate(todayStart.add(const Duration(hours: 8))),
        },
        {
          'id': 'post_today_2',
          'userId': userWithTasks.uid,
          'taskName': 'Reading',
          'createdAt': Timestamp.fromDate(todayStart.add(const Duration(hours: 12))),
        },
        {
          // Duplicate task name on same day: should not count twice
          'id': 'post_today_3',
          'userId': userWithTasks.uid,
          'taskName': 'Running',
          'createdAt': Timestamp.fromDate(todayStart.add(const Duration(hours: 15))),
        },
        // 2 days ago
        {
          'id': 'post_2d_1',
          'userId': userWithTasks.uid,
          'taskName': 'Running',
          'createdAt': Timestamp.fromDate(todayStart.subtract(const Duration(days: 2)).add(const Duration(hours: 2))),
        },
        {
          'id': 'post_2d_2',
          'userId': userWithTasks.uid,
          'taskName': 'Reading',
          'createdAt': Timestamp.fromDate(todayStart.subtract(const Duration(days: 2)).add(const Duration(hours: 4))),
        },
        {
          'id': 'post_2d_3',
          'userId': userWithTasks.uid,
          'taskName': 'Coding',
          'createdAt': Timestamp.fromDate(todayStart.subtract(const Duration(days: 2)).add(const Duration(hours: 6))),
        },
        // 6 days ago
        {
          'id': 'post_6d_1',
          'userId': userWithTasks.uid,
          'taskName': 'Coding',
          'createdAt': Timestamp.fromDate(todayStart.subtract(const Duration(days: 6)).add(const Duration(hours: 1))), // inside range
        },
        // 7 days ago (out of range)
        {
          'id': 'post_7d_1',
          'userId': userWithTasks.uid,
          'taskName': 'Running',
          'createdAt': Timestamp.fromDate(todayStart.subtract(const Duration(days: 7))),
        },
      ]);

      // Call the service method
      final result = await service.getWeeklyCompletionRate(userWithTasks.uid);

      // Verify the map size
      expect(result.length, 7);

      final startOfWeek = todayStart.subtract(const Duration(days: 6));
      
      // Verify individual days
      // Today (Day 6) -> 2 unique tasks: Running, Reading -> 2/3 = 0.67
      expect(result[todayStart], closeTo(2 / 3, 0.01));

      // Yesterday (Day 5) -> 0 unique tasks -> 0.0
      final yesterday = todayStart.subtract(const Duration(days: 1));
      expect(result[yesterday], 0.0);

      // 2 days ago (Day 4) -> 3 unique tasks -> 1.0
      final twoDaysAgo = todayStart.subtract(const Duration(days: 2));
      expect(result[twoDaysAgo], 1.0);

      // 6 days ago (Day 0) -> 1 unique task -> 1/3 = 0.33
      final sixDaysAgo = startOfWeek;
      expect(result[sixDaysAgo], closeTo(1 / 3, 0.01));
    });

    test('getWeeklyCompletionRate returns empty map if user does not exist', () async {
      final result = await service.getWeeklyCompletionRate('non_existent_user');
      expect(result, isEmpty);
    });

    test('getWeeklyCompletionRate returns all 0.0 if user has no tasks', () async {
      final userNoTasks = AppUser(
        uid: 'user_no_tasks',
        displayName: 'No Tasks',
        username: 'notasks',
        tasks: const [],
      );
      fakeDb._usersStorage[userNoTasks.uid] = userNoTasks.toFirestore();

      final result = await service.getWeeklyCompletionRate(userNoTasks.uid);
      expect(result.length, 7);
      expect(result.values.every((v) => v == 0.0), isTrue);
    });

    test('getWeeklyCompletionRate clamps rate to 1.0 when unique posts exceed tasks length', () async {
      final userTwoTasks = AppUser(
        uid: 'user_two_tasks',
        displayName: 'Two Tasks',
        username: 'twotasks',
        tasks: const [
          AppTask(id: 't1', title: 'Task 1'),
          AppTask(id: 't2', title: 'Task 2'),
        ],
      );
      fakeDb._usersStorage[userTwoTasks.uid] = userTwoTasks.toFirestore();

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      fakeDb._postsStorage.addAll([
        {
          'id': 'post_clamp_1',
          'userId': userTwoTasks.uid,
          'taskName': 'Task 1',
          'createdAt': Timestamp.fromDate(todayStart.add(const Duration(hours: 8))),
        },
        {
          'id': 'post_clamp_2',
          'userId': userTwoTasks.uid,
          'taskName': 'Task 2',
          'createdAt': Timestamp.fromDate(todayStart.add(const Duration(hours: 10))),
        },
        {
          'id': 'post_clamp_3',
          'userId': userTwoTasks.uid,
          'taskName': 'Task 3 (extra)',
          'createdAt': Timestamp.fromDate(todayStart.add(const Duration(hours: 12))),
        },
      ]);

      final result = await service.getWeeklyCompletionRate(userTwoTasks.uid);
      expect(result[todayStart], 1.0);
    });

    test('getWeeklyCompletionRate excludes posts outside the 7-day range precisely', () async {
      final userOneTask = AppUser(
        uid: 'user_one_task',
        displayName: 'One Task',
        username: 'onetask',
        tasks: const [
          AppTask(id: 't1', title: 'Task 1'),
        ],
      );
      fakeDb._usersStorage[userOneTask.uid] = userOneTask.toFirestore();

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final startOfWeek = todayStart.subtract(const Duration(days: 6));

      // Just before startOfWeek (e.g. 1 second before) should be excluded
      final justBeforeStart = startOfWeek.subtract(const Duration(seconds: 1));
      // Just after startOfWeek (e.g. at startOfWeek exactly) should be included
      final exactlyAtStart = startOfWeek;

      fakeDb._postsStorage.addAll([
        {
          'id': 'post_excluded',
          'userId': userOneTask.uid,
          'taskName': 'Task 1',
          'createdAt': Timestamp.fromDate(justBeforeStart),
        },
        {
          'id': 'post_included',
          'userId': userOneTask.uid,
          'taskName': 'Task 1',
          'createdAt': Timestamp.fromDate(exactlyAtStart),
        },
      ]);

      final result = await service.getWeeklyCompletionRate(userOneTask.uid);
      
      // The day before startOfWeek is not in the map
      final dayBefore = startOfWeek.subtract(const Duration(days: 1));
      expect(result.containsKey(dayBefore), isFalse);

      // startOfWeek has completion rate of 1.0
      expect(result[startOfWeek], 1.0);
    });
  });
}
