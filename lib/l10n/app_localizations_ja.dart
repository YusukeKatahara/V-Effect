// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsDisplay => '表示とデザイン';

  @override
  String get themeSetting => 'テーマ設定';

  @override
  String get themeDescription => 'アプリの見た目を切り替えます。';

  @override
  String get themeLight => 'ライトモード';

  @override
  String get themeDark => 'ダークモード';

  @override
  String get themeSystem => 'システム設定に同期';

  @override
  String get languageSetting => '言語設定 / Language';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageEnglish => 'ENGLISH';

  @override
  String get errorCannotOpenLink => 'リンクを開けませんでした';

  @override
  String get settingsNotification => '通知';

  @override
  String get settingsPasswordSecurity => 'パスワードとセキュリティ';

  @override
  String get settingsSupportLegal => 'サポート・法的情報';

  @override
  String get settingsContactBugReport => 'お問い合わせ / バグ報告';

  @override
  String get settingsTerms => '利用規約';

  @override
  String get settingsPrivacyPolicy => 'プライバシーポリシー';

  @override
  String get settingsVersionInfo => 'バージョン情報';

  @override
  String get loginTagline => '日々の努力を、仲間と共に。';

  @override
  String get loginEmailOrId => 'メールアドレスまたはユーザーID';

  @override
  String get loginPassword => 'パスワード';

  @override
  String get loginForgotPassword => 'パスワードをお忘れですか？';

  @override
  String get loginButton => 'ログイン';

  @override
  String get loginOrDivider => 'または';

  @override
  String get loginWithApple => 'Appleでログイン';

  @override
  String get loginWithGoogle => 'Googleでログイン';

  @override
  String get loginNoAccount => 'アカウントをお持ちでないですか？';

  @override
  String get loginRegister => '新規登録';

  @override
  String get loginContactSupport => 'ログインできない等のご相談・お問い合わせ';

  @override
  String get loginByLoggingIn => 'ログインすることで、';

  @override
  String get loginAnd => 'および';

  @override
  String get loginAgreeTerms => 'に同意したものとみなされます。';

  @override
  String get loginFailed => 'ログインに失敗しました';

  @override
  String get loginErrorIdOrPassword => 'ユーザーIDまたはパスワードが間違っています';

  @override
  String get loginErrorUserNotFound => 'ユーザーが見つかりません';

  @override
  String get loginErrorWrongPassword => 'パスワードが間違っています';

  @override
  String get loginErrorInvalidCredential => 'メールアドレスまたはパスワードが間違っています';

  @override
  String get loginAppleFailed => 'Appleでのログインに失敗しました';

  @override
  String get loginGoogleFailed => 'Googleでのログインに失敗しました';

  @override
  String get registerCreateAccount => 'アカウントを作成';

  @override
  String get registerSubtitle => 'V EFFECTに参加して仲間と高め合おう';

  @override
  String get registerEmail => 'メールアドレス';

  @override
  String get registerEmailRequired => 'メールアドレスを入力してください';

  @override
  String get registerPasswordRequired => 'パスワードを入力してください';

  @override
  String get registerPasswordMinLength => '6文字以上で入力してください';

  @override
  String get registerPasswordConfirm => 'パスワード（確認）';

  @override
  String get registerPasswordReenter => 'パスワードを再入力してください';

  @override
  String get registerPasswordMismatch => 'パスワードが一致しません';

  @override
  String get registerAgreeToSuffix => 'に同意する';

  @override
  String get registerFailed => '登録に失敗しました。';

  @override
  String get registerEmailInUse => 'このメールアドレスは既に使われています。';

  @override
  String get registerWeakPassword => 'パスワードは6文字以上にしてください。';

  @override
  String get registerFailedRetry => '登録に失敗しました。しばらくしてからお試しください。';

  @override
  String get registerAppleFailed => 'Appleでの登録に失敗しました。';

  @override
  String get registerGoogleFailed => 'Googleでの登録に失敗しました。';

  @override
  String get registerWithApple => 'Appleで作成';

  @override
  String get registerWithGoogle => 'Googleで作成';

  @override
  String get forgotPasswordResetTitle => 'パスワードリセット';

  @override
  String get forgotPasswordInstruction => 'ユーザーIDと登録メールアドレスを入力してください';

  @override
  String get forgotPasswordBothRequired => 'ユーザーIDとメールアドレスを入力してください';

  @override
  String get forgotPasswordInvalid => '入力内容が一致するアカウントが見つかりませんでした';

  @override
  String get forgotPasswordUserId => 'ユーザーID';

  @override
  String get forgotPasswordSendReset => 'リセットメールを送信';

  @override
  String get forgotPasswordEmailSent => 'メールを送信しました';

  @override
  String forgotPasswordEmailSentDesc(String email) {
    return '$email 宛に\nパスワードリセット用のメールを送信しました。';
  }

  @override
  String get forgotPasswordResetViaLink => 'リンクからパスワードを再設定する';

  @override
  String get forgotPasswordBackToLogin => 'ログイン画面に戻る';

  @override
  String get forgotPasswordResend => 'メールが届かない場合は再送信';

  @override
  String get resetPasswordTitle => 'パスワード再設定';

  @override
  String get resetPasswordLinkInvalid => 'リンクが無効です';

  @override
  String get resetPasswordLinkExpired => 'リンクの有効期限が切れています';

  @override
  String get resetPasswordLinkInvalidPaste =>
      'リンクが正しくありません。メールのリンクをそのまま貼り付けてください';

  @override
  String get resetPasswordPasteLink => 'リンクを貼り付けてください';

  @override
  String get resetPasswordMismatch => 'パスワードが一致しません';

  @override
  String get resetPasswordFailed => 'パスワードの再設定に失敗しました';

  @override
  String get resetPasswordWeakPassword => 'パスワードは6文字以上にしてください';

  @override
  String get resetPasswordPasteLinkTitle => 'リンクを貼り付ける';

  @override
  String get resetPasswordPasteLinkDesc =>
      'パスワードリセットメールに記載されているリンクをコピーして貼り付けてください';

  @override
  String get resetPasswordPasteLinkLabel => 'パスワードリセットリンク';

  @override
  String get resetPasswordNext => '次へ';

  @override
  String get resetPasswordNewTitle => '新しいパスワードを設定';

  @override
  String get resetPasswordNew => '新しいパスワード';

  @override
  String get resetPasswordConfirm => 'パスワード（確認）';

  @override
  String get resetPasswordButton => 'パスワードを更新する';

  @override
  String get resetPasswordDone => 'パスワードを更新しました';

  @override
  String get resetPasswordLoginWithNew => '新しいパスワードでログインしてください';

  @override
  String get resetPasswordGoToLogin => 'ログイン画面へ';

  @override
  String get errorGenericRetry => 'エラーが発生しました。しばらくしてからお試しください';

  @override
  String get weeklyReviewSelectBackground => '背景画像を選択';

  @override
  String get weeklyReviewNoPostsDefault => '今週の投稿はまだありません。\nデフォルトの背景でシェアします。';

  @override
  String get weeklyReviewShareWithoutBackground => '背景画像なしでシェア';

  @override
  String weeklyReviewLoadError(Object error) {
    return '読み込みエラー: $error';
  }

  @override
  String get weeklyReviewShareToSns => 'SNSへシェア';

  @override
  String get weeklyReviewStatTasks => '今週のタスク';

  @override
  String get weeklyReviewStatStreak => '連続達成';

  @override
  String get weeklyReviewStatVFire => '累計VFIRE';

  @override
  String get weeklyReviewStatReactions => 'リアクション';

  @override
  String get weeklyReviewNoPosts => '今週の投稿はまだありません';

  @override
  String get weeklyReviewReplay => '今週の振り返りをもう一度見る';

  @override
  String get weeklyReviewTitle => '今週のハイライト';

  @override
  String weeklyReviewMostSentTo(String name, int count) {
    return 'あなたは今週、$nameさんに一番多くV FIRE（合計$count回）を送りました！';
  }

  @override
  String weeklyReviewMostReceivedFrom(String name, int count) {
    return 'あなたは今週、$nameさんから一番多くV FIRE（合計$count回）を送られました！';
  }

  @override
  String weeklyReviewMostActiveDay(String day, int count) {
    return '今週最もモチベーションが高かったのは $day でした！（タスクを $count 個完了！）';
  }

  @override
  String weeklyReviewGoldenTime(String range) {
    return '今週の集中ゴールデンタイムは【$range】でした！集中力が際立っています。';
  }

  @override
  String weeklyReviewBuddyTask(String task, int count) {
    return '今週の相棒タスクは『$task』でした！（今週だけで $count 回クリア！）';
  }

  @override
  String get weeklyReviewNoInteractions => 'フレンドの投稿にV FIREを送って、お互いを鼓舞しましょう！';

  @override
  String get weeklyReviewAiAnalyticsTitle => 'AIデータアナリティクス';

  @override
  String get weeklyReviewAiActionApplied => '✨ 設定を変更完了';

  @override
  String get weeklyReviewAiActionToast => '⚡️ 来週の目標時間を自動最適化しました！';

  @override
  String get weekdayMonday => '月曜日';

  @override
  String get weekdayTuesday => '火曜日';

  @override
  String get weekdayWednesday => '水曜日';

  @override
  String get weekdayThursday => '木曜日';

  @override
  String get weekdayFriday => '金曜日';

  @override
  String get weekdaySaturday => '土曜日';

  @override
  String get weekdaySunday => '日曜日';

  @override
  String get timeRangeMorning => '朝（5:00〜12:00）';

  @override
  String get timeRangeAfternoon => '昼（12:00〜18:00）';

  @override
  String get timeRangeEvening => '夜（18:00〜24:00）';

  @override
  String get timeRangeLateNight => '深夜（0:00〜5:00）';

  @override
  String get authWrapperConnecting => '接続に時間がかかっています...';

  @override
  String get authWrapperRetry => '再試行';

  @override
  String firestoreReadError(Object error) {
    return 'Firestore読み込みエラー: $error';
  }

  @override
  String get followListNoUsers => 'ユーザーがいません';

  @override
  String get followListFollowing => 'フォロー中';

  @override
  String get followListFollowers => 'フォロワー';

  @override
  String get followListPendingBanner => 'フォロー申請が届いています';

  @override
  String get followListMe => '自分';

  @override
  String get qrScannerTitle => 'QRスキャン';

  @override
  String get qrScannerFlashlight => 'フラッシュライト';

  @override
  String get qrScannerUserNotFound => 'ユーザーが見つかりません';

  @override
  String qrScannerError(Object error) {
    return 'エラーが発生しました: $error';
  }

  @override
  String get qrScannerNoQrInImage => '画像からQRコードが見つかりませんでした';

  @override
  String get qrScannerScanLabel => 'QRコードをスキャン';

  @override
  String get qrScannerInstruction => '枠内にQRコードを写してください';

  @override
  String get qrScannerPickFromGallery => 'フォルダーから選択';

  @override
  String get qrDisplayTitle => 'QRコード';

  @override
  String get qrDisplaySaved => 'QRコードを保存しました';

  @override
  String qrDisplaySaveFailed(Object error) {
    return '保存に失敗しました: $error';
  }

  @override
  String get qrDisplaySaving => '保存中...';

  @override
  String get qrDisplayDownload => 'ダウンロード';

  @override
  String get pendingRequestsTitle => 'フォロー申請';

  @override
  String get pendingRequestsEmpty => '申請はありません';

  @override
  String pendingRequestsAcceptFailed(Object error) {
    return '承認に失敗しました: $error';
  }

  @override
  String pendingRequestsRejectFailed(Object error) {
    return '拒否に失敗しました: $error';
  }

  @override
  String get pendingRequestsAccept => '承認';

  @override
  String get pendingRequestsReject => '拒否';

  @override
  String get initialFriendTitle => 'フレンド登録';

  @override
  String get initialFriendSubtitle => '一緒に頑張る仲間を登録しよう！';

  @override
  String get initialFriendWhoInvited => '誰に誘われましたか？';

  @override
  String get initialFriendOtherUser => 'その他のユーザー：ユーザーIDを入力';

  @override
  String get initialFriendUserIdLabel => 'ユーザーID';

  @override
  String initialFriendSentCount(int count) {
    return '$count件のフレンドリクエストを送信しました！';
  }

  @override
  String get initialFriendSendFailed => '送信に失敗しました。もう一度お試しください。';

  @override
  String get initialFriendRegister => '登録する';

  @override
  String get initialFriendLater => 'あとで登録する';

  @override
  String get emailVerificationTitle => 'メールアドレスの認証';

  @override
  String get emailVerificationHeading => 'メールアドレスを認証してください';

  @override
  String emailVerificationSent(String email) {
    return '$email\nに認証メールを送信しました。\nメール内のリンクをタップして認証を完了してください。';
  }

  @override
  String get emailVerificationSpamNote => 'メールが届かない場合は、迷惑メールフォルダやゴミ箱をご確認ください。';

  @override
  String get emailVerificationNotYet => 'まだ認証が完了していません。メールをご確認ください。';

  @override
  String emailVerificationResendCooldown(int seconds) {
    return '$seconds秒後に再送信できます。';
  }

  @override
  String get emailVerificationResent => '認証メールを再送信しました。';

  @override
  String get emailVerificationResendFailed => '送信に失敗しました。しばらくしてからお試しください。';

  @override
  String get emailVerificationConfirmButton => '認証を確認';

  @override
  String get emailVerificationResendButton => '認証メールを再送信';

  @override
  String get notificationSettingsTitle => '通知設定';

  @override
  String get notificationSettingsSaveFailed => '設定の保存に失敗しました';

  @override
  String get notificationSettingsPush => 'プッシュ通知を許可';

  @override
  String get notificationSettingsPushDesc => 'フォローや仲間の新しい投稿のお知らせ';

  @override
  String get notificationSettingsReaction => 'リアクション通知を許可';

  @override
  String get notificationSettingsReactionDesc => '投稿にリアクションが届いたとき';

  @override
  String get notificationSettingsVFire => 'V FIRE通知を許可';

  @override
  String get notificationSettingsVFireDesc => '投稿にV FIREが届いたとき';

  @override
  String get notificationSettingsShield => '保護シールド通知を許可';

  @override
  String get notificationSettingsShieldDesc => 'シールドによるストリーク維持のお知らせ';

  @override
  String get notificationSettingsStreakWarning => 'ストリーク危機通知を許可';

  @override
  String get notificationSettingsStreakWarningDesc =>
      '夜になってもタスクが完了していない時のリマインダー';

  @override
  String get notificationSettingsDebugTitle => '開発者向けデバッグ機能';

  @override
  String get notificationSettingsDebugResetTitle => '通知プレ・ダイアログの表示フラグをリセット';

  @override
  String get notificationSettingsDebugResetDesc => '「一度のみ表示」の制限フラグを消去します';

  @override
  String get notificationSettingsDebugResetDone => '通知ダイアログ表示フラグをリセットしました。';

  @override
  String get notificationSettingsDebugTestTitle => '通知プレ・ダイアログをテスト表示';

  @override
  String get notificationSettingsDebugTestDesc => '現在の通知許可状態に関わらずモーダルを表示します';

  @override
  String get editProfileSettingsHeader => '設定';

  @override
  String get editProfileAccount => 'アカウント';

  @override
  String get editProfileStatus => 'ステータス';

  @override
  String get editProfileNameLabel => '名前';

  @override
  String get editProfileNameRequired => '名前を入力してください';

  @override
  String get editProfileUserIdLabel => 'ユーザーID';

  @override
  String get editProfileUserIdRequired => 'ユーザーIDを入力してください';

  @override
  String get editProfileUserIdMinLength => '5文字以上で入力してください';

  @override
  String get editProfileUserIdAlphanumeric => '英数字とアンダースコアのみ使えます';

  @override
  String get editProfileInstagramIdAlphanumeric => '英数字、アンダースコア、ドットのみ使えます';

  @override
  String get editProfileWebsiteUrlInvalid => '有効なURLを入力してください';

  @override
  String get editProfileWebsiteUrlLabel => 'ウェブサイト';

  @override
  String get editProfileUserIdAlreadyUsed => 'このユーザーIDは既に使われています';

  @override
  String editProfileRestrictionMessage(int days) {
    return 'ユーザーIDは前回の変更から90日間変更できません。\nあと $days 日お待ちください。';
  }

  @override
  String editProfileChangeRestriction(int days) {
    return 'ユーザーIDの変更はあと $days 日経過するまでできません。';
  }

  @override
  String get editProfileConfirmTitle => '確認';

  @override
  String get editProfileConfirmMessage =>
      'この変更を保存すると、ユーザーIDは今後90日間変更できなくなります。\n\n本当によろしいですか？';

  @override
  String get editProfileCancel => 'キャンセル';

  @override
  String get editProfileChange => '変更';

  @override
  String get editProfileSave => '保存';

  @override
  String editProfileSaveFailed(Object error) {
    return '保存に失敗しました: $error';
  }

  @override
  String get editProfileBirthDate => '生年月日 (任意)';

  @override
  String get editProfileGender => '性別 (任意)';

  @override
  String get editProfilePickerCancel => 'キャンセル';

  @override
  String get editProfilePickerDone => '完了';

  @override
  String get editProfileBirthDatePickerTitle => '生年月日';

  @override
  String get editProfileGenderPickerTitle => '性別';

  @override
  String get editProfileBadgeLabel => 'バッジ';

  @override
  String get editProfileBadgeEquipped => '装着中';

  @override
  String get editProfileBadgeNone => '未設定';

  @override
  String get editProfileBadgeChange => '変更';

  @override
  String get editProfileBadgeSelectTitle => 'バッジを選択';

  @override
  String get editProfileBadgeOptionNone => 'なし';

  @override
  String get editProfileBadgeOptionTester => 'テスター';

  @override
  String get editProfileBadgeOptionSeason => 'シーズンバッジ';

  @override
  String get editProfileImageAdjust => '画像を調整';

  @override
  String get pastComparisonTitle => '積み重ねを振りかえる';

  @override
  String get pastComparisonSortOld => '古い順にする';

  @override
  String get pastComparisonSortNew => '新しい順にする';

  @override
  String get pastComparisonEmpty => 'まだ投稿がありません';

  @override
  String get pastComparisonTaskEmpty => 'このタスクの投稿はまだありません';

  @override
  String get pastComparisonCompare => '比較する';

  @override
  String get pastComparisonSelectTwo => '2枚選んでください';

  @override
  String get pastComparisonMode => '選択モード';

  @override
  String get pastComparisonOther => 'その他';

  @override
  String get pastComparisonSelectMode => '選択モード';

  @override
  String get pastComparisonMoveTask => 'タスクを移動';

  @override
  String get pastComparisonMoveConfirmTitle => 'タスクの移動';

  @override
  String pastComparisonMoveConfirmBody(int count, String taskName) {
    return '選択した$count件の投稿を「$taskName」に移動しますか？';
  }

  @override
  String pastComparisonMoveSuccess(int count) {
    return '$count件の投稿を移動しました';
  }

  @override
  String get pastComparisonCancel => 'キャンセル';

  @override
  String get sharePreviewTitle => 'プレビュー';

  @override
  String get previewLabel => 'プレビュー';

  @override
  String sharePreviewShareText(int count, int streak) {
    return '今週も$count回のヒーロータスクを完遂！\n現在のストリーク: $streak日 🔥\n#VEffect';
  }

  @override
  String get sharePreviewFailed => 'シェアに失敗しました。もう一度お試しください。';

  @override
  String get sharePreviewPreparing => '準備中...';

  @override
  String get sharePreviewShareButton => 'SNSへシェア';

  @override
  String heroTaskShareText(int streak) {
    return '今日のヒーロータスクを完了しました！\n現在のストリーク: $streak日 🔥\n#VEffect';
  }

  @override
  String get searchHint => 'IDまたは名前を検索';

  @override
  String get searchKeywordPrompt => '検索キーワードを入力してください';

  @override
  String get searchNoResults => 'ユーザーが見つかりませんでした';

  @override
  String searchError(Object error) {
    return '検索エラー:\n$error';
  }

  @override
  String searchUnfollowed(String username) {
    return '$usernameさんのフォローを解除しました';
  }

  @override
  String searchFollowRequestSent(String username) {
    return '$usernameさんにフォローリクエストを送りました';
  }

  @override
  String searchActionFailed(Object error) {
    return '操作に失敗しました: $error';
  }

  @override
  String get searchFollowing => 'フォロー中';

  @override
  String get searchPending => '申請中';

  @override
  String get searchFollow => 'フォロー';

  @override
  String get securitySettingsTitle => 'パスワードとセキュリティ';

  @override
  String get securityLoginRecoveryTitle => 'ログインとリカバリー';

  @override
  String get securityLoginRecoveryDesc => 'パスワード、ログイン設定、リカバリー方法を管理できます。';

  @override
  String get securityChangePassword => 'パスワードを変更';

  @override
  String get securityChangeEmail => 'メールアドレスを変更';

  @override
  String get securityVerifyEmail => 'メールアドレスを認証する';

  @override
  String get securityAccountManagementTitle => 'アカウント管理';

  @override
  String get securityAccountManagementDesc => 'アプリへのアクセスやアカウントのデータに関する設定を行います。';

  @override
  String get securityLogout => 'ログアウト';

  @override
  String get securityDeleteAccount => 'アカウントを削除';

  @override
  String get securityLinkedAccounts => '連携済みのアカウント';

  @override
  String get securityNoLinkedAccounts => 'なし';

  @override
  String get securityProviderEmail => 'メールアドレス';

  @override
  String get securityChangePasswordDialogTitle => 'パスワードを変更';

  @override
  String securityChangePasswordDialogDesc(String email) {
    return '$email 宛にパスワード再設定用のメールを送信しますか？';
  }

  @override
  String get securityChangePasswordCancel => 'キャンセル';

  @override
  String get securityChangePasswordSend => '送信';

  @override
  String get securityPasswordResetSent => '再設定メールを送信しました。メールをご確認ください。';

  @override
  String get securityChangeEmailDialogTitle => 'メールアドレスを変更';

  @override
  String get securityChangeEmailDialogDesc =>
      '新しいメールアドレスを入力してください。確認メールを送信します。';

  @override
  String get securityNewEmailLabel => '新しいメールアドレス';

  @override
  String get securityChangeEmailSend => '確認メールを送信';

  @override
  String get securityEmailVerificationSent =>
      '新しいアドレスに確認メールを送信しました。リンクをタップして変更を完了してください。';

  @override
  String get securityErrorGeneric => 'エラーが発生しました。';

  @override
  String get securityErrorRecentLogin =>
      'セキュリティのため、一度ログアウトして再度ログインしてからやり直してください。';

  @override
  String get securityErrorInvalidEmail => '無効なメールアドレスです。';

  @override
  String get securityErrorEmailInUse => 'このメールアドレスは既に登録されています。';

  @override
  String get securityLogoutConfirmTitle => 'ログアウト';

  @override
  String get securityLogoutConfirmMessage => '本当にログアウトしますか？';

  @override
  String get securityLogoutConfirmCancel => 'キャンセル';

  @override
  String get securityLogoutConfirmButton => 'ログアウト';

  @override
  String get securityDeleteConfirmTitle => 'アカウントを削除しますか？';

  @override
  String get securityDeleteConfirmDesc =>
      'プロフィール・投稿などすべてのデータが完全に削除されます。この操作は取り消せません。';

  @override
  String get securityDeleteConfirmCancel => 'キャンセル';

  @override
  String get securityDeleteConfirmButton => '削除';

  @override
  String get securityDeleteFinalTitle => '本当に削除しますか？';

  @override
  String get securityDeleteFinalDesc => 'この操作は元に戻せません。アカウントを完全に削除してよろしいですか？';

  @override
  String get securityDeleteFinalCancel => 'キャンセル';

  @override
  String get securityDeleteFinalButton => '完全に削除する';

  @override
  String get securityDeleteFailed => 'アカウントの削除に失敗しました。再ログインして再度お試しください。';

  @override
  String get userProfileNotFound => 'ユーザーが見つかりません';

  @override
  String get userProfileFollowing => 'フォロー中';

  @override
  String get userProfileFollowers => 'フォロワー';

  @override
  String get userProfileStreak => 'ストリーク';

  @override
  String get userProfileFollowRequest => 'フォローをリクエスト';

  @override
  String get userProfilePending => '申請中';

  @override
  String get userProfileHeroTasks => 'ヒーロータスク';

  @override
  String get userProfileBlock => 'ブロック';

  @override
  String get userProfileUnblock => 'ブロックを解除';

  @override
  String get userProfileReport => '通報';

  @override
  String get userProfileBlockConfirmTitle => 'ブロック';

  @override
  String get userProfileBlockConfirmDesc => 'このユーザーをブロックします。フォロー関係も解除されます。';

  @override
  String get userProfileBlockCancel => 'キャンセル';

  @override
  String get userProfileBlockButton => 'ブロック';

  @override
  String get userProfileUnblockConfirmTitle => 'ブロックを解除';

  @override
  String get userProfileUnblockConfirmDesc => 'このユーザーのブロックを解除しますか？';

  @override
  String get userProfileUnblockCancel => 'キャンセル';

  @override
  String get userProfileUnblockButton => '解除する';

  @override
  String get userProfileBlockFailed => 'ブロックに失敗しました';

  @override
  String get userProfileUnblockFailed => 'ブロック解除に失敗しました';

  @override
  String get userProfileReportTitle => '通報する理由を選択';

  @override
  String get userProfileReportSpam => 'スパム';

  @override
  String get userProfileReportHarassment => 'ハラスメント';

  @override
  String get userProfileReportInappropriate => '不適切なコンテンツ';

  @override
  String get userProfileReportOther => 'その他';

  @override
  String get userProfileReportCancel => 'キャンセル';

  @override
  String get userProfileReportDone => '通報しました。ご協力ありがとうございます。';

  @override
  String get userProfileReportAlready => '7日以内に同じユーザーへの通報があります';

  @override
  String get userProfileReportFailed => '通報に失敗しました';

  @override
  String get userProfileFollowFailed => 'フォローリクエストを送信できませんでした';

  @override
  String get blogPostDetailDeleteTitle => '記事を削除しますか？';

  @override
  String get blogPostDetailDeleteDesc => 'この操作は取り消せません。';

  @override
  String get blogPostDetailDeleteCancel => 'キャンセル';

  @override
  String get blogPostDetailDeleteButton => '削除';

  @override
  String get blogPostEditorUpdateButton => '更新';

  @override
  String get blogPostEditorPostButton => '投稿';

  @override
  String get blogPostEditorArticleUpdate => '記事を更新する';

  @override
  String get blogPostEditorArticlePost => '記事を投稿する';

  @override
  String get blogPostEditorCategoryLabel => 'カテゴリ';

  @override
  String get blogPostEditorPinLabel => 'この記事をピン留めする';

  @override
  String get blogPostEditorTitleLabel => 'タイトル';

  @override
  String get blogPostEditorTitleHint => 'タイトルを入力';

  @override
  String get blogPostEditorTitleEnLabel => 'タイトル (ENGLISH)';

  @override
  String get blogPostEditorBodyLabel => '本文';

  @override
  String get blogPostEditorBodyMarkdown => '— Markdownが使えます';

  @override
  String get blogPostEditorBodyHint => '本文を入力\n\n## 見出し\n**太字** *斜体*\n- 箇条書き';

  @override
  String get blogPostEditorBodyEnLabel => '本文 (ENGLISH)';

  @override
  String get blogPostEditorRequiredError => 'タイトルと本文を入力してください';

  @override
  String blogPostEditorSaveError(Object error) {
    return 'エラー: $error';
  }

  @override
  String get blogPostEditorPreviewEmpty => 'タイトルと本文を入力してください';

  @override
  String get blogPostEditorCoverAdd => 'カバー画像を追加';

  @override
  String get blogPostEditorCoverChange => 'カバー画像を変更';

  @override
  String get blogPostEditorSeasonNotSet => 'シーズンタスクを設定する';

  @override
  String get blogPostEditorSeasonSet => 'シーズンタスク設定済み';

  @override
  String get blogPostEditorSeasonDesc => 'このお知らせと一緒にシーズンタスクを配布・通知します。';

  @override
  String get blogPostEditorSeasonModalTitle => 'シーズンタスクの設定';

  @override
  String get blogPostEditorSeasonTaskName => 'タスク名 (必須)';

  @override
  String get blogPostEditorSeasonDuration => '実施期間(日数)';

  @override
  String get blogPostEditorSeasonHintTitle => 'ヒントタイトル';

  @override
  String get blogPostEditorSeasonHintBody => 'ヒント本文';

  @override
  String get blogPostEditorSeasonHintBodyHint => 'ユーザーが写真を撮る際のヒントを入力してください';

  @override
  String get blogPostEditorSeasonRequiredCount => '目標アクション数';

  @override
  String get blogPostEditorSeasonRequiredCountHint => '例: 1';

  @override
  String get blogPostEditorSeasonBadgeUrl => 'バッジアイコン';

  @override
  String get blogPostEditorSeasonDone => '完了';

  @override
  String get blogPostEditorPlaceholder => 'テキスト';

  @override
  String get blogPostEditorCodePlaceholder => 'コードをここに入力';

  @override
  String get blogPostEditorBadgeUploadSuccess => 'バッジ画像をアップロードしました';

  @override
  String get blogPostEditorBadgeUploadFailed => 'アップロードに失敗しました';

  @override
  String get blogPostEditorSchedulePublish => '予約投稿を設定する';

  @override
  String get blogPostEditorPublishAtLabel => '公開日時';

  @override
  String get blogPostEditorPublishAtHint => '公開日時を選択';

  @override
  String get blogPostEditorClearSchedule => '予約を解除';

  @override
  String get taskSetupTitle => 'ヒーロータスク設定';

  @override
  String get taskSetupSubtitle => 'ヒーロータスクとスケジュールをカスタマイズしましょう';

  @override
  String get taskSetupProfilePhoto => 'プロフィール写真';

  @override
  String get taskSetupSelectPhoto => '写真を選択';

  @override
  String get taskSetupHeroTasks => 'やりたいヒーロータスク';

  @override
  String taskSetupHeroTaskLabel(int index) {
    return 'ヒーロータスク $index';
  }

  @override
  String get taskSetupAddTask => 'ヒーロータスクを追加';

  @override
  String get taskSetupTimeSection => 'ヒーロータスクをいつやりたいですか？';

  @override
  String get taskSetupTimeDesc => 'この時間に通知を送ってヒーロータスクをリマインドします';

  @override
  String get taskSetupCompleteButton => '設定を完了してはじめる';

  @override
  String get taskSetupAtLeastOne => 'ヒーロータスクを1つ以上入力してください';

  @override
  String get taskSetupSaveFailed => '保存に失敗しました。もう一度お試しください。';

  @override
  String get taskSetupTimePickerTitle => 'ヒーロータスクの時間';

  @override
  String get taskSetupTimePickerCancel => 'キャンセル';

  @override
  String get taskSetupTimePickerDone => '完了';

  @override
  String get taskTemplateTitle => 'まずは一つ、やってみよう！';

  @override
  String get taskTemplateSubtitle => 'かんたんなヒーロータスクを選んで\nアプリをはじめましょう';

  @override
  String get taskTemplateSkip => 'スキップ';

  @override
  String get taskTemplateStartButton => 'アプリをはじめる';

  @override
  String get taskTemplateCustomInputLabel => 'ヒーロータスク名を入力';

  @override
  String get taskTemplateError => 'エラーが発生しました。もう一度お試しください。';

  @override
  String get profileSetupTitle => 'プロフィール設定';

  @override
  String get profileSetupSubtitle => 'あなたのプロフィールを設定しましょう';

  @override
  String get profileSetupUsernameLabel => 'ユーザー名';

  @override
  String get profileSetupUsernameRequired => 'ユーザー名を入力してください';

  @override
  String get profileSetupUserIdLabel => 'ユーザーID';

  @override
  String get profileSetupUserIdRequired => 'ユーザーIDを入力してください';

  @override
  String get profileSetupUserIdMinLength => '5文字以上で入力してください';

  @override
  String get profileSetupUserIdAlphanumeric => '英数字とアンダースコアのみ使えます';

  @override
  String get profileSetupOccupationSection => '職業（非公開情報）';

  @override
  String get profileSetupSelectPlaceholder => '選択してください';

  @override
  String get profileSetupOccupationPickerTitle => '職業を選択';

  @override
  String get profileSetupNextButton => '次へ';

  @override
  String get profileSetupUserIdAlreadyUsed => 'このユーザーIDは既に使われています';

  @override
  String get profileSetupOccupationRequired => '職業を選択してください';

  @override
  String get profileSetupSaveFailed => '保存に失敗しました。もう一度お試しください。';

  @override
  String get profileSetupPickerCancel => 'キャンセル';

  @override
  String get profileSetupPickerDone => '完了';

  @override
  String get profileScreenProfileNotFound => 'プロフィールが見つかりません';

  @override
  String get profileScreenHeroTasks => 'ヒーロータスク';

  @override
  String get profileScreenWeeklyTrend => '📈 ウィークリートレンド習慣';

  @override
  String get profileScreenAddFirstTask => '最初のタスクを追加';

  @override
  String get profileScreenQrTitle => 'QRコード';

  @override
  String get profileScreenQrDisplay => '表示する';

  @override
  String get profileScreenQrScan => '読み取る';

  @override
  String get profileScreenQrTooltip => 'QRコードで繋がる';

  @override
  String get profileScreenFollowing => 'フォロー';

  @override
  String get profileScreenFollowers => 'フォロワー';

  @override
  String get profileScreenStreak => 'ストリーク';

  @override
  String get profileScreenTotalV => 'トータルV';

  @override
  String get profileScreenCurrentRank => '現在のランク';

  @override
  String get profileScreenNextRank => '次のランク';

  @override
  String get profileScreenStreakProgress => '進捗状況';

  @override
  String profileScreenStreakDays(int count) {
    return '$count日連続';
  }

  @override
  String profileScreenStreakProgressValue(int streak, int threshold) {
    return '$streak / $threshold 日';
  }

  @override
  String get profileScreenStreakMax => '最大';

  @override
  String get tierIron => 'アイアン';

  @override
  String get tierBronze => 'ブロンズ';

  @override
  String get tierSilver => 'シルバー';

  @override
  String get tierGold => 'ゴールド';

  @override
  String get tierPlatinum => 'プラチナ';

  @override
  String get tierEmerald => 'エメラルド';

  @override
  String get tierDiamond => 'ダイヤモンド';

  @override
  String get tierMaster => 'マスター';

  @override
  String get tierGrandmaster => 'グランドマスター';

  @override
  String get tierChallenger => 'チャレンジャー';

  @override
  String get profileScreenFollowingTitle => 'フォロー中';

  @override
  String get profileScreenFollowersTitle => 'フォロワー';

  @override
  String get profileScreenTrendTitle => '📈 ウィークリートレンド習慣';

  @override
  String get profileScreenTrendEmpty => 'トレンドデータがまだありません。';

  @override
  String get profileScreenTimeUpdateFailed => '時刻の更新に失敗しました';

  @override
  String get profileScreenReviewButton => '積み重ねを振りかえる';

  @override
  String get profileScreenAddTask => 'タスクを追加';

  @override
  String get profileScreenEditTask => 'タスクを編集';

  @override
  String get profileScreenDeleteTaskTitle => '削除の確認';

  @override
  String get profileScreenDeleteTaskMessage => 'このタスクを削除しますか？';

  @override
  String get profileScreenDeleteTaskCancel => 'キャンセル';

  @override
  String get profileScreenDeleteTaskButton => '削除';

  @override
  String get profileScreenSaveTask => '保存';

  @override
  String get profileScreenTaskTriggerHint => 'トリガー（任意）';

  @override
  String get profileScreenTaskNameHint => 'タスク名';

  @override
  String get profileScreenOneTimeTaskTitle => '完了から24時間後に自動削除されます';

  @override
  String get profileScreenSecretTaskTitle => 'シークレットタスク';

  @override
  String get profileScreenSecretTaskSubtitle =>
      '友達のタイムラインでは写真がぼかされ、タスク名が非表示になります';

  @override
  String get timelineSecretTaskLabel => 'シークレットタスク';

  @override
  String get profileScreenHabitTipsTitle => '習慣化のコツ';

  @override
  String get profileScreenHabitTipsClose => '閉じる';

  @override
  String get cameraScreenTaskDefault => '今日のヒーロータスク';

  @override
  String get cameraScreenUploadFailed => '投稿に失敗しました。もう一度お試しください。';

  @override
  String get cameraScreenCaption => 'コメントを追加';

  @override
  String get cameraScreenCameraLoading => 'カメラを起動中...';

  @override
  String get cameraScreenCameraUnavailable =>
      'カメラを利用できません\n下のアルバムボタンから写真を選択してください';

  @override
  String get cameraScreenPost => '証明する';

  @override
  String get cameraScreenDragPinch => 'ドラッグ・ピンチで位置調整';

  @override
  String get cameraMusicAdd => '音楽を追加';

  @override
  String get cameraMusicRemoveBgm => 'BGMを削除';

  @override
  String get cameraMusicSearchHint => '曲名やアーティストで検索...';

  @override
  String get cameraMusicRecentSongs => '最近使った曲';

  @override
  String get cameraMusicTrends => '日本のトレンド';

  @override
  String get cameraMusicSelect => '選択';

  @override
  String get heroTasksNoTasks => 'ヒーロータスクが設定されていません';

  @override
  String get heroTasksNoTasksDesc => 'プロフィールからヒーロータスクを設定';

  @override
  String get heroTasksDeletePostTitle => '投稿を削除';

  @override
  String get heroTasksDeletePostDesc => 'この投稿を削除してもよろしいですか？\n(今日の達成記録も取り消されます)';

  @override
  String get heroTasksDeletePostCancel => 'キャンセル';

  @override
  String get heroTasksDeletePostButton => '削除';

  @override
  String get heroTasksWelcomeMessage =>
      'V EFFECTへようこそ。\nここはあなたにとって最適な環境です。\n\nまずはカメラアイコンをタップして、\n最初のVを証明しましょう。';

  @override
  String get notificationsTitle => '通知';

  @override
  String get notificationsDeleteAll => '全て削除';

  @override
  String get notificationsEmpty => '通知はありません';

  @override
  String get notificationsDeleteFailed => '削除に失敗しました。もう一度お試しください。';

  @override
  String get notificationsDeleteAllTitle => '通知を全て削除';

  @override
  String get notificationsDeleteAllMessage => '全ての通知を削除しますか？';

  @override
  String get notificationsDeleteAllCancel => 'キャンセル';

  @override
  String get notificationsDeleteAllButton => '削除';

  @override
  String get notificationsApproveRequest => 'フォローリクエストを承認しました！';

  @override
  String get notificationsRejectRequest => 'フォローリクエストを拒否しました。';

  @override
  String get notificationsApproveFailed => '承認に失敗しました。もう一度お試しください。';

  @override
  String get notificationsFollowed => 'フォローしました！';

  @override
  String get notificationsFollowFailed => 'フォローに失敗しました。';

  @override
  String get notificationsFollowing => 'フォロー中';

  @override
  String get notificationsFollowBack => 'フォローバック';

  @override
  String get notificationsApprove => '承認';

  @override
  String get notificationsReject => '拒否';

  @override
  String get notificationsDelete => '削除';

  @override
  String get notificationsSeasonTaskJoined => '期間限定タスクに参加しました！';

  @override
  String get notificationsSeasonTaskSkipped => '期間限定タスクをスキップしました。';

  @override
  String notificationsFriendAccepted(Object username) {
    return '$usernameさんがフレンド申請を承認しました';
  }

  @override
  String notificationsError(Object error) {
    return 'エラーが発生しました: $error';
  }

  @override
  String get onboardingFirstQuestQuestionText => 'あなたが理想とする姿はどんなだろう？';

  @override
  String get onboardingFirstQuestTriggerLabel => 'トリガー（任意）';

  @override
  String get onboardingFirstQuestTaskLabel => 'タスク名';

  @override
  String get onboardingFirstQuestPrivacyNote =>
      '※ トリガーは自分にのみ表示されます（他のユーザーには公開されません）';

  @override
  String get onboardingFirstQuestCompleteButton => '完了';

  @override
  String get onboardingFirstQuestSkipButton => 'スキップ';

  @override
  String onboardingFirstQuestSaveFailed(Object error) {
    return '保存に失敗しました: $error';
  }

  @override
  String get timeframeMorning => '☀️ 朝';

  @override
  String get timeframeAfternoon => '🌆 昼';

  @override
  String get timeframeNight => '🌙 夜';

  @override
  String get onboardingFirstQuestSuggestedTriggerTitle => 'おすすめのきっかけ（タップで選択）';

  @override
  String get onboardingFirstQuestSuggestedTaskTitle => 'おすすめのタスク（タップで選択）';

  @override
  String get morningTrigger1 => '朝起きたら';

  @override
  String get morningTrigger2 => 'ベッドから出たら';

  @override
  String get morningTrigger3 => '朝食の前に';

  @override
  String get morningTask1 => '水を飲む';

  @override
  String get morningTask2 => 'ToDoを書く';

  @override
  String get morningTask3 => 'ワークアウト';

  @override
  String get afternoonTrigger1 => 'お昼ご飯を食べ終えたら';

  @override
  String get afternoonTrigger2 => 'スマホを開く前に';

  @override
  String get afternoonTrigger3 => 'PCを閉じるタイミングで';

  @override
  String get afternoonTask1 => 'スマホを10分置く';

  @override
  String get afternoonTask2 => '本のページをめくる';

  @override
  String get afternoonTask3 => 'デスクのゴミを1つ捨てる';

  @override
  String get nightTrigger1 => 'お風呂から上がったら';

  @override
  String get nightTrigger2 => '布団に入る前に';

  @override
  String get nightTrigger3 => '22時になったら';

  @override
  String get nightTask1 => '寝る前スマホをやめる';

  @override
  String get nightTask2 => '今日良かったことを3つ書く';

  @override
  String get nightTask3 => '明日の予定を1つ書く';

  @override
  String get onboardingFirstQuestHabitTipsTitle => '習慣化のコツ';

  @override
  String get onboardingProfileWelcome => 'V EFFECT へようこそ';

  @override
  String get onboardingProfileSubtitle => 'プロフィールを設定しましょう';

  @override
  String get onboardingProfileUsernameLabel => 'ユーザー名';

  @override
  String get onboardingProfileUsernameHint => '表示名を入力してください';

  @override
  String get onboardingProfileUsernameRequired => 'ユーザー名を入力してください';

  @override
  String get onboardingProfileUserIdLabel => 'ユーザーID';

  @override
  String get onboardingProfileUserIdMinLength => '5文字以上で入力してください';

  @override
  String get onboardingProfileUserIdAlphanumeric => '英数字とアンダースコアのみ使えます';

  @override
  String get onboardingProfileUserIdRequired => 'ユーザーIDを入力してください';

  @override
  String get onboardingProfileUserIdAlreadyUsed => 'このユーザーIDは既に使われています';

  @override
  String onboardingProfileSaveFailed(Object error) {
    return '保存に失敗しました: $error';
  }

  @override
  String get onboardingProfileStartButton => '最初の V を証明する →';

  @override
  String get onboardingProfileHelperText => '5文字以上・英数字とアンダースコアのみ';

  @override
  String get onboardingProfileImageAdjust => '画像を調整';

  @override
  String get notificationPromptTitle => '「仲間の努力」を習慣の味方にしますか？';

  @override
  String get notificationPromptDesc =>
      'V EFFECTで最も強い習慣化の力は「仲間の存在」です。\n\n通知をONにすることで、仲間の達成がリアルタイムにあなたの刺激になり、あなたの努力も仲間に届きます。\nお互いの存在を背中に感じながら、強固な習慣を築きましょう。';

  @override
  String get notificationPromptNext => '次へ';

  @override
  String get notificationPromptLater => '今はしない';

  @override
  String get friendInviteTitle => 'V (勝利) を仲間と証明しよう！';

  @override
  String get friendInviteDesc =>
      '最初のV Questの設定が完了しました！\n努力と勝利を共有するフレンドを誘いましょう！';

  @override
  String get friendInviteShareButton => '友達を招待する (LINE等でシェア)';

  @override
  String get friendInviteQrButton => 'すでにやっている友達と繋がる (QRコード)';

  @override
  String get friendInviteLater => '今はしない';

  @override
  String get friendInviteQrTitle => 'QRコード';

  @override
  String get friendInviteQrDisplay => 'マイQRコードを表示';

  @override
  String get friendInviteQrScan => 'QRコードをスキャン';

  @override
  String get weeklyReviewBannerTitle => '今週の振り返りが届いています！';

  @override
  String get globalErrorTitle => '申し訳ありません';

  @override
  String get globalErrorDesc => 'アプリの起動中に問題が発生しました。';

  @override
  String get globalErrorRetry => '再試行';

  @override
  String get globalErrorUnknown => '未知のエラー';

  @override
  String get seasonHintDefaultTitle => 'シーズンタスクのヒント💡';

  @override
  String get seasonHintDefaultBody => 'このシーズンタスクを習慣にするためのアドバイスです。';

  @override
  String get seasonHintReadBlog => '開発者の想い・経緯を読む';

  @override
  String get seasonHintTriggerLabel => 'あなたのトリガー（きっかけ）';

  @override
  String get seasonHintTriggerHint => '例: 朝起きたら、通勤電車で';

  @override
  String get seasonHintSaveButton => 'トリガーを保存';

  @override
  String get postSuccessStreakContinuing => '継続中';

  @override
  String homeWeeklyReviewLoadFailed(String code) {
    return '振り返りデータの取得に失敗しました ($code)';
  }

  @override
  String get homeUnexpectedError => '予期せぬエラーが発生しました';

  @override
  String get homeBlockUser => 'ユーザーをブロック';

  @override
  String get homeReportPost => '不適切な投稿を通報する';

  @override
  String get homeBlockConfirmTitle => 'ブロックしますか？';

  @override
  String get homeBlockConfirmDesc => 'このユーザーの投稿が表示されなくなります。';

  @override
  String get homeBlockConfirmCancel => 'キャンセル';

  @override
  String get homeBlockSuccess => 'ユーザーをブロックしました';

  @override
  String get homeBlockFailed => 'ブロックに失敗しました';

  @override
  String get homeBlockButton => 'ブロックする';

  @override
  String get homeReportTitle => '通報する理由を選択';

  @override
  String get homeReportSpam => 'スパム';

  @override
  String get homeReportHarassment => 'ハラスメント';

  @override
  String get homeReportInappropriate => '不適切なコンテンツ';

  @override
  String get homeReportOther => 'その他';

  @override
  String get homeReportCancel => 'キャンセル';

  @override
  String get homeReportSuccess => '通報しました。ご協力ありがとうございます。';

  @override
  String get homeReportFailed => '通報に失敗しました';

  @override
  String get homeErrorOccurred => 'エラーが発生しました';

  @override
  String get homeRetry => '再試行';

  @override
  String homeFriendRequestApproveFailed(Object error) {
    return '承認に失敗しました: $error';
  }

  @override
  String homeFriendRequestProcessFailed(Object error) {
    return '処理に失敗しました: $error';
  }

  @override
  String get homeNewsTitle => '運営からのお知らせ';

  @override
  String get homeMotivationText1 => 'あなたはトップランナーだ。';

  @override
  String get homeMotivationText2 => '小さな選択、小さな勝利が証拠となり\n理想とする自分が真実になる。';

  @override
  String get homeEmojiReactionHint => 'タップして絵文字で応援！';

  @override
  String get homeFriendPostsTitle => '仲間の努力が届いています';

  @override
  String get homeStreakResetMessage =>
      'ストリークが止まったとしても、\nあなたの歩みさえ止まらなければ\nV EFFECTは何度でも引き起こせる。';

  @override
  String get vEffectCoreTitle => 'V EFFECT の使い方';

  @override
  String get vEffectStep1Title => '1. 習慣化したい（やりたい）ことを決めよう';

  @override
  String get vEffectStep1Desc => 'あなたが習慣化したい（やりたい）ことを決めます。';

  @override
  String get vEffectStep2Title => '2. 写真付きで証明しよう';

  @override
  String get vEffectStep2Desc => '勝利したタスク（読書、勉強、ワークアウトなど）を証明しましょう。';

  @override
  String get vEffectConceptFootnotePrefix => '※ 小さな勝利を記録することにより脳科学における';

  @override
  String get vEffectConceptFootnoteHighlight => 'V EFFECT『勝利者効果』';

  @override
  String get vEffectConceptFootnoteSuffix => 'を引き起こし、あなたの継続する力を科学的にサポートします。';

  @override
  String get vEffectJoinButton => 'V EFFECT に参加する →';

  @override
  String get adLabel => '広告';

  @override
  String get dateFormatFull => 'yyyy年M月d日';

  @override
  String heroTaskSeasonDaysLeft(int days) {
    return 'SEASON | 残り$days日';
  }

  @override
  String homeFriendRequestMultiple(String username, int count) {
    return '$usernameさん他$count名から申請が届いています';
  }

  @override
  String get homePostToSeeFriends => '（更新）タスクを投稿してフレンドの投稿を見れる状態にしよう！';

  @override
  String get homeProveVictory => 'Victory を証明しましょう';

  @override
  String get homeNewPostsAvailable => '新しい投稿があります';

  @override
  String get editProfileGenderMale => '男性';

  @override
  String get editProfileGenderFemale => '女性';

  @override
  String get editProfileGenderOther => 'その他';

  @override
  String get blogEditorTextBlockPlaceholder => 'テキスト';

  @override
  String get blogEditorCodeBlockPlaceholder => 'コードをここに入力';

  @override
  String blogEditorSeasonDays(String days) {
    return '$days日間';
  }

  @override
  String get blogEditorExampleTaskHint => '例: 感謝を伝える';

  @override
  String get blogEditorExampleDurationHint => '例: 7';

  @override
  String get blogEditorExampleTesterHint => '例: tester (またはFirebase URL)';

  @override
  String get blogEditorImageUploadTooltip => '画像を選択してアップロード';

  @override
  String initialFriendAtUserNotFound(String userId) {
    return '@$userId: ユーザーが見つかりません';
  }

  @override
  String initialFriendAtSendFailed(String userId) {
    return '@$userId: 送信に失敗しました';
  }

  @override
  String initialFriendOtherUserNotFound(String userId) {
    return '$userId: ユーザーが見つかりません';
  }

  @override
  String initialFriendOtherSendFailed(String userId) {
    return '$userId: 送信に失敗しました';
  }

  @override
  String get initialFriendExampleIdHint => '例: user_123';

  @override
  String hintExampleFormat(String value) {
    return '例: $value';
  }

  @override
  String get firstQuestTaskHint1 => 'ジム';

  @override
  String get firstQuestTaskHint2 => '英語学習';

  @override
  String get firstQuestTaskHint3 => '部屋 of 掃除';

  @override
  String get firstQuestTaskHint4 => 'ランニング';

  @override
  String get firstQuestTaskHint5 => '栄養管理';

  @override
  String get firstQuestTriggerHint1 => '朝起きたら';

  @override
  String get firstQuestTriggerHint2 => '帰宅したら';

  @override
  String get firstQuestTriggerHint3 => 'お風呂から上がったら';

  @override
  String get firstQuestTriggerHint4 => '机に座ったら';

  @override
  String get onboardingFirstQuestTriggerHintText => 'トリガーを入力（任意）';

  @override
  String get onboardingFirstQuestTaskHintText => 'タスク名を入力';

  @override
  String get onboardingFirstQuestTimeframeHeader => '時間帯から選ぶ';

  @override
  String get firstQuestTitle => '習慣化したい(やりたい)ことを決めましょう';

  @override
  String get firstQuestNoTaskPlaceholder => '（タスク）';

  @override
  String get firstQuestKeyword1 => '勝利';

  @override
  String get firstQuestKeyword2 => '努力';

  @override
  String get firstQuestKeyword3 => '達成感';

  @override
  String get firstQuestKeyword4 => '目標';

  @override
  String get firstQuestKeyword5 => '習慣化';

  @override
  String get firstQuestKeyword6 => '継続';

  @override
  String get onboardingProfileExampleIdHint => '例: v_effect';

  @override
  String get categoryOther => 'その他';

  @override
  String get habitStackingHint =>
      '• ハビットスタッキング\n既存の習慣をトリガーにして新しい習慣を取り入れよう。\n例）カーテンを開けたら→ToDoリストを書く';

  @override
  String get temptationBundlingHint =>
      '• テンプテーションバンドリング\n「やるべきこと」と「やりたいこと」をセットにしよう。\n例）デスクワークの時だけ、お気に入りのコーヒー（またはお菓子）を飲む。';

  @override
  String get profileNoTaskPlaceholder => '（タスク）';

  @override
  String get occupationEmployee => '会社員';

  @override
  String get occupationExecutive => '経営者・役員';

  @override
  String get occupationCivilServant => '公務員';

  @override
  String get occupationSelfEmployed => '自営業・フリーランス';

  @override
  String get occupationProfessional => '専門職（医師・弁護士など）';

  @override
  String get occupationEducation => '教員・教育関係';

  @override
  String get occupationStudent => '学生';

  @override
  String get occupationPartTime => 'パート・アルバイト';

  @override
  String get occupationHomemaker => '専業主婦・主夫';

  @override
  String get occupationUnemployed => '無職';

  @override
  String get occupationOther => 'その他';

  @override
  String get hintNameExample => '例: V EFFECT';

  @override
  String timeHour(int hour) {
    return '$hour時';
  }

  @override
  String timeMinute(String minute) {
    return '$minute分';
  }

  @override
  String get timePeriodAm => '午前';

  @override
  String get timePeriodPm => '午後';

  @override
  String get hintTaskExample => '例: ランニング3km';

  @override
  String get taskTemplateBook => '本を開く';

  @override
  String get taskTemplateBookDesc => '好きな本を開いて写真を撮ろう';

  @override
  String get taskTemplateBreathing => '外で深呼吸する';

  @override
  String get taskTemplateBreathingDesc => '外に出て深呼吸している瞬間を撮ろう';

  @override
  String get taskTemplateWater => '水を飲む';

  @override
  String get taskTemplateWaterDesc => 'コップ一杯の水を飲む瞬間を撮ろう';

  @override
  String get taskTemplateCustom => '自分で決める';

  @override
  String get taskTemplateCustomDesc => '好きなヒーロータスクを自由に設定しよう';

  @override
  String get adVeffectLabel => 'VEFFECT 広告';

  @override
  String postSuccessDaysUntilNext(String label, int days) {
    return '$label まで あと$days日';
  }

  @override
  String get defaultUsername => 'ユーザー';

  @override
  String get vPracticeDistributeBadge => '全ユーザーへバッジ配布';

  @override
  String get vPracticeCreateBlog => 'ブログ記事を作成';

  @override
  String get vPracticeError => 'エラーが発生しました';

  @override
  String get vPracticeNoNews => 'お知らせはまだありません';

  @override
  String get vPracticeCategoryAll => 'すべて';

  @override
  String get vPracticeBadgeIdRequired => 'バッジID（または tester など）を入力してください';

  @override
  String vPracticeBadgeDistributed(String badgeUrl) {
    return '全ユーザーにバッジ「$badgeUrl」を配布・装備させました！';
  }

  @override
  String get vPracticeBadgeDistributeFailed => 'バッジの配布に失敗しました';

  @override
  String get vPracticeDialogTitle => '全ユーザーへバッジ配布';

  @override
  String get vPracticeDialogDesc =>
      '現在登録されている全てのユーザーに、指定したバッジを強制的に装備させます。通知は飛びません。';

  @override
  String get vPracticeBadgeIdHint => 'バッジID (例: tester)';

  @override
  String get vPracticeCancel => 'キャンセル';

  @override
  String get vPracticeDistribute => '配布する';

  @override
  String mutualFollowedBy(String userNames) {
    return '$userNamesがフォローしています';
  }

  @override
  String mutualFollowedByAndOthers(String userNames, int count) {
    return '$userNames、他$count人がフォローしています';
  }

  @override
  String get timeNow => '今';

  @override
  String timeMinutesAgo(int count) {
    return '$count分';
  }

  @override
  String timeHoursAgo(int count) {
    return '$count時間';
  }

  @override
  String timeDaysAgo(int count) {
    return '$count日';
  }

  @override
  String get blogPostEditorSaveDraft => '下書きとして保存';

  @override
  String get blogPostEditorStatusDraft => '下書き';

  @override
  String get blogPostEditorPublish => '公開する';

  @override
  String get blogPostEditorSaveAndPublish => '公開して保存';

  @override
  String get blogPostEditorUpdateAndPublish => '公開して更新';

  @override
  String get blogPostEditorRevertToDraft => '下書きに戻す';

  @override
  String get forceUpdateTitle => 'アップデートが必要です';

  @override
  String get forceUpdateBtn => 'アップデートする';

  @override
  String get taskReminderTitle => '🔔 リマインダー時間 (任意)';

  @override
  String get taskReminderNone => 'なし';

  @override
  String get taskReminderMorning => '朝 8:00';

  @override
  String get taskReminderNoon => '昼 12:00';

  @override
  String get taskReminderNight => '夜 21:00';

  @override
  String get taskReminderCustom => 'カスタム';

  @override
  String get taskReminderPickerTitle => '時間の選択';

  @override
  String get heroTasksPublishConfirmTitle => '全体公開にしますか？';

  @override
  String get heroTasksPublishConfirmDesc => 'この投稿をVタイムライン（全体公開）に公開しますか？';

  @override
  String get heroTasksPublishButton => '公開する';

  @override
  String get heroTasksUnpublishConfirmTitle => '非公開に戻しますか？';

  @override
  String get heroTasksUnpublishConfirmDesc => 'この投稿をVタイムラインから非公開に戻しますか？';

  @override
  String get heroTasksUnpublishButton => '非公開にする';

  @override
  String get vPhoenixRescueBadge => '🔥 合計150VFIREで救済！';

  @override
  String vPhoenixNotificationTitle(String name) {
    return '🤝 $nameが立ち上がった！';
  }

  @override
  String vPhoenixNotificationBody(String name) {
    return '$nameが諦めずに投稿！合計150VFIREで$nameさんのストリークが復活します（まるで不死鳥のように！）';
  }

  @override
  String vPhoenixBackup18Title(String taskName) {
    return '⏱️ 2分だけ$taskNameをやればOK！';
  }

  @override
  String vPhoenixBackup18Body(String taskName, int days) {
    return '完璧にやらなくても大丈夫。2分だけ$taskNameに着手して投稿すれば、$days日間のストリークは完全復活します🔥';
  }

  @override
  String vPhoenixBackup21Title(String taskName) {
    return '🌿 $taskNameは2分で十分';
  }

  @override
  String vPhoenixBackup21Body(String taskName) {
    return '『本を2分読む』『スクワット2分』で100点満点！小さな2分間が今日の『決定の瞬間』を変えます⚡️';
  }

  @override
  String vPhoenixRevivedTitle(String name) {
    return '🎉 $nameさんのストリークが復活しました！';
  }

  @override
  String vPhoenixRevivedBody(String name) {
    return 'あなたの熱いVFIREのおかげで、$nameさんの連続記録が息を吹き返しました！「応援ありがとう！🔥」';
  }

  @override
  String get vPhoenixRebirthDialogTitle => 'REIGNITE';

  @override
  String vPhoenixRebirthDialogDesc(int days) {
    return '$days日間のストリークが完全復活！仲間からの想いを受け取り、不死鳥のように蘇りました！';
  }
}
