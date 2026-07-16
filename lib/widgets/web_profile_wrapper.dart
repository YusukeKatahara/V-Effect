import 'package:flutter/material.dart';
import '../services/friend_service.dart';
import '../config/app_colors.dart';
import '../config/routes.dart';

/// Webダイレクトアクセス（/@username）時に、ユーザーIDを元にユーザープロフィールをロードしてリダイレクトするラッパー
class WebProfileWrapper extends StatefulWidget {
  final String username;
  const WebProfileWrapper({super.key, required this.username});

  @override
  State<WebProfileWrapper> createState() => _WebProfileWrapperState();
}

class _WebProfileWrapperState extends State<WebProfileWrapper> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = await FriendService.instance.searchByUserId(widget.username);
      if (user != null) {
        if (mounted) {
          // 見つかったらUserProfileScreenに遷移（履歴を残さないために置換）
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.userProfile,
            arguments: user.uid,
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'ユーザーが見つかりませんでした';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '読み込み中にエラーが発生しました';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Center(
        child: _loading
            ? CircularProgressIndicator(color: AppColors.primary)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _error ?? '',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, AppRoutes.home);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.pureWhite,
                      foregroundColor: AppColors.pureBlack,
                    ),
                    child: const Text('ホームに戻る'),
                  ),
                ],
              ),
      ),
    );
  }
}
