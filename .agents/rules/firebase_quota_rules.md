# Firebase Firestore Guidelines

## Preventing Quota Exhaustion

When building Flutter applications reading from Firestore, adhere strictly to the following caching and streaming rules to prevent exceeding Firebase quota limits (especially the 50,000 document reads/day free tier limit):

### 1. Cache Streams in `State` instances
**Never** initialize a `Stream` directly in the `stream:` parameter of a `StreamBuilder` inside a `build()` method. 

#### Bad (Causes excessive reads on rebuilds)
```dart
@override
Widget build(BuildContext context) {
  return StreamBuilder(
    stream: _firestore.collection('users').snapshots(), // 🔥 ANTI-PATTERN
    builder: (context, snapshot) { ... }
  );
}
```

#### Good (Caches stream per widget lifecycle)
```dart
late final Stream<QuerySnapshot> _usersStream;

@override
void initState() {
  super.initState();
  _usersStream = _firestore.collection('users').snapshots(); // ✅ GOOD
}

@override
Widget build(BuildContext context) {
  return StreamBuilder(
    stream: _usersStream,
    builder: (context, snapshot) { ... }
  );
}
```

### 2. Prefer Future / `get()` over Streams / `snapshots()`
Unless the user interface explicitly requires real-time updating of data while the screen is open (e.g., chat apps, feed viewers waiting for instant replies), **always** use `.get()` in `initState` or inside a refresh callback instead of `.snapshots()`.

### 3. Apply `limit()` to Queries
Do not leave arrays or collections unbounded if you only display a few items. If a user has 1000 past friend requests, reading them all wastes quota. Always apply `.limit(X)` to queries where possible.
