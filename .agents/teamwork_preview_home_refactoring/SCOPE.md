# Scope: Refactor Home Screen

## Architecture & Goal
Extract private widgets and helpers from `lib/screens/home_screen.dart` into separate reusable/clean widget files under `lib/screens/home/components/` and `lib/widgets/`. Keep the main `home_screen.dart` readable and focused.

## Extraction Targets
1. `_FeedCard` -> `lib/screens/home/components/feed_card.dart`
2. `_GuardedStateLayer` -> `lib/screens/home/components/guarded_state_layer.dart`
3. `_FloatingFlamesLayer` and `_FloatingFlameWidget` -> `lib/screens/home/components/floating_flames_layer.dart`
4. `_DopamineEmojiExplosionLayer`, `_EmojiExplosionPainter`, and `_ParticleData` -> `lib/screens/home/components/dopamine_emoji_explosion_layer.dart`
5. `_BgmIndicator` -> `lib/screens/home/components/bgm_indicator.dart`
6. `_FrictionlessPageScrollPhysics` -> `lib/widgets/frictionless_page_scroll_physics.dart` (shared utility)

## Interface Contracts
- The extracted widgets should compile cleanly and expose clean, documented public constructors and callback APIs where they need to communicate with the parent `home_screen.dart` state.
- Keep comments in Japanese.
- No visual or behavioral changes allowed.
- target `home_screen.dart` must be <800-1000 lines.
