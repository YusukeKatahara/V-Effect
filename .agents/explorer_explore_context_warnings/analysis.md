# BuildContextの非同期利用警告（`use_build_context_synchronously`）に関する調査レポート

本レポートでは、`flutter analyze`の実行結果より検出された `use_build_context_synchronously` 警告（非同期処理をまたいで `BuildContext` を使用しないこと）の全インスタンスを整理し、それぞれの発生原因と修正方法を提案します。

---

## 💡 `use_build_context_synchronously` とは？
Flutterにおいて、`await` による非同期処理（ネットワーク通信やファイル読み書きなど）の完了後に `BuildContext` を参照すると、その非同期処理の間にユーザーが画面を離脱（Widgetが破棄/アンマウント）している可能性があります。
すでに破棄された `context` を使用して画面遷移（Navigation）やスナックバーの表示（ScaffoldMessenger）、多言語化テキストの取得（AppLocalizations）などを行うと、**アプリのクラッシュや予期せぬ状態遷移（バグ）を引き起こす原因**になります。

### 🛠️ 主な解決策
1. **非同期処理の前に必要なデータ（多言語テキストなど）をローカル変数に退避しておく**
   - 例: `final l10n = AppLocalizations.of(context)!;` を `await` の前に記述し、非同期処理後には `l10n.xxx` を参照する。
2. **非同期処理の直後に `mounted`（Widgetが画面に存在しているか）をチェックする**
   - 例: `if (!mounted) return;`（StatefulWidget内）または `if (!context.mounted) return;`（StatelessWidget内）を記述する。

---

## 🔍 検出された警告一覧（全24箇所）

### 1. `lib/screens/blog_post_editor_screen.dart` (2箇所)
- **警告箇所**: 643行目、645行目
- **コードスニペット**:
```dart
633:   Future<void> _pickBadgeImage() async {
634:     final picker = ImagePicker();
635:     final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
636:     if (picked != null) {
637:       setState(() => _isSaving = true);
638:       try {
639:         final url = await DevBlogService.instance.uploadBadgeImage(File(picked.path));
640:         setState(() {
641:           _seasonBadgeImageUrlController.text = url;
642:         });
643:         _showError(AppLocalizations.of(context)!.blogPostEditorBadgeUploadSuccess); // ⚠️警告
644:       } catch (e) {
645:         _showError(AppLocalizations.of(context)!.blogPostEditorBadgeUploadFailed);  // ⚠️警告
646:       } finally {
647:         setState(() => _isSaving = false);
648:       }
649:     }
650:   }
```
- **発生原因**:
  `await DevBlogService.instance.uploadBadgeImage(...)` という非同期処理（ファイルのアップロード）の実行後に、エラーメッセージを多言語化（Localizations）するために `context` を参照しています。
- **推奨する修正策**:
  メソッドの最初（または `try` ブロックの直前）で `AppLocalizations` をローカル変数に退避させます。また、UI表示関数 `_showError` を呼び出す前に `mounted` チェックを追加します。
  ```dart
  Future<void> _pickBadgeImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      final l10n = AppLocalizations.of(context)!; // 非同期処理の前に退避
      setState(() => _isSaving = true);
      try {
        final url = await DevBlogService.instance.uploadBadgeImage(File(picked.path));
        if (!mounted) return; // 画面が破棄されていたら何もしない
        setState(() {
          _seasonBadgeImageUrlController.text = url;
        });
        _showError(l10n.blogPostEditorBadgeUploadSuccess);
      } catch (e) {
        if (!mounted) return;
        _showError(l10n.blogPostEditorBadgeUploadFailed);
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    }
  }
  ```

---

### 2. `lib/screens/edit_profile_screen.dart` (2箇所)
- **警告箇所**: 121行目、130行目
- **コードスニペット**:
```dart
110:   Future<void> _pickImage() async {
111:     final picker = ImagePicker();
112:     final pickedFile = await picker.pickImage(
113:       source: ImageSource.gallery,
114:       imageQuality: 70,
115:     );
116:     if (pickedFile != null) {
117:       final croppedFile = await ImageCropper().cropImage(
118:         sourcePath: pickedFile.path,
119:         uiSettings: [
120:           AndroidUiSettings(
121:             toolbarTitle: AppLocalizations.of(context)!.editProfileImageAdjust, // ⚠️警告
...
129:           IOSUiSettings(
130:             title: AppLocalizations.of(context)!.editProfileImageAdjust,         // ⚠️警告
...
```
- **発生原因**:
  `await picker.pickImage(...)` で画像選択（非同期）を待機した直後に、`ImageCropper().cropImage` を呼び出すパラメータ内で `AppLocalizations.of(context)` を参照しています。
- **推奨する修正策**:
  `_pickImage` の開始時に多言語化タイトルテキストを取得しておきます。
  ```dart
  Future<void> _pickImage() async {
    final l10n = AppLocalizations.of(context)!; // 非同期処理の前に取得
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (pickedFile != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: l10n.editProfileImageAdjust, // 退避した変数を使用
            ...
          ),
          IOSUiSettings(
            title: l10n.editProfileImageAdjust, // 退避した変数を使用
            ...
          ),
        ],
      );
      ...
  ```

---

### 3. `lib/screens/forgot_password_screen.dart` (1箇所)
- **警告箇所**: 71行目
- **コードスニペット**:
```dart
58:     setState(() => _isSending = true);
59:     try {
60:       // 1. Cloud Functions でユーザーIDとメールアドレスの一致を検証
61:       final callable = FirebaseFunctions.instance.httpsCallable('sendPasswordReset');
62:       await callable.call({
63:         'userId': userId,
64:         'email': email,
65:       });
66: 
67:       // 2. 検証成功時のみ、Firebase Auth でパスワードリセットメールを送信
68:       await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
69:       if (mounted) setState(() => _sent = true);
70:     } catch (e) {
71:       _showMessage(AppLocalizations.of(context)!.forgotPasswordInvalid); // ⚠️警告
72:     } finally {
73:       if (mounted) setState(() => _isSending = false);
74:     }
```
- **発生原因**:
  `callable.call(...)` や `sendPasswordResetEmail(...)` といった複数の非同期API通信を行った後、エラー発生時の `catch` ブロック内で `context` を使用してエラーメッセージを取得しています。
- **推奨する修正策**:
  `AppLocalizations` を非同期処理（`try` ブロック）の前に退避させます。
  ```dart
  setState(() => _isSending = true);
  final l10n = AppLocalizations.of(context)!; // 1. 非同期処理の前に取得
  try {
    final callable = FirebaseFunctions.instance.httpsCallable('sendPasswordReset');
    await callable.call({
      'userId': userId,
      'email': email,
    });

    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    if (mounted) setState(() => _sent = true);
  } catch (e) {
    if (mounted) { // 2. 画面生存確認
      _showMessage(l10n.forgotPasswordInvalid);
    }
  } finally {
    if (mounted) setState(() => _isSending = false);
  }
  ```

---

### 4. `lib/screens/login_screen.dart` (8箇所)
- **警告箇所**: 115行目, 119行目, 120行目, 121行目, 122行目, 127行目, 156行目, 178行目
- **コードスニペット**:
  - `_login` 内 (115, 119-122, 127行目):
```dart
108:       await _ensureUserDocAndNavigate();
109:     } on FirebaseFunctionsException catch (e) {
110:       debugPrint('Cloud Function error: ${e.code} - ${e.message}');
111:       // resource-exhausted（連続失敗ロック）はサーバーが残り分数を含めたメッセージを返すので
112:       // そのまま表示する。それ以外は一般化したメッセージ。
113:       final msg = e.code == 'resource-exhausted' && (e.message?.isNotEmpty ?? false)
114:           ? e.message!
115:           : AppLocalizations.of(context)!.loginErrorIdOrPassword; // ⚠️警告
116:       scaffold?.showSnackBar(SnackBar(content: Text(msg)));
117:       if (mounted) setState(() => _isEmailLoading = false);
118:     } on FirebaseAuthException catch (e) {
119:       String msg = AppLocalizations.of(context)!.loginFailed; // ⚠️警告
120:       if (e.code == 'user-not-found') msg = AppLocalizations.of(context)!.loginErrorUserNotFound; // ⚠️警告
121:       if (e.code == 'wrong-password') msg = AppLocalizations.of(context)!.loginErrorWrongPassword; // ⚠️警告
122:       if (e.code == 'invalid-credential') msg = AppLocalizations.of(context)!.loginErrorInvalidCredential; // ⚠️警告
123:       scaffold?.showSnackBar(SnackBar(content: Text(msg)));
124:       if (mounted) setState(() => _isEmailLoading = false);
125:     } catch (e) {
126:       debugPrint('Login error: $e');
127:       scaffold?.showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.loginFailed))); // ⚠️警告
128:       if (mounted) setState(() => _isEmailLoading = false);
129:     }
```
  - `_signInWithApple` 内 (156行目):
```dart
137:       final cred = await _authService.signInWithApple();
...
154:       if (!isCanceled) {
155:         scaffold?.showSnackBar(
156:           SnackBar(content: Text(AppLocalizations.of(context)!.loginAppleFailed)), // ⚠️警告
157:         );
158:       }
```
  - `_signInWithGoogle` 内 (178行目):
```dart
168:       final cred = await _authService.signInWithGoogle();
...
177:       scaffold?.showSnackBar(
178:         SnackBar(content: Text(AppLocalizations.of(context)!.loginGoogleFailed)), // ⚠️警告
179:       );
```
- **発生原因**:
  いずれもログイン/サインイン処理（`FirebaseAuth` への問い合わせや外部ソーシャルログイン連携）の待機（`await`）後に発生する各エラーハンドリング（`catch`）の中で、`AppLocalizations` を引くために `context` を使用しています。
- **推奨する修正策**:
  - `_login` の開始時（83行目の下など）に `final l10n = AppLocalizations.of(context)!;` を宣言し、各 catch 句内では `l10n.xxx` を参照するようにします。
  - `_signInWithApple` や `_signInWithGoogle` についても同様に、非同期処理に入る前に `AppLocalizations` をローカル変数に退避します。
  - いずれも `scaffold?.showSnackBar` や `setState` などの状態更新・UI表示を行う前に `if (!mounted) return;` のチェックを入れることで、さらに安全性を高められます。

---

### 5. `lib/screens/register_screen.dart` (2箇所)
- **警告箇所**: 140行目、159行目
- **コードスニペット**:
  - `_signInWithApple` 内 (140行目):
```dart
131:       final cred = await _authService.signInWithApple();
...
138:     } catch (e) {
139:       debugPrint('Apple sign-in error: $e');
140:       scaffold?.showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.registerAppleFailed))); // ⚠️警告
141:       if (mounted) setState(() => _isAppleLoading = false);
142:     }
```
  - `_signInWithGoogle` 内 (159行目):
```dart
150:       final cred = await _authService.signInWithGoogle();
...
157:     } catch (e) {
158:       debugPrint('Google sign-in error: $e');
159:       scaffold?.showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.registerGoogleFailed))); // ⚠️警告
160:       if (mounted) setState(() => _isGoogleLoading = false);
161:     }
```
- **発生原因**:
  `login_screen.dart` と同一パターンです。外部ソーシャル連携（Apple/Googleサインイン）の非同期処理が終わった後の `catch` ブロック内で `context` を用いて多言語化リソースにアクセスしています。
- **推奨する修正策**:
  非同期処理が始まる前に `final l10n = AppLocalizations.of(context)!;` を取得しておき、それを使用するように置き換えます。

---

### 6. `lib/screens/reset_password_screen.dart` (8箇所)
- **警告箇所**: 95行目, 97行目, 99行目, 103行目, 138行目, 140行目, 142行目, 146行目
- **コードスニペット**:
  - `_verifyCode` 内 (95, 97, 99, 103行目):
```dart
84:   Future<void> _verifyCode(String code) async {
85:     setState(() => _isLoading = true);
86:     try {
87:       final info = await _auth.checkActionCode(code);
...
94:     } on FirebaseAuthException catch (e) {
95:       String msg = AppLocalizations.of(context)!.resetPasswordLinkInvalid; // ⚠️警告
96:       if (e.code == 'expired-action-code') {
97:         msg = AppLocalizations.of(context)!.resetPasswordLinkExpired; // ⚠️警告
98:       } else if (e.code == 'invalid-action-code') {
99:         msg = AppLocalizations.of(context)!.resetPasswordLinkInvalidPaste; // ⚠️警告
100:       }
101:       _showMessage(msg);
102:     } catch (e) {
103:       _showMessage(AppLocalizations.of(context)!.errorGenericRetry); // ⚠️警告
104:     } finally {
```
  - `_resetPassword` 内 (138, 140, 142, 146行目):
```dart
120:   Future<void> _resetPassword() async {
...
133:     setState(() => _isLoading = true);
134:     try {
135:       await _auth.confirmPasswordReset(code: _oobCode!, newPassword: password);
...
137:     } on FirebaseAuthException catch (e) {
138:       String msg = AppLocalizations.of(context)!.resetPasswordFailed; // ⚠️警告
139:       if (e.code == 'expired-action-code') {
140:         msg = AppLocalizations.of(context)!.resetPasswordLinkExpired; // ⚠️警告
141:       } else if (e.code == 'weak-password') {
142:         msg = AppLocalizations.of(context)!.resetPasswordWeakPassword; // ⚠️警告
143:       }
144:       _showMessage(msg);
145:     } catch (e) {
146:       _showMessage(AppLocalizations.of(context)!.errorGenericRetry); // ⚠️警告
147:     } finally {
```
- **発生原因**:
  Firebase Authへのパスワードリセットコード検証（`checkActionCode`）やリセット確定（`confirmPasswordReset`）の非同期処理の待機後に、catchブロックで `context` を用いて多言語化テキストを取得しています。
- **推奨する修正策**:
  `_verifyCode` と `_resetPassword` の各メソッドの開始時に `final l10n = AppLocalizations.of(context)!;` をローカル変数として定義し、多言語化テキストの取得をこれに置き換えます。

---

### 7. `lib/screens/share_preview_screen.dart` (1箇所)
- **警告箇所**: 54行目
- **コードスニペット**:
```dart
37:   Future<void> _shareImage() async {
38:     if (_isSharing) return;
39:     setState(() => _isSharing = true);
40: 
41:     try {
42:       final boundary = _previewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
43:       if (boundary == null) return;
44: 
45:       final image = await boundary.toImage(pixelRatio: 3.0);
46:       final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
47:       final pngBytes = byteData!.buffer.asUint8List();
48: 
49:       final directory = await getTemporaryDirectory();
50:       final path = '${directory.path}/v_effect_share_${DateTime.now().millisecondsSinceEpoch}.png';
51:       final file = File(path);
52:       await file.writeAsBytes(pngBytes);
53: 
54:       final l10n = AppLocalizations.of(context)!; // ⚠️警告
55:       await SharePlus.instance.share(
56:         ShareParams(
57:           files: [XFile(path)],
58:           text: l10n.sharePreviewShareText(widget.postsCount, widget.currentStreak),
59:         ),
60:       );
61:     } catch (e) {
...
64:         ScaffoldMessenger.of(context).showSnackBar(
65:           SnackBar(content: Text(AppLocalizations.of(context)!.sharePreviewFailed)), // catch内も同様
66:         );
...
```
- **発生原因**:
  画像をレンダリングしてPNGファイルに書き出す処理（`boundary.toImage`, `toByteData`, `writeAsBytes`）といった非同期処理を繰り返した後に、`AppLocalizations.of(context)!` を呼び出してローカル変数 `l10n` に保存しています。また、`catch` 句内でも `AppLocalizations.of(context)` が使われています。
- **推奨する修正策**:
  `l10n` の取得処理を `_shareImage()` の先頭（すべての `await` が発生する前）で行います。
  ```dart
  Future<void> _shareImage() async {
    if (_isSharing) return;
    final l10n = AppLocalizations.of(context)!; // 非同期の前に取得
    setState(() => _isSharing = true);
    
    try {
      final boundary = _previewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      ...
      // await 処理群
      ...
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          text: l10n.sharePreviewShareText(widget.postsCount, widget.currentStreak),
        ),
      );
    } catch (e) {
      debugPrint('Share error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.sharePreviewFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }
  ```

---

## 📝 まとめと方針
今回検出されたすべての `use_build_context_synchronously` 警告は、**「非同期処理が終わった後の例外ハンドリング等で多言語化リソース（`AppLocalizations`）に `context` を用いてアクセスしている」**という共通パターンを持っています。

この問題を解決するためには、次のシンプルな規約を全ファイルに適用するのが最も安全かつ効果的です。

1. **非同期メソッドに入った直後（または最初の await の前）で必要な `AppLocalizations` などのリソースやコントローラーをローカル変数に読み込んでおく。**
2. **`setState` や `ScaffoldMessenger`、`Navigator` などのUI操作を行う前には必ず `if (!mounted) return;` または `if (context.mounted)` による生存チェックを行う。**

以上が調査結果となります。
