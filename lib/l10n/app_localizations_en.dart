// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settingsTitle => 'Settings';

  @override
  String get languageSetting => 'Language';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageEnglish => 'ENGLISH';

  @override
  String get errorCannotOpenLink => 'Couldn\'t open the link';

  @override
  String get settingsNotification => 'Notifications';

  @override
  String get settingsPasswordSecurity => 'Password & Security';

  @override
  String get settingsSupportLegal => 'Support & Legal';

  @override
  String get settingsContactBugReport => 'Contact Us / Bug Report';

  @override
  String get settingsTerms => 'Terms of Service';

  @override
  String get settingsPrivacyPolicy => 'Privacy Policy';

  @override
  String get settingsVersionInfo => 'Version';

  @override
  String get loginTagline => 'Daily victories. Shared with your crew.';

  @override
  String get loginEmailOrId => 'Email or User ID';

  @override
  String get loginPassword => 'Password';

  @override
  String get loginForgotPassword => 'Forgot your password?';

  @override
  String get loginButton => 'Log In';

  @override
  String get loginOrDivider => 'or';

  @override
  String get loginWithApple => 'Continue with Apple';

  @override
  String get loginWithGoogle => 'Continue with Google';

  @override
  String get loginNoAccount => 'Don\'t have an account?';

  @override
  String get loginRegister => 'Sign Up';

  @override
  String get loginContactSupport => 'Trouble logging in? Contact support';

  @override
  String get loginByLoggingIn => 'By logging in, you agree to our ';

  @override
  String get loginAnd => ' and ';

  @override
  String get loginAgreeTerms => '.';

  @override
  String get loginFailed => 'Login failed';

  @override
  String get loginErrorIdOrPassword => 'Incorrect user ID or password';

  @override
  String get loginErrorUserNotFound => 'User not found';

  @override
  String get loginErrorWrongPassword => 'Incorrect password';

  @override
  String get loginErrorInvalidCredential => 'Incorrect email or password';

  @override
  String get loginAppleFailed => 'Apple sign-in failed';

  @override
  String get loginGoogleFailed => 'Google sign-in failed';

  @override
  String get registerCreateAccount => 'Create Account';

  @override
  String get registerSubtitle => 'Join V EFFECT and level up together';

  @override
  String get registerEmail => 'Email';

  @override
  String get registerEmailRequired => 'Please enter your email';

  @override
  String get registerPasswordRequired => 'Please enter a password';

  @override
  String get registerPasswordMinLength => 'Must be at least 6 characters';

  @override
  String get registerPasswordConfirm => 'Confirm Password';

  @override
  String get registerPasswordReenter => 'Please re-enter your password';

  @override
  String get registerPasswordMismatch => 'Passwords don\'t match';

  @override
  String get registerAgreeToSuffix => '';

  @override
  String get registerFailed => 'Registration failed.';

  @override
  String get registerEmailInUse => 'This email is already in use.';

  @override
  String get registerWeakPassword => 'Password must be at least 6 characters.';

  @override
  String get registerFailedRetry =>
      'Registration failed. Please try again later.';

  @override
  String get registerAppleFailed => 'Apple sign-up failed.';

  @override
  String get registerGoogleFailed => 'Google sign-up failed.';

  @override
  String get registerWithApple => 'Sign up with Apple';

  @override
  String get registerWithGoogle => 'Sign up with Google';

  @override
  String get forgotPasswordResetTitle => 'Reset Password';

  @override
  String get forgotPasswordInstruction =>
      'Enter your user ID and registered email address';

  @override
  String get forgotPasswordBothRequired =>
      'Please enter your user ID and email';

  @override
  String get forgotPasswordInvalid => 'No account found matching those details';

  @override
  String get forgotPasswordUserId => 'User ID';

  @override
  String get forgotPasswordSendReset => 'Send Reset Email';

  @override
  String get forgotPasswordEmailSent => 'Email Sent';

  @override
  String forgotPasswordEmailSentDesc(String email) {
    return 'A password reset email has been sent to $email.';
  }

  @override
  String get forgotPasswordResetViaLink => 'Reset password via link';

  @override
  String get forgotPasswordBackToLogin => 'Back to login';

  @override
  String get forgotPasswordResend => 'Resend if you didn\'t receive the email';

  @override
  String get resetPasswordTitle => 'Set New Password';

  @override
  String get resetPasswordLinkInvalid => 'Invalid link';

  @override
  String get resetPasswordLinkExpired => 'This link has expired';

  @override
  String get resetPasswordLinkInvalidPaste =>
      'Invalid link. Please paste the link directly from your email.';

  @override
  String get resetPasswordPasteLink => 'Please paste the link';

  @override
  String get resetPasswordMismatch => 'Passwords don\'t match';

  @override
  String get resetPasswordFailed => 'Failed to reset password';

  @override
  String get resetPasswordWeakPassword =>
      'Password must be at least 6 characters';

  @override
  String get resetPasswordPasteLinkTitle => 'Paste Your Link';

  @override
  String get resetPasswordPasteLinkDesc =>
      'Copy the link from your password reset email and paste it here';

  @override
  String get resetPasswordPasteLinkLabel => 'Password Reset Link';

  @override
  String get resetPasswordNext => 'Next';

  @override
  String get resetPasswordNewTitle => 'Set New Password';

  @override
  String get resetPasswordNew => 'New Password';

  @override
  String get resetPasswordConfirm => 'Confirm Password';

  @override
  String get resetPasswordButton => 'Update Password';

  @override
  String get resetPasswordDone => 'Password Updated';

  @override
  String get resetPasswordLoginWithNew => 'Sign in with your new password';

  @override
  String get resetPasswordGoToLogin => 'Go to Login';

  @override
  String get errorGenericRetry =>
      'Something went wrong. Please try again later.';

  @override
  String get weeklyReviewSelectBackground => 'Choose Background';

  @override
  String get weeklyReviewNoPostsDefault =>
      'No posts this week yet.\nShare with the default background.';

  @override
  String get weeklyReviewShareWithoutBackground => 'Share without background';

  @override
  String weeklyReviewLoadError(Object error) {
    return 'Load error: $error';
  }

  @override
  String get weeklyReviewShareToSns => 'Share to Social';

  @override
  String get weeklyReviewStatTasks => 'Tasks This Week';

  @override
  String get weeklyReviewStatStreak => 'Streak';

  @override
  String get weeklyReviewStatVFire => 'Total VFIRE';

  @override
  String get weeklyReviewStatReactions => 'Reactions';

  @override
  String get weeklyReviewNoPosts => 'No posts this week';

  @override
  String get authWrapperConnecting => 'Taking a moment to connect...';

  @override
  String get authWrapperRetry => 'Retry';

  @override
  String firestoreReadError(Object error) {
    return 'Firestore error: $error';
  }

  @override
  String get followListNoUsers => 'No users here';

  @override
  String get followListFollowing => 'Following';

  @override
  String get followListFollowers => 'Followers';

  @override
  String get followListPendingBanner => 'You have pending follow requests';

  @override
  String get followListMe => 'You';

  @override
  String get qrScannerTitle => 'Scan QR';

  @override
  String get qrScannerFlashlight => 'Flashlight';

  @override
  String get qrScannerUserNotFound => 'User not found';

  @override
  String qrScannerError(Object error) {
    return 'An error occurred: $error';
  }

  @override
  String get qrScannerNoQrInImage => 'No QR code found in image';

  @override
  String get qrScannerScanLabel => 'Scan QR Code';

  @override
  String get qrScannerInstruction => 'Point the camera at a QR code';

  @override
  String get qrScannerPickFromGallery => 'Choose from Gallery';

  @override
  String get qrDisplayTitle => 'QR Code';

  @override
  String get qrDisplaySaved => 'QR code saved';

  @override
  String qrDisplaySaveFailed(Object error) {
    return 'Failed to save: $error';
  }

  @override
  String get qrDisplaySaving => 'Saving...';

  @override
  String get qrDisplayDownload => 'Download';

  @override
  String get pendingRequestsTitle => 'Follow Requests';

  @override
  String get pendingRequestsEmpty => 'No pending requests';

  @override
  String pendingRequestsAcceptFailed(Object error) {
    return 'Failed to accept: $error';
  }

  @override
  String pendingRequestsRejectFailed(Object error) {
    return 'Failed to decline: $error';
  }

  @override
  String get pendingRequestsAccept => 'Accept';

  @override
  String get pendingRequestsReject => 'Decline';

  @override
  String get initialFriendTitle => 'Add Friends';

  @override
  String get initialFriendSubtitle => 'Find your crew to train with!';

  @override
  String get initialFriendWhoInvited => 'Who invited you?';

  @override
  String get initialFriendOtherUser => 'Someone else — enter their user ID';

  @override
  String get initialFriendUserIdLabel => 'User ID';

  @override
  String initialFriendSentCount(int count) {
    return '$count friend request(s) sent!';
  }

  @override
  String get initialFriendSendFailed => 'Failed to send. Please try again.';

  @override
  String get initialFriendRegister => 'Add Friends';

  @override
  String get initialFriendLater => 'Skip for now';

  @override
  String get emailVerificationTitle => 'Verify Your Email';

  @override
  String get emailVerificationHeading => 'Please verify your email';

  @override
  String emailVerificationSent(String email) {
    return 'A verification email has been sent to\n$email.\nTap the link in the email to complete verification.';
  }

  @override
  String get emailVerificationSpamNote =>
      'Can\'t find it? Check your spam or trash folder.';

  @override
  String get emailVerificationNotYet =>
      'Not verified yet. Please check your email.';

  @override
  String emailVerificationResendCooldown(int seconds) {
    return 'You can resend in $seconds second(s).';
  }

  @override
  String get emailVerificationResent => 'Verification email resent.';

  @override
  String get emailVerificationResendFailed =>
      'Failed to send. Please try again later.';

  @override
  String get emailVerificationConfirmButton => 'I\'ve Verified';

  @override
  String get emailVerificationResendButton => 'Resend Verification Email';

  @override
  String get notificationSettingsTitle => 'Notification Settings';

  @override
  String get notificationSettingsSaveFailed => 'Failed to save settings';

  @override
  String get notificationSettingsPush => 'Enable Push Notifications';

  @override
  String get notificationSettingsPushDesc =>
      'New posts and updates from people you follow';

  @override
  String get notificationSettingsReaction => 'Enable Reaction Notifications';

  @override
  String get notificationSettingsReactionDesc =>
      'When someone reacts to your posts';

  @override
  String get notificationSettingsVAlert => 'Enable V Alert Notifications';

  @override
  String get notificationSettingsVAlertDesc =>
      'Task reminder at your scheduled time';

  @override
  String get notificationSettingsVFire => 'Enable V FIRE Notifications';

  @override
  String get notificationSettingsVFireDesc =>
      'When your post receives a V FIRE';

  @override
  String get notificationSettingsShield => 'Enable Shield Notifications';

  @override
  String get notificationSettingsShieldDesc =>
      'When a shield protects your streak';

  @override
  String get notificationSettingsStreakCelebration =>
      'Enable Streak Milestone Notifications';

  @override
  String get notificationSettingsStreakCelebrationDesc =>
      'Milestones like 30 or 100 days';

  @override
  String get notificationSettingsStreakWarning =>
      'Enable Streak Risk Notifications';

  @override
  String get notificationSettingsStreakWarningDesc =>
      'Reminder if your task isn\'t done by evening';

  @override
  String get notificationSettingsDebugTitle => 'Developer Debug Tools';

  @override
  String get notificationSettingsDebugResetTitle =>
      'Reset Notification Pre-Dialog Flag';

  @override
  String get notificationSettingsDebugResetDesc =>
      'Clears the \'show once\' restriction flag';

  @override
  String get notificationSettingsDebugResetDone =>
      'Notification dialog flag has been reset.';

  @override
  String get notificationSettingsDebugTestTitle =>
      'Test Notification Pre-Dialog';

  @override
  String get notificationSettingsDebugTestDesc =>
      'Shows the modal regardless of current permission status';

  @override
  String get editProfileSettingsHeader => 'Settings';

  @override
  String get editProfileAccount => 'Account';

  @override
  String get editProfileStatus => 'Status';

  @override
  String get editProfileNameLabel => 'Name';

  @override
  String get editProfileNameRequired => 'Please enter your name';

  @override
  String get editProfileUserIdLabel => 'User ID';

  @override
  String get editProfileUserIdRequired => 'Please enter a user ID';

  @override
  String get editProfileUserIdMinLength => 'Must be at least 5 characters';

  @override
  String get editProfileUserIdAlphanumeric =>
      'Only letters, numbers, and underscores';

  @override
  String get editProfileUserIdAlreadyUsed => 'This user ID is already taken';

  @override
  String editProfileRestrictionMessage(int days) {
    return 'Your user ID cannot be changed for 90 days after the last change.\nPlease wait $days more day(s).';
  }

  @override
  String editProfileChangeRestriction(int days) {
    return 'User ID cannot be changed for another $days day(s).';
  }

  @override
  String get editProfileConfirmTitle => 'Confirm';

  @override
  String get editProfileConfirmMessage =>
      'Once saved, your user ID cannot be changed for 90 days.\n\nAre you sure?';

  @override
  String get editProfileCancel => 'Cancel';

  @override
  String get editProfileChange => 'Change';

  @override
  String get editProfileSave => 'Save';

  @override
  String editProfileSaveFailed(Object error) {
    return 'Failed to save: $error';
  }

  @override
  String get editProfileBirthDate => 'Date of Birth (optional)';

  @override
  String get editProfileGender => 'Gender (optional)';

  @override
  String get editProfilePickerCancel => 'Cancel';

  @override
  String get editProfilePickerDone => 'Done';

  @override
  String get editProfileBirthDatePickerTitle => 'Date of Birth';

  @override
  String get editProfileGenderPickerTitle => 'Gender';

  @override
  String get editProfileBadgeLabel => 'Badge';

  @override
  String get editProfileBadgeEquipped => 'Equipped';

  @override
  String get editProfileBadgeNone => 'None';

  @override
  String get editProfileBadgeChange => 'Change';

  @override
  String get editProfileBadgeSelectTitle => 'Select Badge';

  @override
  String get editProfileBadgeOptionNone => 'None';

  @override
  String get editProfileBadgeOptionTester => 'Tester';

  @override
  String get editProfileBadgeOptionSeason => 'Season Badge';

  @override
  String get editProfileImageAdjust => 'Adjust Image';

  @override
  String get pastComparisonTitle => 'Look Back on Your Journey';

  @override
  String get pastComparisonSortOld => 'Oldest First';

  @override
  String get pastComparisonSortNew => 'Newest First';

  @override
  String get pastComparisonEmpty => 'No posts yet';

  @override
  String get pastComparisonTaskEmpty => 'No posts for this task yet';

  @override
  String get pastComparisonCompare => 'Compare';

  @override
  String get pastComparisonSelectTwo => 'Select 2 photos';

  @override
  String get pastComparisonMode => 'Compare Mode';

  @override
  String get pastComparisonOther => 'Other';

  @override
  String get sharePreviewTitle => 'Preview';

  @override
  String sharePreviewShareText(int count, int streak) {
    return 'Crushed my Hero Task $count time(s) this week!\nCurrent streak: $streak days 🔥\n#VEffect';
  }

  @override
  String get sharePreviewFailed => 'Share failed. Please try again.';

  @override
  String get sharePreviewPreparing => 'Preparing...';

  @override
  String get sharePreviewShareButton => 'Share to Social';

  @override
  String get searchHint => 'Search by ID or name';

  @override
  String get searchKeywordPrompt => 'Enter a search keyword';

  @override
  String get searchNoResults => 'No users found';

  @override
  String searchError(Object error) {
    return 'Search error:\n$error';
  }

  @override
  String searchUnfollowed(String username) {
    return 'Unfollowed $username';
  }

  @override
  String searchFollowRequestSent(String username) {
    return 'Follow request sent to $username';
  }

  @override
  String searchActionFailed(Object error) {
    return 'Action failed: $error';
  }

  @override
  String get searchFollowing => 'Following';

  @override
  String get searchPending => 'Requested';

  @override
  String get searchFollow => 'Follow';

  @override
  String get securitySettingsTitle => 'Password & Security';

  @override
  String get securityLoginRecoveryTitle => 'Login & Recovery';

  @override
  String get securityLoginRecoveryDesc =>
      'Manage your password, login settings, and recovery options.';

  @override
  String get securityChangePassword => 'Change Password';

  @override
  String get securityChangeEmail => 'Change Email';

  @override
  String get securityVerifyEmail => 'Verify Email';

  @override
  String get securityAccountManagementTitle => 'Account Management';

  @override
  String get securityAccountManagementDesc =>
      'Manage your app access and account data.';

  @override
  String get securityLogout => 'Log Out';

  @override
  String get securityDeleteAccount => 'Delete Account';

  @override
  String get securityLinkedAccounts => 'Linked Accounts';

  @override
  String get securityNoLinkedAccounts => 'None';

  @override
  String get securityProviderEmail => 'Email';

  @override
  String get securityChangePasswordDialogTitle => 'Change Password';

  @override
  String securityChangePasswordDialogDesc(String email) {
    return 'Send a password reset email to $email?';
  }

  @override
  String get securityChangePasswordCancel => 'Cancel';

  @override
  String get securityChangePasswordSend => 'Send';

  @override
  String get securityPasswordResetSent =>
      'Reset email sent. Please check your inbox.';

  @override
  String get securityChangeEmailDialogTitle => 'Change Email';

  @override
  String get securityChangeEmailDialogDesc =>
      'Enter your new email address. A confirmation email will be sent.';

  @override
  String get securityNewEmailLabel => 'New Email Address';

  @override
  String get securityChangeEmailSend => 'Send Confirmation Email';

  @override
  String get securityEmailVerificationSent =>
      'A confirmation email has been sent to your new address. Tap the link to complete the change.';

  @override
  String get securityErrorGeneric => 'An error occurred.';

  @override
  String get securityErrorRecentLogin =>
      'For security, please log out and log back in before trying again.';

  @override
  String get securityErrorInvalidEmail => 'Invalid email address.';

  @override
  String get securityErrorEmailInUse => 'This email is already registered.';

  @override
  String get securityLogoutConfirmTitle => 'Log Out';

  @override
  String get securityLogoutConfirmMessage =>
      'Are you sure you want to log out?';

  @override
  String get securityLogoutConfirmCancel => 'Cancel';

  @override
  String get securityLogoutConfirmButton => 'Log Out';

  @override
  String get securityDeleteConfirmTitle => 'Delete Account?';

  @override
  String get securityDeleteConfirmDesc =>
      'All your data — profile, posts, and everything else — will be permanently deleted. This cannot be undone.';

  @override
  String get securityDeleteConfirmCancel => 'Cancel';

  @override
  String get securityDeleteConfirmButton => 'Delete';

  @override
  String get securityDeleteFinalTitle => 'Are you absolutely sure?';

  @override
  String get securityDeleteFinalDesc =>
      'This action is irreversible. Your account will be permanently deleted.';

  @override
  String get securityDeleteFinalCancel => 'Cancel';

  @override
  String get securityDeleteFinalButton => 'Delete Permanently';

  @override
  String get securityDeleteFailed =>
      'Failed to delete account. Please log in again and try.';

  @override
  String get userProfileNotFound => 'User not found';

  @override
  String get userProfileFollowing => 'Following';

  @override
  String get userProfileFollowers => 'Followers';

  @override
  String get userProfileStreak => 'Streak';

  @override
  String get userProfileFollowRequest => 'Follow';

  @override
  String get userProfilePending => 'Requested';

  @override
  String get userProfileHeroTasks => 'Hero Tasks';

  @override
  String get userProfileBlock => 'Block';

  @override
  String get userProfileUnblock => 'Unblock';

  @override
  String get userProfileReport => 'Report';

  @override
  String get userProfileBlockConfirmTitle => 'Block User';

  @override
  String get userProfileBlockConfirmDesc =>
      'Blocking this user will also remove your follow connection.';

  @override
  String get userProfileBlockCancel => 'Cancel';

  @override
  String get userProfileBlockButton => 'Block';

  @override
  String get userProfileUnblockConfirmTitle => 'Unblock User';

  @override
  String get userProfileUnblockConfirmDesc =>
      'Are you sure you want to unblock this user?';

  @override
  String get userProfileUnblockCancel => 'Cancel';

  @override
  String get userProfileUnblockButton => 'Unblock';

  @override
  String get userProfileBlockFailed => 'Failed to block user';

  @override
  String get userProfileUnblockFailed => 'Failed to unblock user';

  @override
  String get userProfileReportTitle => 'Select a Reason';

  @override
  String get userProfileReportSpam => 'Spam';

  @override
  String get userProfileReportHarassment => 'Harassment';

  @override
  String get userProfileReportInappropriate => 'Inappropriate Content';

  @override
  String get userProfileReportOther => 'Other';

  @override
  String get userProfileReportCancel => 'Cancel';

  @override
  String get userProfileReportDone =>
      'Reported. Thanks for helping keep V EFFECT safe.';

  @override
  String get userProfileReportAlready =>
      'You\'ve already reported this user within the last 7 days';

  @override
  String get userProfileReportFailed => 'Failed to report';

  @override
  String get userProfileFollowFailed => 'Could not send follow request';

  @override
  String get blogPostDetailDeleteTitle => 'Delete Article?';

  @override
  String get blogPostDetailDeleteDesc => 'This action cannot be undone.';

  @override
  String get blogPostDetailDeleteCancel => 'Cancel';

  @override
  String get blogPostDetailDeleteButton => 'Delete';

  @override
  String get blogPostEditorUpdateButton => 'Update';

  @override
  String get blogPostEditorPostButton => 'Post';

  @override
  String get blogPostEditorArticleUpdate => 'Update Article';

  @override
  String get blogPostEditorArticlePost => 'Publish Article';

  @override
  String get blogPostEditorCategoryLabel => 'Category';

  @override
  String get blogPostEditorPinLabel => 'Pin this article';

  @override
  String get blogPostEditorTitleLabel => 'Title';

  @override
  String get blogPostEditorTitleHint => 'Enter a title';

  @override
  String get blogPostEditorTitleEnLabel => 'Title (ENGLISH)';

  @override
  String get blogPostEditorBodyLabel => 'Body';

  @override
  String get blogPostEditorBodyMarkdown => '— Markdown supported';

  @override
  String get blogPostEditorBodyHint =>
      'Write your post here\n\n## Heading\n**Bold** *Italic*\n- List item';

  @override
  String get blogPostEditorBodyEnLabel => 'Body (ENGLISH)';

  @override
  String get blogPostEditorRequiredError => 'Please enter a title and body';

  @override
  String blogPostEditorSaveError(Object error) {
    return 'Error: $error';
  }

  @override
  String get blogPostEditorPreviewEmpty => 'Please enter a title and body';

  @override
  String get blogPostEditorCoverAdd => 'Add Cover Image';

  @override
  String get blogPostEditorCoverChange => 'Change Cover Image';

  @override
  String get blogPostEditorSeasonNotSet => 'Set Season Task';

  @override
  String get blogPostEditorSeasonSet => 'Season Task Set';

  @override
  String get blogPostEditorSeasonDesc =>
      'Distribute and notify users of a season task alongside this post.';

  @override
  String get blogPostEditorSeasonModalTitle => 'Season Task Settings';

  @override
  String get blogPostEditorSeasonTaskName => 'Task Name (required)';

  @override
  String get blogPostEditorSeasonDuration => 'Duration (days)';

  @override
  String get blogPostEditorSeasonHintTitle => 'Hint Title';

  @override
  String get blogPostEditorSeasonHintBody => 'Hint Body';

  @override
  String get blogPostEditorSeasonHintBodyHint =>
      'Enter a tip to help users take their photo';

  @override
  String get blogPostEditorSeasonRequiredCount => 'Target Actions';

  @override
  String get blogPostEditorSeasonRequiredCountHint => 'e.g. 1';

  @override
  String get blogPostEditorSeasonBadgeUrl => 'Badge Icon';

  @override
  String get blogPostEditorSeasonDone => 'Done';

  @override
  String get blogPostEditorPlaceholder => 'Text';

  @override
  String get blogPostEditorCodePlaceholder => 'Enter code here';

  @override
  String get blogPostEditorBadgeUploadSuccess => 'Badge image uploaded';

  @override
  String get blogPostEditorBadgeUploadFailed => 'Upload failed';

  @override
  String get taskSetupTitle => 'Hero Task Setup';

  @override
  String get taskSetupSubtitle => 'Customize your Hero Tasks and schedule';

  @override
  String get taskSetupProfilePhoto => 'Profile Photo';

  @override
  String get taskSetupSelectPhoto => 'Choose Photo';

  @override
  String get taskSetupHeroTasks => 'Your Hero Tasks';

  @override
  String taskSetupHeroTaskLabel(int index) {
    return 'Hero Task $index';
  }

  @override
  String get taskSetupAddTask => 'Add Hero Task';

  @override
  String get taskSetupTimeSection => 'When do you want to do your Hero Task?';

  @override
  String get taskSetupTimeDesc =>
      'We\'ll send you a reminder notification at this time';

  @override
  String get taskSetupCompleteButton => 'Complete Setup & Start';

  @override
  String get taskSetupAtLeastOne => 'Please enter at least one Hero Task';

  @override
  String get taskSetupSaveFailed => 'Failed to save. Please try again.';

  @override
  String get taskSetupTimePickerTitle => 'Hero Task Time';

  @override
  String get taskSetupTimePickerCancel => 'Cancel';

  @override
  String get taskSetupTimePickerDone => 'Done';

  @override
  String get taskTemplateTitle => 'Start with one small win!';

  @override
  String get taskTemplateSubtitle =>
      'Pick a simple Hero Task\nand kick off your journey';

  @override
  String get taskTemplateSkip => 'Skip';

  @override
  String get taskTemplateStartButton => 'Start the App';

  @override
  String get taskTemplateCustomInputLabel => 'Enter your Hero Task';

  @override
  String get taskTemplateError => 'An error occurred. Please try again.';

  @override
  String get profileSetupTitle => 'Profile Setup';

  @override
  String get profileSetupSubtitle => 'Set up your profile';

  @override
  String get profileSetupUsernameLabel => 'Username';

  @override
  String get profileSetupUsernameRequired => 'Please enter a username';

  @override
  String get profileSetupUserIdLabel => 'User ID';

  @override
  String get profileSetupUserIdRequired => 'Please enter a user ID';

  @override
  String get profileSetupUserIdMinLength => 'Must be at least 5 characters';

  @override
  String get profileSetupUserIdAlphanumeric =>
      'Only letters, numbers, and underscores';

  @override
  String get profileSetupOccupationSection => 'Occupation (private)';

  @override
  String get profileSetupSelectPlaceholder => 'Select...';

  @override
  String get profileSetupOccupationPickerTitle => 'Select Occupation';

  @override
  String get profileSetupTaskTimeSection => 'Hero Task Schedule';

  @override
  String get profileSetupTaskTimePickerTitle => 'Set Hero Task Time';

  @override
  String get profileSetupNextButton => 'Next';

  @override
  String get profileSetupUserIdAlreadyUsed => 'This user ID is already taken';

  @override
  String get profileSetupOccupationRequired => 'Please select an occupation';

  @override
  String get profileSetupTaskTimeRequired => 'Please set a Hero Task time';

  @override
  String get profileSetupSaveFailed => 'Failed to save. Please try again.';

  @override
  String get profileSetupPickerCancel => 'Cancel';

  @override
  String get profileSetupPickerDone => 'Done';

  @override
  String get profileScreenProfileNotFound => 'Profile not found';

  @override
  String get profileScreenHeroTasks => 'Hero Tasks';

  @override
  String get profileScreenWeeklyTrend => '🔥 Weekly Trend Habits';

  @override
  String get profileScreenAddFirstTask => 'Add your first task';

  @override
  String get profileScreenQrTitle => 'QR Code';

  @override
  String get profileScreenQrDisplay => 'Show';

  @override
  String get profileScreenQrScan => 'Scan';

  @override
  String get profileScreenQrTooltip => 'Connect via QR code';

  @override
  String get profileScreenFollowing => 'Following';

  @override
  String get profileScreenFollowers => 'Followers';

  @override
  String get profileScreenStreak => 'Streak';

  @override
  String get profileScreenFollowingTitle => 'Following';

  @override
  String get profileScreenFollowersTitle => 'Followers';

  @override
  String get profileScreenTrendTitle => '🔥 Weekly Trend Habits';

  @override
  String get profileScreenTrendEmpty => 'No trend data yet.';

  @override
  String get profileScreenTimeUpdateFailed => 'Failed to update time';

  @override
  String get profileScreenReviewButton => 'Look Back on Your Journey';

  @override
  String get profileScreenAddTask => 'Add Task';

  @override
  String get profileScreenEditTask => 'Edit Task';

  @override
  String get profileScreenDeleteTaskTitle => 'Delete Task?';

  @override
  String get profileScreenDeleteTaskMessage =>
      'Are you sure you want to delete this task?';

  @override
  String get profileScreenDeleteTaskCancel => 'Cancel';

  @override
  String get profileScreenDeleteTaskButton => 'Delete';

  @override
  String get profileScreenSaveTask => 'Save';

  @override
  String get profileScreenTaskTriggerHint => 'Trigger (optional)';

  @override
  String get profileScreenTaskNameHint => 'Task name (e.g. Reading)';

  @override
  String get profileScreenTaskRewardHint => 'Reward (optional)';

  @override
  String get profileScreenOneTimeTaskTitle =>
      'Auto-deleted 24 hours after completion';

  @override
  String get profileScreenHabitTipsTitle => 'Habit-Building Tips';

  @override
  String get profileScreenHabitTipsClose => 'Close';

  @override
  String get cameraScreenTaskDefault => 'Today\'s Hero Task';

  @override
  String get cameraScreenUploadFailed => 'Post failed. Please try again.';

  @override
  String get cameraScreenCaption => 'Add a caption (optional)';

  @override
  String get cameraScreenCameraLoading => 'Starting camera...';

  @override
  String get cameraScreenPost => 'Post';

  @override
  String get cameraScreenDragPinch => 'Drag or pinch to reposition';

  @override
  String get cameraMusicAdd => 'Add Music';

  @override
  String get cameraMusicRemoveBgm => 'Remove BGM';

  @override
  String get cameraMusicSearchHint => 'Search by title or artist...';

  @override
  String get cameraMusicRecentSongs => 'Recently Used';

  @override
  String get cameraMusicTrends => 'Japan Trends';

  @override
  String get cameraMusicSelect => 'Select';

  @override
  String get heroTasksNoTasks => 'No Hero Tasks set';

  @override
  String get heroTasksNoTasksDesc => 'Set your Hero Tasks from your profile';

  @override
  String get heroTasksDeletePostTitle => 'Delete Post';

  @override
  String get heroTasksDeletePostDesc =>
      'Are you sure you want to delete this post?\n(Your today\'s achievement will also be removed)';

  @override
  String get heroTasksDeletePostCancel => 'Cancel';

  @override
  String get heroTasksDeletePostButton => 'Delete';

  @override
  String get heroTasksWelcomeMessage =>
      'Welcome to V EFFECT.\nThis is your arena.\n\nTap the camera icon and\nprove your first V.';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsDeleteAll => 'Clear All';

  @override
  String get notificationsEmpty => 'No notifications';

  @override
  String get notificationsDeleteFailed => 'Failed to delete. Please try again.';

  @override
  String get notificationsDeleteAllTitle => 'Clear All Notifications';

  @override
  String get notificationsDeleteAllMessage =>
      'Are you sure you want to clear all notifications?';

  @override
  String get notificationsDeleteAllCancel => 'Cancel';

  @override
  String get notificationsDeleteAllButton => 'Clear All';

  @override
  String get notificationsApproveRequest => 'Follow request accepted!';

  @override
  String get notificationsRejectRequest => 'Follow request declined.';

  @override
  String get notificationsApproveFailed =>
      'Failed to accept. Please try again.';

  @override
  String get notificationsFollowed => 'Now following!';

  @override
  String get notificationsFollowFailed => 'Failed to follow.';

  @override
  String get notificationsFollowing => 'Following';

  @override
  String get notificationsFollowBack => 'Follow Back';

  @override
  String get notificationsApprove => 'Approve';

  @override
  String get notificationsReject => 'Reject';

  @override
  String get notificationsDelete => 'Delete';

  @override
  String get notificationsSeasonTaskJoined =>
      'Participated in the limited-time task!';

  @override
  String get notificationsSeasonTaskSkipped => 'Skipped the limited-time task.';

  @override
  String notificationsFriendAccepted(Object username) {
    return '$username approved your friend request.';
  }

  @override
  String notificationsError(Object error) {
    return 'An error occurred: $error';
  }

  @override
  String get onboardingFirstQuestQuestionText =>
      'What does your ideal self look like?\nWhat habit do you want to build?';

  @override
  String get onboardingFirstQuestTriggerLabel => 'Trigger (optional)';

  @override
  String get onboardingFirstQuestTaskLabel => 'Task (your habit)';

  @override
  String get onboardingFirstQuestRewardLabel => 'Reward (optional)';

  @override
  String get onboardingFirstQuestPrivacyNote =>
      '* Trigger and reward are only visible to you.';

  @override
  String get onboardingFirstQuestCompleteButton => 'Let\'s Go';

  @override
  String get onboardingFirstQuestSkipButton => 'Skip';

  @override
  String onboardingFirstQuestSaveFailed(Object error) {
    return 'Failed to save: $error';
  }

  @override
  String get onboardingFirstQuestHabitTipsTitle => 'Habit-Building Tips';

  @override
  String get onboardingFirstQuestHabitStackingTitle => 'Habit Stacking';

  @override
  String get onboardingFirstQuestHabitStackingDesc =>
      'Attach a new habit right after something you already do every day. That\'s your trigger.';

  @override
  String get onboardingFirstQuestTemptationBundlingTitle =>
      'Temptation Bundling';

  @override
  String get onboardingFirstQuestTemptationBundlingDesc =>
      'Pair something you should do (your task) with something you want to do (your reward) to boost your drive.';

  @override
  String get onboardingProfileWelcome => 'Welcome to V EFFECT';

  @override
  String get onboardingProfileSubtitle => 'Set up your profile';

  @override
  String get onboardingProfileUsernameLabel => 'Username';

  @override
  String get onboardingProfileUsernameHint => 'Enter your display name';

  @override
  String get onboardingProfileUsernameRequired => 'Please enter a username';

  @override
  String get onboardingProfileUserIdLabel => 'User ID';

  @override
  String get onboardingProfileUserIdMinLength =>
      'Must be at least 5 characters';

  @override
  String get onboardingProfileUserIdAlphanumeric =>
      'Only letters, numbers, and underscores';

  @override
  String get onboardingProfileUserIdRequired => 'Please enter a user ID';

  @override
  String get onboardingProfileUserIdAlreadyUsed =>
      'This user ID is already taken';

  @override
  String onboardingProfileSaveFailed(Object error) {
    return 'Failed to save: $error';
  }

  @override
  String get onboardingProfileStartButton => 'Prove your first V →';

  @override
  String get onboardingProfileHelperText =>
      '5+ characters · letters, numbers, underscores only';

  @override
  String get onboardingProfileImageAdjust => 'Adjust Image';

  @override
  String get notificationPromptTitle =>
      'Make your crew\'s hustle work for you.';

  @override
  String get notificationPromptDesc =>
      'The most powerful force in V EFFECT is your crew.\n\nWith notifications on, your friends\' victories inspire you in real time — and your effort reaches them too.\nFeel each other\'s presence and build unbreakable habits together.';

  @override
  String get notificationPromptNext => 'Next';

  @override
  String get notificationPromptLater => 'Not now';

  @override
  String get friendInviteTitle => 'Prove V (Victory) with your crew!';

  @override
  String get friendInviteDesc =>
      'Your first V Quest is set!\nInvite friends to share your effort and victories!';

  @override
  String get friendInviteShareButton => 'Invite friends (Share via LINE, etc.)';

  @override
  String get friendInviteQrButton => 'Connect with existing users (QR Code)';

  @override
  String get friendInviteLater => 'Not now';

  @override
  String get friendInviteQrTitle => 'QR Code';

  @override
  String get friendInviteQrDisplay => 'Show My QR Code';

  @override
  String get friendInviteQrScan => 'Scan QR Code';

  @override
  String get weeklyReviewBannerTitle => 'Your weekly review is ready!';

  @override
  String get globalErrorTitle => 'Oops, something went wrong';

  @override
  String get globalErrorDesc => 'A problem occurred while launching the app.';

  @override
  String get globalErrorRetry => 'Retry';

  @override
  String get globalErrorUnknown => 'Unknown error';

  @override
  String get seasonHintDefaultTitle => 'Season Task Hint 💡';

  @override
  String get seasonHintDefaultBody =>
      'Tips to help you build this season task into a habit.';

  @override
  String get seasonHintReadBlog => 'Read the story behind this task';

  @override
  String get seasonHintTriggerLabel => 'Your Trigger';

  @override
  String get seasonHintTriggerHint =>
      'e.g. Right after waking up, On the commute';

  @override
  String get seasonHintSaveButton => 'Save Trigger';

  @override
  String get postSuccessStreakContinuing => 'Streak active';

  @override
  String homeWeeklyReviewLoadFailed(String code) {
    return 'Failed to load review data ($code)';
  }

  @override
  String get homeUnexpectedError => 'An unexpected error occurred';

  @override
  String get homeBlockUser => 'Block User';

  @override
  String get homeReportPost => 'Report Inappropriate Post';

  @override
  String get homeBlockConfirmTitle => 'Block this user?';

  @override
  String get homeBlockConfirmDesc =>
      'Their posts will no longer appear in your feed.';

  @override
  String get homeBlockConfirmCancel => 'Cancel';

  @override
  String get homeBlockSuccess => 'User blocked';

  @override
  String get homeBlockFailed => 'Failed to block user';

  @override
  String get homeBlockButton => 'Block';

  @override
  String get homeReportTitle => 'Select a Reason';

  @override
  String get homeReportSpam => 'Spam';

  @override
  String get homeReportHarassment => 'Harassment';

  @override
  String get homeReportInappropriate => 'Inappropriate Content';

  @override
  String get homeReportOther => 'Other';

  @override
  String get homeReportCancel => 'Cancel';

  @override
  String get homeReportSuccess =>
      'Reported. Thanks for helping keep V EFFECT a safe space.';

  @override
  String get homeReportFailed => 'Failed to report';

  @override
  String get homeErrorOccurred => 'An error occurred';

  @override
  String get homeRetry => 'Retry';

  @override
  String homeFriendRequestApproveFailed(Object error) {
    return 'Failed to accept: $error';
  }

  @override
  String homeFriendRequestProcessFailed(Object error) {
    return 'Action failed: $error';
  }

  @override
  String get homeNewsTitle => 'From the V EFFECT Team';

  @override
  String get homeMotivationText1 => 'You are a front-runner.';

  @override
  String get homeMotivationText2 =>
      'Every small choice, every small victory becomes proof.\nYour ideal self becomes real.';

  @override
  String get homeEmojiReactionHint => 'Tap to cheer with an emoji!';

  @override
  String get homeFriendPostsTitle => 'Your crew\'s effort is here';

  @override
  String get homeStreakResetMessage =>
      'Even if your streak breaks,\nas long as you keep moving forward,\nV EFFECT will ignite again.';

  @override
  String get vEffectConceptLine1 =>
      'Every small victory brings you closer to your ideal self.';

  @override
  String get vEffectConceptLine2 =>
      'This platform is here to support your victories and your habits.';

  @override
  String get vEffectConceptLine3Prefix => 'Now, with your crew, let\'s spark ';

  @override
  String get vEffectConceptLine3Suffix => '.';

  @override
  String get vEffectFeatureLine1 =>
      'Capture today\'s achievement in a photo. That\'s it.';

  @override
  String get vEffectFeatureLine2 =>
      'The fact that you did it builds who you are.';

  @override
  String get vEffectFeatureLine3 => 'Each other\'s effort becomes connection.';

  @override
  String get vEffectFeatureLine4 => 'See who proved their V today.';

  @override
  String get vEffectFeatureLine5 =>
      'Only those who prove their effort can reach — and be reached.';

  @override
  String get vEffectJoinButton => 'Join V EFFECT →';

  @override
  String get adLabel => 'Ad';

  @override
  String get dateFormatFull => 'MMMM d, yyyy';

  @override
  String get vEffectConceptTitle => 'What is V EFFECT?';

  @override
  String get vEffectDefinition => 'The V in V EFFECT stands for Victory.';

  @override
  String get vEffectTerm => 'V EFFECT (Victory Effect)';

  @override
  String get vEffectCoreTitle => 'The Core of V EFFECT';

  @override
  String get vEffectHeroTaskLabel => ' (Hero Task)';

  @override
  String get vEffectSlogan => 'Prove your V. Raw is fine.';

  @override
  String heroTaskSeasonDaysLeft(int days) {
    return 'SEASON | $days days left';
  }

  @override
  String homeFriendRequestMultiple(String username, int count) {
    return '$username and $count others sent you a follow request';
  }

  @override
  String get homePostToSeeFriends =>
      '(Update) Post a task to start seeing your friends\' posts!';

  @override
  String get homeProveVictory => 'Prove your Victory';

  @override
  String get editProfileGenderMale => 'Male';

  @override
  String get editProfileGenderFemale => 'Female';

  @override
  String get editProfileGenderOther => 'Other';

  @override
  String get blogEditorTextBlockPlaceholder => 'Text';

  @override
  String get blogEditorCodeBlockPlaceholder => 'Enter code here';

  @override
  String blogEditorSeasonDays(String days) {
    return '$days day(s)';
  }

  @override
  String get blogEditorExampleTaskHint => 'e.g. Express gratitude';

  @override
  String get blogEditorExampleDurationHint => 'e.g. 7';

  @override
  String get blogEditorExampleTesterHint => 'e.g. tester (or Firebase URL)';

  @override
  String get blogEditorImageUploadTooltip => 'Select and upload an image';

  @override
  String initialFriendAtUserNotFound(String userId) {
    return '@$userId: User not found';
  }

  @override
  String initialFriendAtSendFailed(String userId) {
    return '@$userId: Failed to send';
  }

  @override
  String initialFriendOtherUserNotFound(String userId) {
    return '$userId: User not found';
  }

  @override
  String initialFriendOtherSendFailed(String userId) {
    return '$userId: Failed to send';
  }

  @override
  String get initialFriendExampleIdHint => 'e.g. user_123';

  @override
  String hintExampleFormat(String value) {
    return 'e.g. $value';
  }

  @override
  String get firstQuestTaskHint1 => 'Gym';

  @override
  String get firstQuestTaskHint2 => 'English study';

  @override
  String get firstQuestTaskHint3 => 'Room cleanup';

  @override
  String get firstQuestTaskHint4 => 'Running';

  @override
  String get firstQuestTaskHint5 => 'Nutrition';

  @override
  String get firstQuestTriggerHint1 => 'After waking up';

  @override
  String get firstQuestTriggerHint2 => 'After getting home';

  @override
  String get firstQuestTriggerHint3 => 'After a bath';

  @override
  String get firstQuestTriggerHint4 => 'When sitting at my desk';

  @override
  String get firstQuestRewardHint1 => 'A good cup of coffee';

  @override
  String get firstQuestRewardHint2 => '5 min of social media';

  @override
  String get firstQuestRewardHint3 => 'Watch a video';

  @override
  String get firstQuestRewardHint4 => 'Play a favorite game';

  @override
  String get firstQuestRewardHint5 => 'Read a manga';

  @override
  String get firstQuestTitlePrefix => 'Let\'s decide your first ';

  @override
  String get firstQuestHeroTaskLabel => ' (Hero Task)';

  @override
  String get firstQuestTitleSuffix => '';

  @override
  String get firstQuestNoTaskPlaceholder => '(Task)';

  @override
  String get firstQuestKeyword1 => 'Victory';

  @override
  String get firstQuestKeyword2 => 'Effort';

  @override
  String get firstQuestKeyword3 => 'Achievement';

  @override
  String get firstQuestKeyword4 => 'Goal';

  @override
  String get firstQuestKeyword5 => 'Habit';

  @override
  String get firstQuestKeyword6 => 'Consistency';

  @override
  String get onboardingProfileExampleIdHint => 'e.g. v_effect';

  @override
  String get categoryOther => 'Other';

  @override
  String get habitStackingHint =>
      '• Habit Stacking\nAttach a new habit right after an existing daily action (your trigger) for the best results.';

  @override
  String get temptationBundlingHint =>
      '• Temptation Bundling\nPair something you should do (task) with something you want to do (reward) to build stronger motivation.';

  @override
  String get profileNoTaskPlaceholder => '(Task)';

  @override
  String get occupationEmployee => 'Office Worker';

  @override
  String get occupationExecutive => 'Executive / Manager';

  @override
  String get occupationCivilServant => 'Civil Servant';

  @override
  String get occupationSelfEmployed => 'Self-Employed / Freelancer';

  @override
  String get occupationProfessional => 'Professional (Doctor, Lawyer, etc.)';

  @override
  String get occupationEducation => 'Education / Teaching';

  @override
  String get occupationStudent => 'Student';

  @override
  String get occupationPartTime => 'Part-time Worker';

  @override
  String get occupationHomemaker => 'Homemaker';

  @override
  String get occupationUnemployed => 'Unemployed';

  @override
  String get occupationOther => 'Other';

  @override
  String get hintNameExample => 'e.g. V EFFECT';

  @override
  String timeHour(int hour) {
    return '$hour';
  }

  @override
  String timeMinute(String minute) {
    return '$minute';
  }

  @override
  String get timePeriodAm => 'AM';

  @override
  String get timePeriodPm => 'PM';

  @override
  String get hintTaskExample => 'e.g. Run 3km';

  @override
  String get taskTemplateBook => 'Open a Book';

  @override
  String get taskTemplateBookDesc => 'Open your favorite book and snap a photo';

  @override
  String get taskTemplateBreathing => 'Breathe Outside';

  @override
  String get taskTemplateBreathingDesc =>
      'Step outside and capture a deep breath moment';

  @override
  String get taskTemplateWater => 'Drink Water';

  @override
  String get taskTemplateWaterDesc =>
      'Drink a full glass of water and snap the moment';

  @override
  String get taskTemplateCustom => 'Set Your Own';

  @override
  String get taskTemplateCustomDesc => 'Create any Hero Task you want';

  @override
  String get adVeffectLabel => 'VEFFECT Sponsored';

  @override
  String postSuccessDaysUntilNext(String label, int days) {
    return '$days day(s) until $label';
  }

  @override
  String get defaultUsername => 'User';

  @override
  String get vPracticeDistributeBadge => 'Distribute Badge to All';

  @override
  String get vPracticeCreateBlog => 'Create Blog Post';

  @override
  String get vPracticeError => 'An error occurred';

  @override
  String get vPracticeNoNews => 'No news yet';

  @override
  String get vPracticeBadgeIdRequired =>
      'Please enter a badge ID (e.g. tester)';

  @override
  String vPracticeBadgeDistributed(String badgeUrl) {
    return 'Badge \"$badgeUrl\" distributed to all users!';
  }

  @override
  String get vPracticeBadgeDistributeFailed => 'Failed to distribute badge';

  @override
  String get vPracticeDialogTitle => 'Distribute Badge to All';

  @override
  String get vPracticeDialogDesc =>
      'Forcibly equip the specified badge on all currently registered users. No notifications will be sent.';

  @override
  String get vPracticeBadgeIdHint => 'Badge ID (e.g. tester)';

  @override
  String get vPracticeCancel => 'Cancel';

  @override
  String get vPracticeDistribute => 'Distribute';

  @override
  String mutualFollowedBy(String userNames) {
    return 'Followed by $userNames';
  }

  @override
  String mutualFollowedByAndOthers(String userNames, int count) {
    return 'Followed by $userNames and $count others';
  }

  @override
  String get timeNow => 'now';

  @override
  String timeMinutesAgo(int count) {
    return '${count}m';
  }

  @override
  String timeHoursAgo(int count) {
    return '${count}h';
  }

  @override
  String timeDaysAgo(int count) {
    return '${count}d';
  }
}
