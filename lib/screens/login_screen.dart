import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../config/app_colors.dart';
import '../config/routes.dart';
import '../firebase_options.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';
import '../services/push_notification_service.dart';
import '../widgets/animated_v_logo.dart';
import '../widgets/responsive_container.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _authService = AuthService();
  final _analytics = AnalyticsService.instance;
  bool _isEmailLoading = false;
  bool _isAppleLoading = false;
  bool _isGoogleLoading = false;

  bool get _isLoadingAny => _isEmailLoading || _isAppleLoading || _isGoogleLoading;

  bool _obscurePass = true;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  /// ユーザードキュメントを確認・作成し、auth_wrapper 経由でルーティングする
  Future<void> _ensureUserDocAndNavigate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final doc = await docRef.get();
    if (!doc.exists) {
      await docRef.set({
        'profileCompleted': false,
        'onboardingCompleted': false,
      });
    }
    PushNotificationService().saveFcmToken().catchError((e) => debugPrint('FCM token save error: $e'));
    // V Alert スケジュールをアプリ再インストール後も復元
    PushNotificationService().restoreVAlertSchedule().catchError((e) => debugPrint('V Alert restore error: $e'));

    if (!mounted) return;
    // ルーティングは auth_wrapper に一元化する
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.wrapper, (r) => false);
  }

  Future<void> _login() async {
    if (_isLoadingAny) return;
    setState(() => _isEmailLoading = true);
    final scaffold = ScaffoldMessenger.maybeOf(context);
    try {
      final input = _emailCtrl.text.trim();
      final password = _passCtrl.text.trim();

      // メールアドレス判定: @ を含み、かつ @ の後にドメイン(.)がある場合のみメール扱い
      final isEmail = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(input);

      if (isEmail) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: input,
          password: password,
        );
      } else {
        // @RN のように @ で始まる or @ のないユーザーIDはこちら
        final userId = input.startsWith('@') ? input.substring(1) : input;
        await _authService.loginWithUserId(
          userId,
          password,
          DefaultFirebaseOptions.web.apiKey,
        );
      }

      await _analytics.logLogin('email_or_id');
      await _ensureUserDocAndNavigate();
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Cloud Function error: ${e.code} - ${e.message}');
      // resource-exhausted（連続失敗ロック）はサーバーが残り分数を含めたメッセージを返すので
      // そのまま表示する。それ以外は一般化したメッセージ。
      final msg = e.code == 'resource-exhausted' && (e.message?.isNotEmpty ?? false)
          ? e.message!
          : 'ユーザーIDまたはパスワードが間違っています';
      scaffold?.showSnackBar(SnackBar(content: Text(msg)));
      if (mounted) setState(() => _isEmailLoading = false);
    } on FirebaseAuthException catch (e) {
      String msg = 'ログインに失敗しました';
      if (e.code == 'user-not-found') msg = 'ユーザーが見つかりません';
      if (e.code == 'wrong-password') msg = 'パスワードが間違っています';
      if (e.code == 'invalid-credential') msg = 'メールアドレスまたはパスワードが間違っています';
      scaffold?.showSnackBar(SnackBar(content: Text(msg)));
      if (mounted) setState(() => _isEmailLoading = false);
    } catch (e) {
      debugPrint('Login error: $e');
      scaffold?.showSnackBar(const SnackBar(content: Text('ログインに失敗しました')));
      if (mounted) setState(() => _isEmailLoading = false);
    }
  }

  Future<void> _signInWithApple() async {
    if (_isLoadingAny) return;
    setState(() => _isAppleLoading = true);
    final scaffold = ScaffoldMessenger.maybeOf(context);
    try {
      final cred = await _authService.signInWithApple();
      if (cred != null) {
        await _analytics.logLogin('apple');
        await _ensureUserDocAndNavigate();
      } else {
        if (mounted) setState(() => _isAppleLoading = false);
      }
    } catch (e) {
      debugPrint('Apple sign-in error: $e');
      
      // ユーザーによるキャンセル（ダイアログを閉じただけ）の場合はエラー通知を出さない
      bool isCanceled = false;
      if (e is SignInWithAppleAuthorizationException && 
          e.code == AuthorizationErrorCode.canceled) {
        isCanceled = true;
      }

      if (!isCanceled) {
        scaffold?.showSnackBar(
          const SnackBar(content: Text('Appleでのログインに失敗しました')),
        );
      }
      if (mounted) setState(() => _isAppleLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoadingAny) return;
    setState(() => _isGoogleLoading = true);
    final scaffold = ScaffoldMessenger.maybeOf(context);
    try {
      final cred = await _authService.signInWithGoogle();
      if (cred != null) {
        await _analytics.logLogin('google');
        await _ensureUserDocAndNavigate();
      } else {
        if (mounted) setState(() => _isGoogleLoading = false);
      }
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      scaffold?.showSnackBar(
        const SnackBar(content: Text('Googleでのログインに失敗しました')),
      );
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Stack(
        children: [
          // ── 背景グラデーション＋装飾円 ──────────────────
          _buildBackground(),

          // ── コンテンツ ───────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: ResponsiveContainer(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      const SizedBox(height: 60),
                      _buildLogo(),
                      const SizedBox(height: 48),
                      _buildForm(),
                      const SizedBox(height: 32),
                      _buildSocialSection(),
                      const SizedBox(height: 32),
                      _buildFooter(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════
  // 背景装飾
  // ════════════════════════════════════════════
  Widget _buildBackground() {
    return RepaintBoundary(
      child: Stack(
        children: [
          // 上部グロー
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.white.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // 右下グロー
          Positioned(
            bottom: -80,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.white.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════
  // ロゴ
  // ════════════════════════════════════════════
  Widget _buildLogo() {
    return Column(
      children: [
        // グロー付きアイコン
        const AnimatedVLogo(size: 88),
        const SizedBox(height: 20),
        ShaderMask(
          shaderCallback:
              (bounds) => const LinearGradient(
                colors: [Color(0xFFFFFFFF), Color(0xFFCCCCCC)],
              ).createShader(bounds),
          child: const Text(
            'V EFFECT',
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w800,
              color: AppColors.white,
              letterSpacing: 3.0,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '日々の努力を、仲間と共に。',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════
  // フォーム
  // ════════════════════════════════════════════
  Widget _buildForm() {
    return Column(
      children: [
        // メール
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'メールアドレスまたはユーザーID',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
        ),
        const SizedBox(height: 16),

        // パスワード
        TextField(
          controller: _passCtrl,
          obscureText: _obscurePass,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: 'パスワード',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePass
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.textMuted,
              ),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // パスワード忘れ
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed:
                () => Navigator.pushNamed(context, AppRoutes.forgotPassword),
            child: const Text('パスワードをお忘れですか？'),
          ),
        ),
        const SizedBox(height: 20),

        // ログインボタン
        _isEmailLoading
            ? const _LoadingButton()
            : SizedBox(
              width: double.infinity,
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow:
                      _isLoadingAny
                          ? []
                          : [
                            BoxShadow(
                              color: AppColors.white.withValues(alpha: 0.2),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoadingAny ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: AppColors.black,
                    disabledForegroundColor: AppColors.textMuted,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'ログイン',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }

  // ════════════════════════════════════════════
  // ソーシャルログイン
  // ════════════════════════════════════════════
  Widget _buildSocialSection() {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'または',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 20),

        // Apple
        _SocialButton(
          onPressed: _isLoadingAny ? null : _signInWithApple,
          isLoading: _isAppleLoading,
          icon: const Icon(Icons.apple, size: 24, color: AppColors.textPrimary),
          label: 'Appleでログイン',
          baseLabel: 'Googleでログイン',
        ),
        const SizedBox(height: 12),

        // Google
        _SocialButton(
          onPressed: _isLoadingAny ? null : _signInWithGoogle,
          isLoading: _isGoogleLoading,
          icon: const SizedBox(
            width: 24,
            height: 24,
            child: Center(
              child: Text(
                'G',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  height: 1.1,
                ),
              ),
            ),
          ),
          label: 'Googleでログイン',
        ),
      ],
    );
  }

  // ════════════════════════════════════════════
  // フッター
  // ════════════════════════════════════════════
  Widget _buildFooter() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'アカウントをお持ちでないですか？',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.register),
              child: const Text('新規登録'),
            ),
          ],
        ),
        TextButton(
          onPressed: () => _launchURL('https://veffect.web.app/support/'),
          child: const Text(
            'ログインできない等のご相談・お問い合わせ',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'ログインすることで、',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, AppRoutes.terms),
                child: const Text(
                  '利用規約',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              Text(
                'および',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, AppRoutes.privacyPolicy),
                child: const Text(
                  'プライバシーポリシー',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              Text(
                'に同意したものとみなされます。',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _launchURL(String urlString) async {
    final url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('リンクを開けませんでした')));
      }
    }
  }
}

// ────────────────────────────────────────────
// ソーシャルボタン（共通）
// ────────────────────────────────────────────
class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.baseLabel,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final String label;
  final String? baseLabel;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        child:
            isLoading
                ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    icon,
                    const SizedBox(width: 12),
                    Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        if (baseLabel != null)
                          Opacity(
                            opacity: 0,
                            child: Text(
                              baseLabel!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        Text(
                          label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
      ),
    );
  }
}

// ────────────────────────────────────────────
// ローディング付きボタン
// ────────────────────────────────────────────
class _LoadingButton extends StatelessWidget {
  const _LoadingButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}
