# v-effect-context

## Project Overview

- **Project Name:** V EFFECT
- **App Description:** An all-positive SNS app where users share their daily efforts with photos and praise each other to maintain motivation for growth. Users post photos once a day in a narrow community such as among friends, and only those who post can view others' posts (BeReal style). Combines goal management, roadmap creation, and game elements (skill tree, XP, streak) to visualize self-growth.
- **Target Users:** 自分磨きを頑張る、習慣化したいことがある、または常にある良習慣を強固にしたい人たちへ。サブタイトルは習慣化,努力と勝利の共有である。
- **Platform:** Android / iOS (Cross-platform development using Flutter)
- **Development Language:** Dart (Flutter framework)
- **Development Members:** 2 members
  - **renn** (Planner): アプリ全体の統一感UIUXetcを意識してください
  - **yusuke** (Technical Co-developer): Doctoral course (Engineering). Experienced in Python/C/C++/Matlab. Well-versed in machine learning, generative AI, mathematics, and English. Role is to technically realize the app upon consultation from renn.
- **Source Code Management:** GitHub (Repository: YusukeKatahara/V-Effect)

## Folder Structure (Flutter Project)

```
V-Effect/
├── .agents/          ... AI configuration files
│   ├── skills/       ... Skill definitions
│   └── workflows/    ... Workflow definitions
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

## Security Rules

1. **Never write API keys or passwords directly in the code**
   - Write them in the `.env` file and register it in `.gitignore`
2. **Always configure `.gitignore`** (refer to `docs/release_risk_guide.md` for details)
3. **Encrypt and save user's personal information**
