import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/saved_account.dart';

/// 複数アカウントのログイン情報を端末の SecureStorage に保存・管理する
class MultiAccountService {
  static final MultiAccountService _instance = MultiAccountService._internal();
  static MultiAccountService get instance => _instance;
  MultiAccountService._internal();

  final _storage = const FlutterSecureStorage();
  static const _storageKey = 'saved_accounts';

  /// 現在ログイン中のユーザーを保存する
  Future<void> saveCurrentAccount({required String loginId, String? password}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data();
    final username = data?['username'] ?? user.displayName ?? 'Unknown';
    final photoUrl = data?['photoUrl'] ?? user.photoURL;

    // プロバイダー判定
    AuthAccountType provider = AuthAccountType.custom;
    for (final info in user.providerData) {
      if (info.providerId == 'google.com') provider = AuthAccountType.google;
      if (info.providerId == 'apple.com') provider = AuthAccountType.apple;
    }

    final account = SavedAccount(
      uid: user.uid,
      loginId: loginId,
      username: username,
      photoUrl: photoUrl,
      provider: provider,
      password: password,
    );
    await saveAccount(account);
  }

  /// 保存されたアカウントリストを取得
  Future<List<SavedAccount>> getSavedAccounts() async {
    final jsonStr = await _storage.read(key: _storageKey);
    if (jsonStr == null) return [];
    try {
      final List<dynamic> list = json.decode(jsonStr);
      return list.map((m) => SavedAccount.fromMap(m)).toList();
    } catch (e) {
      return [];
    }
  }

  /// アカウントの追加/更新
  Future<void> saveAccount(SavedAccount account) async {
    final list = await getSavedAccounts();
    // すでに存在すれば更新、なければ追加
    final index = list.indexWhere((a) => a.uid == account.uid);
    if (index >= 0) {
      list[index] = account;
    } else {
      list.add(account);
    }
    await _storage.write(key: _storageKey, value: json.encode(list.map((a) => a.toMap()).toList()));
  }

  /// アカウントの削除
  Future<void> removeAccount(String uid) async {
    final list = await getSavedAccounts();
    list.removeWhere((a) => a.uid == uid);
    await _storage.write(key: _storageKey, value: json.encode(list.map((a) => a.toMap()).toList()));
  }

  /// 指定 UID のアカウントが保存済みかチェック
  Future<SavedAccount?> findSavedAccount(String uid) async {
    final list = await getSavedAccounts();
    return list.where((a) => a.uid == uid).firstOrNull;
  }
}
