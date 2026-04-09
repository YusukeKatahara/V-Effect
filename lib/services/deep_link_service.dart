import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import '../config/routes.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  Future<void> initialize() async {
    _appLinks = AppLinks();

    // アプリが完全に終了している状態からの起動時のリンクを取得
    final initialUri = await _appLinks.getInitialAppLink();
    if (initialUri != null) {
      _handleLink(initialUri);
    }

    // アプリがバックグラウンドにいる状態でのリンクイベントを購読
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleLink(uri);
    });
  }

  void dispose() {
    _linkSubscription?.cancel();
  }

  void _handleLink(Uri uri) async {
    debugPrint('Incoming deep link: $uri');

    // Firebase Auth のアクションリンク（メール認証など）を判定
    // 通常、oobCode パラメータが含まれる
    final oobCode = uri.queryParameters['oobCode'];
    final mode = uri.queryParameters['mode'];

    if (oobCode != null && mode != null) {
      switch (mode) {
        case 'verifyEmail':
          _handleVerifyEmail(oobCode);
          break;
        case 'resetPassword':
          // パスワードリセット画面へ遷移など
          break;
      }
    }
  }

  Future<void> _handleVerifyEmail(String oobCode) async {
    try {
      await FirebaseAuth.instance.confirmPasswordReset(code: oobCode, newPassword: ''); // これはパスワードリセット用
      // メール認証の場合は applyActionCode を使う
      await FirebaseAuth.instance.applyActionCode(oobCode);
      
      debugPrint('Email verified successfully via deep link');
      
      // アプリが起動していれば、メッセージを表示して適切な画面へ
      const snackBar = SnackBar(
        content: Text('メール認証が完了しました！'),
        backgroundColor: Colors.green,
      );
      
      final context = VEffectApp.navigatorKey.currentContext;
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
        // ラッパーに戻して、認証状態を再評価させる
        Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.wrapper, (r) => false);
      }
    } catch (e) {
      debugPrint('Error verifying email: $e');
      final context = VEffectApp.navigatorKey.currentContext;
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('認証に失敗しました。リンクが無効か期限切れの可能性があります。: $e')),
        );
      }
    }
  }
}
