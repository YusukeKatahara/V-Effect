# Context & Knowledge Base

## Project Context
- **Project Name**: V EFFECT
- **Framework**: Flutter (SDK ^3.7.0)
- **Language**: Dart (SDK ^3.7.0)
- **Objective**: Fix all `use_build_context_synchronously` warnings project-wide.

## Technical Context
- **Rule**: `use_build_context_synchronously` is triggered when a `BuildContext` is used across an asynchronous gap (after `await`) without verifying if the widget is still mounted.
- **Remediation**: Use `context.mounted` check (e.g., `if (!context.mounted) return;`) or structured checks, ensuring not to alter original business logic.
- **Reference**: Flutter 3.7+ introduces `BuildContext.mounted` natively.

## Investigation Scope
- Analyze files in `lib/` directory.
- Check target modules: `screens/`, `services/`, `widgets/`, `models/`, `utils/`.
- Compile and analyze warnings with `flutter analyze`.
