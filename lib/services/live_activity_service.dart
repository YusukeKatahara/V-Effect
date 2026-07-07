import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Live Activity (iOSのロック画面やDynamic Islandに表示されるウィジェット) への通信を管理するサービス。
/// ネイティブ側との接続には MethodChannel を使用します。
class LiveActivityService {
  LiveActivityService._();

  static const MethodChannel _channel = MethodChannel('com.veffect.app/live_activity');

  /// Live Activity を開始します。
  /// [taskName] は現在実行中のタスクの名前です。
  /// [imageBytes] はアップロード対象の画像データです。
  static Future<void> startActivity(String taskName, Uint8List? imageBytes) async {
    if (kIsWeb || !Platform.isIOS) return; // iOS以外のプラットフォーム（Web/Androidなど）では処理をスキップします
    try {
      await _channel.invokeMethod('startActivity', {
        'taskName': taskName,
        'progress': 0.05,
        'status': 'uploading',
        'statusMessage': '投稿中...',
        'imageBytes': imageBytes,
      });
    } catch (e) {
      // プラットフォーム固有のエラーや MissingPluginException を安全にキャッチしてアプリ全体のクラッシュを防ぎます
      debugPrint('LiveActivityService.startActivity エラー: $e');
    }
  }

  /// Live Activity の表示内容（進捗率やステータス）を更新します。
  /// [progress] は進捗率 (0.0 から 1.0) です。
  /// [status] は進捗状態を示す文字列です。
  /// [message] はユーザー向けに表示されるメッセージです。
  static Future<void> updateActivity(double progress, String status, String message) async {
    if (kIsWeb || !Platform.isIOS) return; // iOS以外のプラットフォーム（Web/Androidなど）では処理をスキップします
    try {
      await _channel.invokeMethod('updateActivity', {
        'progress': progress,
        'status': status,
        'statusMessage': message,
      });
    } catch (e) {
      debugPrint('LiveActivityService.updateActivity エラー: $e');
    }
  }

  /// Live Activity を終了します。
  /// [status] は終了時の状態 (success, error など) です。
  /// [message] はユーザー向けに表示されるメッセージです。
  static Future<void> stopActivity(String status, String message) async {
    if (kIsWeb || !Platform.isIOS) return; // iOS以外のプラットフォーム（Web/Androidなど）では処理をスキップします
    try {
      await _channel.invokeMethod('stopActivity', {
        'progress': status == 'success' ? 1.0 : 0.0,
        'status': status,
        'statusMessage': message,
      });
    } catch (e) {
      debugPrint('LiveActivityService.stopActivity エラー: $e');
    }
  }
}
