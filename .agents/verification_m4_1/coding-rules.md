# Coding Rules Skill Copy
Refer to the original skill at: `/Users/rennlikeu/development/V-Effect/.agents/skills/coding-rules/SKILL.md`

## Summary of Coding Guidelines
- **Architecture**: Models (immutable, `copyWith`, `withConverter`), Services (singleton, external comms), Widgets (reusable UI), Screens (layout/Provider).
- **Hardened Data Layer**: fieldConstants to avoid magic strings, resilient parsing with `try-catch` & default values in `fromMap`, atomic updates using dot notation, redundant state checks.
- **State Management**: Riverpod for data fetch, ValueNotifier/ChangeNotifier for local/frequent updates.
- **Design System**: Monochrome + Gold Accent, standard fonts (Inter, Orbitron, Outfit), shared widgets, easeOutExpo animations.
- **Naming/Style**: English names, Japanese comments, `///` doc comments.
- **Form UI**: No fixed ratio height layouts, fixed headers, CustomScrollView/SliverList, bottom-docked action buttons inside SliverFillRemaining.
