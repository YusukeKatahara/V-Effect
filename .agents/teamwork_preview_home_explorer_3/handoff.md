# Handoff Report: HomeScreen Components Refactoring Strategy

## 1. Observation
We analyzed `lib/screens/home_screen.dart` and identified six private widgets/classes defined inline:

1. **`_FeedCard`** (lines 1968 - 2285):
   ```dart
   class _FeedCard extends StatelessWidget {
     const _FeedCard({
       required this.post,
       required this.username,
       this.userPhotoUrl,
       this.userBadgeUrl,
       this.userBadgeAnimation,
       required this.dimAlpha,
       required this.onReaction,
       required this.isTop,
       required this.tierColor,
       required this.userPhotos,
       this.onProfileTap,
       this.onOptionsTap,
       this.reactionCountNotifier,
     });
     ...
   ```
   - **State/Service Dependencies**:
     - `Post` data model (`lib/models/post.dart`)
     - `VBadgeWidget` (`lib/widgets/v_badge_widget.dart`)
     - `CachedNetworkImage` & `CachedNetworkImageProvider` (`package:cached_network_image`)
     - `GoogleFonts` (`package:google_fonts`)
     - `AppColors` (`lib/config/app_colors.dart`)
   - **Callback/Interface Dependencies**:
     - `onReaction`: Function signature `Function({String? emoji})` (taps on fire icon)
     - `onProfileTap`: `VoidCallback?` (taps on username/avatar)
     - `onOptionsTap`: `VoidCallback?` (taps on three-dots menu icon)
     - `reactionCountNotifier`: `ValueNotifier<int>?` (value notifier to update the reaction count without rebuilding the entire card stack)
   - **Redundant Parameter**: `Map<String, String?> userPhotos` is defined and passed to `_FeedCard` but not used anywhere in the build method.

2. **`_GuardedStateLayer`** (lines 1802 - 1963):
   ```dart
   class _GuardedStateLayer extends StatefulWidget {
     final List<Post> feedPosts;
     final List<Map<String, dynamic>> postedFriends;
     final VoidCallback? onRefresh;
     ...
   ```
   - **State/Service Dependencies**:
     - `List<Post>` to get the first post's image URL for the blurred background lock screen.
     - `List<Map<String, dynamic>> postedFriends` (keys: `photoUrl`, `username`) to display avatars of friends who have already posted.
     - `AppLocalizations` for Japanese localizations.
     - `RefreshRingButton` (`lib/widgets/home/refresh_ring_button.dart`).
   - **Callback/Interface Dependencies**:
     - `onRefresh`: `VoidCallback?`
   - **Statefulness**: It is defined as a `StatefulWidget` but its `State` class holds no mutable state or lifecycle logic. It can be simplified to a `StatelessWidget`.

3. **`_FloatingFlamesLayer`** (lines 2290 - 2336) & **`_FloatingFlameWidget`** (lines 2341 - 2430):
   - **State/Service Dependencies**:
     - Controlled from the parent `HomeScreen` via `GlobalKey<_FloatingFlamesLayerState>`.
     - Internal map of flames `final Map<int, Widget> _flames`.
     - Uses `Icons.whatshot` and `AppColors.accentGold` / `AppColors.accentGoldLight` for rendering.
   - **Callback/Interface Dependencies**:
     - Exposes a public method `addFlame` on its state:
       ```dart
       void addFlame({
         Color? color,
         Color? glowColor,
         double? size,
         bool isGold = false,
         double bottomOffset = 120.0,
       })
       ```
     - `_FloatingFlameWidget` uses a `VoidCallback onComplete` to notify when its transition is finished.

4. **`_DopamineEmojiExplosionLayer`** (lines 2489 - 2568) & helper classes `_ParticleData` (lines 2463 - 2487), `_EmojiExplosionPainter` (lines 2571 - 2648):
   - **State/Service Dependencies**:
     - Controlled from the parent `HomeScreen` via `GlobalKey<_DopamineEmojiExplosionLayerState>`.
     - Internal physics ticker using `SingleTickerProviderStateMixin`.
     - High-performance drawing via `CustomPaint` and `TextPainter` directly to the Canvas to avoid widget rebuild overhead.
   - **Callback/Interface Dependencies**:
     - Exposes `explode(String emoji)` on its state.

5. **`_BgmIndicator`** (lines 2669 - 2767):
   - **State/Service Dependencies**:
     - `SoundService` (`lib/services/sound_service.dart`) to read `isBgmMuted` and toggle mute via `toggleBgmMute(widget.url)`.
     - `CachedNetworkImage` for displaying artwork.
     - `GoogleFonts` and `AppColors` for formatting.
     - `HapticFeedback.lightImpact()` on tap.
   - **Callback/Interface Dependencies**:
     - Fully self-contained widget. Does not require callback methods from the parent.

6. **`_FrictionlessPageScrollPhysics`** (lines 2435 - 2455):
   - **State/Service Dependencies**:
     - Completely self-contained custom `PageScrollPhysics` using custom `SpringDescription`. No external app dependencies.

---

## 2. Logic Chain
1. Code readability and testability in `home_screen.dart` is impacted by its size (~2,768 lines).
2. By extracting these six private widgets into public widgets inside `lib/widgets/home/`, we will significantly reduce the size of `home_screen.dart` (~1000+ lines saved) and improve maintenance.
3. Our analysis identified the dependencies (e.g., `Post` models, state tracking via `ValueNotifier`, `SoundService` singleton, and `GlobalKey` controllers) and clean parameter interfaces that allow the widgets to be fully decoupled from `HomeScreen` without breaking functionality.
4. Cleanups like removing the unused `userPhotos` parameter in `_FeedCard` and converting the stateless `_GuardedStateLayer` to a `StatelessWidget` will also improve code quality.

---

## 3. Caveats
- **GlobalKey usage**: `_FloatingFlamesLayer` and `_DopamineEmojiExplosionLayer` rely on `GlobalKey` state access for imperatively triggering fire/emoji animations. While an alternative controller pattern could be implemented, keeping `GlobalKey<FloatingFlamesLayerState>` and `GlobalKey<DopamineEmojiExplosionLayerState>` is the most direct and safest refactoring approach.
- **Localizations**: Both `FeedCard` and `GuardedStateLayer` use `AppLocalizations.of(context)`. We assume the widgets will be kept within the same app context where the localization provider is active.

---

## 4. Conclusion
We propose creating the following files in `lib/widgets/home/` and importing them back into `lib/screens/home_screen.dart`:

### A. `lib/widgets/home/feed_card.dart`
Exposes public `FeedCard`:
```dart
class FeedCard extends StatelessWidget {
  final Post post;
  final String username;
  final String? userPhotoUrl;
  final String? userBadgeUrl;
  final String? userBadgeAnimation;
  final double dimAlpha;
  final bool isTop;
  final Color tierColor;
  final ValueNotifier<int>? reactionCountNotifier;
  final VoidCallback? onReactionTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onOptionsTap;

  const FeedCard({
    super.key,
    required this.post,
    required this.username,
    this.userPhotoUrl,
    this.userBadgeUrl,
    this.userBadgeAnimation,
    required this.dimAlpha,
    required this.isTop,
    required this.tierColor,
    this.reactionCountNotifier,
    this.onReactionTap,
    this.onProfileTap,
    this.onOptionsTap,
  });
  
  // Implements the card UI code
}
```

### B. `lib/widgets/home/guarded_state_layer.dart`
Exposes public `GuardedStateLayer` (refactored as a `StatelessWidget`):
```dart
class GuardedStateLayer extends StatelessWidget {
  final List<Post> feedPosts;
  final List<Map<String, dynamic>> postedFriends;
  final VoidCallback? onRefresh;

  const GuardedStateLayer({
    super.key,
    required this.feedPosts,
    required this.postedFriends,
    this.onRefresh,
  });

  // Implements the lock screen/guarded state UI
}
```

### C. `lib/widgets/home/floating_flames_layer.dart`
Exposes `FloatingFlamesLayer` and its public state `FloatingFlamesLayerState` (with private `_FloatingFlameWidget` inside the file):
```dart
class FloatingFlamesLayer extends StatefulWidget {
  const FloatingFlamesLayer({super.key});

  @override
  State<FloatingFlamesLayer> createState() => FloatingFlamesLayerState();
}

class FloatingFlamesLayerState extends State<FloatingFlamesLayer> {
  void addFlame({
    Color? color,
    Color? glowColor,
    double? size,
    bool isGold = false,
    double bottomOffset = 120.0,
  });
}
```

### D. `lib/widgets/home/dopamine_emoji_explosion_layer.dart`
Exposes `DopamineEmojiExplosionLayer` and its state `DopamineEmojiExplosionLayerState` (with private `_ParticleData` and `_EmojiExplosionPainter` inside the file):
```dart
class DopamineEmojiExplosionLayer extends StatefulWidget {
  const DopamineEmojiExplosionLayer({super.key});

  @override
  State<DopamineEmojiExplosionLayer> createState() => DopamineEmojiExplosionLayerState();
}

class DopamineEmojiExplosionLayerState extends State<DopamineEmojiExplosionLayer>
    with SingleTickerProviderStateMixin {
  void explode(String emoji);
}
```

### E. `lib/widgets/home/bgm_indicator.dart`
Exposes `BgmIndicator`:
```dart
class BgmIndicator extends StatefulWidget {
  final String title;
  final String? artist;
  final String? url;
  final String? artworkUrl;

  const BgmIndicator({
    super.key,
    required this.title,
    this.artist,
    this.url,
    this.artworkUrl,
  });

  @override
  State<BgmIndicator> createState() => _BgmIndicatorState();
}
```

### F. `lib/widgets/home/frictionless_page_scroll_physics.dart`
Exposes `FrictionlessPageScrollPhysics`:
```dart
class FrictionlessPageScrollPhysics extends PageScrollPhysics {
  const FrictionlessPageScrollPhysics({super.parent});

  @override
  FrictionlessPageScrollPhysics applyTo(ScrollPhysics? ancestor);
}
```

---

## 5. Verification Method
1. **Analyze command**: Run `flutter analyze` to ensure there are no compilation, type, or lint errors in the workspace.
2. **Unit / Widget tests**: Run `flutter test` to ensure that existing tests for the home screen and its sub-widgets continue to pass.
3. **Manual verification**: Verify that the home screen builds correctly, BGM playing still works via `SoundService`, and fire/emoji animations play correctly under `GlobalKey` references.
