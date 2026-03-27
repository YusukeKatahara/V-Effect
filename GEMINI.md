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

## Build Error & Debugging (Efficiency)

- **Prioritize Error Messages**: When a build error occurs, identify the first specific error message and file path. Don't process the entire log if it's too large.
- **Direct File Inspection**: Use `view_file` on the exact file and line number mentioned in the error immediately.
- **Search for Patterns**: Use `grep_search` to find other occurrences of similar patterns if the error seems to be widespread.
- **Generated Files**: If the error occurs in a generated file (e.g., `.g.dart`, `.freezed.dart`), do not edit it directly. Check the corresponding source file and rebuild.
- **Concise Diagnostics**: If the build log is too long, suggest running `flutter analyze` to get a more directed list of issues.
- **Fast Response**: Avoid over-explanation of the build process. Focus directly on the root cause and the fix.

---
*This file is managed by the development team and AI agents.*
