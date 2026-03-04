---
name: V-Effect App Development Skills
description: Common rules and skill definitions for mobile app development in the V-Effect project
---

# V-Effect App Development Skills
---

## Project Overview

- **Project Name:** V-Effect
- **App Description:** An all-positive SNS app where users share their daily efforts with photos and praise each other to maintain motivation for growth. Users post photos once a day in a narrow community such as among friends, and only those who post can view others' posts (BeReal style). Combines goal management, roadmap creation, and game elements (skill tree, XP, streak) to visualize self-growth.
- **Target Users:** People working hard towards dreams and goals, and those around them. Starting from the friend relationship of Yusuke and renn, assuming phased expansion through word-of-mouth like Facebook.
- **Platform:** Android / iOS (Cross-platform development using Flutter)
- **Development Language:** Dart (Flutter framework)
- **Development Members:** 2 members
  - **renn** (Planner): A beginner with no programming experience. In charge of ideas, planning, and design direction.
  - **yusuke** (Technical Co-developer): Doctoral course (Engineering). Experienced in Python/C/C++/Matlab. Well-versed in machine learning, generative AI, mathematics, and English. Role is to technically realize the app upon consultation from renn.
- **Source Code Management:** GitHub (Repository: YusukeKatahara/V-Effect)

---

## Main Feature List

### ★ Essential Features (MVP: Minimum viable features required for the first release)
1. **Daily Photo Posting** — Post a photo once a day. You can only view friends' posts the day after posting.
2. **Reaction Feature** — Send positive reactions to friends' posts.
3. **Goal Management Assistance** — Support for setting personal goals, creating roadmaps, and tracking progress.
4. **Effort Alert (From renn)** — Encourage real-time photo posting of efforts with random notifications 1-2 times a day.

### ☆ Additional Features (Implement if there's time)
- Skill Tree (Visualize growth by category: "Body", "Mind", "Spirit")
- Daily Quests (AM/PM 2-task system)
- Game Elements (Earn XP, level up, maintain streaks, rank system)
- Music Sharing (Share currently listening music with friends in real-time)
- Friend Search (Feature to find peers with the same goals using goal tags)

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
V-Effect/
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
1. **Always add simple explanations for technical terms**, and explain code changes and reasons clearly in Japanese every time.
2. **When instructing to paste code, specifically state which file and which line to add/modify.**
3. Write polite comments (explanatory notes) within the code so beginners can understand.
4. Always include error handling (dealing with unexpected situations).
5. When writing code related to security, always explain the points of caution.

### Response Rules for yusuke
1. A certain degree of technical discussion is welcome.
2. Explain what was changed and why modifications every time.
3. If there are choices, present the pros and cons in a comparison table.
4. Talk in English.