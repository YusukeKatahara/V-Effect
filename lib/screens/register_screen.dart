import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import '../config/app_colors.dart';
import '../config/routes.dart';

import '../services/analytics_service.dart';
import '../services/auth_service.dart';
import '../services/push_notification_service.dart';
import '../widgets/animated_v_logo.dart';
import '../widgets/responsive_container.dart';

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
  bool _isAppleLoading = false;
  bool _isGoogleLoading = false;

  bool get _isLoadingAny => _isEmailLoading || _isAppleLoading || _isGoogleLoading;

  bool _obscurePass = true;
  bool _obscureConf = true;
  bool _agreedToTerms = false;
  bool _agreedToPrivacy = false;

  bool get _canSubmit => _agreedToTerms && _agreedToPrivacy && !_isLoadingAny;

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

  /// ユーザードキュメントを作成する（初回のみ termsAgreed も記録）
  Future<void> _ensureUserDoc(User user) async {
    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final doc = await docRef.get();
    if (!doc.exists) {
      await docRef.set({
        'profileCompleted': false,
        'onboardingCompleted': false,
        'termsAgreed': true,
        'termsAgreedAt': FieldValue.serverTimestamp(),
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
    final l10n = AppLocalizations.of(context)!;
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      // 🚨 【追加】登録直後に認証メールを送信する
      try {
        await cred.user?.sendEmailVerification();
      } catch (e) {
        debugPrint('Verification email send error: $e');
      }
      await _analytics.logSignUp('email');
      await _ensureUserDoc(cred.user!);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.wrapper, (r) => false);
    } on FirebaseAuthException catch (e) {
      String msg = l10n.registerFailed;
      if (e.code == 'email-already-in-use') msg = l10n.registerEmailInUse;
      if (e.code == 'weak-password') msg = l10n.registerWeakPassword;
      scaffold?.showSnackBar(SnackBar(content: Text(msg)));
      if (mounted) setState(() => _isEmailLoading = false);
    } catch (e) {
      debugPrint('Registration error: $e');
      scaffold?.showSnackBar(SnackBar(content: Text(l10n.registerFailedRetry)));
      if (mounted) setState(() => _isEmailLoading = false);
    }
  }

  Future<void> _signInWithApple() async {
    if (_isLoadingAny) return;
    setState(() => _isAppleLoading = true);
    final scaffold = ScaffoldMessenger.maybeOf(context);
    final l10n = AppLocalizations.of(context)!;
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
      scaffold?.showSnackBar(SnackBar(content: Text(l10n.registerAppleFailed)));
      if (mounted) setState(() => _isAppleLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoadingAny) return;
    setState(() => _isGoogleLoading = true);
    final scaffold = ScaffoldMessenger.maybeOf(context);
    final l10n = AppLocalizations.of(context)!;
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
      scaffold?.showSnackBar(SnackBar(content: Text(l10n.registerGoogleFailed)));
      if (mounted) setState(() => _isGoogleLoading = false);
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
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: AppColors.textPrimary,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Text(
                          AppLocalizations.of(context)!.loginRegister,
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
                    child: ResponsiveContainer(
                      child: Form(
                        key: _formKey,
                        child: CustomScrollView(
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 28),
                              sliver: SliverList(
                                delegate: SliverChildListDelegate([
                                  const SizedBox(height: 24),
                                  _buildLogo(),
                                  const SizedBox(height: 36),
                                  _buildForm(),
                                  const SizedBox(height: 28),
                                ]),
                              ),
                            ),
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 28, right: 28, bottom: 32),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    _buildSocialSection(),
                                  ],
                                ),
                              ),
                            ),
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
                    AppColors.white.withValues(alpha: 0.08),
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
                    AppColors.white.withValues(alpha: 0.04),
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
        Text(
          AppLocalizations.of(context)!.registerCreateAccount,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          AppLocalizations.of(context)!.registerSubtitle,
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
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.registerEmail,
            prefixIcon: const Icon(Icons.mail_outline_rounded),
          ),
          validator:
              (v) =>
                  (v == null || v.trim().isEmpty) ? AppLocalizations.of(context)!.registerEmailRequired : null,
        ),
        const SizedBox(height: 14),

        // パスワード
        TextFormField(
          controller: _passCtrl,
          obscureText: _obscurePass,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.loginPassword,
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
            if (v == null || v.trim().isEmpty) return AppLocalizations.of(context)!.registerPasswordRequired;
            if (v.trim().length < 6) return AppLocalizations.of(context)!.registerPasswordMinLength;
            return null;
          },
        ),
        const SizedBox(height: 14),

        // パスワード確認
        TextFormField(
          controller: _passConfirmCtrl,
          obscureText: _obscureConf,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.registerPasswordConfirm,
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
            if (v == null || v.trim().isEmpty) return AppLocalizations.of(context)!.registerPasswordReenter;
            if (v.trim() != _passCtrl.text.trim()) return AppLocalizations.of(context)!.registerPasswordMismatch;
            return null;
          },
        ),
        const SizedBox(height: 20),
        _buildAgreementCheckbox(
          value: _agreedToTerms,
          onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
          label: AppLocalizations.of(context)!.registerAgreeToSuffix,
          linkText: AppLocalizations.of(context)!.settingsTerms,
          url: 'https://veffect.web.app/terms/',
        ),
        const SizedBox(height: 8),
        _buildAgreementCheckbox(
          value: _agreedToPrivacy,
          onChanged: (v) => setState(() => _agreedToPrivacy = v ?? false),
          label: AppLocalizations.of(context)!.registerAgreeToSuffix,
          linkText: AppLocalizations.of(context)!.settingsPrivacyPolicy,
          url: 'https://veffect.web.app/privacy/',
        ),
        const SizedBox(height: 20),

        // 登録ボタン
        _isEmailLoading
            ? _buildLoadingButton()
            : SizedBox(
              width: double.infinity,
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: _canSubmit ? AppColors.primaryGradient : null,
                  color: _canSubmit ? null : AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _canSubmit ? [
                    BoxShadow(
                      color: AppColors.white.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ] : [],
                ),
                child: ElevatedButton(
                  onPressed: _canSubmit ? _register : null,
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
                  child: Text(
                    AppLocalizations.of(context)!.registerCreateAccount,
                    style: const TextStyle(
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
                AppLocalizations.of(context)!.loginOrDivider,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 18),
        // Apple
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: _canSubmit ? _signInWithApple : null,
            child: _isAppleLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.apple, size: 24, color: AppColors.textPrimary),
                      const SizedBox(width: 12),
                      Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          Opacity(
                            opacity: 0,
                            child: Text(
                              AppLocalizations.of(context)!.registerWithGoogle,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          Text(
                            AppLocalizations.of(context)!.registerWithApple,
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
        ),
        const SizedBox(height: 12),

        // Google
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: _canSubmit ? _signInWithGoogle : null,
            child: _isGoogleLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
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
                      const SizedBox(width: 12),
                      Text(
                        AppLocalizations.of(context)!.registerWithGoogle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildAgreementCheckbox({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String linkText,
    required String label,
    required String url,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.textPrimary,
            side: BorderSide(color: AppColors.textMuted, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              GestureDetector(
                onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                child: Text(
                  linkText,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4A9EFF),
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFF4A9EFF),
                  ),
                ),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
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
