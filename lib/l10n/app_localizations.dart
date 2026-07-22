import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja')
  ];

  /// No description provided for @settingsTitle.
  ///
  /// In ja, this message translates to:
  /// **'設定'**
  String get settingsTitle;

  /// No description provided for @settingsDisplay.
  ///
  /// In ja, this message translates to:
  /// **'表示とデザイン'**
  String get settingsDisplay;

  /// No description provided for @themeSetting.
  ///
  /// In ja, this message translates to:
  /// **'テーマ設定'**
  String get themeSetting;

  /// No description provided for @themeDescription.
  ///
  /// In ja, this message translates to:
  /// **'アプリの見た目を切り替えます。'**
  String get themeDescription;

  /// No description provided for @themeLight.
  ///
  /// In ja, this message translates to:
  /// **'ライトモード'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In ja, this message translates to:
  /// **'ダークモード'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In ja, this message translates to:
  /// **'システム設定に同期'**
  String get themeSystem;

  /// No description provided for @languageSetting.
  ///
  /// In ja, this message translates to:
  /// **'言語設定 / Language'**
  String get languageSetting;

  /// No description provided for @languageJapanese.
  ///
  /// In ja, this message translates to:
  /// **'日本語'**
  String get languageJapanese;

  /// No description provided for @languageEnglish.
  ///
  /// In ja, this message translates to:
  /// **'ENGLISH'**
  String get languageEnglish;

  /// No description provided for @errorCannotOpenLink.
  ///
  /// In ja, this message translates to:
  /// **'リンクを開けませんでした'**
  String get errorCannotOpenLink;

  /// No description provided for @settingsNotification.
  ///
  /// In ja, this message translates to:
  /// **'通知'**
  String get settingsNotification;

  /// No description provided for @settingsPasswordSecurity.
  ///
  /// In ja, this message translates to:
  /// **'パスワードとセキュリティ'**
  String get settingsPasswordSecurity;

  /// No description provided for @settingsSupportLegal.
  ///
  /// In ja, this message translates to:
  /// **'サポート・法的情報'**
  String get settingsSupportLegal;

  /// No description provided for @settingsContactBugReport.
  ///
  /// In ja, this message translates to:
  /// **'お問い合わせ / バグ報告'**
  String get settingsContactBugReport;

  /// No description provided for @settingsTerms.
  ///
  /// In ja, this message translates to:
  /// **'利用規約'**
  String get settingsTerms;

  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In ja, this message translates to:
  /// **'プライバシーポリシー'**
  String get settingsPrivacyPolicy;

  /// No description provided for @settingsVersionInfo.
  ///
  /// In ja, this message translates to:
  /// **'バージョン情報'**
  String get settingsVersionInfo;

  /// No description provided for @loginTagline.
  ///
  /// In ja, this message translates to:
  /// **'日々の努力を、仲間と共に。'**
  String get loginTagline;

  /// No description provided for @loginEmailOrId.
  ///
  /// In ja, this message translates to:
  /// **'メールアドレスまたはユーザーID'**
  String get loginEmailOrId;

  /// No description provided for @loginPassword.
  ///
  /// In ja, this message translates to:
  /// **'パスワード'**
  String get loginPassword;

  /// No description provided for @loginForgotPassword.
  ///
  /// In ja, this message translates to:
  /// **'パスワードをお忘れですか？'**
  String get loginForgotPassword;

  /// No description provided for @loginButton.
  ///
  /// In ja, this message translates to:
  /// **'ログイン'**
  String get loginButton;

  /// No description provided for @loginOrDivider.
  ///
  /// In ja, this message translates to:
  /// **'または'**
  String get loginOrDivider;

  /// No description provided for @loginWithApple.
  ///
  /// In ja, this message translates to:
  /// **'Appleでログイン'**
  String get loginWithApple;

  /// No description provided for @loginWithGoogle.
  ///
  /// In ja, this message translates to:
  /// **'Googleでログイン'**
  String get loginWithGoogle;

  /// No description provided for @loginNoAccount.
  ///
  /// In ja, this message translates to:
  /// **'アカウントをお持ちでないですか？'**
  String get loginNoAccount;

  /// No description provided for @loginRegister.
  ///
  /// In ja, this message translates to:
  /// **'新規登録'**
  String get loginRegister;

  /// No description provided for @loginContactSupport.
  ///
  /// In ja, this message translates to:
  /// **'ログインできない等のご相談・お問い合わせ'**
  String get loginContactSupport;

  /// No description provided for @loginByLoggingIn.
  ///
  /// In ja, this message translates to:
  /// **'ログインすることで、'**
  String get loginByLoggingIn;

  /// No description provided for @loginAnd.
  ///
  /// In ja, this message translates to:
  /// **'および'**
  String get loginAnd;

  /// No description provided for @loginAgreeTerms.
  ///
  /// In ja, this message translates to:
  /// **'に同意したものとみなされます。'**
  String get loginAgreeTerms;

  /// No description provided for @loginFailed.
  ///
  /// In ja, this message translates to:
  /// **'ログインに失敗しました'**
  String get loginFailed;

  /// No description provided for @loginErrorIdOrPassword.
  ///
  /// In ja, this message translates to:
  /// **'ユーザーIDまたはパスワードが間違っています'**
  String get loginErrorIdOrPassword;

  /// No description provided for @loginErrorUserNotFound.
  ///
  /// In ja, this message translates to:
  /// **'ユーザーが見つかりません'**
  String get loginErrorUserNotFound;

  /// No description provided for @loginErrorWrongPassword.
  ///
  /// In ja, this message translates to:
  /// **'パスワードが間違っています'**
  String get loginErrorWrongPassword;

  /// No description provided for @loginErrorInvalidCredential.
  ///
  /// In ja, this message translates to:
  /// **'メールアドレスまたはパスワードが間違っています'**
  String get loginErrorInvalidCredential;

  /// No description provided for @loginAppleFailed.
  ///
  /// In ja, this message translates to:
  /// **'Appleでのログインに失敗しました'**
  String get loginAppleFailed;

  /// No description provided for @loginGoogleFailed.
  ///
  /// In ja, this message translates to:
  /// **'Googleでのログインに失敗しました'**
  String get loginGoogleFailed;

  /// No description provided for @registerCreateAccount.
  ///
  /// In ja, this message translates to:
  /// **'アカウントを作成'**
  String get registerCreateAccount;

  /// No description provided for @registerSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'V EFFECTに参加して仲間と高め合おう'**
  String get registerSubtitle;

  /// No description provided for @registerEmail.
  ///
  /// In ja, this message translates to:
  /// **'メールアドレス'**
  String get registerEmail;

  /// No description provided for @registerEmailRequired.
  ///
  /// In ja, this message translates to:
  /// **'メールアドレスを入力してください'**
  String get registerEmailRequired;

  /// No description provided for @registerPasswordRequired.
  ///
  /// In ja, this message translates to:
  /// **'パスワードを入力してください'**
  String get registerPasswordRequired;

  /// No description provided for @registerPasswordMinLength.
  ///
  /// In ja, this message translates to:
  /// **'6文字以上で入力してください'**
  String get registerPasswordMinLength;

  /// No description provided for @registerPasswordConfirm.
  ///
  /// In ja, this message translates to:
  /// **'パスワード（確認）'**
  String get registerPasswordConfirm;

  /// No description provided for @registerPasswordReenter.
  ///
  /// In ja, this message translates to:
  /// **'パスワードを再入力してください'**
  String get registerPasswordReenter;

  /// No description provided for @registerPasswordMismatch.
  ///
  /// In ja, this message translates to:
  /// **'パスワードが一致しません'**
  String get registerPasswordMismatch;

  /// No description provided for @registerAgreeToSuffix.
  ///
  /// In ja, this message translates to:
  /// **'に同意する'**
  String get registerAgreeToSuffix;

  /// No description provided for @registerFailed.
  ///
  /// In ja, this message translates to:
  /// **'登録に失敗しました。'**
  String get registerFailed;

  /// No description provided for @registerEmailInUse.
  ///
  /// In ja, this message translates to:
  /// **'このメールアドレスは既に使われています。'**
  String get registerEmailInUse;

  /// No description provided for @registerWeakPassword.
  ///
  /// In ja, this message translates to:
  /// **'パスワードは6文字以上にしてください。'**
  String get registerWeakPassword;

  /// No description provided for @registerFailedRetry.
  ///
  /// In ja, this message translates to:
  /// **'登録に失敗しました。しばらくしてからお試しください。'**
  String get registerFailedRetry;

  /// No description provided for @registerAppleFailed.
  ///
  /// In ja, this message translates to:
  /// **'Appleでの登録に失敗しました。'**
  String get registerAppleFailed;

  /// No description provided for @registerGoogleFailed.
  ///
  /// In ja, this message translates to:
  /// **'Googleでの登録に失敗しました。'**
  String get registerGoogleFailed;

  /// No description provided for @registerWithApple.
  ///
  /// In ja, this message translates to:
  /// **'Appleで作成'**
  String get registerWithApple;

  /// No description provided for @registerWithGoogle.
  ///
  /// In ja, this message translates to:
  /// **'Googleで作成'**
  String get registerWithGoogle;

  /// No description provided for @forgotPasswordResetTitle.
  ///
  /// In ja, this message translates to:
  /// **'パスワードリセット'**
  String get forgotPasswordResetTitle;

  /// No description provided for @forgotPasswordInstruction.
  ///
  /// In ja, this message translates to:
  /// **'ユーザーIDと登録メールアドレスを入力してください'**
  String get forgotPasswordInstruction;

  /// No description provided for @forgotPasswordBothRequired.
  ///
  /// In ja, this message translates to:
  /// **'ユーザーIDとメールアドレスを入力してください'**
  String get forgotPasswordBothRequired;

  /// No description provided for @forgotPasswordInvalid.
  ///
  /// In ja, this message translates to:
  /// **'入力内容が一致するアカウントが見つかりませんでした'**
  String get forgotPasswordInvalid;

  /// No description provided for @forgotPasswordUserId.
  ///
  /// In ja, this message translates to:
  /// **'ユーザーID'**
  String get forgotPasswordUserId;

  /// No description provided for @forgotPasswordSendReset.
  ///
  /// In ja, this message translates to:
  /// **'リセットメールを送信'**
  String get forgotPasswordSendReset;

  /// No description provided for @forgotPasswordEmailSent.
  ///
  /// In ja, this message translates to:
  /// **'メールを送信しました'**
  String get forgotPasswordEmailSent;

  /// No description provided for @forgotPasswordEmailSentDesc.
  ///
  /// In ja, this message translates to:
  /// **'{email} 宛に\nパスワードリセット用のメールを送信しました。'**
  String forgotPasswordEmailSentDesc(String email);

  /// No description provided for @forgotPasswordResetViaLink.
  ///
  /// In ja, this message translates to:
  /// **'リンクからパスワードを再設定する'**
  String get forgotPasswordResetViaLink;

  /// No description provided for @forgotPasswordBackToLogin.
  ///
  /// In ja, this message translates to:
  /// **'ログイン画面に戻る'**
  String get forgotPasswordBackToLogin;

  /// No description provided for @forgotPasswordResend.
  ///
  /// In ja, this message translates to:
  /// **'メールが届かない場合は再送信'**
  String get forgotPasswordResend;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In ja, this message translates to:
  /// **'パスワード再設定'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordLinkInvalid.
  ///
  /// In ja, this message translates to:
  /// **'リンクが無効です'**
  String get resetPasswordLinkInvalid;

  /// No description provided for @resetPasswordLinkExpired.
  ///
  /// In ja, this message translates to:
  /// **'リンクの有効期限が切れています'**
  String get resetPasswordLinkExpired;

  /// No description provided for @resetPasswordLinkInvalidPaste.
  ///
  /// In ja, this message translates to:
  /// **'リンクが正しくありません。メールのリンクをそのまま貼り付けてください'**
  String get resetPasswordLinkInvalidPaste;

  /// No description provided for @resetPasswordPasteLink.
  ///
  /// In ja, this message translates to:
  /// **'リンクを貼り付けてください'**
  String get resetPasswordPasteLink;

  /// No description provided for @resetPasswordMismatch.
  ///
  /// In ja, this message translates to:
  /// **'パスワードが一致しません'**
  String get resetPasswordMismatch;

  /// No description provided for @resetPasswordFailed.
  ///
  /// In ja, this message translates to:
  /// **'パスワードの再設定に失敗しました'**
  String get resetPasswordFailed;

  /// No description provided for @resetPasswordWeakPassword.
  ///
  /// In ja, this message translates to:
  /// **'パスワードは6文字以上にしてください'**
  String get resetPasswordWeakPassword;

  /// No description provided for @resetPasswordPasteLinkTitle.
  ///
  /// In ja, this message translates to:
  /// **'リンクを貼り付ける'**
  String get resetPasswordPasteLinkTitle;

  /// No description provided for @resetPasswordPasteLinkDesc.
  ///
  /// In ja, this message translates to:
  /// **'パスワードリセットメールに記載されているリンクをコピーして貼り付けてください'**
  String get resetPasswordPasteLinkDesc;

  /// No description provided for @resetPasswordPasteLinkLabel.
  ///
  /// In ja, this message translates to:
  /// **'パスワードリセットリンク'**
  String get resetPasswordPasteLinkLabel;

  /// No description provided for @resetPasswordNext.
  ///
  /// In ja, this message translates to:
  /// **'次へ'**
  String get resetPasswordNext;

  /// No description provided for @resetPasswordNewTitle.
  ///
  /// In ja, this message translates to:
  /// **'新しいパスワードを設定'**
  String get resetPasswordNewTitle;

  /// No description provided for @resetPasswordNew.
  ///
  /// In ja, this message translates to:
  /// **'新しいパスワード'**
  String get resetPasswordNew;

  /// No description provided for @resetPasswordConfirm.
  ///
  /// In ja, this message translates to:
  /// **'パスワード（確認）'**
  String get resetPasswordConfirm;

  /// No description provided for @resetPasswordButton.
  ///
  /// In ja, this message translates to:
  /// **'パスワードを更新する'**
  String get resetPasswordButton;

  /// No description provided for @resetPasswordDone.
  ///
  /// In ja, this message translates to:
  /// **'パスワードを更新しました'**
  String get resetPasswordDone;

  /// No description provided for @resetPasswordLoginWithNew.
  ///
  /// In ja, this message translates to:
  /// **'新しいパスワードでログインしてください'**
  String get resetPasswordLoginWithNew;

  /// No description provided for @resetPasswordGoToLogin.
  ///
  /// In ja, this message translates to:
  /// **'ログイン画面へ'**
  String get resetPasswordGoToLogin;

  /// No description provided for @errorGenericRetry.
  ///
  /// In ja, this message translates to:
  /// **'エラーが発生しました。しばらくしてからお試しください'**
  String get errorGenericRetry;

  /// No description provided for @weeklyReviewSelectBackground.
  ///
  /// In ja, this message translates to:
  /// **'背景画像を選択'**
  String get weeklyReviewSelectBackground;

  /// No description provided for @weeklyReviewNoPostsDefault.
  ///
  /// In ja, this message translates to:
  /// **'今週の投稿はまだありません。\nデフォルトの背景でシェアします。'**
  String get weeklyReviewNoPostsDefault;

  /// No description provided for @weeklyReviewShareWithoutBackground.
  ///
  /// In ja, this message translates to:
  /// **'背景画像なしでシェア'**
  String get weeklyReviewShareWithoutBackground;

  /// No description provided for @weeklyReviewLoadError.
  ///
  /// In ja, this message translates to:
  /// **'読み込みエラー: {error}'**
  String weeklyReviewLoadError(Object error);

  /// No description provided for @weeklyReviewShareToSns.
  ///
  /// In ja, this message translates to:
  /// **'SNSへシェア'**
  String get weeklyReviewShareToSns;

  /// No description provided for @weeklyReviewStatTasks.
  ///
  /// In ja, this message translates to:
  /// **'今週のタスク'**
  String get weeklyReviewStatTasks;

  /// No description provided for @weeklyReviewStatStreak.
  ///
  /// In ja, this message translates to:
  /// **'連続達成'**
  String get weeklyReviewStatStreak;

  /// No description provided for @weeklyReviewStatVFire.
  ///
  /// In ja, this message translates to:
  /// **'累計VFIRE'**
  String get weeklyReviewStatVFire;

  /// No description provided for @weeklyReviewStatReactions.
  ///
  /// In ja, this message translates to:
  /// **'リアクション'**
  String get weeklyReviewStatReactions;

  /// No description provided for @weeklyReviewNoPosts.
  ///
  /// In ja, this message translates to:
  /// **'今週の投稿はまだありません'**
  String get weeklyReviewNoPosts;

  /// No description provided for @weeklyReviewReplay.
  ///
  /// In ja, this message translates to:
  /// **'今週の振り返りをもう一度見る'**
  String get weeklyReviewReplay;

  /// No description provided for @weeklyReviewTitle.
  ///
  /// In ja, this message translates to:
  /// **'今週のハイライト'**
  String get weeklyReviewTitle;

  /// No description provided for @weeklyReviewMostSentTo.
  ///
  /// In ja, this message translates to:
  /// **'あなたは今週、{name}さんに一番多くV FIRE（合計{count}回）を送りました！'**
  String weeklyReviewMostSentTo(String name, int count);

  /// No description provided for @weeklyReviewMostReceivedFrom.
  ///
  /// In ja, this message translates to:
  /// **'あなたは今週、{name}さんから一番多くV FIRE（合計{count}回）を送られました！'**
  String weeklyReviewMostReceivedFrom(String name, int count);

  /// No description provided for @weeklyReviewMostActiveDay.
  ///
  /// In ja, this message translates to:
  /// **'今週最もモチベーションが高かったのは {day} でした！（タスクを {count} 個完了！）'**
  String weeklyReviewMostActiveDay(String day, int count);

  /// No description provided for @weeklyReviewGoldenTime.
  ///
  /// In ja, this message translates to:
  /// **'今週の集中ゴールデンタイムは【{range}】でした！集中力が際立っています。'**
  String weeklyReviewGoldenTime(String range);

  /// No description provided for @weeklyReviewBuddyTask.
  ///
  /// In ja, this message translates to:
  /// **'今週の相棒タスクは『{task}』でした！（今週だけで {count} 回クリア！）'**
  String weeklyReviewBuddyTask(String task, int count);

  /// No description provided for @weeklyReviewNoInteractions.
  ///
  /// In ja, this message translates to:
  /// **'フレンドの投稿にV FIREを送って、お互いを鼓舞しましょう！'**
  String get weeklyReviewNoInteractions;

  /// No description provided for @weekdayMonday.
  ///
  /// In ja, this message translates to:
  /// **'月曜日'**
  String get weekdayMonday;

  /// No description provided for @weekdayTuesday.
  ///
  /// In ja, this message translates to:
  /// **'火曜日'**
  String get weekdayTuesday;

  /// No description provided for @weekdayWednesday.
  ///
  /// In ja, this message translates to:
  /// **'水曜日'**
  String get weekdayWednesday;

  /// No description provided for @weekdayThursday.
  ///
  /// In ja, this message translates to:
  /// **'木曜日'**
  String get weekdayThursday;

  /// No description provided for @weekdayFriday.
  ///
  /// In ja, this message translates to:
  /// **'金曜日'**
  String get weekdayFriday;

  /// No description provided for @weekdaySaturday.
  ///
  /// In ja, this message translates to:
  /// **'土曜日'**
  String get weekdaySaturday;

  /// No description provided for @weekdaySunday.
  ///
  /// In ja, this message translates to:
  /// **'日曜日'**
  String get weekdaySunday;

  /// No description provided for @timeRangeMorning.
  ///
  /// In ja, this message translates to:
  /// **'朝（5:00〜12:00）'**
  String get timeRangeMorning;

  /// No description provided for @timeRangeAfternoon.
  ///
  /// In ja, this message translates to:
  /// **'昼（12:00〜18:00）'**
  String get timeRangeAfternoon;

  /// No description provided for @timeRangeEvening.
  ///
  /// In ja, this message translates to:
  /// **'夜（18:00〜24:00）'**
  String get timeRangeEvening;

  /// No description provided for @timeRangeLateNight.
  ///
  /// In ja, this message translates to:
  /// **'深夜（0:00〜5:00）'**
  String get timeRangeLateNight;

  /// No description provided for @authWrapperConnecting.
  ///
  /// In ja, this message translates to:
  /// **'接続に時間がかかっています...'**
  String get authWrapperConnecting;

  /// No description provided for @authWrapperRetry.
  ///
  /// In ja, this message translates to:
  /// **'再試行'**
  String get authWrapperRetry;

  /// No description provided for @firestoreReadError.
  ///
  /// In ja, this message translates to:
  /// **'Firestore読み込みエラー: {error}'**
  String firestoreReadError(Object error);

  /// No description provided for @followListNoUsers.
  ///
  /// In ja, this message translates to:
  /// **'ユーザーがいません'**
  String get followListNoUsers;

  /// No description provided for @followListFollowing.
  ///
  /// In ja, this message translates to:
  /// **'フォロー中'**
  String get followListFollowing;

  /// No description provided for @followListFollowers.
  ///
  /// In ja, this message translates to:
  /// **'フォロワー'**
  String get followListFollowers;

  /// No description provided for @followListPendingBanner.
  ///
  /// In ja, this message translates to:
  /// **'フォロー申請が届いています'**
  String get followListPendingBanner;

  /// No description provided for @followListMe.
  ///
  /// In ja, this message translates to:
  /// **'自分'**
  String get followListMe;

  /// No description provided for @qrScannerTitle.
  ///
  /// In ja, this message translates to:
  /// **'QRスキャン'**
  String get qrScannerTitle;

  /// No description provided for @qrScannerFlashlight.
  ///
  /// In ja, this message translates to:
  /// **'フラッシュライト'**
  String get qrScannerFlashlight;

  /// No description provided for @qrScannerUserNotFound.
  ///
  /// In ja, this message translates to:
  /// **'ユーザーが見つかりません'**
  String get qrScannerUserNotFound;

  /// No description provided for @qrScannerError.
  ///
  /// In ja, this message translates to:
  /// **'エラーが発生しました: {error}'**
  String qrScannerError(Object error);

  /// No description provided for @qrScannerNoQrInImage.
  ///
  /// In ja, this message translates to:
  /// **'画像からQRコードが見つかりませんでした'**
  String get qrScannerNoQrInImage;

  /// No description provided for @qrScannerScanLabel.
  ///
  /// In ja, this message translates to:
  /// **'QRコードをスキャン'**
  String get qrScannerScanLabel;

  /// No description provided for @qrScannerInstruction.
  ///
  /// In ja, this message translates to:
  /// **'枠内にQRコードを写してください'**
  String get qrScannerInstruction;

  /// No description provided for @qrScannerPickFromGallery.
  ///
  /// In ja, this message translates to:
  /// **'フォルダーから選択'**
  String get qrScannerPickFromGallery;

  /// No description provided for @qrDisplayTitle.
  ///
  /// In ja, this message translates to:
  /// **'QRコード'**
  String get qrDisplayTitle;

  /// No description provided for @qrDisplaySaved.
  ///
  /// In ja, this message translates to:
  /// **'QRコードを保存しました'**
  String get qrDisplaySaved;

  /// No description provided for @qrDisplaySaveFailed.
  ///
  /// In ja, this message translates to:
  /// **'保存に失敗しました: {error}'**
  String qrDisplaySaveFailed(Object error);

  /// No description provided for @qrDisplaySaving.
  ///
  /// In ja, this message translates to:
  /// **'保存中...'**
  String get qrDisplaySaving;

  /// No description provided for @qrDisplayDownload.
  ///
  /// In ja, this message translates to:
  /// **'ダウンロード'**
  String get qrDisplayDownload;

  /// No description provided for @pendingRequestsTitle.
  ///
  /// In ja, this message translates to:
  /// **'フォロー申請'**
  String get pendingRequestsTitle;

  /// No description provided for @pendingRequestsEmpty.
  ///
  /// In ja, this message translates to:
  /// **'申請はありません'**
  String get pendingRequestsEmpty;

  /// No description provided for @pendingRequestsAcceptFailed.
  ///
  /// In ja, this message translates to:
  /// **'承認に失敗しました: {error}'**
  String pendingRequestsAcceptFailed(Object error);

  /// No description provided for @pendingRequestsRejectFailed.
  ///
  /// In ja, this message translates to:
  /// **'拒否に失敗しました: {error}'**
  String pendingRequestsRejectFailed(Object error);

  /// No description provided for @pendingRequestsAccept.
  ///
  /// In ja, this message translates to:
  /// **'承認'**
  String get pendingRequestsAccept;

  /// No description provided for @pendingRequestsReject.
  ///
  /// In ja, this message translates to:
  /// **'拒否'**
  String get pendingRequestsReject;

  /// No description provided for @initialFriendTitle.
  ///
  /// In ja, this message translates to:
  /// **'フレンド登録'**
  String get initialFriendTitle;

  /// No description provided for @initialFriendSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'一緒に頑張る仲間を登録しよう！'**
  String get initialFriendSubtitle;

  /// No description provided for @initialFriendWhoInvited.
  ///
  /// In ja, this message translates to:
  /// **'誰に誘われましたか？'**
  String get initialFriendWhoInvited;

  /// No description provided for @initialFriendOtherUser.
  ///
  /// In ja, this message translates to:
  /// **'その他のユーザー：ユーザーIDを入力'**
  String get initialFriendOtherUser;

  /// No description provided for @initialFriendUserIdLabel.
  ///
  /// In ja, this message translates to:
  /// **'ユーザーID'**
  String get initialFriendUserIdLabel;

  /// No description provided for @initialFriendSentCount.
  ///
  /// In ja, this message translates to:
  /// **'{count}件のフレンドリクエストを送信しました！'**
  String initialFriendSentCount(int count);

  /// No description provided for @initialFriendSendFailed.
  ///
  /// In ja, this message translates to:
  /// **'送信に失敗しました。もう一度お試しください。'**
  String get initialFriendSendFailed;

  /// No description provided for @initialFriendRegister.
  ///
  /// In ja, this message translates to:
  /// **'登録する'**
  String get initialFriendRegister;

  /// No description provided for @initialFriendLater.
  ///
  /// In ja, this message translates to:
  /// **'あとで登録する'**
  String get initialFriendLater;

  /// No description provided for @emailVerificationTitle.
  ///
  /// In ja, this message translates to:
  /// **'メールアドレスの認証'**
  String get emailVerificationTitle;

  /// No description provided for @emailVerificationHeading.
  ///
  /// In ja, this message translates to:
  /// **'メールアドレスを認証してください'**
  String get emailVerificationHeading;

  /// No description provided for @emailVerificationSent.
  ///
  /// In ja, this message translates to:
  /// **'{email}\nに認証メールを送信しました。\nメール内のリンクをタップして認証を完了してください。'**
  String emailVerificationSent(String email);

  /// No description provided for @emailVerificationSpamNote.
  ///
  /// In ja, this message translates to:
  /// **'メールが届かない場合は、迷惑メールフォルダやゴミ箱をご確認ください。'**
  String get emailVerificationSpamNote;

  /// No description provided for @emailVerificationNotYet.
  ///
  /// In ja, this message translates to:
  /// **'まだ認証が完了していません。メールをご確認ください。'**
  String get emailVerificationNotYet;

  /// No description provided for @emailVerificationResendCooldown.
  ///
  /// In ja, this message translates to:
  /// **'{seconds}秒後に再送信できます。'**
  String emailVerificationResendCooldown(int seconds);

  /// No description provided for @emailVerificationResent.
  ///
  /// In ja, this message translates to:
  /// **'認証メールを再送信しました。'**
  String get emailVerificationResent;

  /// No description provided for @emailVerificationResendFailed.
  ///
  /// In ja, this message translates to:
  /// **'送信に失敗しました。しばらくしてからお試しください。'**
  String get emailVerificationResendFailed;

  /// No description provided for @emailVerificationConfirmButton.
  ///
  /// In ja, this message translates to:
  /// **'認証を確認'**
  String get emailVerificationConfirmButton;

  /// No description provided for @emailVerificationResendButton.
  ///
  /// In ja, this message translates to:
  /// **'認証メールを再送信'**
  String get emailVerificationResendButton;

  /// No description provided for @notificationSettingsTitle.
  ///
  /// In ja, this message translates to:
  /// **'通知設定'**
  String get notificationSettingsTitle;

  /// No description provided for @notificationSettingsSaveFailed.
  ///
  /// In ja, this message translates to:
  /// **'設定の保存に失敗しました'**
  String get notificationSettingsSaveFailed;

  /// No description provided for @notificationSettingsPush.
  ///
  /// In ja, this message translates to:
  /// **'プッシュ通知を許可'**
  String get notificationSettingsPush;

  /// No description provided for @notificationSettingsPushDesc.
  ///
  /// In ja, this message translates to:
  /// **'フォローや仲間の新しい投稿のお知らせ'**
  String get notificationSettingsPushDesc;

  /// No description provided for @notificationSettingsReaction.
  ///
  /// In ja, this message translates to:
  /// **'リアクション通知を許可'**
  String get notificationSettingsReaction;

  /// No description provided for @notificationSettingsReactionDesc.
  ///
  /// In ja, this message translates to:
  /// **'投稿にリアクションが届いたとき'**
  String get notificationSettingsReactionDesc;

  /// No description provided for @notificationSettingsVFire.
  ///
  /// In ja, this message translates to:
  /// **'V FIRE通知を許可'**
  String get notificationSettingsVFire;

  /// No description provided for @notificationSettingsVFireDesc.
  ///
  /// In ja, this message translates to:
  /// **'投稿にV FIREが届いたとき'**
  String get notificationSettingsVFireDesc;

  /// No description provided for @notificationSettingsShield.
  ///
  /// In ja, this message translates to:
  /// **'保護シールド通知を許可'**
  String get notificationSettingsShield;

  /// No description provided for @notificationSettingsShieldDesc.
  ///
  /// In ja, this message translates to:
  /// **'シールドによるストリーク維持のお知らせ'**
  String get notificationSettingsShieldDesc;

  /// No description provided for @notificationSettingsStreakWarning.
  ///
  /// In ja, this message translates to:
  /// **'ストリーク危機通知を許可'**
  String get notificationSettingsStreakWarning;

  /// No description provided for @notificationSettingsStreakWarningDesc.
  ///
  /// In ja, this message translates to:
  /// **'夜になってもタスクが完了していない時のリマインダー'**
  String get notificationSettingsStreakWarningDesc;

  /// No description provided for @notificationSettingsDebugTitle.
  ///
  /// In ja, this message translates to:
  /// **'開発者向けデバッグ機能'**
  String get notificationSettingsDebugTitle;

  /// No description provided for @notificationSettingsDebugResetTitle.
  ///
  /// In ja, this message translates to:
  /// **'通知プレ・ダイアログの表示フラグをリセット'**
  String get notificationSettingsDebugResetTitle;

  /// No description provided for @notificationSettingsDebugResetDesc.
  ///
  /// In ja, this message translates to:
  /// **'「一度のみ表示」の制限フラグを消去します'**
  String get notificationSettingsDebugResetDesc;

  /// No description provided for @notificationSettingsDebugResetDone.
  ///
  /// In ja, this message translates to:
  /// **'通知ダイアログ表示フラグをリセットしました。'**
  String get notificationSettingsDebugResetDone;

  /// No description provided for @notificationSettingsDebugTestTitle.
  ///
  /// In ja, this message translates to:
  /// **'通知プレ・ダイアログをテスト表示'**
  String get notificationSettingsDebugTestTitle;

  /// No description provided for @notificationSettingsDebugTestDesc.
  ///
  /// In ja, this message translates to:
  /// **'現在の通知許可状態に関わらずモーダルを表示します'**
  String get notificationSettingsDebugTestDesc;

  /// No description provided for @editProfileSettingsHeader.
  ///
  /// In ja, this message translates to:
  /// **'設定'**
  String get editProfileSettingsHeader;

  /// No description provided for @editProfileAccount.
  ///
  /// In ja, this message translates to:
  /// **'アカウント'**
  String get editProfileAccount;

  /// No description provided for @editProfileStatus.
  ///
  /// In ja, this message translates to:
  /// **'ステータス'**
  String get editProfileStatus;

  /// No description provided for @editProfileNameLabel.
  ///
  /// In ja, this message translates to:
  /// **'名前'**
  String get editProfileNameLabel;

  /// No description provided for @editProfileNameRequired.
  ///
  /// In ja, this message translates to:
  /// **'名前を入力してください'**
  String get editProfileNameRequired;

  /// No description provided for @editProfileUserIdLabel.
  ///
  /// In ja, this message translates to:
  /// **'ユーザーID'**
  String get editProfileUserIdLabel;

  /// No description provided for @editProfileUserIdRequired.
  ///
  /// In ja, this message translates to:
  /// **'ユーザーIDを入力してください'**
  String get editProfileUserIdRequired;

  /// No description provided for @editProfileUserIdMinLength.
  ///
  /// In ja, this message translates to:
  /// **'5文字以上で入力してください'**
  String get editProfileUserIdMinLength;

  /// No description provided for @editProfileUserIdAlphanumeric.
  ///
  /// In ja, this message translates to:
  /// **'英数字とアンダースコアのみ使えます'**
  String get editProfileUserIdAlphanumeric;

  /// No description provided for @editProfileInstagramIdAlphanumeric.
  ///
  /// In ja, this message translates to:
  /// **'英数字、アンダースコア、ドットのみ使えます'**
  String get editProfileInstagramIdAlphanumeric;

  /// No description provided for @editProfileWebsiteUrlInvalid.
  ///
  /// In ja, this message translates to:
  /// **'有効なURLを入力してください'**
  String get editProfileWebsiteUrlInvalid;

  /// No description provided for @editProfileWebsiteUrlLabel.
  ///
  /// In ja, this message translates to:
  /// **'ウェブサイト'**
  String get editProfileWebsiteUrlLabel;

  /// No description provided for @editProfileUserIdAlreadyUsed.
  ///
  /// In ja, this message translates to:
  /// **'このユーザーIDは既に使われています'**
  String get editProfileUserIdAlreadyUsed;

  /// No description provided for @editProfileRestrictionMessage.
  ///
  /// In ja, this message translates to:
  /// **'ユーザーIDは前回の変更から90日間変更できません。\nあと {days} 日お待ちください。'**
  String editProfileRestrictionMessage(int days);

  /// No description provided for @editProfileChangeRestriction.
  ///
  /// In ja, this message translates to:
  /// **'ユーザーIDの変更はあと {days} 日経過するまでできません。'**
  String editProfileChangeRestriction(int days);

  /// No description provided for @editProfileConfirmTitle.
  ///
  /// In ja, this message translates to:
  /// **'確認'**
  String get editProfileConfirmTitle;

  /// No description provided for @editProfileConfirmMessage.
  ///
  /// In ja, this message translates to:
  /// **'この変更を保存すると、ユーザーIDは今後90日間変更できなくなります。\n\n本当によろしいですか？'**
  String get editProfileConfirmMessage;

  /// No description provided for @editProfileCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get editProfileCancel;

  /// No description provided for @editProfileChange.
  ///
  /// In ja, this message translates to:
  /// **'変更'**
  String get editProfileChange;

  /// No description provided for @editProfileSave.
  ///
  /// In ja, this message translates to:
  /// **'保存'**
  String get editProfileSave;

  /// No description provided for @editProfileSaveFailed.
  ///
  /// In ja, this message translates to:
  /// **'保存に失敗しました: {error}'**
  String editProfileSaveFailed(Object error);

  /// No description provided for @editProfileBirthDate.
  ///
  /// In ja, this message translates to:
  /// **'生年月日 (任意)'**
  String get editProfileBirthDate;

  /// No description provided for @editProfileGender.
  ///
  /// In ja, this message translates to:
  /// **'性別 (任意)'**
  String get editProfileGender;

  /// No description provided for @editProfilePickerCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get editProfilePickerCancel;

  /// No description provided for @editProfilePickerDone.
  ///
  /// In ja, this message translates to:
  /// **'完了'**
  String get editProfilePickerDone;

  /// No description provided for @editProfileBirthDatePickerTitle.
  ///
  /// In ja, this message translates to:
  /// **'生年月日'**
  String get editProfileBirthDatePickerTitle;

  /// No description provided for @editProfileGenderPickerTitle.
  ///
  /// In ja, this message translates to:
  /// **'性別'**
  String get editProfileGenderPickerTitle;

  /// No description provided for @editProfileBadgeLabel.
  ///
  /// In ja, this message translates to:
  /// **'バッジ'**
  String get editProfileBadgeLabel;

  /// No description provided for @editProfileBadgeEquipped.
  ///
  /// In ja, this message translates to:
  /// **'装着中'**
  String get editProfileBadgeEquipped;

  /// No description provided for @editProfileBadgeNone.
  ///
  /// In ja, this message translates to:
  /// **'未設定'**
  String get editProfileBadgeNone;

  /// No description provided for @editProfileBadgeChange.
  ///
  /// In ja, this message translates to:
  /// **'変更'**
  String get editProfileBadgeChange;

  /// No description provided for @editProfileBadgeSelectTitle.
  ///
  /// In ja, this message translates to:
  /// **'バッジを選択'**
  String get editProfileBadgeSelectTitle;

  /// No description provided for @editProfileBadgeOptionNone.
  ///
  /// In ja, this message translates to:
  /// **'なし'**
  String get editProfileBadgeOptionNone;

  /// No description provided for @editProfileBadgeOptionTester.
  ///
  /// In ja, this message translates to:
  /// **'テスター'**
  String get editProfileBadgeOptionTester;

  /// No description provided for @editProfileBadgeOptionSeason.
  ///
  /// In ja, this message translates to:
  /// **'シーズンバッジ'**
  String get editProfileBadgeOptionSeason;

  /// No description provided for @editProfileImageAdjust.
  ///
  /// In ja, this message translates to:
  /// **'画像を調整'**
  String get editProfileImageAdjust;

  /// No description provided for @pastComparisonTitle.
  ///
  /// In ja, this message translates to:
  /// **'積み重ねを振りかえる'**
  String get pastComparisonTitle;

  /// No description provided for @pastComparisonSortOld.
  ///
  /// In ja, this message translates to:
  /// **'古い順にする'**
  String get pastComparisonSortOld;

  /// No description provided for @pastComparisonSortNew.
  ///
  /// In ja, this message translates to:
  /// **'新しい順にする'**
  String get pastComparisonSortNew;

  /// No description provided for @pastComparisonEmpty.
  ///
  /// In ja, this message translates to:
  /// **'まだ投稿がありません'**
  String get pastComparisonEmpty;

  /// No description provided for @pastComparisonTaskEmpty.
  ///
  /// In ja, this message translates to:
  /// **'このタスクの投稿はまだありません'**
  String get pastComparisonTaskEmpty;

  /// No description provided for @pastComparisonCompare.
  ///
  /// In ja, this message translates to:
  /// **'比較する'**
  String get pastComparisonCompare;

  /// No description provided for @pastComparisonSelectTwo.
  ///
  /// In ja, this message translates to:
  /// **'2枚選んでください'**
  String get pastComparisonSelectTwo;

  /// No description provided for @pastComparisonMode.
  ///
  /// In ja, this message translates to:
  /// **'選択モード'**
  String get pastComparisonMode;

  /// No description provided for @pastComparisonOther.
  ///
  /// In ja, this message translates to:
  /// **'その他'**
  String get pastComparisonOther;

  /// No description provided for @pastComparisonSelectMode.
  ///
  /// In ja, this message translates to:
  /// **'選択モード'**
  String get pastComparisonSelectMode;

  /// No description provided for @pastComparisonMoveTask.
  ///
  /// In ja, this message translates to:
  /// **'タスクを移動'**
  String get pastComparisonMoveTask;

  /// No description provided for @pastComparisonMoveConfirmTitle.
  ///
  /// In ja, this message translates to:
  /// **'タスクの移動'**
  String get pastComparisonMoveConfirmTitle;

  /// No description provided for @pastComparisonMoveConfirmBody.
  ///
  /// In ja, this message translates to:
  /// **'選択した{count}件の投稿を「{taskName}」に移動しますか？'**
  String pastComparisonMoveConfirmBody(int count, String taskName);

  /// No description provided for @pastComparisonMoveSuccess.
  ///
  /// In ja, this message translates to:
  /// **'{count}件の投稿を移動しました'**
  String pastComparisonMoveSuccess(int count);

  /// No description provided for @pastComparisonCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get pastComparisonCancel;

  /// No description provided for @sharePreviewTitle.
  ///
  /// In ja, this message translates to:
  /// **'プレビュー'**
  String get sharePreviewTitle;

  /// No description provided for @previewLabel.
  ///
  /// In ja, this message translates to:
  /// **'プレビュー'**
  String get previewLabel;

  /// No description provided for @sharePreviewShareText.
  ///
  /// In ja, this message translates to:
  /// **'今週も{count}回のヒーロータスクを完遂！\n現在のストリーク: {streak}日 🔥\n#VEffect'**
  String sharePreviewShareText(int count, int streak);

  /// No description provided for @sharePreviewFailed.
  ///
  /// In ja, this message translates to:
  /// **'シェアに失敗しました。もう一度お試しください。'**
  String get sharePreviewFailed;

  /// No description provided for @sharePreviewPreparing.
  ///
  /// In ja, this message translates to:
  /// **'準備中...'**
  String get sharePreviewPreparing;

  /// No description provided for @sharePreviewShareButton.
  ///
  /// In ja, this message translates to:
  /// **'SNSへシェア'**
  String get sharePreviewShareButton;

  /// No description provided for @heroTaskShareText.
  ///
  /// In ja, this message translates to:
  /// **'今日のヒーロータスクを完了しました！\n現在のストリーク: {streak}日 🔥\n#VEffect'**
  String heroTaskShareText(int streak);

  /// No description provided for @searchHint.
  ///
  /// In ja, this message translates to:
  /// **'IDまたは名前を検索'**
  String get searchHint;

  /// No description provided for @searchKeywordPrompt.
  ///
  /// In ja, this message translates to:
  /// **'検索キーワードを入力してください'**
  String get searchKeywordPrompt;

  /// No description provided for @searchNoResults.
  ///
  /// In ja, this message translates to:
  /// **'ユーザーが見つかりませんでした'**
  String get searchNoResults;

  /// No description provided for @searchError.
  ///
  /// In ja, this message translates to:
  /// **'検索エラー:\n{error}'**
  String searchError(Object error);

  /// No description provided for @searchUnfollowed.
  ///
  /// In ja, this message translates to:
  /// **'{username}さんのフォローを解除しました'**
  String searchUnfollowed(String username);

  /// No description provided for @searchFollowRequestSent.
  ///
  /// In ja, this message translates to:
  /// **'{username}さんにフォローリクエストを送りました'**
  String searchFollowRequestSent(String username);

  /// No description provided for @searchActionFailed.
  ///
  /// In ja, this message translates to:
  /// **'操作に失敗しました: {error}'**
  String searchActionFailed(Object error);

  /// No description provided for @searchFollowing.
  ///
  /// In ja, this message translates to:
  /// **'フォロー中'**
  String get searchFollowing;

  /// No description provided for @searchPending.
  ///
  /// In ja, this message translates to:
  /// **'申請中'**
  String get searchPending;

  /// No description provided for @searchFollow.
  ///
  /// In ja, this message translates to:
  /// **'フォロー'**
  String get searchFollow;

  /// No description provided for @securitySettingsTitle.
  ///
  /// In ja, this message translates to:
  /// **'パスワードとセキュリティ'**
  String get securitySettingsTitle;

  /// No description provided for @securityLoginRecoveryTitle.
  ///
  /// In ja, this message translates to:
  /// **'ログインとリカバリー'**
  String get securityLoginRecoveryTitle;

  /// No description provided for @securityLoginRecoveryDesc.
  ///
  /// In ja, this message translates to:
  /// **'パスワード、ログイン設定、リカバリー方法を管理できます。'**
  String get securityLoginRecoveryDesc;

  /// No description provided for @securityChangePassword.
  ///
  /// In ja, this message translates to:
  /// **'パスワードを変更'**
  String get securityChangePassword;

  /// No description provided for @securityChangeEmail.
  ///
  /// In ja, this message translates to:
  /// **'メールアドレスを変更'**
  String get securityChangeEmail;

  /// No description provided for @securityVerifyEmail.
  ///
  /// In ja, this message translates to:
  /// **'メールアドレスを認証する'**
  String get securityVerifyEmail;

  /// No description provided for @securityAccountManagementTitle.
  ///
  /// In ja, this message translates to:
  /// **'アカウント管理'**
  String get securityAccountManagementTitle;

  /// No description provided for @securityAccountManagementDesc.
  ///
  /// In ja, this message translates to:
  /// **'アプリへのアクセスやアカウントのデータに関する設定を行います。'**
  String get securityAccountManagementDesc;

  /// No description provided for @securityLogout.
  ///
  /// In ja, this message translates to:
  /// **'ログアウト'**
  String get securityLogout;

  /// No description provided for @securityDeleteAccount.
  ///
  /// In ja, this message translates to:
  /// **'アカウントを削除'**
  String get securityDeleteAccount;

  /// No description provided for @securityLinkedAccounts.
  ///
  /// In ja, this message translates to:
  /// **'連携済みのアカウント'**
  String get securityLinkedAccounts;

  /// No description provided for @securityNoLinkedAccounts.
  ///
  /// In ja, this message translates to:
  /// **'なし'**
  String get securityNoLinkedAccounts;

  /// No description provided for @securityProviderEmail.
  ///
  /// In ja, this message translates to:
  /// **'メールアドレス'**
  String get securityProviderEmail;

  /// No description provided for @securityChangePasswordDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'パスワードを変更'**
  String get securityChangePasswordDialogTitle;

  /// No description provided for @securityChangePasswordDialogDesc.
  ///
  /// In ja, this message translates to:
  /// **'{email} 宛にパスワード再設定用のメールを送信しますか？'**
  String securityChangePasswordDialogDesc(String email);

  /// No description provided for @securityChangePasswordCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get securityChangePasswordCancel;

  /// No description provided for @securityChangePasswordSend.
  ///
  /// In ja, this message translates to:
  /// **'送信'**
  String get securityChangePasswordSend;

  /// No description provided for @securityPasswordResetSent.
  ///
  /// In ja, this message translates to:
  /// **'再設定メールを送信しました。メールをご確認ください。'**
  String get securityPasswordResetSent;

  /// No description provided for @securityChangeEmailDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'メールアドレスを変更'**
  String get securityChangeEmailDialogTitle;

  /// No description provided for @securityChangeEmailDialogDesc.
  ///
  /// In ja, this message translates to:
  /// **'新しいメールアドレスを入力してください。確認メールを送信します。'**
  String get securityChangeEmailDialogDesc;

  /// No description provided for @securityNewEmailLabel.
  ///
  /// In ja, this message translates to:
  /// **'新しいメールアドレス'**
  String get securityNewEmailLabel;

  /// No description provided for @securityChangeEmailSend.
  ///
  /// In ja, this message translates to:
  /// **'確認メールを送信'**
  String get securityChangeEmailSend;

  /// No description provided for @securityEmailVerificationSent.
  ///
  /// In ja, this message translates to:
  /// **'新しいアドレスに確認メールを送信しました。リンクをタップして変更を完了してください。'**
  String get securityEmailVerificationSent;

  /// No description provided for @securityErrorGeneric.
  ///
  /// In ja, this message translates to:
  /// **'エラーが発生しました。'**
  String get securityErrorGeneric;

  /// No description provided for @securityErrorRecentLogin.
  ///
  /// In ja, this message translates to:
  /// **'セキュリティのため、一度ログアウトして再度ログインしてからやり直してください。'**
  String get securityErrorRecentLogin;

  /// No description provided for @securityErrorInvalidEmail.
  ///
  /// In ja, this message translates to:
  /// **'無効なメールアドレスです。'**
  String get securityErrorInvalidEmail;

  /// No description provided for @securityErrorEmailInUse.
  ///
  /// In ja, this message translates to:
  /// **'このメールアドレスは既に登録されています。'**
  String get securityErrorEmailInUse;

  /// No description provided for @securityLogoutConfirmTitle.
  ///
  /// In ja, this message translates to:
  /// **'ログアウト'**
  String get securityLogoutConfirmTitle;

  /// No description provided for @securityLogoutConfirmMessage.
  ///
  /// In ja, this message translates to:
  /// **'本当にログアウトしますか？'**
  String get securityLogoutConfirmMessage;

  /// No description provided for @securityLogoutConfirmCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get securityLogoutConfirmCancel;

  /// No description provided for @securityLogoutConfirmButton.
  ///
  /// In ja, this message translates to:
  /// **'ログアウト'**
  String get securityLogoutConfirmButton;

  /// No description provided for @securityDeleteConfirmTitle.
  ///
  /// In ja, this message translates to:
  /// **'アカウントを削除しますか？'**
  String get securityDeleteConfirmTitle;

  /// No description provided for @securityDeleteConfirmDesc.
  ///
  /// In ja, this message translates to:
  /// **'プロフィール・投稿などすべてのデータが完全に削除されます。この操作は取り消せません。'**
  String get securityDeleteConfirmDesc;

  /// No description provided for @securityDeleteConfirmCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get securityDeleteConfirmCancel;

  /// No description provided for @securityDeleteConfirmButton.
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get securityDeleteConfirmButton;

  /// No description provided for @securityDeleteFinalTitle.
  ///
  /// In ja, this message translates to:
  /// **'本当に削除しますか？'**
  String get securityDeleteFinalTitle;

  /// No description provided for @securityDeleteFinalDesc.
  ///
  /// In ja, this message translates to:
  /// **'この操作は元に戻せません。アカウントを完全に削除してよろしいですか？'**
  String get securityDeleteFinalDesc;

  /// No description provided for @securityDeleteFinalCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get securityDeleteFinalCancel;

  /// No description provided for @securityDeleteFinalButton.
  ///
  /// In ja, this message translates to:
  /// **'完全に削除する'**
  String get securityDeleteFinalButton;

  /// No description provided for @securityDeleteFailed.
  ///
  /// In ja, this message translates to:
  /// **'アカウントの削除に失敗しました。再ログインして再度お試しください。'**
  String get securityDeleteFailed;

  /// No description provided for @userProfileNotFound.
  ///
  /// In ja, this message translates to:
  /// **'ユーザーが見つかりません'**
  String get userProfileNotFound;

  /// No description provided for @userProfileFollowing.
  ///
  /// In ja, this message translates to:
  /// **'フォロー中'**
  String get userProfileFollowing;

  /// No description provided for @userProfileFollowers.
  ///
  /// In ja, this message translates to:
  /// **'フォロワー'**
  String get userProfileFollowers;

  /// No description provided for @userProfileStreak.
  ///
  /// In ja, this message translates to:
  /// **'ストリーク'**
  String get userProfileStreak;

  /// No description provided for @userProfileFollowRequest.
  ///
  /// In ja, this message translates to:
  /// **'フォローをリクエスト'**
  String get userProfileFollowRequest;

  /// No description provided for @userProfilePending.
  ///
  /// In ja, this message translates to:
  /// **'申請中'**
  String get userProfilePending;

  /// No description provided for @userProfileHeroTasks.
  ///
  /// In ja, this message translates to:
  /// **'ヒーロータスク'**
  String get userProfileHeroTasks;

  /// No description provided for @userProfileBlock.
  ///
  /// In ja, this message translates to:
  /// **'ブロック'**
  String get userProfileBlock;

  /// No description provided for @userProfileUnblock.
  ///
  /// In ja, this message translates to:
  /// **'ブロックを解除'**
  String get userProfileUnblock;

  /// No description provided for @userProfileReport.
  ///
  /// In ja, this message translates to:
  /// **'通報'**
  String get userProfileReport;

  /// No description provided for @userProfileBlockConfirmTitle.
  ///
  /// In ja, this message translates to:
  /// **'ブロック'**
  String get userProfileBlockConfirmTitle;

  /// No description provided for @userProfileBlockConfirmDesc.
  ///
  /// In ja, this message translates to:
  /// **'このユーザーをブロックします。フォロー関係も解除されます。'**
  String get userProfileBlockConfirmDesc;

  /// No description provided for @userProfileBlockCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get userProfileBlockCancel;

  /// No description provided for @userProfileBlockButton.
  ///
  /// In ja, this message translates to:
  /// **'ブロック'**
  String get userProfileBlockButton;

  /// No description provided for @userProfileUnblockConfirmTitle.
  ///
  /// In ja, this message translates to:
  /// **'ブロックを解除'**
  String get userProfileUnblockConfirmTitle;

  /// No description provided for @userProfileUnblockConfirmDesc.
  ///
  /// In ja, this message translates to:
  /// **'このユーザーのブロックを解除しますか？'**
  String get userProfileUnblockConfirmDesc;

  /// No description provided for @userProfileUnblockCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get userProfileUnblockCancel;

  /// No description provided for @userProfileUnblockButton.
  ///
  /// In ja, this message translates to:
  /// **'解除する'**
  String get userProfileUnblockButton;

  /// No description provided for @userProfileBlockFailed.
  ///
  /// In ja, this message translates to:
  /// **'ブロックに失敗しました'**
  String get userProfileBlockFailed;

  /// No description provided for @userProfileUnblockFailed.
  ///
  /// In ja, this message translates to:
  /// **'ブロック解除に失敗しました'**
  String get userProfileUnblockFailed;

  /// No description provided for @userProfileReportTitle.
  ///
  /// In ja, this message translates to:
  /// **'通報する理由を選択'**
  String get userProfileReportTitle;

  /// No description provided for @userProfileReportSpam.
  ///
  /// In ja, this message translates to:
  /// **'スパム'**
  String get userProfileReportSpam;

  /// No description provided for @userProfileReportHarassment.
  ///
  /// In ja, this message translates to:
  /// **'ハラスメント'**
  String get userProfileReportHarassment;

  /// No description provided for @userProfileReportInappropriate.
  ///
  /// In ja, this message translates to:
  /// **'不適切なコンテンツ'**
  String get userProfileReportInappropriate;

  /// No description provided for @userProfileReportOther.
  ///
  /// In ja, this message translates to:
  /// **'その他'**
  String get userProfileReportOther;

  /// No description provided for @userProfileReportCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get userProfileReportCancel;

  /// No description provided for @userProfileReportDone.
  ///
  /// In ja, this message translates to:
  /// **'通報しました。ご協力ありがとうございます。'**
  String get userProfileReportDone;

  /// No description provided for @userProfileReportAlready.
  ///
  /// In ja, this message translates to:
  /// **'7日以内に同じユーザーへの通報があります'**
  String get userProfileReportAlready;

  /// No description provided for @userProfileReportFailed.
  ///
  /// In ja, this message translates to:
  /// **'通報に失敗しました'**
  String get userProfileReportFailed;

  /// No description provided for @userProfileFollowFailed.
  ///
  /// In ja, this message translates to:
  /// **'フォローリクエストを送信できませんでした'**
  String get userProfileFollowFailed;

  /// No description provided for @blogPostDetailDeleteTitle.
  ///
  /// In ja, this message translates to:
  /// **'記事を削除しますか？'**
  String get blogPostDetailDeleteTitle;

  /// No description provided for @blogPostDetailDeleteDesc.
  ///
  /// In ja, this message translates to:
  /// **'この操作は取り消せません。'**
  String get blogPostDetailDeleteDesc;

  /// No description provided for @blogPostDetailDeleteCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get blogPostDetailDeleteCancel;

  /// No description provided for @blogPostDetailDeleteButton.
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get blogPostDetailDeleteButton;

  /// No description provided for @blogPostEditorUpdateButton.
  ///
  /// In ja, this message translates to:
  /// **'更新'**
  String get blogPostEditorUpdateButton;

  /// No description provided for @blogPostEditorPostButton.
  ///
  /// In ja, this message translates to:
  /// **'投稿'**
  String get blogPostEditorPostButton;

  /// No description provided for @blogPostEditorArticleUpdate.
  ///
  /// In ja, this message translates to:
  /// **'記事を更新する'**
  String get blogPostEditorArticleUpdate;

  /// No description provided for @blogPostEditorArticlePost.
  ///
  /// In ja, this message translates to:
  /// **'記事を投稿する'**
  String get blogPostEditorArticlePost;

  /// No description provided for @blogPostEditorCategoryLabel.
  ///
  /// In ja, this message translates to:
  /// **'カテゴリ'**
  String get blogPostEditorCategoryLabel;

  /// No description provided for @blogPostEditorPinLabel.
  ///
  /// In ja, this message translates to:
  /// **'この記事をピン留めする'**
  String get blogPostEditorPinLabel;

  /// No description provided for @blogPostEditorTitleLabel.
  ///
  /// In ja, this message translates to:
  /// **'タイトル'**
  String get blogPostEditorTitleLabel;

  /// No description provided for @blogPostEditorTitleHint.
  ///
  /// In ja, this message translates to:
  /// **'タイトルを入力'**
  String get blogPostEditorTitleHint;

  /// No description provided for @blogPostEditorTitleEnLabel.
  ///
  /// In ja, this message translates to:
  /// **'タイトル (ENGLISH)'**
  String get blogPostEditorTitleEnLabel;

  /// No description provided for @blogPostEditorBodyLabel.
  ///
  /// In ja, this message translates to:
  /// **'本文'**
  String get blogPostEditorBodyLabel;

  /// No description provided for @blogPostEditorBodyMarkdown.
  ///
  /// In ja, this message translates to:
  /// **'— Markdownが使えます'**
  String get blogPostEditorBodyMarkdown;

  /// No description provided for @blogPostEditorBodyHint.
  ///
  /// In ja, this message translates to:
  /// **'本文を入力\n\n## 見出し\n**太字** *斜体*\n- 箇条書き'**
  String get blogPostEditorBodyHint;

  /// No description provided for @blogPostEditorBodyEnLabel.
  ///
  /// In ja, this message translates to:
  /// **'本文 (ENGLISH)'**
  String get blogPostEditorBodyEnLabel;

  /// No description provided for @blogPostEditorRequiredError.
  ///
  /// In ja, this message translates to:
  /// **'タイトルと本文を入力してください'**
  String get blogPostEditorRequiredError;

  /// No description provided for @blogPostEditorSaveError.
  ///
  /// In ja, this message translates to:
  /// **'エラー: {error}'**
  String blogPostEditorSaveError(Object error);

  /// No description provided for @blogPostEditorPreviewEmpty.
  ///
  /// In ja, this message translates to:
  /// **'タイトルと本文を入力してください'**
  String get blogPostEditorPreviewEmpty;

  /// No description provided for @blogPostEditorCoverAdd.
  ///
  /// In ja, this message translates to:
  /// **'カバー画像を追加'**
  String get blogPostEditorCoverAdd;

  /// No description provided for @blogPostEditorCoverChange.
  ///
  /// In ja, this message translates to:
  /// **'カバー画像を変更'**
  String get blogPostEditorCoverChange;

  /// No description provided for @blogPostEditorSeasonNotSet.
  ///
  /// In ja, this message translates to:
  /// **'シーズンタスクを設定する'**
  String get blogPostEditorSeasonNotSet;

  /// No description provided for @blogPostEditorSeasonSet.
  ///
  /// In ja, this message translates to:
  /// **'シーズンタスク設定済み'**
  String get blogPostEditorSeasonSet;

  /// No description provided for @blogPostEditorSeasonDesc.
  ///
  /// In ja, this message translates to:
  /// **'このお知らせと一緒にシーズンタスクを配布・通知します。'**
  String get blogPostEditorSeasonDesc;

  /// No description provided for @blogPostEditorSeasonModalTitle.
  ///
  /// In ja, this message translates to:
  /// **'シーズンタスクの設定'**
  String get blogPostEditorSeasonModalTitle;

  /// No description provided for @blogPostEditorSeasonTaskName.
  ///
  /// In ja, this message translates to:
  /// **'タスク名 (必須)'**
  String get blogPostEditorSeasonTaskName;

  /// No description provided for @blogPostEditorSeasonDuration.
  ///
  /// In ja, this message translates to:
  /// **'実施期間(日数)'**
  String get blogPostEditorSeasonDuration;

  /// No description provided for @blogPostEditorSeasonHintTitle.
  ///
  /// In ja, this message translates to:
  /// **'ヒントタイトル'**
  String get blogPostEditorSeasonHintTitle;

  /// No description provided for @blogPostEditorSeasonHintBody.
  ///
  /// In ja, this message translates to:
  /// **'ヒント本文'**
  String get blogPostEditorSeasonHintBody;

  /// No description provided for @blogPostEditorSeasonHintBodyHint.
  ///
  /// In ja, this message translates to:
  /// **'ユーザーが写真を撮る際のヒントを入力してください'**
  String get blogPostEditorSeasonHintBodyHint;

  /// No description provided for @blogPostEditorSeasonRequiredCount.
  ///
  /// In ja, this message translates to:
  /// **'目標アクション数'**
  String get blogPostEditorSeasonRequiredCount;

  /// No description provided for @blogPostEditorSeasonRequiredCountHint.
  ///
  /// In ja, this message translates to:
  /// **'例: 1'**
  String get blogPostEditorSeasonRequiredCountHint;

  /// No description provided for @blogPostEditorSeasonBadgeUrl.
  ///
  /// In ja, this message translates to:
  /// **'バッジアイコン'**
  String get blogPostEditorSeasonBadgeUrl;

  /// No description provided for @blogPostEditorSeasonDone.
  ///
  /// In ja, this message translates to:
  /// **'完了'**
  String get blogPostEditorSeasonDone;

  /// No description provided for @blogPostEditorPlaceholder.
  ///
  /// In ja, this message translates to:
  /// **'テキスト'**
  String get blogPostEditorPlaceholder;

  /// No description provided for @blogPostEditorCodePlaceholder.
  ///
  /// In ja, this message translates to:
  /// **'コードをここに入力'**
  String get blogPostEditorCodePlaceholder;

  /// No description provided for @blogPostEditorBadgeUploadSuccess.
  ///
  /// In ja, this message translates to:
  /// **'バッジ画像をアップロードしました'**
  String get blogPostEditorBadgeUploadSuccess;

  /// No description provided for @blogPostEditorBadgeUploadFailed.
  ///
  /// In ja, this message translates to:
  /// **'アップロードに失敗しました'**
  String get blogPostEditorBadgeUploadFailed;

  /// No description provided for @blogPostEditorSchedulePublish.
  ///
  /// In ja, this message translates to:
  /// **'予約投稿を設定する'**
  String get blogPostEditorSchedulePublish;

  /// No description provided for @blogPostEditorPublishAtLabel.
  ///
  /// In ja, this message translates to:
  /// **'公開日時'**
  String get blogPostEditorPublishAtLabel;

  /// No description provided for @blogPostEditorPublishAtHint.
  ///
  /// In ja, this message translates to:
  /// **'公開日時を選択'**
  String get blogPostEditorPublishAtHint;

  /// No description provided for @blogPostEditorClearSchedule.
  ///
  /// In ja, this message translates to:
  /// **'予約を解除'**
  String get blogPostEditorClearSchedule;

  /// No description provided for @taskSetupTitle.
  ///
  /// In ja, this message translates to:
  /// **'ヒーロータスク設定'**
  String get taskSetupTitle;

  /// No description provided for @taskSetupSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'ヒーロータスクとスケジュールをカスタマイズしましょう'**
  String get taskSetupSubtitle;

  /// No description provided for @taskSetupProfilePhoto.
  ///
  /// In ja, this message translates to:
  /// **'プロフィール写真'**
  String get taskSetupProfilePhoto;

  /// No description provided for @taskSetupSelectPhoto.
  ///
  /// In ja, this message translates to:
  /// **'写真を選択'**
  String get taskSetupSelectPhoto;

  /// No description provided for @taskSetupHeroTasks.
  ///
  /// In ja, this message translates to:
  /// **'やりたいヒーロータスク'**
  String get taskSetupHeroTasks;

  /// No description provided for @taskSetupHeroTaskLabel.
  ///
  /// In ja, this message translates to:
  /// **'ヒーロータスク {index}'**
  String taskSetupHeroTaskLabel(int index);

  /// No description provided for @taskSetupAddTask.
  ///
  /// In ja, this message translates to:
  /// **'ヒーロータスクを追加'**
  String get taskSetupAddTask;

  /// No description provided for @taskSetupTimeSection.
  ///
  /// In ja, this message translates to:
  /// **'ヒーロータスクをいつやりたいですか？'**
  String get taskSetupTimeSection;

  /// No description provided for @taskSetupTimeDesc.
  ///
  /// In ja, this message translates to:
  /// **'この時間に通知を送ってヒーロータスクをリマインドします'**
  String get taskSetupTimeDesc;

  /// No description provided for @taskSetupCompleteButton.
  ///
  /// In ja, this message translates to:
  /// **'設定を完了してはじめる'**
  String get taskSetupCompleteButton;

  /// No description provided for @taskSetupAtLeastOne.
  ///
  /// In ja, this message translates to:
  /// **'ヒーロータスクを1つ以上入力してください'**
  String get taskSetupAtLeastOne;

  /// No description provided for @taskSetupSaveFailed.
  ///
  /// In ja, this message translates to:
  /// **'保存に失敗しました。もう一度お試しください。'**
  String get taskSetupSaveFailed;

  /// No description provided for @taskSetupTimePickerTitle.
  ///
  /// In ja, this message translates to:
  /// **'ヒーロータスクの時間'**
  String get taskSetupTimePickerTitle;

  /// No description provided for @taskSetupTimePickerCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get taskSetupTimePickerCancel;

  /// No description provided for @taskSetupTimePickerDone.
  ///
  /// In ja, this message translates to:
  /// **'完了'**
  String get taskSetupTimePickerDone;

  /// No description provided for @taskTemplateTitle.
  ///
  /// In ja, this message translates to:
  /// **'まずは一つ、やってみよう！'**
  String get taskTemplateTitle;

  /// No description provided for @taskTemplateSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'かんたんなヒーロータスクを選んで\nアプリをはじめましょう'**
  String get taskTemplateSubtitle;

  /// No description provided for @taskTemplateSkip.
  ///
  /// In ja, this message translates to:
  /// **'スキップ'**
  String get taskTemplateSkip;

  /// No description provided for @taskTemplateStartButton.
  ///
  /// In ja, this message translates to:
  /// **'アプリをはじめる'**
  String get taskTemplateStartButton;

  /// No description provided for @taskTemplateCustomInputLabel.
  ///
  /// In ja, this message translates to:
  /// **'ヒーロータスク名を入力'**
  String get taskTemplateCustomInputLabel;

  /// No description provided for @taskTemplateError.
  ///
  /// In ja, this message translates to:
  /// **'エラーが発生しました。もう一度お試しください。'**
  String get taskTemplateError;

  /// No description provided for @profileSetupTitle.
  ///
  /// In ja, this message translates to:
  /// **'プロフィール設定'**
  String get profileSetupTitle;

  /// No description provided for @profileSetupSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'あなたのプロフィールを設定しましょう'**
  String get profileSetupSubtitle;

  /// No description provided for @profileSetupUsernameLabel.
  ///
  /// In ja, this message translates to:
  /// **'ユーザー名'**
  String get profileSetupUsernameLabel;

  /// No description provided for @profileSetupUsernameRequired.
  ///
  /// In ja, this message translates to:
  /// **'ユーザー名を入力してください'**
  String get profileSetupUsernameRequired;

  /// No description provided for @profileSetupUserIdLabel.
  ///
  /// In ja, this message translates to:
  /// **'ユーザーID'**
  String get profileSetupUserIdLabel;

  /// No description provided for @profileSetupUserIdRequired.
  ///
  /// In ja, this message translates to:
  /// **'ユーザーIDを入力してください'**
  String get profileSetupUserIdRequired;

  /// No description provided for @profileSetupUserIdMinLength.
  ///
  /// In ja, this message translates to:
  /// **'5文字以上で入力してください'**
  String get profileSetupUserIdMinLength;

  /// No description provided for @profileSetupUserIdAlphanumeric.
  ///
  /// In ja, this message translates to:
  /// **'英数字とアンダースコアのみ使えます'**
  String get profileSetupUserIdAlphanumeric;

  /// No description provided for @profileSetupOccupationSection.
  ///
  /// In ja, this message translates to:
  /// **'職業（非公開情報）'**
  String get profileSetupOccupationSection;

  /// No description provided for @profileSetupSelectPlaceholder.
  ///
  /// In ja, this message translates to:
  /// **'選択してください'**
  String get profileSetupSelectPlaceholder;

  /// No description provided for @profileSetupOccupationPickerTitle.
  ///
  /// In ja, this message translates to:
  /// **'職業を選択'**
  String get profileSetupOccupationPickerTitle;

  /// No description provided for @profileSetupNextButton.
  ///
  /// In ja, this message translates to:
  /// **'次へ'**
  String get profileSetupNextButton;

  /// No description provided for @profileSetupUserIdAlreadyUsed.
  ///
  /// In ja, this message translates to:
  /// **'このユーザーIDは既に使われています'**
  String get profileSetupUserIdAlreadyUsed;

  /// No description provided for @profileSetupOccupationRequired.
  ///
  /// In ja, this message translates to:
  /// **'職業を選択してください'**
  String get profileSetupOccupationRequired;

  /// No description provided for @profileSetupSaveFailed.
  ///
  /// In ja, this message translates to:
  /// **'保存に失敗しました。もう一度お試しください。'**
  String get profileSetupSaveFailed;

  /// No description provided for @profileSetupPickerCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get profileSetupPickerCancel;

  /// No description provided for @profileSetupPickerDone.
  ///
  /// In ja, this message translates to:
  /// **'完了'**
  String get profileSetupPickerDone;

  /// No description provided for @profileScreenProfileNotFound.
  ///
  /// In ja, this message translates to:
  /// **'プロフィールが見つかりません'**
  String get profileScreenProfileNotFound;

  /// No description provided for @profileScreenHeroTasks.
  ///
  /// In ja, this message translates to:
  /// **'ヒーロータスク'**
  String get profileScreenHeroTasks;

  /// No description provided for @profileScreenWeeklyTrend.
  ///
  /// In ja, this message translates to:
  /// **'📈 ウィークリートレンド習慣'**
  String get profileScreenWeeklyTrend;

  /// No description provided for @profileScreenAddFirstTask.
  ///
  /// In ja, this message translates to:
  /// **'最初のタスクを追加'**
  String get profileScreenAddFirstTask;

  /// No description provided for @profileScreenQrTitle.
  ///
  /// In ja, this message translates to:
  /// **'QRコード'**
  String get profileScreenQrTitle;

  /// No description provided for @profileScreenQrDisplay.
  ///
  /// In ja, this message translates to:
  /// **'表示する'**
  String get profileScreenQrDisplay;

  /// No description provided for @profileScreenQrScan.
  ///
  /// In ja, this message translates to:
  /// **'読み取る'**
  String get profileScreenQrScan;

  /// No description provided for @profileScreenQrTooltip.
  ///
  /// In ja, this message translates to:
  /// **'QRコードで繋がる'**
  String get profileScreenQrTooltip;

  /// No description provided for @profileScreenFollowing.
  ///
  /// In ja, this message translates to:
  /// **'フォロー'**
  String get profileScreenFollowing;

  /// No description provided for @profileScreenFollowers.
  ///
  /// In ja, this message translates to:
  /// **'フォロワー'**
  String get profileScreenFollowers;

  /// No description provided for @profileScreenStreak.
  ///
  /// In ja, this message translates to:
  /// **'ストリーク'**
  String get profileScreenStreak;

  /// No description provided for @profileScreenTotalV.
  ///
  /// In ja, this message translates to:
  /// **'トータルV'**
  String get profileScreenTotalV;

  /// No description provided for @profileScreenCurrentRank.
  ///
  /// In ja, this message translates to:
  /// **'現在のランク'**
  String get profileScreenCurrentRank;

  /// No description provided for @profileScreenNextRank.
  ///
  /// In ja, this message translates to:
  /// **'次のランク'**
  String get profileScreenNextRank;

  /// No description provided for @profileScreenStreakProgress.
  ///
  /// In ja, this message translates to:
  /// **'進捗状況'**
  String get profileScreenStreakProgress;

  /// No description provided for @profileScreenStreakDays.
  ///
  /// In ja, this message translates to:
  /// **'{count}日連続'**
  String profileScreenStreakDays(int count);

  /// No description provided for @profileScreenStreakProgressValue.
  ///
  /// In ja, this message translates to:
  /// **'{streak} / {threshold} 日'**
  String profileScreenStreakProgressValue(int streak, int threshold);

  /// No description provided for @profileScreenStreakMax.
  ///
  /// In ja, this message translates to:
  /// **'最大'**
  String get profileScreenStreakMax;

  /// No description provided for @tierIron.
  ///
  /// In ja, this message translates to:
  /// **'アイアン'**
  String get tierIron;

  /// No description provided for @tierBronze.
  ///
  /// In ja, this message translates to:
  /// **'ブロンズ'**
  String get tierBronze;

  /// No description provided for @tierSilver.
  ///
  /// In ja, this message translates to:
  /// **'シルバー'**
  String get tierSilver;

  /// No description provided for @tierGold.
  ///
  /// In ja, this message translates to:
  /// **'ゴールド'**
  String get tierGold;

  /// No description provided for @tierPlatinum.
  ///
  /// In ja, this message translates to:
  /// **'プラチナ'**
  String get tierPlatinum;

  /// No description provided for @tierEmerald.
  ///
  /// In ja, this message translates to:
  /// **'エメラルド'**
  String get tierEmerald;

  /// No description provided for @tierDiamond.
  ///
  /// In ja, this message translates to:
  /// **'ダイヤモンド'**
  String get tierDiamond;

  /// No description provided for @tierMaster.
  ///
  /// In ja, this message translates to:
  /// **'マスター'**
  String get tierMaster;

  /// No description provided for @tierGrandmaster.
  ///
  /// In ja, this message translates to:
  /// **'グランドマスター'**
  String get tierGrandmaster;

  /// No description provided for @tierChallenger.
  ///
  /// In ja, this message translates to:
  /// **'チャレンジャー'**
  String get tierChallenger;

  /// No description provided for @profileScreenFollowingTitle.
  ///
  /// In ja, this message translates to:
  /// **'フォロー中'**
  String get profileScreenFollowingTitle;

  /// No description provided for @profileScreenFollowersTitle.
  ///
  /// In ja, this message translates to:
  /// **'フォロワー'**
  String get profileScreenFollowersTitle;

  /// No description provided for @profileScreenTrendTitle.
  ///
  /// In ja, this message translates to:
  /// **'📈 ウィークリートレンド習慣'**
  String get profileScreenTrendTitle;

  /// No description provided for @profileScreenTrendEmpty.
  ///
  /// In ja, this message translates to:
  /// **'トレンドデータがまだありません。'**
  String get profileScreenTrendEmpty;

  /// No description provided for @profileScreenTimeUpdateFailed.
  ///
  /// In ja, this message translates to:
  /// **'時刻の更新に失敗しました'**
  String get profileScreenTimeUpdateFailed;

  /// No description provided for @profileScreenReviewButton.
  ///
  /// In ja, this message translates to:
  /// **'積み重ねを振りかえる'**
  String get profileScreenReviewButton;

  /// No description provided for @profileScreenAddTask.
  ///
  /// In ja, this message translates to:
  /// **'タスクを追加'**
  String get profileScreenAddTask;

  /// No description provided for @profileScreenEditTask.
  ///
  /// In ja, this message translates to:
  /// **'タスクを編集'**
  String get profileScreenEditTask;

  /// No description provided for @profileScreenDeleteTaskTitle.
  ///
  /// In ja, this message translates to:
  /// **'削除の確認'**
  String get profileScreenDeleteTaskTitle;

  /// No description provided for @profileScreenDeleteTaskMessage.
  ///
  /// In ja, this message translates to:
  /// **'このタスクを削除しますか？'**
  String get profileScreenDeleteTaskMessage;

  /// No description provided for @profileScreenDeleteTaskCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get profileScreenDeleteTaskCancel;

  /// No description provided for @profileScreenDeleteTaskButton.
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get profileScreenDeleteTaskButton;

  /// No description provided for @profileScreenSaveTask.
  ///
  /// In ja, this message translates to:
  /// **'保存'**
  String get profileScreenSaveTask;

  /// No description provided for @profileScreenTaskTriggerHint.
  ///
  /// In ja, this message translates to:
  /// **'トリガー（任意）'**
  String get profileScreenTaskTriggerHint;

  /// No description provided for @profileScreenTaskNameHint.
  ///
  /// In ja, this message translates to:
  /// **'タスク名'**
  String get profileScreenTaskNameHint;

  /// No description provided for @profileScreenOneTimeTaskTitle.
  ///
  /// In ja, this message translates to:
  /// **'完了から24時間後に自動削除されます'**
  String get profileScreenOneTimeTaskTitle;

  /// No description provided for @profileScreenSecretTaskTitle.
  ///
  /// In ja, this message translates to:
  /// **'シークレットタスク'**
  String get profileScreenSecretTaskTitle;

  /// No description provided for @profileScreenSecretTaskSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'友達のタイムラインでは写真がぼかされ、タスク名が非表示になります'**
  String get profileScreenSecretTaskSubtitle;

  /// No description provided for @timelineSecretTaskLabel.
  ///
  /// In ja, this message translates to:
  /// **'シークレットタスク'**
  String get timelineSecretTaskLabel;

  /// No description provided for @profileScreenHabitTipsTitle.
  ///
  /// In ja, this message translates to:
  /// **'習慣化のコツ'**
  String get profileScreenHabitTipsTitle;

  /// No description provided for @profileScreenHabitTipsClose.
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get profileScreenHabitTipsClose;

  /// No description provided for @cameraScreenTaskDefault.
  ///
  /// In ja, this message translates to:
  /// **'今日のヒーロータスク'**
  String get cameraScreenTaskDefault;

  /// No description provided for @cameraScreenUploadFailed.
  ///
  /// In ja, this message translates to:
  /// **'投稿に失敗しました。もう一度お試しください。'**
  String get cameraScreenUploadFailed;

  /// No description provided for @cameraScreenCaption.
  ///
  /// In ja, this message translates to:
  /// **'コメントを追加'**
  String get cameraScreenCaption;

  /// No description provided for @cameraScreenCameraLoading.
  ///
  /// In ja, this message translates to:
  /// **'カメラを起動中...'**
  String get cameraScreenCameraLoading;

  /// No description provided for @cameraScreenCameraUnavailable.
  ///
  /// In ja, this message translates to:
  /// **'カメラを利用できません\n下のアルバムボタンから写真を選択してください'**
  String get cameraScreenCameraUnavailable;

  /// No description provided for @cameraScreenPost.
  ///
  /// In ja, this message translates to:
  /// **'証明する'**
  String get cameraScreenPost;

  /// No description provided for @cameraScreenDragPinch.
  ///
  /// In ja, this message translates to:
  /// **'ドラッグ・ピンチで位置調整'**
  String get cameraScreenDragPinch;

  /// No description provided for @cameraMusicAdd.
  ///
  /// In ja, this message translates to:
  /// **'音楽を追加'**
  String get cameraMusicAdd;

  /// No description provided for @cameraMusicRemoveBgm.
  ///
  /// In ja, this message translates to:
  /// **'BGMを削除'**
  String get cameraMusicRemoveBgm;

  /// No description provided for @cameraMusicSearchHint.
  ///
  /// In ja, this message translates to:
  /// **'曲名やアーティストで検索...'**
  String get cameraMusicSearchHint;

  /// No description provided for @cameraMusicRecentSongs.
  ///
  /// In ja, this message translates to:
  /// **'最近使った曲'**
  String get cameraMusicRecentSongs;

  /// No description provided for @cameraMusicTrends.
  ///
  /// In ja, this message translates to:
  /// **'日本のトレンド'**
  String get cameraMusicTrends;

  /// No description provided for @cameraMusicSelect.
  ///
  /// In ja, this message translates to:
  /// **'選択'**
  String get cameraMusicSelect;

  /// No description provided for @heroTasksNoTasks.
  ///
  /// In ja, this message translates to:
  /// **'ヒーロータスクが設定されていません'**
  String get heroTasksNoTasks;

  /// No description provided for @heroTasksNoTasksDesc.
  ///
  /// In ja, this message translates to:
  /// **'プロフィールからヒーロータスクを設定'**
  String get heroTasksNoTasksDesc;

  /// No description provided for @heroTasksDeletePostTitle.
  ///
  /// In ja, this message translates to:
  /// **'投稿を削除'**
  String get heroTasksDeletePostTitle;

  /// No description provided for @heroTasksDeletePostDesc.
  ///
  /// In ja, this message translates to:
  /// **'この投稿を削除してもよろしいですか？\n(今日の達成記録も取り消されます)'**
  String get heroTasksDeletePostDesc;

  /// No description provided for @heroTasksDeletePostCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get heroTasksDeletePostCancel;

  /// No description provided for @heroTasksDeletePostButton.
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get heroTasksDeletePostButton;

  /// No description provided for @heroTasksWelcomeMessage.
  ///
  /// In ja, this message translates to:
  /// **'V EFFECTへようこそ。\nここはあなたにとって最適な環境です。\n\nまずはカメラアイコンをタップして、\n最初のVを証明しましょう。'**
  String get heroTasksWelcomeMessage;

  /// No description provided for @notificationsTitle.
  ///
  /// In ja, this message translates to:
  /// **'通知'**
  String get notificationsTitle;

  /// No description provided for @notificationsDeleteAll.
  ///
  /// In ja, this message translates to:
  /// **'全て削除'**
  String get notificationsDeleteAll;

  /// No description provided for @notificationsEmpty.
  ///
  /// In ja, this message translates to:
  /// **'通知はありません'**
  String get notificationsEmpty;

  /// No description provided for @notificationsDeleteFailed.
  ///
  /// In ja, this message translates to:
  /// **'削除に失敗しました。もう一度お試しください。'**
  String get notificationsDeleteFailed;

  /// No description provided for @notificationsDeleteAllTitle.
  ///
  /// In ja, this message translates to:
  /// **'通知を全て削除'**
  String get notificationsDeleteAllTitle;

  /// No description provided for @notificationsDeleteAllMessage.
  ///
  /// In ja, this message translates to:
  /// **'全ての通知を削除しますか？'**
  String get notificationsDeleteAllMessage;

  /// No description provided for @notificationsDeleteAllCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get notificationsDeleteAllCancel;

  /// No description provided for @notificationsDeleteAllButton.
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get notificationsDeleteAllButton;

  /// No description provided for @notificationsApproveRequest.
  ///
  /// In ja, this message translates to:
  /// **'フォローリクエストを承認しました！'**
  String get notificationsApproveRequest;

  /// No description provided for @notificationsRejectRequest.
  ///
  /// In ja, this message translates to:
  /// **'フォローリクエストを拒否しました。'**
  String get notificationsRejectRequest;

  /// No description provided for @notificationsApproveFailed.
  ///
  /// In ja, this message translates to:
  /// **'承認に失敗しました。もう一度お試しください。'**
  String get notificationsApproveFailed;

  /// No description provided for @notificationsFollowed.
  ///
  /// In ja, this message translates to:
  /// **'フォローしました！'**
  String get notificationsFollowed;

  /// No description provided for @notificationsFollowFailed.
  ///
  /// In ja, this message translates to:
  /// **'フォローに失敗しました。'**
  String get notificationsFollowFailed;

  /// No description provided for @notificationsFollowing.
  ///
  /// In ja, this message translates to:
  /// **'フォロー中'**
  String get notificationsFollowing;

  /// No description provided for @notificationsFollowBack.
  ///
  /// In ja, this message translates to:
  /// **'フォローバック'**
  String get notificationsFollowBack;

  /// No description provided for @notificationsApprove.
  ///
  /// In ja, this message translates to:
  /// **'承認'**
  String get notificationsApprove;

  /// No description provided for @notificationsReject.
  ///
  /// In ja, this message translates to:
  /// **'拒否'**
  String get notificationsReject;

  /// No description provided for @notificationsDelete.
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get notificationsDelete;

  /// No description provided for @notificationsSeasonTaskJoined.
  ///
  /// In ja, this message translates to:
  /// **'期間限定タスクに参加しました！'**
  String get notificationsSeasonTaskJoined;

  /// No description provided for @notificationsSeasonTaskSkipped.
  ///
  /// In ja, this message translates to:
  /// **'期間限定タスクをスキップしました。'**
  String get notificationsSeasonTaskSkipped;

  /// No description provided for @notificationsFriendAccepted.
  ///
  /// In ja, this message translates to:
  /// **'{username}さんがフレンド申請を承認しました'**
  String notificationsFriendAccepted(Object username);

  /// No description provided for @notificationsError.
  ///
  /// In ja, this message translates to:
  /// **'エラーが発生しました: {error}'**
  String notificationsError(Object error);

  /// No description provided for @onboardingFirstQuestQuestionText.
  ///
  /// In ja, this message translates to:
  /// **'あなたが理想とする姿はどんなだろう？'**
  String get onboardingFirstQuestQuestionText;

  /// No description provided for @onboardingFirstQuestTriggerLabel.
  ///
  /// In ja, this message translates to:
  /// **'トリガー（任意）'**
  String get onboardingFirstQuestTriggerLabel;

  /// No description provided for @onboardingFirstQuestTaskLabel.
  ///
  /// In ja, this message translates to:
  /// **'タスク名'**
  String get onboardingFirstQuestTaskLabel;

  /// No description provided for @onboardingFirstQuestPrivacyNote.
  ///
  /// In ja, this message translates to:
  /// **'※ トリガーは自分にのみ表示されます（他のユーザーには公開されません）'**
  String get onboardingFirstQuestPrivacyNote;

  /// No description provided for @onboardingFirstQuestCompleteButton.
  ///
  /// In ja, this message translates to:
  /// **'完了'**
  String get onboardingFirstQuestCompleteButton;

  /// No description provided for @onboardingFirstQuestSkipButton.
  ///
  /// In ja, this message translates to:
  /// **'スキップ'**
  String get onboardingFirstQuestSkipButton;

  /// No description provided for @onboardingFirstQuestSaveFailed.
  ///
  /// In ja, this message translates to:
  /// **'保存に失敗しました: {error}'**
  String onboardingFirstQuestSaveFailed(Object error);

  /// No description provided for @timeframeMorning.
  ///
  /// In ja, this message translates to:
  /// **'☀️ 朝'**
  String get timeframeMorning;

  /// No description provided for @timeframeAfternoon.
  ///
  /// In ja, this message translates to:
  /// **'🌆 昼'**
  String get timeframeAfternoon;

  /// No description provided for @timeframeNight.
  ///
  /// In ja, this message translates to:
  /// **'🌙 夜'**
  String get timeframeNight;

  /// No description provided for @onboardingFirstQuestSuggestedTriggerTitle.
  ///
  /// In ja, this message translates to:
  /// **'おすすめのきっかけ（タップで選択）'**
  String get onboardingFirstQuestSuggestedTriggerTitle;

  /// No description provided for @onboardingFirstQuestSuggestedTaskTitle.
  ///
  /// In ja, this message translates to:
  /// **'おすすめのタスク（タップで選択）'**
  String get onboardingFirstQuestSuggestedTaskTitle;

  /// No description provided for @morningTrigger1.
  ///
  /// In ja, this message translates to:
  /// **'朝起きたら'**
  String get morningTrigger1;

  /// No description provided for @morningTrigger2.
  ///
  /// In ja, this message translates to:
  /// **'ベッドから出たら'**
  String get morningTrigger2;

  /// No description provided for @morningTrigger3.
  ///
  /// In ja, this message translates to:
  /// **'朝食の前に'**
  String get morningTrigger3;

  /// No description provided for @morningTask1.
  ///
  /// In ja, this message translates to:
  /// **'水を飲む'**
  String get morningTask1;

  /// No description provided for @morningTask2.
  ///
  /// In ja, this message translates to:
  /// **'ToDoを書く'**
  String get morningTask2;

  /// No description provided for @morningTask3.
  ///
  /// In ja, this message translates to:
  /// **'ワークアウト'**
  String get morningTask3;

  /// No description provided for @afternoonTrigger1.
  ///
  /// In ja, this message translates to:
  /// **'お昼ご飯を食べ終えたら'**
  String get afternoonTrigger1;

  /// No description provided for @afternoonTrigger2.
  ///
  /// In ja, this message translates to:
  /// **'スマホを開く前に'**
  String get afternoonTrigger2;

  /// No description provided for @afternoonTrigger3.
  ///
  /// In ja, this message translates to:
  /// **'PCを閉じるタイミングで'**
  String get afternoonTrigger3;

  /// No description provided for @afternoonTask1.
  ///
  /// In ja, this message translates to:
  /// **'スマホを10分置く'**
  String get afternoonTask1;

  /// No description provided for @afternoonTask2.
  ///
  /// In ja, this message translates to:
  /// **'本のページをめくる'**
  String get afternoonTask2;

  /// No description provided for @afternoonTask3.
  ///
  /// In ja, this message translates to:
  /// **'デスクのゴミを1つ捨てる'**
  String get afternoonTask3;

  /// No description provided for @nightTrigger1.
  ///
  /// In ja, this message translates to:
  /// **'お風呂から上がったら'**
  String get nightTrigger1;

  /// No description provided for @nightTrigger2.
  ///
  /// In ja, this message translates to:
  /// **'布団に入る前に'**
  String get nightTrigger2;

  /// No description provided for @nightTrigger3.
  ///
  /// In ja, this message translates to:
  /// **'22時になったら'**
  String get nightTrigger3;

  /// No description provided for @nightTask1.
  ///
  /// In ja, this message translates to:
  /// **'寝る前スマホをやめる'**
  String get nightTask1;

  /// No description provided for @nightTask2.
  ///
  /// In ja, this message translates to:
  /// **'今日良かったことを3つ書く'**
  String get nightTask2;

  /// No description provided for @nightTask3.
  ///
  /// In ja, this message translates to:
  /// **'明日の予定を1つ書く'**
  String get nightTask3;

  /// No description provided for @onboardingFirstQuestHabitTipsTitle.
  ///
  /// In ja, this message translates to:
  /// **'習慣化のコツ'**
  String get onboardingFirstQuestHabitTipsTitle;

  /// No description provided for @onboardingProfileWelcome.
  ///
  /// In ja, this message translates to:
  /// **'V EFFECT へようこそ'**
  String get onboardingProfileWelcome;

  /// No description provided for @onboardingProfileSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'プロフィールを設定しましょう'**
  String get onboardingProfileSubtitle;

  /// No description provided for @onboardingProfileUsernameLabel.
  ///
  /// In ja, this message translates to:
  /// **'ユーザー名'**
  String get onboardingProfileUsernameLabel;

  /// No description provided for @onboardingProfileUsernameHint.
  ///
  /// In ja, this message translates to:
  /// **'表示名を入力してください'**
  String get onboardingProfileUsernameHint;

  /// No description provided for @onboardingProfileUsernameRequired.
  ///
  /// In ja, this message translates to:
  /// **'ユーザー名を入力してください'**
  String get onboardingProfileUsernameRequired;

  /// No description provided for @onboardingProfileUserIdLabel.
  ///
  /// In ja, this message translates to:
  /// **'ユーザーID'**
  String get onboardingProfileUserIdLabel;

  /// No description provided for @onboardingProfileUserIdMinLength.
  ///
  /// In ja, this message translates to:
  /// **'5文字以上で入力してください'**
  String get onboardingProfileUserIdMinLength;

  /// No description provided for @onboardingProfileUserIdAlphanumeric.
  ///
  /// In ja, this message translates to:
  /// **'英数字とアンダースコアのみ使えます'**
  String get onboardingProfileUserIdAlphanumeric;

  /// No description provided for @onboardingProfileUserIdRequired.
  ///
  /// In ja, this message translates to:
  /// **'ユーザーIDを入力してください'**
  String get onboardingProfileUserIdRequired;

  /// No description provided for @onboardingProfileUserIdAlreadyUsed.
  ///
  /// In ja, this message translates to:
  /// **'このユーザーIDは既に使われています'**
  String get onboardingProfileUserIdAlreadyUsed;

  /// No description provided for @onboardingProfileSaveFailed.
  ///
  /// In ja, this message translates to:
  /// **'保存に失敗しました: {error}'**
  String onboardingProfileSaveFailed(Object error);

  /// No description provided for @onboardingProfileStartButton.
  ///
  /// In ja, this message translates to:
  /// **'最初の V を証明する →'**
  String get onboardingProfileStartButton;

  /// No description provided for @onboardingProfileHelperText.
  ///
  /// In ja, this message translates to:
  /// **'5文字以上・英数字とアンダースコアのみ'**
  String get onboardingProfileHelperText;

  /// No description provided for @onboardingProfileImageAdjust.
  ///
  /// In ja, this message translates to:
  /// **'画像を調整'**
  String get onboardingProfileImageAdjust;

  /// No description provided for @notificationPromptTitle.
  ///
  /// In ja, this message translates to:
  /// **'「仲間の努力」を習慣の味方にしますか？'**
  String get notificationPromptTitle;

  /// No description provided for @notificationPromptDesc.
  ///
  /// In ja, this message translates to:
  /// **'V EFFECTで最も強い習慣化の力は「仲間の存在」です。\n\n通知をONにすることで、仲間の達成がリアルタイムにあなたの刺激になり、あなたの努力も仲間に届きます。\nお互いの存在を背中に感じながら、強固な習慣を築きましょう。'**
  String get notificationPromptDesc;

  /// No description provided for @notificationPromptNext.
  ///
  /// In ja, this message translates to:
  /// **'次へ'**
  String get notificationPromptNext;

  /// No description provided for @notificationPromptLater.
  ///
  /// In ja, this message translates to:
  /// **'今はしない'**
  String get notificationPromptLater;

  /// No description provided for @friendInviteTitle.
  ///
  /// In ja, this message translates to:
  /// **'V (勝利) を仲間と証明しよう！'**
  String get friendInviteTitle;

  /// No description provided for @friendInviteDesc.
  ///
  /// In ja, this message translates to:
  /// **'最初のV Questの設定が完了しました！\n努力と勝利を共有するフレンドを誘いましょう！'**
  String get friendInviteDesc;

  /// No description provided for @friendInviteShareButton.
  ///
  /// In ja, this message translates to:
  /// **'友達を招待する (LINE等でシェア)'**
  String get friendInviteShareButton;

  /// No description provided for @friendInviteQrButton.
  ///
  /// In ja, this message translates to:
  /// **'すでにやっている友達と繋がる (QRコード)'**
  String get friendInviteQrButton;

  /// No description provided for @friendInviteLater.
  ///
  /// In ja, this message translates to:
  /// **'今はしない'**
  String get friendInviteLater;

  /// No description provided for @friendInviteQrTitle.
  ///
  /// In ja, this message translates to:
  /// **'QRコード'**
  String get friendInviteQrTitle;

  /// No description provided for @friendInviteQrDisplay.
  ///
  /// In ja, this message translates to:
  /// **'マイQRコードを表示'**
  String get friendInviteQrDisplay;

  /// No description provided for @friendInviteQrScan.
  ///
  /// In ja, this message translates to:
  /// **'QRコードをスキャン'**
  String get friendInviteQrScan;

  /// No description provided for @weeklyReviewBannerTitle.
  ///
  /// In ja, this message translates to:
  /// **'今週の振り返りが届いています！'**
  String get weeklyReviewBannerTitle;

  /// No description provided for @globalErrorTitle.
  ///
  /// In ja, this message translates to:
  /// **'申し訳ありません'**
  String get globalErrorTitle;

  /// No description provided for @globalErrorDesc.
  ///
  /// In ja, this message translates to:
  /// **'アプリの起動中に問題が発生しました。'**
  String get globalErrorDesc;

  /// No description provided for @globalErrorRetry.
  ///
  /// In ja, this message translates to:
  /// **'再試行'**
  String get globalErrorRetry;

  /// No description provided for @globalErrorUnknown.
  ///
  /// In ja, this message translates to:
  /// **'未知のエラー'**
  String get globalErrorUnknown;

  /// No description provided for @seasonHintDefaultTitle.
  ///
  /// In ja, this message translates to:
  /// **'シーズンタスクのヒント💡'**
  String get seasonHintDefaultTitle;

  /// No description provided for @seasonHintDefaultBody.
  ///
  /// In ja, this message translates to:
  /// **'このシーズンタスクを習慣にするためのアドバイスです。'**
  String get seasonHintDefaultBody;

  /// No description provided for @seasonHintReadBlog.
  ///
  /// In ja, this message translates to:
  /// **'開発者の想い・経緯を読む'**
  String get seasonHintReadBlog;

  /// No description provided for @seasonHintTriggerLabel.
  ///
  /// In ja, this message translates to:
  /// **'あなたのトリガー（きっかけ）'**
  String get seasonHintTriggerLabel;

  /// No description provided for @seasonHintTriggerHint.
  ///
  /// In ja, this message translates to:
  /// **'例: 朝起きたら、通勤電車で'**
  String get seasonHintTriggerHint;

  /// No description provided for @seasonHintSaveButton.
  ///
  /// In ja, this message translates to:
  /// **'トリガーを保存'**
  String get seasonHintSaveButton;

  /// No description provided for @postSuccessStreakContinuing.
  ///
  /// In ja, this message translates to:
  /// **'継続中'**
  String get postSuccessStreakContinuing;

  /// No description provided for @homeWeeklyReviewLoadFailed.
  ///
  /// In ja, this message translates to:
  /// **'振り返りデータの取得に失敗しました ({code})'**
  String homeWeeklyReviewLoadFailed(String code);

  /// No description provided for @homeUnexpectedError.
  ///
  /// In ja, this message translates to:
  /// **'予期せぬエラーが発生しました'**
  String get homeUnexpectedError;

  /// No description provided for @homeBlockUser.
  ///
  /// In ja, this message translates to:
  /// **'ユーザーをブロック'**
  String get homeBlockUser;

  /// No description provided for @homeReportPost.
  ///
  /// In ja, this message translates to:
  /// **'不適切な投稿を通報する'**
  String get homeReportPost;

  /// No description provided for @homeBlockConfirmTitle.
  ///
  /// In ja, this message translates to:
  /// **'ブロックしますか？'**
  String get homeBlockConfirmTitle;

  /// No description provided for @homeBlockConfirmDesc.
  ///
  /// In ja, this message translates to:
  /// **'このユーザーの投稿が表示されなくなります。'**
  String get homeBlockConfirmDesc;

  /// No description provided for @homeBlockConfirmCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get homeBlockConfirmCancel;

  /// No description provided for @homeBlockSuccess.
  ///
  /// In ja, this message translates to:
  /// **'ユーザーをブロックしました'**
  String get homeBlockSuccess;

  /// No description provided for @homeBlockFailed.
  ///
  /// In ja, this message translates to:
  /// **'ブロックに失敗しました'**
  String get homeBlockFailed;

  /// No description provided for @homeBlockButton.
  ///
  /// In ja, this message translates to:
  /// **'ブロックする'**
  String get homeBlockButton;

  /// No description provided for @homeReportTitle.
  ///
  /// In ja, this message translates to:
  /// **'通報する理由を選択'**
  String get homeReportTitle;

  /// No description provided for @homeReportSpam.
  ///
  /// In ja, this message translates to:
  /// **'スパム'**
  String get homeReportSpam;

  /// No description provided for @homeReportHarassment.
  ///
  /// In ja, this message translates to:
  /// **'ハラスメント'**
  String get homeReportHarassment;

  /// No description provided for @homeReportInappropriate.
  ///
  /// In ja, this message translates to:
  /// **'不適切なコンテンツ'**
  String get homeReportInappropriate;

  /// No description provided for @homeReportOther.
  ///
  /// In ja, this message translates to:
  /// **'その他'**
  String get homeReportOther;

  /// No description provided for @homeReportCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get homeReportCancel;

  /// No description provided for @homeReportSuccess.
  ///
  /// In ja, this message translates to:
  /// **'通報しました。ご協力ありがとうございます。'**
  String get homeReportSuccess;

  /// No description provided for @homeReportFailed.
  ///
  /// In ja, this message translates to:
  /// **'通報に失敗しました'**
  String get homeReportFailed;

  /// No description provided for @homeErrorOccurred.
  ///
  /// In ja, this message translates to:
  /// **'エラーが発生しました'**
  String get homeErrorOccurred;

  /// No description provided for @homeRetry.
  ///
  /// In ja, this message translates to:
  /// **'再試行'**
  String get homeRetry;

  /// No description provided for @homeFriendRequestApproveFailed.
  ///
  /// In ja, this message translates to:
  /// **'承認に失敗しました: {error}'**
  String homeFriendRequestApproveFailed(Object error);

  /// No description provided for @homeFriendRequestProcessFailed.
  ///
  /// In ja, this message translates to:
  /// **'処理に失敗しました: {error}'**
  String homeFriendRequestProcessFailed(Object error);

  /// No description provided for @homeNewsTitle.
  ///
  /// In ja, this message translates to:
  /// **'運営からのお知らせ'**
  String get homeNewsTitle;

  /// No description provided for @homeMotivationText1.
  ///
  /// In ja, this message translates to:
  /// **'あなたはトップランナーだ。'**
  String get homeMotivationText1;

  /// No description provided for @homeMotivationText2.
  ///
  /// In ja, this message translates to:
  /// **'小さな選択、小さな勝利が証拠となり\n理想とする自分が真実になる。'**
  String get homeMotivationText2;

  /// No description provided for @homeEmojiReactionHint.
  ///
  /// In ja, this message translates to:
  /// **'タップして絵文字で応援！'**
  String get homeEmojiReactionHint;

  /// No description provided for @homeFriendPostsTitle.
  ///
  /// In ja, this message translates to:
  /// **'仲間の努力が届いています'**
  String get homeFriendPostsTitle;

  /// No description provided for @homeStreakResetMessage.
  ///
  /// In ja, this message translates to:
  /// **'ストリークが止まったとしても、\nあなたの歩みさえ止まらなければ\nV EFFECTは何度でも引き起こせる。'**
  String get homeStreakResetMessage;

  /// No description provided for @vEffectCoreTitle.
  ///
  /// In ja, this message translates to:
  /// **'V EFFECT の使い方'**
  String get vEffectCoreTitle;

  /// No description provided for @vEffectStep1Title.
  ///
  /// In ja, this message translates to:
  /// **'1. 習慣化したい（やりたい）ことを決めよう'**
  String get vEffectStep1Title;

  /// No description provided for @vEffectStep1Desc.
  ///
  /// In ja, this message translates to:
  /// **'あなたが習慣化したい（やりたい）ことを決めます。'**
  String get vEffectStep1Desc;

  /// No description provided for @vEffectStep2Title.
  ///
  /// In ja, this message translates to:
  /// **'2. 写真付きで証明しよう'**
  String get vEffectStep2Title;

  /// No description provided for @vEffectStep2Desc.
  ///
  /// In ja, this message translates to:
  /// **'勝利したタスク（読書、勉強、ワークアウトなど）を証明しましょう。'**
  String get vEffectStep2Desc;

  /// No description provided for @vEffectConceptFootnotePrefix.
  ///
  /// In ja, this message translates to:
  /// **'※ 小さな勝利を記録することにより脳科学における'**
  String get vEffectConceptFootnotePrefix;

  /// No description provided for @vEffectConceptFootnoteHighlight.
  ///
  /// In ja, this message translates to:
  /// **'V EFFECT『勝利者効果』'**
  String get vEffectConceptFootnoteHighlight;

  /// No description provided for @vEffectConceptFootnoteSuffix.
  ///
  /// In ja, this message translates to:
  /// **'を引き起こし、あなたの継続する力を科学的にサポートします。'**
  String get vEffectConceptFootnoteSuffix;

  /// No description provided for @vEffectJoinButton.
  ///
  /// In ja, this message translates to:
  /// **'V EFFECT に参加する →'**
  String get vEffectJoinButton;

  /// No description provided for @adLabel.
  ///
  /// In ja, this message translates to:
  /// **'広告'**
  String get adLabel;

  /// No description provided for @dateFormatFull.
  ///
  /// In ja, this message translates to:
  /// **'yyyy年M月d日'**
  String get dateFormatFull;

  /// No description provided for @heroTaskSeasonDaysLeft.
  ///
  /// In ja, this message translates to:
  /// **'SEASON | 残り{days}日'**
  String heroTaskSeasonDaysLeft(int days);

  /// No description provided for @homeFriendRequestMultiple.
  ///
  /// In ja, this message translates to:
  /// **'{username}さん他{count}名から申請が届いています'**
  String homeFriendRequestMultiple(String username, int count);

  /// No description provided for @homePostToSeeFriends.
  ///
  /// In ja, this message translates to:
  /// **'（更新）タスクを投稿してフレンドの投稿を見れる状態にしよう！'**
  String get homePostToSeeFriends;

  /// No description provided for @homeProveVictory.
  ///
  /// In ja, this message translates to:
  /// **'Victory を証明しましょう'**
  String get homeProveVictory;

  /// No description provided for @homeNewPostsAvailable.
  ///
  /// In ja, this message translates to:
  /// **'新しい投稿があります'**
  String get homeNewPostsAvailable;

  /// No description provided for @editProfileGenderMale.
  ///
  /// In ja, this message translates to:
  /// **'男性'**
  String get editProfileGenderMale;

  /// No description provided for @editProfileGenderFemale.
  ///
  /// In ja, this message translates to:
  /// **'女性'**
  String get editProfileGenderFemale;

  /// No description provided for @editProfileGenderOther.
  ///
  /// In ja, this message translates to:
  /// **'その他'**
  String get editProfileGenderOther;

  /// No description provided for @blogEditorTextBlockPlaceholder.
  ///
  /// In ja, this message translates to:
  /// **'テキスト'**
  String get blogEditorTextBlockPlaceholder;

  /// No description provided for @blogEditorCodeBlockPlaceholder.
  ///
  /// In ja, this message translates to:
  /// **'コードをここに入力'**
  String get blogEditorCodeBlockPlaceholder;

  /// No description provided for @blogEditorSeasonDays.
  ///
  /// In ja, this message translates to:
  /// **'{days}日間'**
  String blogEditorSeasonDays(String days);

  /// No description provided for @blogEditorExampleTaskHint.
  ///
  /// In ja, this message translates to:
  /// **'例: 感謝を伝える'**
  String get blogEditorExampleTaskHint;

  /// No description provided for @blogEditorExampleDurationHint.
  ///
  /// In ja, this message translates to:
  /// **'例: 7'**
  String get blogEditorExampleDurationHint;

  /// No description provided for @blogEditorExampleTesterHint.
  ///
  /// In ja, this message translates to:
  /// **'例: tester (またはFirebase URL)'**
  String get blogEditorExampleTesterHint;

  /// No description provided for @blogEditorImageUploadTooltip.
  ///
  /// In ja, this message translates to:
  /// **'画像を選択してアップロード'**
  String get blogEditorImageUploadTooltip;

  /// No description provided for @initialFriendAtUserNotFound.
  ///
  /// In ja, this message translates to:
  /// **'@{userId}: ユーザーが見つかりません'**
  String initialFriendAtUserNotFound(String userId);

  /// No description provided for @initialFriendAtSendFailed.
  ///
  /// In ja, this message translates to:
  /// **'@{userId}: 送信に失敗しました'**
  String initialFriendAtSendFailed(String userId);

  /// No description provided for @initialFriendOtherUserNotFound.
  ///
  /// In ja, this message translates to:
  /// **'{userId}: ユーザーが見つかりません'**
  String initialFriendOtherUserNotFound(String userId);

  /// No description provided for @initialFriendOtherSendFailed.
  ///
  /// In ja, this message translates to:
  /// **'{userId}: 送信に失敗しました'**
  String initialFriendOtherSendFailed(String userId);

  /// No description provided for @initialFriendExampleIdHint.
  ///
  /// In ja, this message translates to:
  /// **'例: user_123'**
  String get initialFriendExampleIdHint;

  /// No description provided for @hintExampleFormat.
  ///
  /// In ja, this message translates to:
  /// **'例: {value}'**
  String hintExampleFormat(String value);

  /// No description provided for @firstQuestTaskHint1.
  ///
  /// In ja, this message translates to:
  /// **'ジム'**
  String get firstQuestTaskHint1;

  /// No description provided for @firstQuestTaskHint2.
  ///
  /// In ja, this message translates to:
  /// **'英語学習'**
  String get firstQuestTaskHint2;

  /// No description provided for @firstQuestTaskHint3.
  ///
  /// In ja, this message translates to:
  /// **'部屋 of 掃除'**
  String get firstQuestTaskHint3;

  /// No description provided for @firstQuestTaskHint4.
  ///
  /// In ja, this message translates to:
  /// **'ランニング'**
  String get firstQuestTaskHint4;

  /// No description provided for @firstQuestTaskHint5.
  ///
  /// In ja, this message translates to:
  /// **'栄養管理'**
  String get firstQuestTaskHint5;

  /// No description provided for @firstQuestTriggerHint1.
  ///
  /// In ja, this message translates to:
  /// **'朝起きたら'**
  String get firstQuestTriggerHint1;

  /// No description provided for @firstQuestTriggerHint2.
  ///
  /// In ja, this message translates to:
  /// **'帰宅したら'**
  String get firstQuestTriggerHint2;

  /// No description provided for @firstQuestTriggerHint3.
  ///
  /// In ja, this message translates to:
  /// **'お風呂から上がったら'**
  String get firstQuestTriggerHint3;

  /// No description provided for @firstQuestTriggerHint4.
  ///
  /// In ja, this message translates to:
  /// **'机に座ったら'**
  String get firstQuestTriggerHint4;

  /// No description provided for @onboardingFirstQuestTriggerHintText.
  ///
  /// In ja, this message translates to:
  /// **'トリガーを入力（任意）'**
  String get onboardingFirstQuestTriggerHintText;

  /// No description provided for @onboardingFirstQuestTaskHintText.
  ///
  /// In ja, this message translates to:
  /// **'タスク名を入力'**
  String get onboardingFirstQuestTaskHintText;

  /// No description provided for @onboardingFirstQuestTimeframeHeader.
  ///
  /// In ja, this message translates to:
  /// **'時間帯から選ぶ'**
  String get onboardingFirstQuestTimeframeHeader;

  /// No description provided for @firstQuestTitle.
  ///
  /// In ja, this message translates to:
  /// **'習慣化したい(やりたい)ことを決めましょう'**
  String get firstQuestTitle;

  /// No description provided for @firstQuestNoTaskPlaceholder.
  ///
  /// In ja, this message translates to:
  /// **'（タスク）'**
  String get firstQuestNoTaskPlaceholder;

  /// No description provided for @firstQuestKeyword1.
  ///
  /// In ja, this message translates to:
  /// **'勝利'**
  String get firstQuestKeyword1;

  /// No description provided for @firstQuestKeyword2.
  ///
  /// In ja, this message translates to:
  /// **'努力'**
  String get firstQuestKeyword2;

  /// No description provided for @firstQuestKeyword3.
  ///
  /// In ja, this message translates to:
  /// **'達成感'**
  String get firstQuestKeyword3;

  /// No description provided for @firstQuestKeyword4.
  ///
  /// In ja, this message translates to:
  /// **'目標'**
  String get firstQuestKeyword4;

  /// No description provided for @firstQuestKeyword5.
  ///
  /// In ja, this message translates to:
  /// **'習慣化'**
  String get firstQuestKeyword5;

  /// No description provided for @firstQuestKeyword6.
  ///
  /// In ja, this message translates to:
  /// **'継続'**
  String get firstQuestKeyword6;

  /// No description provided for @onboardingProfileExampleIdHint.
  ///
  /// In ja, this message translates to:
  /// **'例: v_effect'**
  String get onboardingProfileExampleIdHint;

  /// No description provided for @categoryOther.
  ///
  /// In ja, this message translates to:
  /// **'その他'**
  String get categoryOther;

  /// No description provided for @habitStackingHint.
  ///
  /// In ja, this message translates to:
  /// **'• ハビットスタッキング\n既存の習慣をトリガーにして新しい習慣を取り入れよう。\n例）カーテンを開けたら→ToDoリストを書く'**
  String get habitStackingHint;

  /// No description provided for @temptationBundlingHint.
  ///
  /// In ja, this message translates to:
  /// **'• テンプテーションバンドリング\n「やるべきこと」と「やりたいこと」をセットにしよう。\n例）デスクワークの時だけ、お気に入りのコーヒー（またはお菓子）を飲む。'**
  String get temptationBundlingHint;

  /// No description provided for @profileNoTaskPlaceholder.
  ///
  /// In ja, this message translates to:
  /// **'（タスク）'**
  String get profileNoTaskPlaceholder;

  /// No description provided for @occupationEmployee.
  ///
  /// In ja, this message translates to:
  /// **'会社員'**
  String get occupationEmployee;

  /// No description provided for @occupationExecutive.
  ///
  /// In ja, this message translates to:
  /// **'経営者・役員'**
  String get occupationExecutive;

  /// No description provided for @occupationCivilServant.
  ///
  /// In ja, this message translates to:
  /// **'公務員'**
  String get occupationCivilServant;

  /// No description provided for @occupationSelfEmployed.
  ///
  /// In ja, this message translates to:
  /// **'自営業・フリーランス'**
  String get occupationSelfEmployed;

  /// No description provided for @occupationProfessional.
  ///
  /// In ja, this message translates to:
  /// **'専門職（医師・弁護士など）'**
  String get occupationProfessional;

  /// No description provided for @occupationEducation.
  ///
  /// In ja, this message translates to:
  /// **'教員・教育関係'**
  String get occupationEducation;

  /// No description provided for @occupationStudent.
  ///
  /// In ja, this message translates to:
  /// **'学生'**
  String get occupationStudent;

  /// No description provided for @occupationPartTime.
  ///
  /// In ja, this message translates to:
  /// **'パート・アルバイト'**
  String get occupationPartTime;

  /// No description provided for @occupationHomemaker.
  ///
  /// In ja, this message translates to:
  /// **'専業主婦・主夫'**
  String get occupationHomemaker;

  /// No description provided for @occupationUnemployed.
  ///
  /// In ja, this message translates to:
  /// **'無職'**
  String get occupationUnemployed;

  /// No description provided for @occupationOther.
  ///
  /// In ja, this message translates to:
  /// **'その他'**
  String get occupationOther;

  /// No description provided for @hintNameExample.
  ///
  /// In ja, this message translates to:
  /// **'例: V EFFECT'**
  String get hintNameExample;

  /// No description provided for @timeHour.
  ///
  /// In ja, this message translates to:
  /// **'{hour}時'**
  String timeHour(int hour);

  /// No description provided for @timeMinute.
  ///
  /// In ja, this message translates to:
  /// **'{minute}分'**
  String timeMinute(String minute);

  /// No description provided for @timePeriodAm.
  ///
  /// In ja, this message translates to:
  /// **'午前'**
  String get timePeriodAm;

  /// No description provided for @timePeriodPm.
  ///
  /// In ja, this message translates to:
  /// **'午後'**
  String get timePeriodPm;

  /// No description provided for @hintTaskExample.
  ///
  /// In ja, this message translates to:
  /// **'例: ランニング3km'**
  String get hintTaskExample;

  /// No description provided for @taskTemplateBook.
  ///
  /// In ja, this message translates to:
  /// **'本を開く'**
  String get taskTemplateBook;

  /// No description provided for @taskTemplateBookDesc.
  ///
  /// In ja, this message translates to:
  /// **'好きな本を開いて写真を撮ろう'**
  String get taskTemplateBookDesc;

  /// No description provided for @taskTemplateBreathing.
  ///
  /// In ja, this message translates to:
  /// **'外で深呼吸する'**
  String get taskTemplateBreathing;

  /// No description provided for @taskTemplateBreathingDesc.
  ///
  /// In ja, this message translates to:
  /// **'外に出て深呼吸している瞬間を撮ろう'**
  String get taskTemplateBreathingDesc;

  /// No description provided for @taskTemplateWater.
  ///
  /// In ja, this message translates to:
  /// **'水を飲む'**
  String get taskTemplateWater;

  /// No description provided for @taskTemplateWaterDesc.
  ///
  /// In ja, this message translates to:
  /// **'コップ一杯の水を飲む瞬間を撮ろう'**
  String get taskTemplateWaterDesc;

  /// No description provided for @taskTemplateCustom.
  ///
  /// In ja, this message translates to:
  /// **'自分で決める'**
  String get taskTemplateCustom;

  /// No description provided for @taskTemplateCustomDesc.
  ///
  /// In ja, this message translates to:
  /// **'好きなヒーロータスクを自由に設定しよう'**
  String get taskTemplateCustomDesc;

  /// No description provided for @adVeffectLabel.
  ///
  /// In ja, this message translates to:
  /// **'VEFFECT 広告'**
  String get adVeffectLabel;

  /// No description provided for @postSuccessDaysUntilNext.
  ///
  /// In ja, this message translates to:
  /// **'{label} まで あと{days}日'**
  String postSuccessDaysUntilNext(String label, int days);

  /// No description provided for @defaultUsername.
  ///
  /// In ja, this message translates to:
  /// **'ユーザー'**
  String get defaultUsername;

  /// No description provided for @vPracticeDistributeBadge.
  ///
  /// In ja, this message translates to:
  /// **'全ユーザーへバッジ配布'**
  String get vPracticeDistributeBadge;

  /// No description provided for @vPracticeCreateBlog.
  ///
  /// In ja, this message translates to:
  /// **'ブログ記事を作成'**
  String get vPracticeCreateBlog;

  /// No description provided for @vPracticeError.
  ///
  /// In ja, this message translates to:
  /// **'エラーが発生しました'**
  String get vPracticeError;

  /// No description provided for @vPracticeNoNews.
  ///
  /// In ja, this message translates to:
  /// **'お知らせはまだありません'**
  String get vPracticeNoNews;

  /// No description provided for @vPracticeCategoryAll.
  ///
  /// In ja, this message translates to:
  /// **'すべて'**
  String get vPracticeCategoryAll;

  /// No description provided for @vPracticeBadgeIdRequired.
  ///
  /// In ja, this message translates to:
  /// **'バッジID（または tester など）を入力してください'**
  String get vPracticeBadgeIdRequired;

  /// No description provided for @vPracticeBadgeDistributed.
  ///
  /// In ja, this message translates to:
  /// **'全ユーザーにバッジ「{badgeUrl}」を配布・装備させました！'**
  String vPracticeBadgeDistributed(String badgeUrl);

  /// No description provided for @vPracticeBadgeDistributeFailed.
  ///
  /// In ja, this message translates to:
  /// **'バッジの配布に失敗しました'**
  String get vPracticeBadgeDistributeFailed;

  /// No description provided for @vPracticeDialogTitle.
  ///
  /// In ja, this message translates to:
  /// **'全ユーザーへバッジ配布'**
  String get vPracticeDialogTitle;

  /// No description provided for @vPracticeDialogDesc.
  ///
  /// In ja, this message translates to:
  /// **'現在登録されている全てのユーザーに、指定したバッジを強制的に装備させます。通知は飛びません。'**
  String get vPracticeDialogDesc;

  /// No description provided for @vPracticeBadgeIdHint.
  ///
  /// In ja, this message translates to:
  /// **'バッジID (例: tester)'**
  String get vPracticeBadgeIdHint;

  /// No description provided for @vPracticeCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get vPracticeCancel;

  /// No description provided for @vPracticeDistribute.
  ///
  /// In ja, this message translates to:
  /// **'配布する'**
  String get vPracticeDistribute;

  /// No description provided for @mutualFollowedBy.
  ///
  /// In ja, this message translates to:
  /// **'{userNames}がフォローしています'**
  String mutualFollowedBy(String userNames);

  /// No description provided for @mutualFollowedByAndOthers.
  ///
  /// In ja, this message translates to:
  /// **'{userNames}、他{count}人がフォローしています'**
  String mutualFollowedByAndOthers(String userNames, int count);

  /// No description provided for @timeNow.
  ///
  /// In ja, this message translates to:
  /// **'今'**
  String get timeNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In ja, this message translates to:
  /// **'{count}分'**
  String timeMinutesAgo(int count);

  /// No description provided for @timeHoursAgo.
  ///
  /// In ja, this message translates to:
  /// **'{count}時間'**
  String timeHoursAgo(int count);

  /// No description provided for @timeDaysAgo.
  ///
  /// In ja, this message translates to:
  /// **'{count}日'**
  String timeDaysAgo(int count);

  /// No description provided for @blogPostEditorSaveDraft.
  ///
  /// In ja, this message translates to:
  /// **'下書きとして保存'**
  String get blogPostEditorSaveDraft;

  /// No description provided for @blogPostEditorStatusDraft.
  ///
  /// In ja, this message translates to:
  /// **'下書き'**
  String get blogPostEditorStatusDraft;

  /// No description provided for @blogPostEditorPublish.
  ///
  /// In ja, this message translates to:
  /// **'公開する'**
  String get blogPostEditorPublish;

  /// No description provided for @blogPostEditorSaveAndPublish.
  ///
  /// In ja, this message translates to:
  /// **'公開して保存'**
  String get blogPostEditorSaveAndPublish;

  /// No description provided for @blogPostEditorUpdateAndPublish.
  ///
  /// In ja, this message translates to:
  /// **'公開して更新'**
  String get blogPostEditorUpdateAndPublish;

  /// No description provided for @blogPostEditorRevertToDraft.
  ///
  /// In ja, this message translates to:
  /// **'下書きに戻す'**
  String get blogPostEditorRevertToDraft;

  /// No description provided for @forceUpdateTitle.
  ///
  /// In ja, this message translates to:
  /// **'アップデートが必要です'**
  String get forceUpdateTitle;

  /// No description provided for @forceUpdateBtn.
  ///
  /// In ja, this message translates to:
  /// **'アップデートする'**
  String get forceUpdateBtn;

  /// No description provided for @taskReminderTitle.
  ///
  /// In ja, this message translates to:
  /// **'🔔 リマインダー時間 (任意)'**
  String get taskReminderTitle;

  /// No description provided for @taskReminderNone.
  ///
  /// In ja, this message translates to:
  /// **'なし'**
  String get taskReminderNone;

  /// No description provided for @taskReminderMorning.
  ///
  /// In ja, this message translates to:
  /// **'朝 8:00'**
  String get taskReminderMorning;

  /// No description provided for @taskReminderNoon.
  ///
  /// In ja, this message translates to:
  /// **'昼 12:00'**
  String get taskReminderNoon;

  /// No description provided for @taskReminderNight.
  ///
  /// In ja, this message translates to:
  /// **'夜 21:00'**
  String get taskReminderNight;

  /// No description provided for @taskReminderCustom.
  ///
  /// In ja, this message translates to:
  /// **'カスタム'**
  String get taskReminderCustom;

  /// No description provided for @taskReminderPickerTitle.
  ///
  /// In ja, this message translates to:
  /// **'時間の選択'**
  String get taskReminderPickerTitle;

  /// No description provided for @heroTasksPublishConfirmTitle.
  ///
  /// In ja, this message translates to:
  /// **'全体公開にしますか？'**
  String get heroTasksPublishConfirmTitle;

  /// No description provided for @heroTasksPublishConfirmDesc.
  ///
  /// In ja, this message translates to:
  /// **'この投稿をVタイムライン（全体公開）に公開しますか？'**
  String get heroTasksPublishConfirmDesc;

  /// No description provided for @heroTasksPublishButton.
  ///
  /// In ja, this message translates to:
  /// **'公開する'**
  String get heroTasksPublishButton;

  /// No description provided for @heroTasksUnpublishConfirmTitle.
  ///
  /// In ja, this message translates to:
  /// **'非公開に戻しますか？'**
  String get heroTasksUnpublishConfirmTitle;

  /// No description provided for @heroTasksUnpublishConfirmDesc.
  ///
  /// In ja, this message translates to:
  /// **'この投稿をVタイムラインから非公開に戻しますか？'**
  String get heroTasksUnpublishConfirmDesc;

  /// No description provided for @heroTasksUnpublishButton.
  ///
  /// In ja, this message translates to:
  /// **'非公開にする'**
  String get heroTasksUnpublishButton;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'ja': return AppLocalizationsJa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
