import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_effect/providers/home_provider.dart';
import 'package:v_effect/services/post_service.dart';
import 'package:v_effect/services/live_activity_service.dart';

/// アップロードの状態を表す列挙型
enum UploadStatus {
  idle,
  uploading,
  success,
  error,
}

/// アップロードの状態を保持するイミュータブルなデータクラス
class UploadState {
  final UploadStatus status;
  final double progress;
  final String? errorMessage;

  // 再送信用のパラメータ
  final Uint8List? imageBytes;
  final String? taskName;
  final String? caption;
  final String? bgmUrl;
  final String? bgmTitle;
  final String? bgmArtist;
  final String? bgmArtworkUrl;

  UploadState({
    required this.status,
    this.progress = 0.0,
    this.errorMessage,
    this.imageBytes,
    this.taskName,
    this.caption,
    this.bgmUrl,
    this.bgmTitle,
    this.bgmArtist,
    this.bgmArtworkUrl,
  });

  UploadState copyWith({
    UploadStatus? status,
    double? progress,
    String? errorMessage,
    Uint8List? imageBytes,
    String? taskName,
    String? caption,
    String? bgmUrl,
    String? bgmTitle,
    String? bgmArtist,
    String? bgmArtworkUrl,
  }) {
    return UploadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      imageBytes: imageBytes ?? this.imageBytes,
      taskName: taskName ?? this.taskName,
      caption: caption ?? this.caption,
      bgmUrl: bgmUrl ?? this.bgmUrl,
      bgmTitle: bgmTitle ?? this.bgmTitle,
      bgmArtist: bgmArtist ?? this.bgmArtist,
      bgmArtworkUrl: bgmArtworkUrl ?? this.bgmArtworkUrl,
    );
  }
}

/// アップロード状態を管理するNotifier
class UploadNotifier extends StateNotifier<UploadState> {
  final Ref _ref;
  Timer? _dummyProgressTimer;

  UploadNotifier(this._ref) : super(UploadState(status: UploadStatus.idle));

  /// アップロードを開始します
  Future<void> startUpload({
    required Uint8List imageBytes,
    required String taskName,
    String? caption,
    String? bgmUrl,
    String? bgmTitle,
    String? bgmArtist,
    String? bgmArtworkUrl,
  }) async {
    _dummyProgressTimer?.cancel();
    state = UploadState(
      status: UploadStatus.uploading,
      progress: 0.05,
      imageBytes: imageBytes,
      taskName: taskName,
      caption: caption,
      bgmUrl: bgmUrl,
      bgmTitle: bgmTitle,
      bgmArtist: bgmArtist,
      bgmArtworkUrl: bgmArtworkUrl,
    );

    await _executeUpload();
  }

  /// 失敗したアップロードを再試行します
  Future<void> retryUpload() async {
    if (state.status != UploadStatus.error) return;

    state = state.copyWith(
      status: UploadStatus.uploading,
      progress: 0.05,
      errorMessage: null,
    );

    await _executeUpload();
  }

  /// 実際のアップロード処理を実行します
  Future<void> _executeUpload() async {
    final imageBytes = state.imageBytes;
    final taskName = state.taskName;

    if (imageBytes == null || taskName == null) {
      state = state.copyWith(
        status: UploadStatus.error,
        errorMessage: 'アップロードデータが見つかりません。',
      );
      return;
    }

    // 🚀 Live Activity を開始します。
    await LiveActivityService.startActivity(taskName, imageBytes);

    // 擬似的に進捗バーを進めるタイマーを開始（300msごとに少しずつ進行、最大90%まで）
    double currentProgress = 0.05;
    _dummyProgressTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) async {
      if (currentProgress < 0.90) {
        currentProgress += 0.05;
        if (state.status == UploadStatus.uploading) {
          state = state.copyWith(progress: currentProgress);
          // 🚀 Live Activity の進捗を更新します。
          await LiveActivityService.updateActivity(
            currentProgress,
            'uploading',
            '投稿中...',
          );
        }
      } else {
        timer.cancel();
      }
    });

    try {
      // 投稿のアップロード処理
      await PostService.instance.createPost(
        imageBytes: imageBytes,
        taskName: taskName,
        caption: state.caption,
        bgmUrl: state.bgmUrl,
        bgmTitle: state.bgmTitle,
        bgmArtist: state.bgmArtist,
        bgmArtworkUrl: state.bgmArtworkUrl,
      );

      _dummyProgressTimer?.cancel();

      // 完了状態（100%）に更新
      state = state.copyWith(
        status: UploadStatus.success,
        progress: 1.0,
      );

      // 🚀 Live Activity を成功終了します。
      await LiveActivityService.stopActivity('success', '投稿完了');

      // ホームのデータを強制リフレッシュして最新のフィードを表示
      _ref.invalidate(homeDataProvider);

      // 成功表示を少し見せてから idle 状態に戻す (3秒後)
      Future.delayed(const Duration(seconds: 3), () {
        if (state.status == UploadStatus.success) {
          state = UploadState(status: UploadStatus.idle);
        }
      });
    } catch (e) {
      _dummyProgressTimer?.cancel();
      state = state.copyWith(
        status: UploadStatus.error,
        errorMessage: e.toString(),
      );

      // 🚀 Live Activity をエラー終了します。
      await LiveActivityService.stopActivity('error', '投稿できませんでした');
    }
  }

  @override
  void dispose() {
    _dummyProgressTimer?.cancel();
    super.dispose();
  }
}

/// アプリ全体からアップロード状態にアクセスするためのProvider
final uploadProvider = StateNotifierProvider<UploadNotifier, UploadState>((ref) {
  return UploadNotifier(ref);
});
