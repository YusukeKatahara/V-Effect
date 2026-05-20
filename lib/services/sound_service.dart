import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class SoundService {
  SoundService._internal();
  static final SoundService instance = SoundService._internal();

  // 単一のプレイヤーを再利用する（メモリ効率と低遅延のため）
  final AudioPlayer _player = AudioPlayer();
  // 連打時のサウンド用に独立したプレイヤーを用意（タスク完了音と競合させないため）
  final AudioPlayer _tapPlayer = AudioPlayer();

  /// アプリ起動時に音声を事前ロード（キャッシュ）しておくことで遅延を防ぎます
  Future<void> init() async {
    try {
      // iOSのマナーモードを無視して再生するための設定
      // BGM（SpotifyやApple Musicなど）が止まらないようにAudioContextを設定
      await AudioPlayer.global.setAudioContext(AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient, // BGMを止めないためのカテゴリ
          options: const {
            AVAudioSessionOptions.mixWithOthers,
          },
        ),
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.assistanceSonification,
          audioFocus: AndroidAudioFocus.none, // オーディオフォーカスを奪わず、BGMを止めない
        ),
      ));

      // audioplayers v6では setSource だけで十分
      await _player.setSource(AssetSource('sounds/task_complete_sync.mp3'));
      await _tapPlayer.setSource(AssetSource('sounds/fire_tap.wav'));
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

  /// V-FIRE 連打時の効果音（Overwatch風）を再生
  Future<void> playFireTapSound({required double playbackRate}) async {
    try {
      // 連打に対応するため、再生中なら直ちに停止する
      if (_tapPlayer.state == PlayerState.playing) {
        await _tapPlayer.stop();
      }
      await _tapPlayer.setPlaybackRate(playbackRate);
      await _tapPlayer.play(AssetSource('sounds/fire_tap.wav'));
    } catch (e) {
      debugPrint('Error playing fire tap sound: $e');
    }
  }
}
