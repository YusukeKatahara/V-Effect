# Scope: Hero Tasks Screen Refactoring Completion & Fix

## Architecture
- `lib/screens/hero_tasks_screen.dart` is the main screen showing hero tasks.
- Extracted components are located in `lib/screens/hero_tasks/components/`.
  - `task_card.dart`
  - `hero_task_item.dart`
  - `pulse_camera_button.dart`
  - `auto_size_text.dart`
- Custom physics: `lib/widgets/frictionless_page_scroll_physics.dart`.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Exploration & Diagnostic | Identify duplicate widgets, verify components, check import requirements and current issues. | None | DONE |
| 2 | Refactoring & Integration | Delete lines 1245 to end in `hero_tasks_screen.dart`, add correct imports, rename `_HeroTaskItem` to `HeroTaskItem`, use `FrictionlessPageScrollPhysics` widget. | M1 | DONE |
| 3 | Verification & Compile Fix | Run build tests, `flutter analyze`, and fix any compile/lint errors until build completes successfully. | M2 | DONE |

## Interface Contracts
- **No visual or functional changes**: Keep the exact same UI and behaviors.
- **Component integrity**: Do not alter component logic unless required to resolve compile errors.
