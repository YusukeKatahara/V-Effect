# Execution Plan — Refactoring Hero Tasks Screen & Fixing Compile Errors

This plan outlines the steps to complete the refactoring of `lib/screens/hero_tasks_screen.dart`, delete duplicate classes, import and use the extracted components, and verify correctness.

## Steps

### Step 1: Investigation (Explorer Agent)
- Spawn an Explorer agent to:
  - Inspect `lib/screens/hero_tasks_screen.dart` from line 1240 onwards to confirm classes to be deleted.
  - Review components in `lib/screens/hero_tasks/components/` to ensure we understand their APIs.
  - Find all references to `_HeroTaskItem`, `_TaskCard`, `_PulseCameraButton`, `_FrictionlessPageScrollPhysics`, `_AutoSizeText` in `hero_tasks_screen.dart`.
  - Recommend the exact modifications and imports needed.
- **Verification**: The Explorer reports the precise line numbers, classes, and import statements.

### Step 2: Implementation (Worker Agent)
- Spawn a Worker agent to:
  - Apply the recommended changes to `lib/screens/hero_tasks_screen.dart`.
  - Remove duplicate classes/methods (lines 1245 to end).
  - Add imports for components and custom physics.
  - Update all `_HeroTaskItem` references to `HeroTaskItem`.
  - Run `flutter analyze` and `flutter build ios --config-only` to ensure it compiles without errors.
- **Verification**: The Worker provides a report with the changes applied, analysis output, and build output.

### Step 3: Review & Challenge (Reviewer & Challenger Agents)
- Spawn Reviewers to inspect the modified code for correctness, design style, and consistency.
- Spawn Challengers to verify compilation and verify no runtime or logic errors are introduced.
- **Verification**: Both agents approve the changes.

### Step 4: Forensic Audit (Auditor Agent)
- Spawn a Forensic Auditor agent to verify code integrity (no hardcoding, no dummy implementations, authentic refactoring).
- **Verification**: Auditor returns a CLEAN verdict.

### Step 5: Final Aggregation and Completion
- Verify that everything compiles, analyze has 0 issues, and the screen size is under 1300 lines.
- Report victory to the main agent.
