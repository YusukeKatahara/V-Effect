# Changes Log — Milestone 1 (Auth & Access Screens)

## Summary of Changes

Addressed all `use_build_context_synchronously` warnings across 4 authentication screen files.

### 1. `lib/screens/forgot_password_screen.dart`
- **Before**: `AppLocalizations.of(context)` was used after the asynchronous Firebase Functions calls in the `catch` block of `_sendResetEmail()`.
- **After**: Resolved `l10n = AppLocalizations.of(context)!` at the start of the method, before any async gaps, and referenced `l10n` inside the `catch` block.

### 2. `lib/screens/login_screen.dart`
- **Before**: `AppLocalizations.of(context)` was used across async gaps inside the `catch` blocks of `_login()`, `_signInWithApple()`, and `_signInWithGoogle()`.
- **After**: Stored `l10n = AppLocalizations.of(context)!` in local variables at the beginning of each method and referenced `l10n` inside the error handler / callback blocks.

### 3. `lib/screens/register_screen.dart`
- **Before**: `AppLocalizations.of(context)` was accessed after the async social sign-in calls in the `catch` blocks of `_signInWithApple()` and `_signInWithGoogle()`.
- **After**: Stored `l10n = AppLocalizations.of(context)!` at the beginning of `_register()`, `_signInWithApple()`, and `_signInWithGoogle()` and referenced it inside the `catch` blocks.

### 4. `lib/screens/reset_password_screen.dart`
- **Before**: `AppLocalizations.of(context)` was accessed after the async verification and confirmation calls inside `_verifyCode()` and `_resetPassword()`.
- **After**: Cached `l10n = AppLocalizations.of(context)!` in local variables at the start of the methods and replaced the synchronous calls with `l10n`.

## Verification Results

- **`flutter analyze`**:
  - Successfully verified.
  - Zero warnings or errors related to `use_build_context_synchronously` are reported in the modified files.
