---
name: V EFFECT App Development Skills
description: Common rules and skill definitions for mobile app development in the V EFFECT project
---

# V EFFECT App Development Skills
---

## Project Overview

- **Project Name:** V EFFECT
- **App Description:** An all-positive SNS app where users share their daily efforts with photos and praise each other to maintain motivation for growth. Users post photos once a day in a narrow community such as among friends, and only those who post can view others' posts (BeReal style). Combines goal management, roadmap creation, and game elements (skill tree, XP, streak) to visualize self-growth.
- **Target Users:** 学生や、日々の目標に向かって泥臭く頑張る人たち。
- **Platform:** Android / iOS (Cross-platform development using Flutter)
- **Development Language:** Dart (Flutter framework)
- **Development Members:** 2 members
  - **renn** (Planner): A beginner with no programming experience. In charge of ideas, planning, and design direction.
  - **yusuke** (Technical Co-developer): Doctoral course (Engineering). Experienced in Python/C/C++/Matlab. Well-versed in machine learning, generative AI, mathematics, and English. Role is to technically realize the app upon consultation from renn.
- **Source Code Management:** GitHub (Repository: YusukeKatahara/V EFFECT)

---

## Development Rules

### Coding Conventions (Rules for writing code)

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

### Folder Structure (Flutter Project)

```
V EFFECT/
├── .agents/          ... AI configuration files (this folder)
├── docs/             ... Documents
├── setup/            ... Setup guides
├── lib/              ... Dart source code (main development area)
│   ├── main.dart     ... App entry point (startup file)
│   ├── screens/      ... Widgets for each screen
│   ├── widgets/      ... Reusable UI parts
│   ├── models/       ... Data models (defines data shapes)
│   ├── services/     ... API communication and database processing
│   └── utils/        ... Common utility functions
├── test/             ... Test code
├── android/          ... Android-specific settings (auto-generated, usually don't touch)
├── ios/              ... iOS-specific settings (auto-generated, usually don't touch)
├── pubspec.yaml      ... Package (external library) management file
└── README.md
```

---

## Security Rules

1. **Never write API keys or passwords directly in the code**
   - Write them in the `.env` file and register it in `.gitignore`
2. **Always configure `.gitignore`** (refer to `docs/release_risk_guide.md` for details)
3. **Encrypt and save user's personal information**

---

## Basic Instructions for Antigravity

This project is developed by 2 people: **renn (Planner / Beginner)** and **yusuke (Technical Co-developer / Advanced)**.

### Response Rules for renn
1. **Always add simple explanations for technical terms in parentheses** (e.g., "Let's do refactoring (organizing code without changing its behavior)").
2. **Explain what changed and why in Japanese for every code change.**
3. **If renn says "I don't understand", explain it more simply and break it down.**
4. **If there are choices/options, present the pros and cons in a comparison table.**
5. Write polite comments (explanatory notes) within the code so beginners can understand.

### Response Rules for yusuke
1. A certain degree of technical discussion is welcome.
2. Explain what was changed and why modifications every time.
3. If there are choices, present the pros and cons in a comparison table.

## command
1. **pull** : git pull
2. **push** : git push && git commit