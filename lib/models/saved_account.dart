import 'dart:convert';

enum AuthAccountType { custom, google, apple }

/// 端末に保存されるログイン済みアカウント情報
class SavedAccount {
  final String uid;
  final String loginId; // ログインに使用するID (email または userId)
  final String username;
  final String? photoUrl;
  final AuthAccountType provider;
  final String? password; // custom の場合のみ利用

  SavedAccount({
    required this.uid,
    required this.loginId,
    required this.username,
    this.photoUrl,
    required this.provider,
    this.password,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'loginId': loginId,
      'username': username,
      'photoUrl': photoUrl,
      'provider': provider.name,
      'password': password,
    };
  }

  factory SavedAccount.fromMap(Map<String, dynamic> map) {
    return SavedAccount(
      uid: map['uid'] as String,
      loginId: map['loginId'] as String? ?? '', // 後方互換性のため
      username: map['username'] as String,
      photoUrl: map['photoUrl'] as String?,
      provider: AuthAccountType.values.byName(map['provider'] as String),
      password: map['password'] as String?,
    );
  }

  String toJson() => json.encode(toMap());
  factory SavedAccount.fromJson(String source) =>
      SavedAccount.fromMap(json.decode(source) as Map<String, dynamic>);
}
