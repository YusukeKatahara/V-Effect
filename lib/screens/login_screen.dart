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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _authService = AuthService();
  final _analytics = AnalyticsService.instance;
  bool _isEmailLoading = false;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;

  bool get _isLoadingAny => _isEmailLoading || _isGoogleLoading || _isAppleLoading;

  bool _obscurePass = true;

  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim  = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  /// ユーザードキュメントを確認・作成し、状態に応じた画面に直接遷移する
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

    if (!mounted) return;

    // ドキュメントの状態に応じて遷移先を決定
    final data = doc.exists ? doc.data() : null;
    final isProfileCompleted = data?['profileCompleted'] == true;
    final isOnboardingCompleted = data?['onboardingCompleted'] == true;

    String route;
    if (!isProfileCompleted) {
      route = AppRoutes.profileSetup;
    } else if (!isOnboardingCompleted) {
      route = AppRoutes.taskSetup;
    } else {
      route = AppRoutes.home;
    }

    Navigator.of(context).pushNamedAndRemoveUntil(route, (r) => false);
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
      scaffold?.showSnackBar(const SnackBar(content: Text('ユーザーIDまたはパスワードが間違っています。')));
      if (mounted) setState(() => _isEmailLoading = false);
    } on FirebaseAuthException catch (e) {
      String msg = 'ログインに失敗しました。';
      if (e.code == 'user-not-found') msg = 'ユーザーが見つかりません。';
      if (e.code == 'wrong-password')  msg = 'パスワードが間違っています。';
      if (e.code == 'invalid-credential') msg = 'メールアドレスまたはパスワードが間違っています。';
      scaffold?.showSnackBar(SnackBar(content: Text(msg)));
      if (mounted) setState(() => _isEmailLoading = false);
    } catch (e) {
      debugPrint('Login error: $e');
      scaffold?.showSnackBar(const SnackBar(content: Text('ログインに失敗しました。')));
      if (mounted) setState(() => _isEmailLoading = false);
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
      scaffold?.showSnackBar(const SnackBar(content: Text('Googleでのログインに失敗しました。')));
      if (mounted) setState(() => _isGoogleLoading = false);
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
      scaffold?.showSnackBar(const SnackBar(content: Text('Appleでのログインに失敗しました。')));
      if (mounted) setState(() => _isAppleLoading = false);
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
                    Colors.white.withValues(alpha: 0.08),
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
                    Colors.white.withValues(alpha: 0.05),
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
          shaderCallback: (bounds) =>
              const LinearGradient(
                colors: [Color(0xFFFFFFFF), Color(0xFFCCCCCC)],
              ).createShader(bounds),
          child: const Text(
            'V EFFECT',
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w800,
              color: Colors.white,
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
                _obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
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
            onPressed: () => Navigator.pushNamed(context, AppRoutes.forgotPassword),
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
                    boxShadow: _isLoadingAny ? [] : [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.2),
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
              child: Text('または', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 20),

        // Google
        _SocialButton(
          onPressed: _isLoadingAny ? null : _signInWithGoogle,
          isLoading: _isGoogleLoading,
          icon: Image.network(
            'https://developers.google.com/identity/images/g-logo.png',
            height: 22,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.g_mobiledata, size: 24, color: AppColors.textPrimary),
          ),
          label: 'Googleでログイン',
        ),
        const SizedBox(height: 12),

        // Apple
        _SocialButton(
          onPressed: _isLoadingAny ? null : _signInWithApple,
          isLoading: _isAppleLoading,
          icon: const Icon(Icons.apple, size: 24, color: AppColors.textPrimary),
          label: 'Appleでログイン',
        ),
      ],
    );
  }

  // ════════════════════════════════════════════
  // フッター
  // ════════════════════════════════════════════
  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('アカウントをお持ちでないですか？',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, AppRoutes.register),
          child: const Text('新規登録'),
        ),
      ],
    );
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
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final String label;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(width: 10),
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
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
