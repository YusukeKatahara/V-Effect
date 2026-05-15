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
          options: const {
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

      // audioplayers v6では setSource だけで十分
      await _player.setSource(AssetSource('sounds/task_complete_sync.mp3'));
    } catch (e) {
      debugPrint('Error initializing sound service: $e');
    }
  }

  /// タスク完了時のドーパミンサウンドを再生
  Future<void> playTaskCompleteSound() async {
    try {
      if (_player.state == PlayerState.playing) {
        await _player.stop();
      }
      // lowLatency は iOS で mp3 の再生に失敗する原因になることがあるため外す
      // stop() してから play() で最速再生
      await _player.play(AssetSource('sounds/task_complete_sync.mp3'));
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }
}
