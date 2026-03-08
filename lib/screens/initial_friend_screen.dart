import 'package:flutter/material.dart';
import '../config/routes.dart';
import '../services/friend_service.dart';

/// タスク設定完了後に表示される初期フレンド登録画面
class InitialFriendScreen extends StatefulWidget {
  const InitialFriendScreen({super.key});

  @override
  State<InitialFriendScreen> createState() => _InitialFriendScreenState();
}

class _InitialFriendScreenState extends State<InitialFriendScreen> {
  final FriendService _friendService = FriendService();
  final TextEditingController _userIdCtrl = TextEditingController();

  // プリセットユーザーの選択状態
  bool _rennSelected = false;
  bool _yusukeSelected = false;
  bool _otherSelected = false;

  bool _isSending = false;
  String? _error;

  // プリセットユーザーの User ID
  static const String _rennUserId = 'renn';
  static const String _yusukeUserId = 'yusuke';

  @override
  void dispose() {
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
      final userIds = <String>[];
      if (_rennSelected) userIds.add(_rennUserId);
      if (_yusukeSelected) userIds.add(_yusukeUserId);
      if (_otherSelected && _userIdCtrl.text.trim().isNotEmpty) {
        userIds.add(_userIdCtrl.text.trim());
      }

      int sentCount = 0;
      final errors = <String>[];

      for (final userId in userIds) {
        try {
          final user = await _friendService.searchByUserId(userId);
          if (user == null) {
            errors.add('$userId: ユーザーが見つかりません');
            continue;
          }
          await _friendService.sendRequest(user.uid);
          sentCount++;
        } catch (e) {
          errors.add('$userId: $e');
        }
      }

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
          Navigator.pushReplacementNamed(context, AppRoutes.home);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = '送信に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('フレンド登録')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.people, size: 80, color: Colors.amber),
            const SizedBox(height: 16),
            const Text(
              '一緒に頑張る仲間を登録しよう！',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),

            // ── 誰に誘われましたか？ ──
            const Text(
              '誰に誘われましたか？',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            // Renn
            CheckboxListTile(
              value: _rennSelected,
              onChanged: (v) => setState(() => _rennSelected = v ?? false),
              title: const Text('Renn'),
              activeColor: Colors.amber.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            ),

            // Yusuke
            CheckboxListTile(
              value: _yusukeSelected,
              onChanged: (v) => setState(() => _yusukeSelected = v ?? false),
              title: const Text('Yusuke'),
              activeColor: Colors.amber.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            ),

            // Other user
            CheckboxListTile(
              value: _otherSelected,
              onChanged: (v) => setState(() => _otherSelected = v ?? false),
              title: const Text('その他のユーザー：ユーザーIDを入力'),
              activeColor: Colors.amber.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            ),

            // ユーザーID入力欄（「その他」選択時のみ表示）
            if (_otherSelected) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextField(
                  controller: _userIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ユーザーID',
                    hintText: '例: user_123',
                    border: OutlineInputBorder(),
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
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ],

            const SizedBox(height: 32),

            // ── 登録ボタン ──
            _isSending
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _hasSelection ? _register : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.amber.shade700,
                      textStyle: const TextStyle(fontSize: 17),
                    ),
                    child: const Text('登録する'),
                  ),

            const SizedBox(height: 16),

            // ── あとで登録する ──
            TextButton(
              onPressed: _isSending
                  ? null
                  : () {
                      Navigator.pushReplacementNamed(context, AppRoutes.home);
                    },
              child: const Text(
                'あとで登録する',
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
