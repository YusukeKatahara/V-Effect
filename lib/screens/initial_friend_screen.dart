import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../services/analytics_service.dart';
import '../services/friend_service.dart';
import '../widgets/premium_background.dart';
import '../widgets/gradient_button.dart';
import '../widgets/premium_icon_header.dart';
import '../widgets/section_title.dart';
import '../widgets/swipe_back_gate.dart';

/// ヒーロータスク設定完了後に表示される初期フレンド登録画面
class InitialFriendScreen extends StatefulWidget {
  const InitialFriendScreen({super.key});

  @override
  State<InitialFriendScreen> createState() => _InitialFriendScreenState();
}

class _InitialFriendScreenState extends State<InitialFriendScreen>
    with SingleTickerProviderStateMixin {
  final FriendService _friendService = FriendService.instance;
  final TextEditingController _userIdCtrl = TextEditingController();

  // プリセットユーザーの選択状態
  bool _rennSelected = false;
  bool _yusukeSelected = false;
  bool _otherSelected = false;

  bool _isSending = false;
  String? _error;

  // プリセットユーザーのユーザーID
  static const String _rennUserId = 'X';
  static const String _yusukeUserId = 'katahara01';

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _userIdCtrl.dispose();
    super.dispose();
  }

  bool get _hasSelection =>
      _rennSelected ||
      _yusukeSelected ||
      (_otherSelected && _userIdCtrl.text.trim().isNotEmpty);

  Future<void> _register() async {
    if (!_hasSelection) return;

    setState(() {
      _isSending = true;
      _error = null;
    });

    try {
      final presetUserIds = <String>[];
      if (_rennSelected) presetUserIds.add(_rennUserId);
      if (_yusukeSelected) presetUserIds.add(_yusukeUserId);

      final otherUserId =
          _otherSelected ? _userIdCtrl.text.trim() : null;

      int sentCount = 0;
      final errors = <String>[];

      // プリセットユーザー（ユーザーIDで検索）
      for (final userId in presetUserIds) {
        try {
          final user = await _friendService.searchByUserId(userId);
          if (user == null) {
            errors.add('@$userId: ユーザーが見つかりません');
            continue;
          }
          await _friendService.sendRequest(user.uid);
          sentCount++;
        } catch (e) {
          errors.add('@$userId: 送信に失敗しました');
        }
      }

      // その他のユーザー（ユーザーIDで検索）
      if (otherUserId != null && otherUserId.isNotEmpty) {
        try {
          final user = await _friendService.searchByUserId(otherUserId);
          if (user == null) {
            errors.add('$otherUserId: ユーザーが見つかりません');
          } else {
            await _friendService.sendRequest(user.uid);
            sentCount++;
          }
        } catch (e) {
          errors.add('$otherUserId: 送信に失敗しました');
        }
      }

      // 招待元を Analytics に記録（UIには影響なし）
      final referrers = <String>[];
      if (_rennSelected) referrers.add('renn');
      if (_yusukeSelected) referrers.add('yusuke');
      if (otherUserId != null && otherUserId.isNotEmpty) {
        referrers.add('other');
      }
      AnalyticsService.instance
          .logReferralSource(referrers: referrers, skipped: false);

      if (mounted) {
        if (sentCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$sentCount件のフレンドリクエストを送信しました！'),
            ),
          );
        }
        if (errors.isNotEmpty) {
          setState(() => _error = errors.join('\n'));
        } else {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = '送信に失敗しました。もう一度お試しください。');
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Widget _buildSelectableCard({
    required bool selected,
    required VoidCallback onTap,
    required String label,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.textMuted,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 14, color: AppColors.black)
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SwipeBackGate(
      child: Scaffold(
        backgroundColor: AppColors.bgBase,
      body: Stack(
        children: [
          const PremiumBackground(),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  // Custom header row
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: AppColors.textPrimary),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const Text(
                          'フレンド登録',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const PremiumIconHeader(
                              icon: Icons.people, size: 72, iconSize: 40),
                          const SizedBox(height: 16),
                          const Text(
                            '一緒に頑張る仲間を登録しよう！',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // ── 誰に誘われましたか？ ──
                          const SectionTitle(title: '誰に誘われましたか？'),
                          const SizedBox(height: 12),

                          // Renn
                          _buildSelectableCard(
                            selected: _rennSelected,
                            onTap: () => setState(
                                () => _rennSelected = !_rennSelected),
                            label: 'Renn',
                          ),

                          // Yusuke
                          _buildSelectableCard(
                            selected: _yusukeSelected,
                            onTap: () => setState(
                                () => _yusukeSelected = !_yusukeSelected),
                            label: 'Yusuke',
                          ),

                          // Other user
                          _buildSelectableCard(
                            selected: _otherSelected,
                            onTap: () => setState(
                                () => _otherSelected = !_otherSelected),
                            label: 'その他のユーザー：ユーザーIDを入力',
                          ),

                          // ユーザーID入力欄（「その他」選択時のみ表示）
                          if (_otherSelected) ...[
                            const SizedBox(height: 8),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: TextField(
                                controller: _userIdCtrl,
                                style: const TextStyle(
                                    color: AppColors.textPrimary),
                                decoration: const InputDecoration(
                                  labelText: 'ユーザーID',
                                  hintText: '例: user_123',
                                  prefixIcon: Icon(Icons.person_search),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],

                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              style: const TextStyle(
                                  color: AppColors.error, fontSize: 13),
                            ),
                          ],

                          const SizedBox(height: 32),

                          // ── 登録ボタン ──
                          GradientButton(
                            onPressed: _hasSelection ? _register : null,
                            isLoading: _isSending,
                            child: const Text('登録する'),
                          ),

                          const SizedBox(height: 16),

                          // ── あとで登録する ──
                          TextButton(
                            onPressed: _isSending
                                ? null
                                : () {
                                    // スキップも記録
                                    AnalyticsService.instance
                                        .logReferralSource(
                                            referrers: [], skipped: true);
                                    Navigator.of(context).pop();
                                  },
                            child: const Text(
                              'あとで登録する',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}
