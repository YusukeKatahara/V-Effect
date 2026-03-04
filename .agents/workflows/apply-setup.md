---
description: Automatically optimizes the configuration files in .agents/ based on the contents of setup_guide.md
---

# Setup Guide Application Workflow

> **What is this workflow?**
> It reads the content filled in by development members in `setup/setup_guide.md`,
> and automatically rewrites the configuration files inside the `.agents/` folder (SKILL.md, GEMINI.md, CLAUDE.md)
> to their optimal contents.

## Steps

### 1. Read setup_guide.md

First, thoroughly read the contents of `setup/setup_guide.md` and extract the following information:

- Profile (name, programming experience, strengths)
- App description, target users, main features
- Development method (Flutter / React Native / Kotlin Multiplatform)
- Services to be used (Firebase, etc.)
- Role allocation
- Schedule
- Personal instructions to the AI

### 2. Update SKILL.md

Based on the information extracted from `setup/setup_guide.md`, update `.agents/SKILL.md` as follows:

- **Project Overview Section:** Reflect the app description and target users.
- **Development Rules > Coding Conventions:** Rewrite to the language/framework rules tailored to the selected development method.
  - Flutter → Dart coding conventions
  - React Native → JavaScript/TypeScript coding conventions
  - Kotlin Multiplatform → Kotlin coding conventions
- **Folder Structure:** Rewrite to the directory structure tailored to the selected development method.
- **Basic Instructions for Antigravity:** Adjust the level of detail in explanations according to the members' programming experience level.

### 3. Update GEMINI.md

Update `.agents/GEMINI.md` as follows:

- **Project-Specific Instructions > Common Rules:** Rewrite tailored to the selected development method and language.
  - Example: If Flutter, "Write code using Dart / Flutter."
  - Example: If React Native, "Write code using JavaScript (TypeScript) / React Native."
- **Firebase-Related Instructions:** If Firebase is used, uncomment and enable it. If not, leave it as is.
- **Examples of How to Talk:** Replace with specific examples tailored to the selected development method.

### 4. Update CLAUDE.md

Update `.agents/CLAUDE.md` as follows:

- **Project-Specific Instructions > Common Rules:** Clearly state the language and framework to be reviewed.
- Add review perspectives tailored to the app's main features.
  - Example: Has a login feature → Add review perspectives for authentication security.
  - Example: Has a payment feature → Add review perspectives for payment-related security checks.

### 5. Report the Update Results

Once all updates are complete, report the following:

- List of modified files
- Brief explanation of what was changed in each file
- What to do next (advice in case there are unfinalized items)

---

## ⚠️ Notes

- If there are unpopulated items in `setup_guide.md` (left as [Fill in here]), **do not change the settings related to those items and leave them as defaults**.
- If there are unpopulated items, guide during the report: "XXX is not decided yet. Please run `/apply-setup` again once it is decided."
- This workflow can be executed **any number of times**. If you update setup_guide.md, you can execute it again to bring the settings up to date.
