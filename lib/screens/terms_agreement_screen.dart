import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_colors.dart';
import '../config/routes.dart';
import 'privacy_policy_screen.dart';
import 'terms_screen.dart';

/// 新規登録時に利用規約とプライバシーポリシーへの同意を求めるスクリーン。
///
/// メール認証完了後、プロフィール設定前にのみ表示される。
/// 両方にチェックを入れると Firestore に termsAgreed: true を保存して次へ進む。
class TermsAgreementScreen extends StatefulWidget {
  const TermsAgreementScreen({super.key});

  @override
  State<TermsAgreementScreen> createState() => _TermsAgreementScreenState();
}

class _TermsAgreementScreenState extends State<TermsAgreementScreen> {
  final PageController _pageController = PageController();

  bool _termsAgreed = false;
  bool _privacyAgreed = false;
  bool _isSaving = false;
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
  }

  /// 次のページへスワイプ（利用規約 → プライバシーポリシー）
  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  /// 両方同意 → Firestore に保存してプロフィール設定へ
  Future<void> _saveAndContinue() async {
    if (!_termsAgreed || !_privacyAgreed) return;
    setState(() => _isSaving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // termsAgreed フラグと同意日時を Firestore に保存（merge でドキュメントを作成または更新）
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'termsAgreed': true,
          'termsAgreedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      // wrapper に戻すことで auth_wrapper が次の画面（profileSetup 等）へルーティング
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.wrapper,
        (r) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存に失敗しました。もう一度お試しください。')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            // ── ヘッダー ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
              child: Column(
                children: [
                  const Text(
                    'ご確認ください',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'スワイプして内容をご確認のうえ、\n同意してアカウントを作成してください。',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── ページ インジケーター ─────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(2, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? AppColors.accentGold
                        : AppColors.grey30,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),

            const SizedBox(height: 20),

            // ── ドキュメント PageView ──────────────────────
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: [
                  _DocumentPage(
                    title: '利用規約',
                    agreed: _termsAgreed,
                    checkLabel: '利用規約を読み、同意しました',
                    onChanged: (v) => setState(() => _termsAgreed = v ?? false),
                    child: const TermsContent(),
                  ),
                  _DocumentPage(
                    title: 'プライバシーポリシー',
                    agreed: _privacyAgreed,
                    checkLabel: 'プライバシーポリシーを読み、同意しました',
                    onChanged: (v) =>
                        setState(() => _privacyAgreed = v ?? false),
                    child: const PrivacyPolicyContent(),
                  ),
                ],
              ),
            ),

            // ── ボタン ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              child: _currentPage == 0
                  ? _NextButton(
                      enabled: _termsAgreed,
                      onPressed: _nextPage,
                    )
                  : _AgreeButton(
                      enabled: _termsAgreed && _privacyAgreed && !_isSaving,
                      isSaving: _isSaving,
                      onPressed: _saveAndContinue,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ドキュメントページ（スクロール可能なテキスト + 同意チェックボックス）
// ─────────────────────────────────────────────────────────────────────────────
class _DocumentPage extends StatelessWidget {
  const _DocumentPage({
    required this.title,
    required this.agreed,
    required this.checkLabel,
    required this.onChanged,
    required this.child,
  });

  final String title;
  final bool agreed;
  final Widget child;
  final String checkLabel;
  final void Function(bool?) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // タイトル
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // スクロール可能な文書エリア
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.grey20, width: 1),
              ),
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: child,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // タップで切り替える同意チェックボックス
          GestureDetector(
            onTap: () => onChanged(!agreed),
            behavior: HitTestBehavior.opaque,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // アニメーション付きチェックボックス
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: agreed ? AppColors.accentGold : Colors.transparent,
                    border: Border.all(
                      color:
                          agreed ? AppColors.accentGold : AppColors.grey50,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: agreed
                      ? const Icon(
                          Icons.check,
                          size: 16,
                          color: AppColors.black,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    checkLabel,
                    style: TextStyle(
                      fontSize: 14,
                      color: agreed
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight:
                          agreed ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 「次へ」ボタン（利用規約に同意するまで非活性）
// ─────────────────────────────────────────────────────────────────────────────
class _NextButton extends StatelessWidget {
  const _NextButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: enabled ? AppColors.primaryGradient : null,
          color: enabled ? null : AppColors.grey20,
          borderRadius: BorderRadius.circular(14),
        ),
        child: ElevatedButton(
          onPressed: enabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor:
                enabled ? AppColors.black : AppColors.textMuted,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text(
            '次へ',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 「同意してアカウントを作成」ボタン（両方同意するまで非活性）
// ─────────────────────────────────────────────────────────────────────────────
class _AgreeButton extends StatelessWidget {
  const _AgreeButton({
    required this.enabled,
    required this.isSaving,
    required this.onPressed,
  });

  final bool enabled;
  final bool isSaving;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: enabled ? AppColors.primaryGradient : null,
          color: enabled ? null : AppColors.grey20,
          borderRadius: BorderRadius.circular(14),
        ),
        child: ElevatedButton(
          onPressed: enabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor:
                enabled ? AppColors.black : AppColors.textMuted,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: isSaving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text(
                  '同意してアカウントを作成',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
        ),
      ),
    );
  }
}
