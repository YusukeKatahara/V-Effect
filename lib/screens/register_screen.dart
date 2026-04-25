import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_colors.dart';
import '../config/routes.dart';
import '../config/firebase_config.dart';

import '../services/analytics_service.dart';
import '../services/auth_service.dart';
import '../services/push_notification_service.dart';
import '../widgets/animated_v_logo.dart';
import 'package:cached_network_image/cached_network_image.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passConfirmCtrl = TextEditingController();
  final _authService = AuthService();
  final _analytics = AnalyticsService.instance;
  bool _isEmailLoading = false;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;

  bool get _isLoadingAny => _isEmailLoading || _isGoogleLoading || _isAppleLoading;

  bool _obscurePass = true;
  bool _obscureConf = true;

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
    _passConfirmCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  /// ユーザードキュメントを作成する（ソーシャルログイン用）
  Future<void> _ensureUserDoc(User user) async {
    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final doc = await docRef.get();
    if (!doc.exists) {
      await docRef.set({
        'profileCompleted': false,
        'onboardingCompleted': false,
      });
    }
    PushNotificationService().saveFcmToken().catchError((e) => debugPrint('FCM token save error: $e'));
  }

  /// ユーザードキュメントを作成し、wrapper 経由でルーティングする（ソーシャルログイン用）
  /// wrapper に戻すことで auth_wrapper の termsAgreed チェックが走り、同意画面が表示される
  Future<void> _ensureUserDocAndNavigate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _ensureUserDoc(user);
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.wrapper, (r) => false);
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoadingAny) return;
    setState(() => _isEmailLoading = true);
    final scaffold = ScaffoldMessenger.maybeOf(context);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      await _analytics.logSignUp('email');
      // 認証メールを送信（Deep Link でアプリに戻れるよう ActionCodeSettings を設定）
      await cred.user?.sendEmailVerification(FirebaseConfig.actionCodeSettings);
      // Firestoreドキュメントを作成
      await _ensureUserDoc(cred.user!);
      
      if (!mounted) return;
      // メール認証待ち画面へ
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.emailVerification, (r) => false);
    } on FirebaseAuthException catch (e) {
      String msg = '登録に失敗しました。';
      if (e.code == 'email-already-in-use') msg = 'このメールアドレスは既に使われています。';
      if (e.code == 'weak-password') msg = 'パスワードは6文字以上にしてください。';
      scaffold?.showSnackBar(SnackBar(content: Text(msg)));
      if (mounted) setState(() => _isEmailLoading = false);
    } catch (e) {
      debugPrint('Registration error: $e');
      scaffold?.showSnackBar(const SnackBar(content: Text('登録に失敗しました。しばらくしてからお試しください。')));
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
        await _analytics.logSignUp('google');
        await _ensureUserDocAndNavigate();
      } else {
        if (mounted) setState(() => _isGoogleLoading = false);
      }
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      scaffold?.showSnackBar(const SnackBar(content: Text('Googleでの登録に失敗しました。')));
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
        await _analytics.logSignUp('apple');
        await _ensureUserDocAndNavigate();
      } else {
        if (mounted) setState(() => _isAppleLoading = false);
      }
    } catch (e) {
      debugPrint('Apple sign-in error: $e');
      scaffold?.showSnackBar(const SnackBar(content: Text('Appleでの登録に失敗しました。')));
      if (mounted) setState(() => _isAppleLoading = false);
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  // ── カスタムAppBar ──
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: AppColors.textPrimary,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Text(
                          '新規登録',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            const SizedBox(height: 24),
                            _buildLogo(),
                            const SizedBox(height: 36),
                            _buildForm(),
                            const SizedBox(height: 28),
                            _buildSocialSection(),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return RepaintBoundary(
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 320,
              height: 320,
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
          Positioned(
            bottom: -60,
            left: -40,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.04),
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

  Widget _buildLogo() {
    return Column(
      children: [
        const AnimatedVLogo(size: 72),
        const SizedBox(height: 14),
        const Text(
          'アカウントを作成',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'V EFFECTに参加して仲間と高め合おう',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        // メール
        TextFormField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'メールアドレス',
            prefixIcon: Icon(Icons.mail_outline_rounded),
          ),
          validator:
              (v) =>
                  (v == null || v.trim().isEmpty) ? 'メールアドレスを入力してください' : null,
        ),
        const SizedBox(height: 14),

        // パスワード
        TextFormField(
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
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'パスワードを入力してください';
            if (v.trim().length < 6) return '6文字以上で入力してください';
            return null;
          },
        ),
        const SizedBox(height: 14),

        // パスワード確認
        TextFormField(
          controller: _passConfirmCtrl,
          obscureText: _obscureConf,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: 'パスワード（確認）',
            prefixIcon: const Icon(Icons.lock_person_outlined),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConf
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.textMuted,
              ),
              onPressed: () => setState(() => _obscureConf = !_obscureConf),
            ),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'パスワードを再入力してください';
            if (v.trim() != _passCtrl.text.trim()) return 'パスワードが一致しません';
            return null;
          },
        ),
        const SizedBox(height: 28),

        // 登録ボタン
        _isEmailLoading
            ? _buildLoadingButton()
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
                  onPressed: _isLoadingAny ? null : _register,
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
                    'アカウントを作成',
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
        const SizedBox(height: 18),
        // Google
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: _isLoadingAny ? null : _signInWithGoogle,
            child: _isGoogleLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CachedNetworkImage(
                        imageUrl: 'https://developers.google.com/identity/images/g-logo.png',
                        height: 22,
                        placeholder: (context, url) => const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 1),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.g_mobiledata,
                          size: 24,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Googleで作成',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        // Apple
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: _isLoadingAny ? null : _signInWithApple,
            child: _isAppleLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.apple, size: 24, color: AppColors.textPrimary),
                      const SizedBox(width: 10),
                      const Text('Appleで作成', style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingButton() {
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
