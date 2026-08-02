# Project Context: V-Effect Screen Refactoring

## Target Files & Sizes
1. `lib/screens/home_screen.dart` (~108KB)
2. `lib/screens/hero_tasks_screen.dart` (~85KB)
3. `lib/screens/profile_screen.dart` (~75KB)

## Architectural Guidelines
- Follow `coding-rules/SKILL.md`.
- Keep screen-specific sub-widgets under screen-specific folders (e.g. `lib/screens/home/components/`) to avoid cluttering `lib/widgets/` which is for global reusable components.
- Do not modify data models or Firestore services.
- Ensure all comments in code are in Japanese.
- Technical terms in explanations for renn (Planner) should have simple explanations in parentheses.

## Technical Environment
- Flutter SDK ^3.7.0
- Provider for State Management
- Absolute Monochrome + Gold Accent Theme
