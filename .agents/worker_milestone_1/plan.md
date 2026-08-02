# Implementation Plan — Fix use_build_context_synchronously Warnings

This plan outlines the changes to be made to address 19 `use_build_context_synchronously` warnings across 4 authentication screen files.

## Files to Modify

1. `lib/screens/forgot_password_screen.dart`
2. `lib/screens/login_screen.dart`
3. `lib/screens/register_screen.dart`
4. `lib/screens/reset_password_screen.dart`

## Step-by-Step Actions

### Step 1: `lib/screens/forgot_password_screen.dart` (1 warning)
- Retrieve `final l10n = AppLocalizations.of(context)!;` at the beginning of `_sendResetEmail()`.
- Replace `AppLocalizations.of(context)!.forgotPasswordBothRequired` with `l10n.forgotPasswordBothRequired`.
- Replace `AppLocalizations.of(context)!.forgotPasswordInvalid` with `l10n.forgotPasswordInvalid` in the `catch` block.

### Step 2: `lib/screens/login_screen.dart` (8 warnings)
- In `_login()`:
  - Retrieve `final l10n = AppLocalizations.of(context)!;` before the `try` block.
  - In `catch` blocks, replace all 6 occurrences of `AppLocalizations.of(context)!.` with `l10n.`.
- In `_signInWithApple()`:
  - Retrieve `final l10n = AppLocalizations.of(context)!;` before the `try` block.
  - Replace `AppLocalizations.of(context)!.loginAppleFailed` with `l10n.loginAppleFailed` in the `catch` block.
- In `_signInWithGoogle()`:
  - Retrieve `final l10n = AppLocalizations.of(context)!;` before the `try` block.
  - Replace `AppLocalizations.of(context)!.loginGoogleFailed` with `l10n.loginGoogleFailed` in the `catch` block.

### Step 3: `lib/screens/register_screen.dart` (2 warnings)
- In `_signInWithApple()`:
  - Retrieve `final l10n = AppLocalizations.of(context)!;` before the `try` block.
  - Replace `AppLocalizations.of(context)!.registerAppleFailed` with `l10n.registerAppleFailed` in the `catch` block.
- In `_signInWithGoogle()`:
  - Retrieve `final l10n = AppLocalizations.of(context)!;` before the `try` block.
  - Replace `AppLocalizations.of(context)!.registerGoogleFailed` with `l10n.registerGoogleFailed` in the `catch` block.
- In `_register()`:
  - To be safe/consistent, retrieve `final l10n = AppLocalizations.of(context)!;` before the `try` block.
  - Replace all occurrences of `AppLocalizations.of(context)!.` with `l10n.`.

### Step 4: `lib/screens/reset_password_screen.dart` (8 warnings)
- In `_verifyCode()`:
  - Retrieve `final l10n = AppLocalizations.of(context)!;` at the beginning of the method.
  - In the `catch` blocks, replace all 4 occurrences of `AppLocalizations.of(context)!.` with `l10n.`.
- In `_resetPassword()`:
  - Retrieve `final l10n = AppLocalizations.of(context)!;` at the beginning of the method.
  - In the `catch` blocks, replace all 4 occurrences of `AppLocalizations.of(context)!.` with `l10n.`.

## Verification Steps
1. Run `flutter analyze` and verify that the 19 warnings for these 4 files are no longer reported.
2. Run `flutter build ios --config-only` to ensure the project builds correctly and there are no compilation errors.
