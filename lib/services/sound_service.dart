import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:audio_session/audio_session.dart' as asession;
import 'package:sound_mode_advanced/sound_mode_advanced.dart';

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
      // iOSのオーディオセッション管理は audio_session プラグイン（main.dart）に委譲します。
      // 起動直後の不意な音楽停止を防ぐため、audioplayers 側での初期化や事前ロード（setSource）を控えます。
      
      // BGMをループ再生に設定
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);

      // 端末のマナーモード状態を確認して初期状態を同期します。
      // デフォルトではミュート解除（音が鳴る状態）としますが、マナーモード中はミュートを優先します。
      try {
        final ringerStatus = await SoundMode.ringerModeStatus;
        if (ringerStatus == RingerModeStatus.silent || ringerStatus == RingerModeStatus.vibrate) {
          _isBgmMuted = true;
        } else {
          _isBgmMuted = false;
        }
      } catch (e) {
        debugPrint('Error getting ringer mode: $e');
        _isBgmMuted = false;
      }
    } catch (e) {
      debugPrint('Error initializing sound service: $e');
    }
  }

  /// BGM再生時にオーディオセッションを playback に変更し、マナーモードを上書きする
  Future<void> _setPlaybackSession() async {
    try {
      final session = await asession.AudioSession.instance;
      await session.configure(const asession.AudioSessionConfiguration(
        avAudioSessionCategory: asession.AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: asession.AVAudioSessionCategoryOptions.mixWithOthers,
        androidAudioAttributes: asession.AndroidAudioAttributes(
          contentType: asession.AndroidAudioContentType.music,
          usage: asession.AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: asession.AndroidAudioFocusGainType.gainTransientMayDuck,
      ));
      await session.setActive(true);
    } catch (e) {
      debugPrint('Error setting playback session: $e');
    }
  }

  /// BGM停止時にオーディオセッションを ambient に戻し、他アプリの音楽を優先する
  Future<void> _setAmbientSession() async {
    try {
      final session = await asession.AudioSession.instance;
      await session.configure(const asession.AudioSessionConfiguration(
        avAudioSessionCategory: asession.AVAudioSessionCategory.ambient,
        avAudioSessionCategoryOptions: asession.AVAudioSessionCategoryOptions.mixWithOthers,
        androidAudioAttributes: asession.AndroidAudioAttributes(
          contentType: asession.AndroidAudioContentType.sonification,
          usage: asession.AndroidAudioUsage.assistanceSonification,
        ),
        androidAudioFocusGainType: asession.AndroidAudioFocusGainType.gainTransientMayDuck,
      ));
      await session.setActive(false);
    } catch (e) {
      debugPrint('Error setting ambient session: $e');
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
  /// [userExplicitAction] が true の場合、ユーザーが明示的にミュート解除したと見なし、マナーモードを上書き（playback）して音を鳴らします。
  /// それ以外（自動再生）の場合はマナーモードに従います（ambient）。
  Future<void> playBgm(String url, {bool userExplicitAction = false, double initialVolume = 1.0}) async {
    _fadeTimer?.cancel();
    
    if (_isBgmMuted) {
      // ミュート設定時は再生しない（UIで切り替え可能にする）
      return;
    }

    try {
      if (_bgmPlayer.state == PlayerState.playing) {
        await _bgmPlayer.stop();
      }
      
      // BGM再生開始に合わせてセッションを切り替え
      if (userExplicitAction) {
        await _setPlaybackSession();
      } else {
        await _setAmbientSession();
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
            _bgmPlayer.setVolume(initialVolume);
          } else {
            final vol = ((fadeTicks / maxTicks) * initialVolume).clamp(0.0, 1.0);
            _bgmPlayer.setVolume(vol);
          }
        });
      } else {
        // 2曲目以降：即座に指定の初期音量で再生
        await _bgmPlayer.setVolume(initialVolume);
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
    } finally {
      // BGM停止に合わせてオーディオ設定を戻す
      await _setAmbientSession();
    }
  }

  /// 現在再生中のBGMの音量を変更します (0.0 〜 1.0)
  Future<void> setBgmVolume(double volume) async {
    try {
      await _bgmPlayer.setVolume(volume.clamp(0.0, 1.0));
    } catch (e) {
      debugPrint('Error setting BGM volume: $e');
    }
  }

  /// BGMミュートの切り替え
  Future<void> toggleBgmMute(String? currentPlayingUrl) async {
    _isBgmMuted = !_isBgmMuted;

    if (_isBgmMuted) {
      await stopBgm();
    } else if (currentPlayingUrl != null) {
      // ミュート解除時、現在のURLがあれば再生開始（ユーザーの明示的な操作なので強制再生）
      await playBgm(currentPlayingUrl, userExplicitAction: true);
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
