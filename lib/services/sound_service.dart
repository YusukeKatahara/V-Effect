import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class SoundService {
  SoundService._internal();
  static final SoundService instance = SoundService._internal();

  // 単一のプレイヤーを再利用する（メモリ効率と低遅延のため）
  final AudioPlayer _player = AudioPlayer();

  /// アプリ起動時に音声を事前ロード（キャッシュ）しておくことで遅延を防ぎます
  Future<void> init() async {
    try {
      // iOSのマナーモードを無視して再生するための設定
      await AudioPlayer.global.setAudioContext(AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {
            AVAudioSessionOptions.mixWithOthers,
            AVAudioSessionOptions.defaultToSpeaker,
          },
        ),
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.assistanceSonification,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
      ));

      await _player.setSource(AssetSource('sounds/task_complete_sync.mp3'));
      _player.setPlayerMode(PlayerMode.lowLatency);
    } catch (e) {
      debugPrint('Error initializing sound service: $e');
    }
  }

  /// タスク完了時のドーパミンサウンドを再生
  Future<void> playTaskCompleteSound() async {
    try {
      // 連続で完了した場合でも、一度停止して即座に鳴らし直す
      if (_player.state == PlayerState.playing) {
        await _player.stop();
      }
      await _player.resume(); // すでにsetSourceされているのでresumeで最速再生
    } catch (e) {
      debugPrint('Error playing sound: $e');
      // 万が一resumeに失敗した場合は直接再生
      await _player.play(AssetSource('sounds/task_complete_sync.mp3'), mode: PlayerMode.lowLatency);
    }
  }
}
