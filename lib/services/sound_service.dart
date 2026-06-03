import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundService {
  SoundService._internal();
  static final SoundService instance = SoundService._internal();

  // 単一のプレイヤーを再利用する（メモリ効率と低遅延のため）
  final AudioPlayer _player = AudioPlayer();
  // 連打時のサウンド用に独立したプレイヤーを用意（タスク完了音と競合させないため）
  final AudioPlayer _tapPlayer = AudioPlayer();
  // 投稿BGM用のストリーミングプレイヤー
  final AudioPlayer _bgmPlayer = AudioPlayer();

  bool _isBgmMuted = false;
  bool get isBgmMuted => _isBgmMuted;

  Timer? _fadeTimer;
  bool _isFirstBgmPlay = true;

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
      
      // BGMをループ再生に設定
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);

      // ミュート設定の読み込み
      final prefs = await SharedPreferences.getInstance();
      _isBgmMuted = prefs.getBool('is_bgm_muted') ?? false;
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

  /// 投稿のBGMを再生（初回のみゆっくりフェードイン、以降は即座に再生）
  Future<void> playBgm(String url) async {
    _fadeTimer?.cancel();
    
    if (_isBgmMuted) {
      // ミュート設定時は再生しない（UIで切り替え可能にする）
      return;
    }

    try {
      if (_bgmPlayer.state == PlayerState.playing) {
        await _bgmPlayer.stop();
      }
      
      if (_isFirstBgmPlay) {
        _isFirstBgmPlay = false;
        
        // 1曲目：フェードイン
        // エラー（-12860等）を防ぐため、再生を開始してから少し遅延を入れて音量を上げ始める
        await _bgmPlayer.setVolume(0.0);
        await _bgmPlayer.play(UrlSource(url));
        
        // ストリーミングのバッファリングが始まるのを少し待つ
        await Future.delayed(const Duration(milliseconds: 300));
        
        int fadeTicks = 0;
        const int maxTicks = 20; // 2秒間かけてフェードイン
        _fadeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
          fadeTicks++;
          if (fadeTicks > maxTicks) {
            timer.cancel();
            _fadeTimer = null;
            _bgmPlayer.setVolume(1.0);
          } else {
            final vol = (fadeTicks / maxTicks).clamp(0.0, 1.0);
            _bgmPlayer.setVolume(vol);
          }
        });
      } else {
        // 2曲目以降：即座に再生
        await _bgmPlayer.setVolume(1.0);
        await _bgmPlayer.play(UrlSource(url));
      }
      
    } catch (e) {
      debugPrint('Error playing BGM: $e');
    }
  }

  /// BGMの停止
  Future<void> stopBgm() async {
    _fadeTimer?.cancel();
    _fadeTimer = null;
    try {
      await _bgmPlayer.stop();
    } catch (e) {
      debugPrint('Error stopping BGM: $e');
    }
  }

  /// BGMミュートの切り替え
  Future<void> toggleBgmMute(String? currentPlayingUrl) async {
    _isBgmMuted = !_isBgmMuted;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_bgm_muted', _isBgmMuted);

    if (_isBgmMuted) {
      await stopBgm();
    } else if (currentPlayingUrl != null) {
      // ミュート解除時、現在のURLがあれば再生開始
      await playBgm(currentPlayingUrl);
    }
  }

  /// アプリ終了時のリソース解放
  void dispose() {
    _fadeTimer?.cancel();
    _player.dispose();
    _tapPlayer.dispose();
    _bgmPlayer.dispose();
  }
}
