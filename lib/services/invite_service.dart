import 'package:share_plus/share_plus.dart';
import 'analytics_service.dart';

class InviteService {
  static final InviteService _instance = InviteService._internal();
  factory InviteService() => _instance;
  InviteService._internal();

  static InviteService get instance => _instance;

  static const _baseUrl = 'https://veffect.web.app/u';

  String buildInviteUrl(String userId) {
    return '$_baseUrl/${Uri.encodeComponent(userId)}';
  }

  Future<void> shareInviteCard({
    required String userId,
    required String username,
  }) async {
    final url = buildInviteUrl(userId);
    await SharePlus.instance.share(
      ShareParams(
        text: '$username さんがV EFFECTに招待しています！\n$url',
        subject: 'V EFFECTに参加しよう',
      ),
    );
    await AnalyticsService.instance.logPostShared(platform: 'invite_link');
  }
}
