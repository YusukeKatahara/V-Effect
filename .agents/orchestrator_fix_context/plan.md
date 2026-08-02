# Project Execution Plan - Fix Build Context Warnings

## Phase 1: Exploration & Code Analysis
1. Spawn an Explorer subagent (`teamwork_preview_explorer`) to find all occurrences of `use_build_context_synchronously` warnings.
2. The Explorer will run analysis (e.g. `flutter analyze` or grep search) to get the exact file paths and line numbers.
3. Review the Explorer's findings report.

## Phase 2: Plan & Decompose
1. Classify warnings by file / module (e.g., Auth, Profile, Home, Notifications).
2. Create `PROJECT.md` at the project root defining the Architecture, Milestones, and Interface Contracts.
3. Determine target subagents and define their workspaces.

## Phase 3: Implementation
1. Spawn Workers to implement fixes module by module.
2. Make sure the implementation strictly uses `context.mounted` check (e.g., `if (!context.mounted) return;`) or appropriate error/flow handling.
3. Ensure Worker does not change surrounding business logic.

## Phase 4: Verification
1. Spawn Reviewers to check changes.
2. Spawn Challengers to verify correctness.
3. Spawn Forensic Auditor to verify integrity and correctness.
4. Run global `flutter analyze` and `flutter build ios --config-only` to ensure everything is resolved and compiling.
