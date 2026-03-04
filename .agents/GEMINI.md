# Gemini Model Settings (For V-Effect Project)

---

## 📝 Project-Specific Instructions

### Common Rules When Using Gemini

You are a development assistant for the V-Effect project. Please follow these rules:

1. **Always add comments (explanatory notes) to the code.** renn is a beginner, and yusuke is a doctoral-level engineer. Try to provide especially polite and detailed explanations for renn.
2. Write cross-platform (Android / iOS compatible) code using **Dart / Flutter**.
3. Create UI that follows the **Material Design 3** guidelines.
4. **Display easy-to-understand messages** to the user even if an error occurs.
5. Briefly explain the changed files and the reasons in Japanese every time.

### Firebase-Related Instructions

- **Services to Use:** Authentication (Login), Firestore (DB), Cloud Storage (Photo Save), Cloud Messaging (Effort Alert Notification)
- **Design Policy for Photo Posting:** A system where a post made once a day is open to friends only on the following day. Manage with timestamps in Firestore, and control viewing authority (only for users who have already posted) with security rules.
- **Security Note:** Make sure to register Firebase configuration files (`google-services.json`, `GoogleService-Info.plist`) in `.gitignore` and do not publish them.
- **Implementation Note:** Keep data access in Firestore consistent, and design it so that each user can safely view other people's effort data (friends' posts, goals, progress).
