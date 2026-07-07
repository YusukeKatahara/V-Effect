import 'dart:async';
import 'package:home_widget/home_widget.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import '../config/routes.dart';
import 'friend_service.dart';
import '../screens/main_shell.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription<Uri?>? _widgetSubscription;
  
  // Navigatorの準備ができるまでリンクを保持するキュー
  final List<Uri> _pendingLinks = [];
  bool _isNavigatorReady = false;

  Future<void> initialize() async {
    _appLinks = AppLinks();

    // イベント購読は可能な限り早く行う
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _queueOrHandleLink(uri);
    });

    // home_widget は Web 非対応。ストリームの listen は非同期エラーになり
    // zone ハンドラーがアプリ全体をエラー画面にしてしまうため、必ずガードする
    if (!kIsWeb) {
      _widgetSubscription = HomeWidget.widgetClicked.listen((Uri? uri) {
        if (uri != null) {
          _queueOrHandleLink(uri);
        }
      });
    }

    // 初期リンクも取得してキューに入れる
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      _queueOrHandleLink(initialUri);
    }

    if (!kIsWeb) {
      final initialWidgetUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (initialWidgetUri != null) {
        _queueOrHandleLink(initialWidgetUri);
      }
    }
  }

  /// Navigatorが準備できたことを通知し、保留中のリンクを処理する
  void onNavigatorReady() {
    _isNavigatorReady = true;
    for (final uri in _pendingLinks) {
      _handleLink(uri);
    }
    _pendingLinks.clear();
  }

  void _queueOrHandleLink(Uri uri) {
    if (!_isNavigatorReady) {
      _pendingLinks.add(uri);
    } else {
      _handleLink(uri);
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
    _widgetSubscription?.cancel();
  }

  void _handleLink(Uri uri) async {
    final uriString = uri.toString();
    debugPrint('Incoming deep link: $uriString');

    // プロフィールURL（/u/{userId}）のハンドリング
    if (uri.host == 'veffect.web.app') {
      final segments = uri.pathSegments;
      if (segments.length >= 2 && segments[0] == 'u') {
        await _handleUserProfileLink(Uri.decodeComponent(segments[1]));
        return;
      }
    }

    // カスタムスキーム（ウィジェットからの遷移など）
    if (uriString.contains('veffect://task') || uriString.contains('veffect:task')) {
      _navigateToTaskScreen();
      return;
    }

    // Firebase Auth のアクションリンク（メール認証など）を判定
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

  Future<void> _handleUserProfileLink(String userId) async {
    try {
      final user = await FriendService.instance.searchByUserId(userId);
      final context = VEffectApp.navigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ユーザーが見つかりません')),
        );
        return;
      }
      if (!context.mounted) return;
      Navigator.of(context).pushNamed(
        AppRoutes.userProfile,
        arguments: {
          'uid': user.uid,
          'username': user.username,
          'photoUrl': user.photoUrl,
        },
      );
    } catch (e) {
      debugPrint('Error handling user profile link: $e');
    }
  }

  Future<void> _navigateToTaskScreen() async {
    try {
      // 1. 最も確実な方法: グローバルなタブ切り替えフラグを直接変更する
      MainShell.activeTabIndex.value = 1;
      
      final context = VEffectApp.navigatorKey.currentContext;
      if (context == null || !context.mounted) return;

      // 2. 万が一、まだMainShellが表示されていない（別の画面にいる）場合のために
      // ルートをAppRoutes.homeにリセットする。
      // すでにMainShellにいる場合は同じルートへの遷移は無視されるか、didUpdateWidgetが走る。
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.home,
        (r) => false,
        arguments: 1,
      );
    } catch (e) {
      debugPrint('Error navigating to task screen: $e');
    }
  }

  Future<void> _handleVerifyEmail(String oobCode) async {
    try {
      // メール認証の場合は applyActionCode を使う
      // (注意: 以前誤って呼び出されていた confirmPasswordReset は、パスワードリセット用のため invalid-action-code エラーの原因となっており削除しました)
      await FirebaseAuth.instance.applyActionCode(oobCode);
      
      debugPrint('Email verified successfully via deep link');
      
      // アプリが起動していれば、メッセージを表示して適切な画面へ
      const snackBar = SnackBar(
        content: Text('メール認証が完了しました！'),
        backgroundColor: Colors.green,
      );
      
      final context = VEffectApp.navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
        // ラッパーに戻して、認証状態を再評価させる
        Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.wrapper, (r) => false);
      }
    } catch (e) {
      debugPrint('Error verifying email: $e');
      final context = VEffectApp.navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('認証に失敗しました。リンクが無効か期限切れの可能性があります。: $e')),
        );
      }
    }
  }
}
