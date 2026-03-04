# 🧑‍💻 Subagent Usage Guide

> **What is this document?**
> Antigravity has a feature called "Subagent".
> This is a feature where the AI operates the browser itself to look things up or check screens for you.
> This guide introduces specific ways to utilize subagents in the V-Effect project.

---

## 🔤 Terminology You Should Know First

| Term | Meaning |
|------|------|
| **Subagent** | "Another AI assistant" that Antigravity launches in the background. It automatically performs browser operations, etc. |
| **Browser Operation** | Opening a website, clicking buttons, and entering information. |
| **Screenshot** | Taking a picture of the screen. You can show it to the AI and instruct, "Fix this part of the screen." |
| **Recording** | A feature where the subagent's operations are automatically recorded as a video. |

---

## 📋 V-Effect Specific Subagent Definitions

Below are **specific subagent task definitions** that can be repeatedly used in V-Effect development.
Just talk to Antigravity as follows, and the subagent will automatically perform the work.

---

### 🔍 1. Flutter Package Research Agent

**Purpose:** Research necessary packages on pub.dev (the official Dart/Flutter package site).

**Example of how to talk:**
> "Research image compression packages on pub.dev and make a comparison table in order of popularity."
> "Find the latest version and how to introduce the Flutter package for Firebase Cloud Messaging."
> "Compare 3 Flutter packages that can be used for camera features."

**What the subagent does:**
1. Open pub.dev and search by keywords.
2. Collect information on likes, pub points, and popularity.
3. Check the last updated date and supported platforms of each package.
4. Organize and report as a comparison table.

**When to use:**
- Before implementing new features (camera shooting, image editing, push notifications, etc.)
- As research before adding a package to `pubspec.yaml`
- When looking for alternatives to existing packages

---

### 🎨 2. UI/UX Design Reference Research Agent

**Purpose:** Research competing apps and reference designs to use as a reference for V-Effect's design.

**Example of how to talk:**
> "Research the home screen designs of BeReal or Instagram and summarize their features."
> "Research how to use Material Design 3's card components."
> "Research UI/UX trends in photo posting apps and tell me 5 ideas that could be used for V-Effect."

**What the subagent does:**
1. Check specified apps or design resource sites in the browser.
2. Analyze design features (layout, color scheme, interaction).
3. Pick up elements that fit V-Effect's concept.
4. Report the analysis results along with screenshots.

**When to use:**
- For research before deciding on screen designs (especially effective in renn's planning stage).
- When checking Material Design guidelines.
- When considering competitive analysis and differentiation points.

---

### 🔐 3. Firebase Document Research Agent

**Purpose:** Collect information necessary for implementation from Firebase's official documentation.

**Example of how to talk:**
> "Find out how to implement email link login with Firebase Authentication from the official documentation."
> "Find out how to implement time-based access control in Firestore Security Rules."
> "Find out how to set image upload limits (size limits, etc.) in Cloud Storage."
> "Find out how to send scheduled push notifications with Firebase Cloud Messaging."

**What the subagent does:**
1. Open the Firebase official documentation (firebase.google.com/docs).
2. Browse related pages in the browser to collect information.
3. Summarize the implementation steps for Flutter.
4. Report along with security notes.

**When to use:**
- When introducing a new Firebase service.
- During the design/confirmation of Security Rules.
- For implementation research of V-Effect specific requirements like "can only be viewed the day after posting".

---

### 📱 4. Flutter Web Preview Check Agent

**Purpose:** Check and test the display of the Web version app launched with `flutter run -d chrome`.

**Example of how to talk:**
> "Open the locally launched Flutter Web app and check the appearance of the login screen."
> "Open http://localhost:XXXX and check if all buttons are displayed."
> "Open the Flutter Web home screen and check for layout collapse."

**What the subagent does:**
1. Open the specified URL (localhost) in the browser.
2. Wait for the page to finish loading.
3. Check the screen layout and element display status.
4. Test basic operations like button clicks and form input.
5. If there is a problem, report it along with a screenshot.

**When to use:**
- Preview check on Flutter Web (when Android emulator cannot be used).
- UI layout collapse check.
- Operation check of screen transitions.

---

### 📊 5. Store Publishing Preparation Research Agent

**Purpose:** Research Google Play / App Store guidelines and publishing procedures.

**Example of how to talk:**
> "Find out the steps to publish an app on Google Play and summarize them in a checklist."
> "Find out common rejection reasons in App Store reviews."
> "Find out the privacy policy requirements for SNS apps."
> "Find out the steps and costs for registering a Google Play developer account."

**What the subagent does:**
1. Browse the help pages of Google Play Console / App Store Connect.
2. List necessary procedures, documents, and costs.
3. Research review points specific to SNS apps (photo handling, minor protection, etc.).
4. Organize as an action list required for V-Effect's release.

**When to use:**
- Preliminary research for Phase 5 (Release preparation).
- Preparation for creating a privacy policy / terms of service.
- Confirmation of store listing information (screenshot specifications, etc.).

---

### 🐛 6. Error/Troubleshooting Research Agent

**Purpose:** Investigate the causes of error messages or crashes encountered during development.

**Example of how to talk:**
> "Find out how to resolve the error 'Gradle build failed with exit code 1'."
> "Got a CocoaPods error in Flutter, find out the solution."
> "Find out the cause of the 'No Firebase App has been created' error during Firebase initialization."

**What the subagent does:**
1. Search Stack Overflow or GitHub Issues based on the error message.
2. Check the troubleshooting section of the official documentation.
3. Collect multiple solutions from developers who encountered the same problem.
4. Propose a resolution procedure suited for the V-Effect environment (Flutter + Firebase).

**When to use:**
- When a warning or error occurs in `flutter doctor`.
- When the build fails.
- When the app crashes during execution.

---

### 🌐 7. GitHub Repository Management Support Agent

**Purpose:** Support the checking and management of repository settings and Issues on GitHub.

**Example of how to talk:**
> "Check the Settings of the V-Effect repository on GitHub and see if branch protection is configured."
> "Check the execution results of GitHub Actions workflows."
> "Check the Issue list of the V-Effect repository and summarize open tasks."

**What the subagent does:**
1. Open the V-Effect repository page on GitHub in the browser.
2. Check the specified tab (Settings, Actions, Issues, etc.).
3. Report the configuration content and results along with screenshots.
4. Propose if there are points that need improvement.

**When to use:**
- Checking repository security settings.
- Checking CI/CD (automated testing/automated building) results.
- Task management (checking/organizing Issues).

---

## 💡 Tips for Effective Use

1. **Be specific about what you want done**
   - ❌ "Research"
   - ✅ "Make a comparison table of the differences between Firebase Realtime Database and Firestore in terms of speed, cost, and ease of use."

2. **Specify how you want the results returned**
   - ✅ "Summarize in a table", "Tell me 5 bullet points", "Explain clearly in Japanese"

3. **Break down complex tasks into smaller requests**
   - ❌ "Make the whole app"
   - ✅ "First design the login screen" → "Next, write the code for the login process"

4. **Connect research results to the next action**
   - It's efficient to instruct implementation after seeing the results of the research agent.
   - Example: "Add the most popular one from the packages you researched to `pubspec.yaml`."

---

## 🔄 Examples of Combining Subagents

### Flow When Adding a New Feature

```
Step 1: Package Research Agent
  "Find Flutter packages that can be used for camera shooting."
     ↓
Step 2: Firebase Document Research Agent
  "Find out how to upload photos to Cloud Storage."
     ↓
Step 3: (Direct instruction to AI)
  "Based on the research results, implement the photo posting feature."
     ↓
Step 4: Flutter Web Preview Check Agent
  "Check the implemented screen in the browser."
```

### Flow During Release Preparation

```
Step 1: Store Publishing Preparation Agent
  "Find out the publishing steps for Google Play."
     ↓
Step 2: UI/UX Design Reference Research Agent
  "Find out recommended sizes and compositions for store listing screenshots."
     ↓
Step 3: (Direct instruction to AI)
  "Create a privacy policy." (Claude recommended)
```

---

## ⚠️ Notes

- Subagents access **publicly available websites**.
- Pages that **require login** may not be operable (such as modifying settings in the Firebase Console).
- Browser operations are performed automatically in the background, and the process is **recorded as a video**.
- Treat research results as **reference information**, and verify important settings with official documentation as well.
- For security-related research results, we recommend performing an **additional check with Claude**.
