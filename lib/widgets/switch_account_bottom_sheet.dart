import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_colors.dart';
import '../config/routes.dart';
import '../models/saved_account.dart';
import '../services/multi_account_service.dart';
import '../services/auth_service.dart';
import '../firebase_options.dart';

class SwitchAccountBottomSheet extends StatefulWidget {
  const SwitchAccountBottomSheet({super.key});

  @override
  State<SwitchAccountBottomSheet> createState() => _SwitchAccountBottomSheetState();
}

class _SwitchAccountBottomSheetState extends State<SwitchAccountBottomSheet> {
  final _multiAccountService = MultiAccountService.instance;
  final _authService = AuthService();
  List<SavedAccount> _accounts = [];
  bool _isLoading = true;
  String? _switchingUid;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final accounts = await _multiAccountService.getSavedAccounts();
    if (mounted) {
      setState(() {
        _accounts = accounts;
        _isLoading = false;
      });
    }
  }

  Future<void> _switchAccount(SavedAccount account) async {
    if (_switchingUid != null) return;
    
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == account.uid) {
      Navigator.pop(context);
      return;
    }

    setState(() => _switchingUid = account.uid);

    try {
      await FirebaseAuth.instance.signOut();

      if (account.provider == AuthAccountType.custom) {
        if (account.password != null) {
          await _authService.loginWithUserId(
            account.loginId,
            account.password!,
            DefaultFirebaseOptions.web.apiKey,
          );
        } else {
          // パスワードがない場合はログイン画面へ飛ばす
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (r) => false);
            return;
          }
        }
      } else if (account.provider == AuthAccountType.google) {
        await _authService.signInWithGoogle();
      } else if (account.provider == AuthAccountType.apple) {
        await _authService.signInWithApple();
      }

      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (r) => false);
      }
    } catch (e) {
      debugPrint('Switch account error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('アカウントの切り替えに失敗しました。')),
        );
        setState(() => _switchingUid = null);
      }
    }
  }

  void _addAccount() {
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ハンドルバー
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.grey20,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            )
          else ...[
            // アカウントリスト
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _accounts.length,
                itemBuilder: (context, index) {
                  final account = _accounts[index];
                  final isCurrent = account.uid == currentUser?.uid;
                  final isSwitching = _switchingUid == account.uid;

                  return GestureDetector(
                    onTap: () => _switchAccount(account),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCurrent ? AppColors.accentGold.withValues(alpha: 0.5) : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundImage: account.photoUrl != null
                                ? NetworkImage(account.photoUrl!)
                                : null,
                            backgroundColor: AppColors.grey10,
                            child: account.photoUrl == null
                                ? const Icon(Icons.person, color: AppColors.grey50)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  account.username,
                                  style: GoogleFonts.notoSansJp(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                if (account.loginId.isNotEmpty)
                                  Text(
                                    account.loginId,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (isSwitching)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else if (isCurrent)
                            const Icon(Icons.check_circle, color: Colors.blue, size: 24),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // アカウント追加ボタン
            Padding(
              padding: const EdgeInsets.all(16),
              child: InkWell(
                onTap: _addAccount,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.grey10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add_circle_outline, color: AppColors.textPrimary),
                      SizedBox(width: 16),
                      Text(
                        'アカウントを追加',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}
