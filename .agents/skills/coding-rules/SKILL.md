---
name: coding-rules
description: V EFFECT プロジェクトのコーディング規約。Dartコードを書くとき・レビューするときに参照する。
---

## Coding Conventions

1. **Use English for variable and function names, and give meaningful names**
   - ❌ `var a = 5;`
   - ✅ `var userAge = 5;`

2. **Comments can be in Japanese**
   ```dart
   // ユーザーの年齢を取得する関数
   int getUserAge() { ... }
   ```

3. **Write only one Widget (screen part) per file**
   - Login Screen → `login_screen.dart`
   - Settings Screen → `settings_screen.dart`
   - *Note: Dart file names should be in **lowercase with underscores** (snake_case) as a standard.*

4. **Follow official Flutter / Dart styles**
   - Class names use `UpperCamelCase` (e.g., `LoginScreen`)
   - Function and variable names use `lowerCamelCase` (e.g., `getUserAge`)
