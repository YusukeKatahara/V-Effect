import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';

/// アプリの強制アップデートを管理するサービス
class ForceUpdateService {
  ForceUpdateService._();
  static final ForceUpdateService instance = ForceUpdateService._();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  bool _needsForceUpdate = false;
  String _forceUpdateMessage = '新しいバージョンが利用可能です。セキュリティ向上のため、アプリのアップデートをお願いいたします。';

  /// 強制アップデートが必要かどうかの判定結果を取得
  bool get needsForceUpdate => _needsForceUpdate;

  /// 画面に表示するアップデート案内メッセージを取得
  String get forceUpdateMessage => _forceUpdateMessage;

  /// アプリ起動時に呼び出し、リモート構成の取得とバージョン比較を行います。
  Future<void> checkForceUpdate() async {
    try {
      // 1. デフォルト値の設定
      await _remoteConfig.setDefaults(<String, dynamic>{
        'minimum_version': '1.0.0',
        'force_update_enabled': false,
        'force_update_message': '新しいバージョンが利用可能です。セキュリティ向上のため、アプリのアップデートをお願いいたします。',
      });

      // 2. フェッチの実行（12時間のキャッシュ、デバッグ時はキャッシュを無効化）
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: kDebugMode ? Duration.zero : const Duration(hours: 12),
      ));

      await _remoteConfig.fetchAndActivate();

      // 3. パラメータの取得
      final minimumVersion = _remoteConfig.getString('minimum_version');
      final forceUpdateEnabled = _remoteConfig.getBool('force_update_enabled');
      _forceUpdateMessage = _remoteConfig.getString('force_update_message');

      // 4. 自分のアプリのバージョンを取得
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      debugPrint('[ForceUpdate] Current: $currentVersion, Minimum required: $minimumVersion, Enabled: $forceUpdateEnabled');

      // 5. バージョン判定
      if (forceUpdateEnabled) {
        _needsForceUpdate = _isVersionLessThan(currentVersion, minimumVersion);
      } else {
        _needsForceUpdate = false;
      }

      // デバッグモード（開発中）では、強制アップデート画面で開発作業がブロックされないよう判定をスキップします
      if (kDebugMode) {
        debugPrint('[ForceUpdate] デバッグモードのため強制アップデート判定をスキップします');
        _needsForceUpdate = false;
      }
    } catch (e) {
      debugPrint('[ForceUpdate] エラーが発生したため強制アップデート判定をスキップします: $e');
      _needsForceUpdate = false; // エラー時はアプリの利用を妨げないように安全側に倒す
    }
  }

  /// セマンティック・バージョニング（X.Y.Z）に基づき、現在のバージョンがターゲット未満か判定します
  bool _isVersionLessThan(String current, String target) {
    try {
      final currentParts = current.split('+').first.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final targetParts = target.split('+').first.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      // 桁数を揃える (例: "1.0" -> [1, 0, 0])
      while (currentParts.length < 3) {
        currentParts.add(0);
      }
      while (targetParts.length < 3) {
        targetParts.add(0);
      }

      for (int i = 0; i < 3; i++) {
        if (currentParts[i] < targetParts[i]) {
          return true; // 現在のバージョンの方が小さい
        } else if (currentParts[i] > targetParts[i]) {
          return false; // 現在のバージョンの方が大きい
        }
      }
    } catch (e) {
      debugPrint('[ForceUpdate] バージョン比較パースエラー: $e');
    }
    return false; // 等しいかエラー時は false (アップデート不要とみなす)
  }
}
