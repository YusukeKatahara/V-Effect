import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// ユーザーIDとパスワードによるカスタム認証（Cloud Functions経由）
  Future<UserCredential> loginWithUserId(String userId, String password, String apiKey) async {
    final callable = FirebaseFunctions.instance.httpsCallable('loginWithUserId');
    final response = await callable.call({
      'userId': userId,
      'password': password,
      'apiKey': apiKey,
    });
    final token = response.data['token'] as String;
    return await _auth.signInWithCustomToken(token);
  }

  /// Googleでログイン（または登録）
  Future<UserCredential?> signInWithGoogle() async {
    if (kIsWeb) {
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      return await _auth.signInWithPopup(googleProvider);
    } else {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null; // ユーザーがキャンセルした場合

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    }
  }

  /// Appleでログイン（または登録）
  Future<UserCredential?> signInWithApple() async {
    if (kIsWeb) {
      final appleProvider = OAuthProvider('apple.com');
      appleProvider.addScope('email');
      appleProvider.addScope('name');
      return await _auth.signInWithPopup(appleProvider);
    } else {
      final AuthorizationCredentialAppleID appleCredential =
          await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final OAuthProvider oAuthProvider = OAuthProvider('apple.com');
      final credential = oAuthProvider.credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );
      
      return await _auth.signInWithCredential(credential);
    }
  }
}
