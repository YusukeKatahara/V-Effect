import 'package:share_plus/share_plus.dart';

/// フレンド招待リンクの生成・シェアを担当するサービス
class InviteService {
  InviteService._();
  static final InviteService instance = InviteService._();

  /// 招待ページのベースURL
  static const String _baseUrl = 'https://veffect.web.app/u';

  /// ユーザーIDに対応する招待URLを生成する
  String buildInviteUrl(String userId) {
    return '$_baseUrl/${Uri.encodeComponent(userId)}';
  }

  /// OSのシェアシートを開いて招待URLをシェアする
  ///
  /// [userId]   : 自分のユーザーID (例: 'yusuke_v')
  /// [username] : 自分のユーザー名 (例: 'Yusuke')
  Future<void> shareInviteCard({
    required String userId,
    required String username,
  }) async {
    final url = buildInviteUrl(userId);
    final text = '$username があなたをV EFFECTに招待しています 🔥\n'
        'フレンドになって一緒に頑張ろう！\n\n'
        '$url';

    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: 'V EFFECT – フレンドからの招待',
      ),
    );
  }
}
