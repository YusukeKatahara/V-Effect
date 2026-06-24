import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Live Activity (iOSのロック画面やDynamic Islandに表示されるウィジェット) への通信を管理するサービス。
/// ネイティブ側との接続には MethodChannel を使用します。
class LiveActivityService {
  LiveActivityService._();

  static const MethodChannel _channel = MethodChannel('com.veffect.app/live_activity');

  /// Live Activity を開始します。
  /// [taskName] は現在実行中のタスクの名前です。
  static Future<void> startActivity(String taskName) async {
    try {
      await _channel.invokeMethod('startActivity', {
        'taskName': taskName,
      });
    } on PlatformException catch (e) {
      // プラットフォーム固有のエラーが発生した場合の処理（シミュレータやAndroidなど）
      // ログを出力して、アプリ全体がクラッシュするのを防ぎます
      debugPrint('LiveActivityService.startActivity エラー: ${e.message}');
    }
  }

  /// Live Activity の表示内容（進捗率やステータス）を更新します。
  /// [progress] は進捗率 (0.0 から 1.0) です。
  /// [status] は進捗状態を示す文字列です。
  /// [message] はユーザー向けに表示されるメッセージです。
  static Future<void> updateActivity(double progress, String status, String message) async {
    try {
      await _channel.invokeMethod('updateActivity', {
        'progress': progress,
        'status': status,
        'message': message,
      });
    } on PlatformException catch (e) {
      debugPrint('LiveActivityService.updateActivity エラー: ${e.message}');
    }
  }

  /// Live Activity を終了します。
  /// [status] は終了時の状態 (success, error など) です。
  /// [message] はユーザー向けに表示されるメッセージです。
  static Future<void> stopActivity(String status, String message) async {
    try {
      await _channel.invokeMethod('stopActivity', {
        'status': status,
        'message': message,
      });
    } on PlatformException catch (e) {
      debugPrint('LiveActivityService.stopActivity エラー: ${e.message}');
    }
  }
}
