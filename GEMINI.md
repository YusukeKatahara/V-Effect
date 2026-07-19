# V EFFECT Project Context (Gemini CLI)

This file provides context and instructions for the Gemini CLI. It imports existing rules and project information to ensure consistency between the CLI and Antigravity (IDE agent).

## Imports

@./.agents/skills/v-effect-context/SKILL.md
@./.agents/skills/coding-rules/SKILL.md
@./.agents/skills/response-style/SKILL.md
@./CONTEXT.md

## Additional CLI Instructions

- **File Management**: Use `read_url_content` (or similar tools) to fetch documentation when needed.
- **Safety**: Ensure API keys and sensitive data are never committed (check `.env` and `.gitignore`).

## Version Update Procedures (バージョン変更時の手順)

- **Automated Update & Sync**: `pubspec.yaml` のバージョンを変更する指示を受けた際は、単にファイルを書き換えるだけでなく、必ず以下の手順を連続して実行すること：
  1. `pubspec.yaml` のバージョン番号（およびビルド番号）を更新。
  2. `flutter pub get` を実行して依存関係を同期。
  3. `flutter build ios --config-only` コマンドを実行し、Xcode用のビルド構成ファイル（`Generated.xcconfig` など）に新しいバージョンを強制的に同期させる。
  4. **iOS Target Validation (iOSターゲット検証)**: `project.pbxproj` の `IPHONEOS_DEPLOYMENT_TARGET` や `CreatedOnToolsVersion` が異常な値（例: `20.0` 以上など、存在しないiOSバージョン）になっていないかを検証すること。

## iOS Build Target Guardrails (iOSビルドターゲットの監視ルール)

- **Target Version Consistency**: AIエージェントがバージョンバンプやビルド設定の書き換えを行う際は、`project.pbxproj` のiOSバージョンを勝手に書き換えてはならない。もし `20.0` 以上の異常値を発見した場合は、自動的に `16.0`（および関連のツールバージョンは `1600` など）に修正すること。

## Build Error & Debugging (Efficiency)

- **Prioritize Error Messages**: When a build error occurs, identify the first specific error message and file path. Don't process the entire log if it's too large.
- **Direct File Inspection**: Use `view_file` on the exact file and line number mentioned in the error immediately.
- **Search for Patterns**: Use `grep_search` to find other occurrences of similar patterns if the error seems to be widespread.
- **Generated Files**: If the error occurs in a generated file (e.g., `.g.dart`, `.freezed.dart`), do not edit it directly. Check the corresponding source file and rebuild.
- **Concise Diagnostics**: If the build log is too long, suggest running `flutter analyze` to get a more directed list of issues.
- **Fast Response**: Avoid over-explanation of the build process. Focus directly on the root cause and the fix.

---
*This file is managed by the development team and AI agents.*
