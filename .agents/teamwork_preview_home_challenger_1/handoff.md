# Handoff Report — Home Screen Adversarial & Empirical Validation

## 1. Observation

Based on direct inspection of the newly refactored home screen files, we observed the following specific implementation details, lines of code, and tool results:

### A. Ad Card Click Blocking (Gesture Interception)
In `lib/screens/home_screen.dart`, lines 1230–1235:
```dart
Positioned.fill(
  child: PageView.builder(
    controller: _pageController,
    physics: const FrictionlessPageScrollPhysics(),
    onPageChanged: _onPageChanged,
    itemBuilder: (context, index) {
      final actualIndex = index % _feedItems.length;
      final item = _feedItems[actualIndex];
      ...
```
And lines 1250–1268:
```dart
Positioned(
  top: 0,
  left: 0,
  right: 0,
  bottom: 180,
  child: GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () {
      if (item is! Post) return;
      if (_reactionMenuOpen) {
        setState(() => _reactionMenuOpen = false);
        _reactionMenuController.reverse();
      } else {
        _sendReaction(actualIndex);
      }
    },
    child: const SizedBox.expand(),
  ),
),
```
For items where `item == 'ad'`, this opaque `GestureDetector` covering the top portion of the page is still rendered in the tree. Because its behavior is `opaque` and it expands to fill the area, it intercepts pointer hit-tests.

### B. Unhandled TickerCanceled Exception in Animation
In `lib/screens/home/components/floating_flames_layer.dart`, lines 85–110:
```dart
_ctrl = AnimationController(
  vsync: this,
  duration: Duration(milliseconds: widget.isGold ? 1500 : 1000),
);
...
_ctrl.forward().then((_) => widget.onComplete());
```
There is no error callback or catch block attached to `_ctrl.forward()`.

### C. Async BGM Race Conditions in SoundService
In `lib/services/sound_service.dart`, lines 124–136:
```dart
Future<void> playBgm(String url, {bool userExplicitAction = false}) async {
  _fadeTimer?.cancel();
  
  if (_isBgmMuted) {
    return;
  }

  try {
    if (_bgmPlayer.state == PlayerState.playing) {
      await _bgmPlayer.stop();
    }
```
This asynchronous play function is triggered on card focus changes without any concurrency locks or checking if the request matches the latest user-focused card.

### D. ValueNotifier Allocation and Disposal
In `lib/screens/home_screen.dart`, line 79:
```dart
final Map<String, ValueNotifier<int>> _flameNotifiers = {};
```
In `lib/screens/home_screen.dart`, lines 955–959:
```dart
if (_flameNotifiers.containsKey(fetchedPost.id)) {
  _flameNotifiers[fetchedPost.id]!.value = totalCount;
} else {
  _flameNotifiers[fetchedPost.id] = ValueNotifier(totalCount);
}
```
However, in `_HomeScreenState.dispose()`, these `ValueNotifier` instances are not disposed.
Additionally, in `lib/screens/home/components/feed_card.dart`, lines 268–280:
```dart
ValueListenableBuilder<int>(
  valueListenable: reactionCountNotifier ?? ValueNotifier(post.reactionCount),
  ...
)
```
If `reactionCountNotifier` is null, a new `ValueNotifier` is created inline inside the `build` method.

### E. In-Memory Read Status
In `lib/screens/home_screen.dart`, line 55:
```dart
final Set<String> _viewedPostIds = {}; // 閲覧済みポストのID
```
This set is purely in-memory and is never stored in `SharedPreferences` or database.

### F. Tool Execution Results
* **Analysis**: `flutter analyze` completed with exit code `1` due to warnings/infos in other unrelated files (42 issues found total, e.g., unused imports/fields in camera, notifications, etc.). The newly refactored home screen and provider files contained **zero compiler errors or warnings**.
* **Testing**: `flutter test` completed successfully with:
  ```
  All tests passed!
  ```

---

## 2. Logic Chain

From these observations, we trace the following reasoning:

1. **Ad Card Blocking**:
   * The transparent `PageView.builder` sits on top of the 3D card stack.
   * When `item == 'ad'`, the `GestureDetector` in the page overlay still renders as an opaque `SizedBox.expand()`.
   * **Conclusion**: This gesture detector absorbs and blocks all tap hit-tests, preventing click events from reaching `NativeAdCard` underneath. Ads are unclickable.

2. **Animation Crash Risk (`TickerCanceled`)**:
   * When `_FloatingFlameWidgetState.dispose()` is called (e.g. when navigated away or parent screen is closed), `_ctrl.dispose()` is called while the controller is running.
   * This cancels the ticker, causing `_ctrl.forward()` to complete with a `TickerCanceled` error.
   * Because `.then((_) => ...)` is chained without error-handling (`catchError`), this error bubbles up as an unhandled async exception.
   * **Conclusion**: Navigating away from the home screen while flames are active will trigger unhandled asynchronous exceptions in production.

3. **BGM Race Conditions**:
   * `playBgm` is an async function that stops the player and starts a new source.
   * If the user swipes quickly, multiple async `playBgm` calls execute concurrently.
   * **Conclusion**: Out-of-order network responses could cause the wrong BGM to start playing for the focused post, or cause player engine errors.

4. **ValueNotifier Lifetime**:
   * `_flameNotifiers` are added to a map on the state. They are never disposed during state teardown.
   * In `FeedCard`, if `reactionCountNotifier` is null, creating `ValueNotifier` on every build leads to GC churn.
   * **Conclusion**: Memory is not cleaned up cleanly on disposal, and stateless widget instantiates disposable resources inline.

5. **State Restoration & Read Status**:
   * `_viewedPostIds` is stored in-memory.
   * **Conclusion**: Restarting the app resets the read status, causing previously read posts to resort and show up as unread again.

---

## 3. Caveats

* **Ad Click Testing**: We evaluated gesture behavior via code analysis of the layout stack and hit-testing properties. Since the runtime runs headlessly, we cannot physically tap the screen to record a native click event, but the layout logic dictates hit-test blockages.
* **Audio player configuration**: Native media player behavior under concurrency depends heavily on the OS implementation (iOS AVQueuePlayer / Android MediaPlayer).

---

## 4. Conclusion

The newly refactored home screen builds cleanly and passes all test suites. However, adversarial analysis reveals key vulnerabilities:
1. **Critical**: Ads cannot be clicked due to PageView opaque gesture interception.
2. **High**: Unhandled `TickerCanceled` crash risk during active flame animations upon screen exit.
3. **Medium**: Audio race condition when swiping quickly.
4. **Low**: Memory cleanup issues regarding undisposed `ValueNotifier`s and in-memory read status loss.

---

## 5. Verification Method

### How to Verify Analysis and Tests
1. Run static analysis:
   ```bash
   flutter analyze
   ```
2. Run project tests:
   ```bash
   flutter test
   ```

### How to Verify the Findings
* **Ad Interception**: Inspect `lib/screens/home_screen.dart` line 1250. Check if `item is! Post` prevents rendering or changes gesture behavior.
* **Animation Exceptions**: Navigate away from the home screen while spamming the V-FIRE button. Observe the console for unhandled `TickerCanceled` errors.
