import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import '../config/app_colors.dart';
import '../widgets/swipe_to_post_button.dart';

import '../services/music_api_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/home_provider.dart';
import '../providers/upload_provider.dart';
import '../providers/service_providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/v_badge_widget.dart';
import '../screens/home/components/bgm_indicator.dart';

/// Hero Task 撮影画面
///
/// カメラ起動時にボトムシートを表示せず、即座にカメラプレビューを表示。
/// 左下にアルバムボタン、中央にシャッターボタンを配置したカスタムカメラUI。
/// [heroTaskName] が渡された場合、ヒーロータスク名は固定表示されます。
/// 投稿成功時は `Navigator.pop(context, Map<String, dynamic>)` で結果を返します。
class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key, this.heroTaskName});

  final String? heroTaskName;

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  final ImagePicker _picker = ImagePicker();
  
  XFile? _image;
  bool _isUploading = false;
  bool _isPosted = false; // ── 投稿完了フラグ（離脱ログ判定用） ──
  bool _postToPublicTimeline = false; // ── 全体公開投稿フラグ ──
  double _publicIconScale = 1.0; // ── 地球アイコンのスケールアニメーション用 ──
  final TextEditingController _captionController = TextEditingController();
  final GlobalKey _boundaryKey = GlobalKey();
  final TransformationController _transformationController = TransformationController();

  // ── BGM ──
  MusicItem? _selectedMusic;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // ── カメラ制御 ──
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraReady = false;
  bool _cameraUnavailable = false; // カメラ非搭載・権限拒否時（Web含む）はアルバム選択を案内
  bool _isCapturing = false; // シャッター連打防止
  int _currentCameraIndex = 0; // 0: 背面, 1: 前面
  FlashMode _flashMode = FlashMode.off; // フラッシュモード
  bool _isInitializing = false; // カメラ初期化中フラグ（二重起動防止）

  // ── ズーム制御 ──
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _currentZoomLevel = 1.0;
  double _baseZoomLevel = 1.0;

  String? get _taskName {
    // ルート引数 or コンストラクタ引数
    final args = ModalRoute.of(context)?.settings.arguments;
    if (widget.heroTaskName != null) return widget.heroTaskName;
    if (args is String) return args;
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _captionController.addListener(_onCaptionChanged);
    
    // ── 投稿（撮影）フロー開始ログ ──
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsServiceProvider).logPostFlowStart();
    });
  }

  void _onCaptionChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    // ── 投稿フローを完了せず画面が破棄された場合は離脱ログ ──
    if (!_isPosted) {
      ref.read(analyticsServiceProvider).logPostFlowCancel(reason: 'dismissed');
    }
    WidgetsBinding.instance.removeObserver(this);
    _captionController.removeListener(_onCaptionChanged);
    _cameraController?.dispose();
    _captionController.dispose();
    _transformationController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  /// アプリがバックグラウンドから復帰したときにカメラを再初期化
  /// ※ カメラ権限ダイアログ表示中にも inactive → resumed が発生するため、
  ///   _isInitializing ガードで初期化中の二重破棄・二重起動を防ぐ。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 初期化中（権限ダイアログ含む）は何もしない
    if (_isInitializing) return;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      final controller = _cameraController;
      if (controller != null && controller.value.isInitialized) {
        controller.dispose();
        setState(() {
          _isCameraReady = false;
          _cameraController = null;
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      // プレビュー表示中（写真確認画面でない）かつカメラが未初期化なら再起動
      if (_image == null && _cameraController == null) {
        _initCamera();
      }
    }
  }



  /// カメラを初期化してプレビューを開始
  /// 二重呼び出しを防ぐために _isInitializing フラグで排他制御する。
  Future<void> _initCamera() async {
    if (_isInitializing) return; // 二重起動防止
    _isInitializing = true;

    try {
      final allCameras = await availableCameras();
      if (allCameras.isEmpty) {
        debugPrint('CAMERA: No cameras available');
        if (mounted) setState(() => _cameraUnavailable = true);
        return;
      }

      // 複数のレンズ（広角・超広角など）が搭載されている端末に対応するため、
      // 背面カメラと前面カメラをそれぞれ最初の1つずつ（標準カメラ）のみに絞り込みます。
      final backCamera = allCameras.where((c) => c.lensDirection == CameraLensDirection.back).firstOrNull;
      final frontCamera = allCameras.where((c) => c.lensDirection == CameraLensDirection.front).firstOrNull;

      // 取得したカメラのみを保持するリストを再構築（最大2つ）
      _cameras = [
        if (backCamera != null) backCamera,
        if (frontCamera != null) frontCamera,
      ];

      if (_cameras.isEmpty) {
        debugPrint('CAMERA: No suitable cameras found');
        if (mounted) setState(() => _cameraUnavailable = true);
        return;
      }

      // 背面カメラを優先的に選択
      _currentCameraIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (_currentCameraIndex < 0) _currentCameraIndex = 0;

      await _startCamera(_cameras[_currentCameraIndex]);
    } catch (e) {
      // Web で権限拒否された場合などもここに入る
      debugPrint('CAMERA INIT ERROR: $e');
      if (mounted) setState(() => _cameraUnavailable = true);
    } finally {
      _isInitializing = false;
    }
  }

  /// 指定のカメラでコントローラーを起動
  Future<void> _startCamera(CameraDescription camera) async {
    // 既存のコントローラーを安全に破棄
    final oldController = _cameraController;
    _cameraController = null;
    await oldController?.dispose();

    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false, // 写真のみなのでオーディオ不要
    );

    _cameraController = controller;

    try {
      await controller.initialize();
      // 初期化完了後、まだこのコントローラーが有効か確認
      if (!mounted || _cameraController != controller) return;
      
      // ズームレベルの初期化
      _minAvailableZoom = await controller.getMinZoomLevel();
      _maxAvailableZoom = await controller.getMaxZoomLevel();
      _currentZoomLevel = _minAvailableZoom;
      _baseZoomLevel = _minAvailableZoom;

      // 現在のフラッシュモードを適用 (iPadなどフラッシュ非搭載端末への配慮)
      try {
        await controller.setFlashMode(_flashMode);
      } catch (e) {
        debugPrint('FLASH SET ERROR (Ignored): $e');
      }
      
      if (mounted) {
        setState(() => _isCameraReady = true);
      }
    } catch (e) {
      debugPrint('CAMERA START ERROR: $e');
      // 万が一その他の初期化エラーが起きてもローディングから抜け出せるように配慮
      if (mounted) {
        setState(() {
          _isCameraReady = true;
          _cameraUnavailable = true;
        });
      }
    }
  }

  /// インカメラ / アウトカメラを切り替え
  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;
    HapticFeedback.lightImpact();

    setState(() => _isCameraReady = false);

    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    await _startCamera(_cameras[_currentCameraIndex]);
  }

  /// フラッシュモードを切り替え（off → auto → always → torch → off）
  Future<void> _toggleFlash() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    HapticFeedback.lightImpact();

    FlashMode next;
    switch (_flashMode) {
      case FlashMode.off:
        next = FlashMode.auto;
        break;
      case FlashMode.auto:
        next = FlashMode.always;
        break;
      case FlashMode.always:
        next = FlashMode.torch;
        break;
      case FlashMode.torch:
        next = FlashMode.off;
        break;
    }

    try {
      await controller.setFlashMode(next);
      setState(() => _flashMode = next);
    } catch (e) {
      debugPrint('FLASH MODE ERROR: $e');
    }
  }

  /// フラッシュモードに対応するアイコンを返す
  IconData get _flashIcon {
    switch (_flashMode) {
      case FlashMode.off:
        return Icons.flash_off_rounded;
      case FlashMode.auto:
        return Icons.flash_auto_rounded;
      case FlashMode.always:
        return Icons.flash_on_rounded;
      case FlashMode.torch:
        return Icons.highlight_rounded;
    }
  }


  /// 現在インカメラかどうか
  bool get _isFrontCamera {
    if (_cameras.isEmpty || _currentCameraIndex >= _cameras.length) return false;
    return _cameras[_currentCameraIndex].lensDirection == CameraLensDirection.front;
  }

  /// 画像を水平反転して保存する（インカメラ用: Instagram と同じ挙動）
  /// プレビューはミラー表示されるが、camera パッケージの撮影画像は反転済み。
  /// これを再度反転させて「見た通り」に保存する。
  Future<String> _mirrorImage(String originalPath) async {
    final bytes = await File(originalPath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final width = image.width.toDouble();

    // X軸を反転: 右端を原点にして左右を反転描画
    canvas.translate(width, 0);
    canvas.scale(-1, 1);
    canvas.drawImage(image, Offset.zero, Paint());

    final picture = recorder.endRecording();
    final flipped = await picture.toImage(image.width, image.height);
    final byteData = await flipped.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    flipped.dispose();

    if (byteData == null) return originalPath;

    // 元ファイルと同じディレクトリに _mirrored を付けて保存
    final dir = File(originalPath).parent.path;
    final name = originalPath.split('/').last.split('.').first;
    final mirroredPath = '$dir/${name}_mirrored.png';
    await File(mirroredPath).writeAsBytes(byteData.buffer.asUint8List());
    return mirroredPath;
  }

  /// シャッターボタン: カメラで撮影
  Future<void> _capturePhoto() async {
    final controller = _cameraController;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isCapturing) {
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isCapturing = true);

    try {
      final photo = await controller.takePicture();
      String photoPath = photo.path;

      // インカメラの場合、画像をミラー反転してプレビューと一致させる
      // （Instagram と同じ挙動: 見た通りの画像を保存）
      // Web はファイル書き込みができないためミラー処理をスキップする
      if (!kIsWeb && _isFrontCamera) {
        photoPath = await _mirrorImage(photoPath);
      }

      // カメラでの撮影時はクロップ画面をスキップして直接プレビュー（Instagramライクな挙動）
      if (mounted) {
        setState(() {
          _image = XFile(photoPath);
        });
      }
    } catch (e) {
      debugPrint('CAPTURE ERROR: $e');
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  /// アルバムから選択
  Future<void> _pickFromGallery() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1920,
        imageQuality: 80,
      );
      if (photo != null && mounted) {
        setState(() {
          _image = XFile(photo.path);
        });
      }
    } catch (e) {
      debugPrint('GALLERY PICK ERROR: $e');
    }
  }

  /// 撮り直し: プレビューをクリアしてカメラに戻る
  Future<void> _retake() async {
    setState(() {
      _image = null;
      _captionController.clear();
      _selectedMusic = null;
      _postToPublicTimeline = false;
      _publicIconScale = 1.0;
    });
    await _stopPreviewAudio();
    // カメラが破棄されている場合は再初期化
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      await _initCamera();
    }
  }

  Future<Uint8List?> _capturePng() async {
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      
      // pixelRatio を固定 3.0 にすると巨大な画像（OOM）になりキャプチャが失敗するため、デバイスの比率（最大2.0）に制限する
      final pixelRatio = MediaQuery.of(context).devicePixelRatio;
      final safePixelRatio = pixelRatio > 2.0 ? 2.0 : pixelRatio;
      
      final img = await boundary.toImage(pixelRatio: safePixelRatio);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Capture PNG Error: $e');
      return null;
    }
  }

  Future<void> _uploadPost() async {
    if (_image == null) return;
    final taskName = _taskName ?? AppLocalizations.of(context)!.cameraScreenTaskDefault;

    // ── キャプチャ処理の実行 ──
    // ローディング状態（_isUploading = true）になってUIが再描画・非活性化される前に、
    // 現在のプレビュー（ドラッグ＆ズームが適用されたもの）を確実にキャプチャします。
    final rawBytes = await _capturePng();

    setState(() => _isUploading = true);

    try {
      final finalRawBytes = rawBytes ?? await _image!.readAsBytes();
      final captionText = _captionController.text.trim();

      // 超高速ネイティブ圧縮：巨大なPNG（約2〜4MB）を軽量JPEG（約200KB）へ変換
      // Web など圧縮が利用できない環境では元データのままアップロードする
      Uint8List finalBytes;
      try {
        final compressedBytes = await FlutterImageCompress.compressWithList(
          finalRawBytes,
          minWidth: 1080,
          minHeight: 1920,
          quality: 80,
          format: CompressFormat.jpeg,
        );
        finalBytes = compressedBytes.isNotEmpty ? compressedBytes : finalRawBytes;
      } catch (e) {
        debugPrint('画像圧縮エラー（未対応環境では元データを使用）: $e');
        finalBytes = finalRawBytes;
      }

      // バックグラウンドで非同期にアップロードを開始
      ref.read(uploadProvider.notifier).startUpload(
        imageBytes: finalBytes,
        taskName: taskName,
        caption: captionText.isNotEmpty ? captionText : null,
        bgmUrl: _selectedMusic?.previewUrl,
        bgmTitle: _selectedMusic?.title,
        bgmArtist: _selectedMusic?.artist,
        bgmArtworkUrl: _selectedMusic?.artworkUrl,
        isPublic: _postToPublicTimeline,
      );

      // 拡大調整・圧縮済みの画像データを一時ファイルとしてローカル（Temporary Directory: 一時フォルダ）に書き出し、演出用に使用する
      // Web はファイル書き込み不可のため、元画像の blob URL をそのまま演出に使う
      final String tempPath;
      if (kIsWeb) {
        tempPath = _image!.path;
      } else {
        final tempDir = await getTemporaryDirectory();
        tempPath = '${tempDir.path}/v_effect_post_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final tempFile = File(tempPath);
        await tempFile.writeAsBytes(finalBytes);
      }

      // 現在の streak と今日投稿済みフラグを取得して、適切な楽観的結果を返して即座に画面を閉じる
      final homeData = ref.read(homeDataProvider).value;
      final currentStreak = homeData?.streak ?? 0;
      final postedToday = homeData?.postedToday ?? false;
      // 今日すでに投稿済みの場合はストリークは増えない
      final calculatedStreak = postedToday ? currentStreak : currentStreak + 1;

      if (mounted) {
        _isPosted = true; // ── 投稿完了を記録 ──
        Navigator.pop(context, {
          'posted': true,
          'imagePath': tempPath, // 拡大調整された一時ファイルのパスを返す
          'newStreak': calculatedStreak,
          'isRecordUpdating': false,
        });
      }
    } catch (e, st) {
      debugPrint('POST UPLOAD ERROR: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.cameraScreenUploadFailed)));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskName = _taskName;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: AppColors.pureBlack,
      resizeToAvoidBottomInset: false, // キーボード出現時にプレビュー画像が圧縮されるのを防ぐ
      body: Stack(
        children: [
          // ── プレビュー・カメラ領域（キーボードで縮まない） ──
          Positioned.fill(
            child: SafeArea(
              child: Column(
                children: [
                  // ── Header ──
                  _buildHeader(taskName),

                  // ── メインエリア: カメラ or プレビュー ──
                  Expanded(
                    child: _image != null ? _buildPreview() : _buildCameraView(),
                  ),

                  // ボトムバー領域のダミー余白
                  if (_image != null)
                    const SizedBox(height: 140),
                ],
              ),
            ),
          ),

          // ── 入力欄とボトムバー（キーボードに合わせて上に移動） ──
          if (_image != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomInset,
              child: Container(
                // キーボード表示中は背景を少し暗くして入力しやすくする
                color: AppColors.pureBlack.withValues(alpha: bottomInset > 0 ? 0.6 : 0.0),
                child: SafeArea(
                  top: false,
                  bottom: bottomInset == 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: TextField(
                          controller: _captionController,
                          style: TextStyle(color: AppColors.pureWhite),
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.cameraScreenCaption,
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: AppColors.pureWhite.withValues(alpha: 0.1),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      _buildPostBottomBar(),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(String? taskName) {
    // 写真撮影済みの場合はフラッシュボタンを非表示にする
    final showFlash = _image == null;
    // 推薦ユーザー制限をなくし、全員が全体公開のトグルスイッチを表示・操作できるようにします。
    const showPublicToggle = true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SizedBox(
        height: 44, // ── 高さを固定し、Stack内部のセンタリング基準を揃える ──
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── 中央: タスク名（左右のボタンと被らないようにセーフエリアマージンを設定） ──
            if (taskName != null)
              Positioned(
                left: 100,
                right: 100,
                child: Text(
                  taskName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.notoSansJp(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.pureWhite,
                  ),
                ),
              ),

            // ── 左側: 閉じるボタン または 撮り直しボタン ──
            Positioned(
              left: 8,
              child: _image == null
                  ? IconButton(
                      icon: Icon(Icons.close, color: AppColors.pureWhite),
                      onPressed: () => Navigator.pop(context),
                    )
                  : GestureDetector(
                      onTap: _isUploading ? null : _retake,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white12,
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Icon(Icons.refresh_rounded,
                            color: Colors.white70, size: 22),
                      ),
                    ),
            ),

            // ── 右側: アクションボタン（フラッシュ または 地球トグル＆BGM） ──
            Positioned(
              right: 8,
              child: showFlash
                  ? GestureDetector(
                      onTap: _toggleFlash,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _flashMode != FlashMode.off
                              ? AppColors.accentGold.withValues(alpha: 0.2)
                              : Colors.transparent,
                        ),
                        child: Icon(
                          _flashIcon,
                          color: _flashMode != FlashMode.off
                              ? AppColors.accentGold
                              : AppColors.pureWhite,
                          size: 24,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showPublicToggle) ...[
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _postToPublicTimeline = !_postToPublicTimeline;
                                _publicIconScale = 1.3; // ぷるんと大きくなるトリガー
                              });
                              Future.delayed(const Duration(milliseconds: 150), () {
                                if (mounted) {
                                  setState(() {
                                    _publicIconScale = 1.0;
                                  });
                                }
                              });
                            },
                            child: AnimatedScale(
                              scale: _publicIconScale,
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.easeOutBack, // 弾むスプリング効果
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _postToPublicTimeline
                                      ? AppColors.accentGold.withValues(alpha: 0.2)
                                      : AppColors.pureWhite.withValues(alpha: 0.1),
                                ),
                                child: Icon(
                                  Icons.public_rounded,
                                  color: _postToPublicTimeline ? AppColors.accentGold : AppColors.pureWhite,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        GestureDetector(
                          onTap: _showMusicBottomSheet,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _selectedMusic != null
                                  ? AppColors.accentGold.withValues(alpha: 0.2)
                                  : AppColors.pureWhite.withValues(alpha: 0.1),
                            ),
                            child: Icon(
                              Icons.music_note_rounded,
                              color: _selectedMusic != null ? AppColors.accentGold : AppColors.pureWhite,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── BGM 制御とUI ──

  Future<void> _playPreviewAudio(String url) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
    } catch (e) {
      debugPrint('Audio Play Error: $e');
    }
  }

  Future<void> _stopPreviewAudio() async {
    await _audioPlayer.stop();
  }

  void _showMusicBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return MusicSearchBottomSheet(
          onPreviewStarted: () {
            // 他の曲のプレビュー再生が始まったら、現在カメラ画面で流れているBGMを一時停止（pause）します
            if (_audioPlayer.state == PlayerState.playing) {
              _audioPlayer.pause();
            }
          },
          onPreviewStopped: () {
            // プレビュー再生が停止・終了したら、元々選択されていたBGMを再開（resume）します
            if (_selectedMusic != null && _audioPlayer.state == PlayerState.paused) {
              _audioPlayer.resume();
            }
          },
        );
      },
    ).then((selected) {
      if (selected is MusicItem) {
        setState(() {
          _selectedMusic = selected;
        });
        _playPreviewAudio(selected.previewUrl);
      } else if (selected == 'remove') {
        setState(() {
          _selectedMusic = null;
        });
        _stopPreviewAudio();
      } else {
        // 曲を選択せず、ボトムシートを閉じただけのとき、
        // もしBGMが一時停止（paused）状態のまま残っていたら、再生を再開します
        if (_selectedMusic != null && _audioPlayer.state == PlayerState.paused) {
          _audioPlayer.resume();
        }
      }
    });
  }

  /// ── カメラプレビュー画面（写真未撮影時） ──
  Widget _buildCameraView() {
    return Column(
      children: [
        // カメラプレビュー
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: Container(
                  decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.white.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
            child: GestureDetector(
              onScaleStart: (details) {
                _baseZoomLevel = _currentZoomLevel;
              },
              onScaleUpdate: (details) async {
                final controller = _cameraController;
                if (controller == null || !controller.value.isInitialized) return;
                
                final zoom = (_baseZoomLevel * details.scale).clamp(_minAvailableZoom, _maxAvailableZoom);
                if (zoom != _currentZoomLevel) {
                  _currentZoomLevel = zoom;
                  try {
                    await controller.setZoomLevel(zoom);
                  } catch (e) {
                    debugPrint('ZOOM ERROR: $e');
                  }
                }
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: _isCameraReady && _cameraController != null && _cameraController!.value.isInitialized
                    ? _buildCameraPreview()
                    : _buildCameraLoading(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),

        // ── カメラ操作バー: 左にアルバム / 中央にシャッター / 右にカメラ切替 ──
        _buildCameraControls(),
      ],
    );
  }

  /// カメラプレビューをアスペクト比を保って全画面フィット表示
  Widget _buildCameraPreview() {
    final controller = _cameraController!;

    return LayoutBuilder(
      builder: (context, constraints) {
        // カメラのアスペクト比を取得（カメラは横向き基準なので反転）
        final cameraAspectRatio = 1 / controller.value.aspectRatio;
        final containerAspectRatio =
            constraints.maxWidth / constraints.maxHeight;

        // コンテナに対して横・縦どちらが余るかを計算し、拡大率を決める
        double scale;
        if (cameraAspectRatio > containerAspectRatio) {
          // カメラの方が横長 → 高さに合わせて拡大し、横をクリップ
          scale = constraints.maxHeight /
              (constraints.maxWidth / cameraAspectRatio);
        } else {
          // カメラの方が縦長 → 幅に合わせて拡大し、縦をクリップ
          scale = constraints.maxWidth *
              cameraAspectRatio /
              constraints.maxHeight;
        }
        // 最低でも 1.0 倍にして隙間が出ないように
        scale = scale.clamp(1.0, 2.0);

        return Transform.scale(
          scale: scale,
          child: Center(
            child: CameraPreview(controller),
          ),
        );
      },
    );
  }

  /// カメラ読み込み中のプレースホルダー
  /// カメラが使えない場合（Web の権限拒否・非搭載端末など）はアルバム選択を案内する
  Widget _buildCameraLoading() {
    if (_cameraUnavailable) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.no_photography_outlined, size: 32, color: AppColors.grey50),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.cameraScreenCameraUnavailable,
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansJp(
                fontSize: 13,
                color: AppColors.grey50,
              ),
            ),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.grey50,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.cameraScreenCameraLoading,
            style: TextStyle(color: AppColors.grey30, fontSize: 14),
          ),
        ],
      ),
    );
  }

  /// ── カメラ操作バー ──
  /// 左: アルバムボタン / 中央: シャッター / 右: カメラ切替
  Widget _buildCameraControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── 左: アルバムボタン ──
          GestureDetector(
            onTap: _pickFromGallery,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                color: AppColors.grey15,
              ),
              child: Icon(
                Icons.photo_library_rounded,
                color: AppColors.white,
                size: 22,
              ),
            ),
          ),

          // ── 中央: シャッターボタン ──
          GestureDetector(
            onTap: _isCapturing ? null : _capturePhoto,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.white,
                  width: 4,
                ),
              ),
              padding: const EdgeInsets.all(4),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isCapturing
                      ? AppColors.grey50
                      : AppColors.white,
                ),
              ),
            ),
          ),

          // ── 右: カメラ切り替えボタン ──
          GestureDetector(
            onTap: _cameras.length > 1 ? _flipCamera : null,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.grey15,
                border: Border.all(
                  color: AppColors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.flip_camera_ios_rounded,
                color: _cameras.length > 1
                    ? AppColors.white
                    : AppColors.grey30,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ── 写真プレビュー（撮影済み） ──
  Widget _buildPreview() {
    final taskName = _taskName ?? AppLocalizations.of(context)!.cameraScreenTaskDefault;

    // homeDataProvider からユーザー情報を取得
    final homeData = ref.watch(homeDataProvider).value;
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final username = homeData?.username ?? '';
    final userPhotoUrl = myUid != null ? homeData?.userPhotos[myUid] : null;
    final userBadgeUrl = myUid != null ? homeData?.userBadgeUrls[myUid] : null;
    final userBadgeAnimation = myUid != null ? homeData?.userBadgeAnimations[myUid] : null;

    // キャプション（コメント入力欄のリアルタイム値）
    final captionText = _captionController.text.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Center(
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.accentGold.withValues(alpha: 0.8), // FeedCardのisTop=true時のボーダーと同期
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
                BoxShadow(
                  color: AppColors.accentGold.withValues(alpha: 0.15),
                  blurRadius: 40,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 背景色 (白枠対策)
                  Container(color: AppColors.grey15),

                  // ドラッグ＆ピンチズーム用の領域（画像部分のみをRepaintBoundaryで囲んで切り取る）
                  // ClipRRectを外側にすることで、保存される画像に角丸（白枠）が焼き付かないようにする
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: RepaintBoundary(
                      key: _boundaryKey,
                      child: InteractiveViewer(
                        transformationController: _transformationController,
                        minScale: 1.0,
                        maxScale: 3.0,
                        panEnabled: true,
                        scaleEnabled: true,
                        child: kIsWeb
                            ? Image.network(
                                _image!.path,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              )
                            : Image.file(
                                File(_image!.path),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                      ),
                    ),
                  ),

                  // グラデーションオーバーレイ（下部を暗くしてテキストを読みやすく、FeedCardと同期）
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 240,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.9),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // カード左上のタスク名チップ ＆ 投稿時間（今）＆ BGM
                  Positioned(
                    top: 24,
                    left: 20,
                    right: 60, // 右上の音符ボタンと重ならないように制限
                    child: IgnorePointer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    width: 0.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  taskName,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.pureWhite,
                                    letterSpacing: 1,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                AppLocalizations.of(context)!.timeNow,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.pureWhite.withValues(alpha: 0.8),
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              if (_postToPublicTimeline) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentGold.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.accentGold.withValues(alpha: 0.6),
                                      width: 0.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.accentGold.withValues(alpha: 0.1),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.public_rounded,
                                        color: AppColors.accentGold,
                                        size: 11,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '全体公開',
                                        style: GoogleFonts.notoSansJp(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.accentGold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (_selectedMusic != null) ...[
                            const SizedBox(height: 8),
                            BgmIndicator(
                              title: _selectedMusic!.title,
                              artist: _selectedMusic!.artist,
                              url: _selectedMusic!.previewUrl,
                              artworkUrl: _selectedMusic!.artworkUrl,
                              isMuted: false, // プレビュー中はミュート状態を固定表示
                              onMuteToggle: () {},
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // カード下部のユーザー情報 ＆ キャプション (リアルタイム反映)
                  Positioned(
                    bottom: 32, // 絶対基準線の起点、FeedCardと同期
                    left: 20,
                    right: 20,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // アバター + ユーザー名
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AppColors.grey20,
                                    backgroundImage: userPhotoUrl != null
                                        ? ResizeImage(
                                            CachedNetworkImageProvider(userPhotoUrl),
                                            width: 120,
                                          )
                                        : null,
                                    child: userPhotoUrl == null
                                        ? Text(
                                            username.isNotEmpty ? username[0].toUpperCase() : 'U',
                                            style: TextStyle(
                                              color: AppColors.pureWhite,
                                              fontSize: 12,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    username,
                                    textAlign: TextAlign.left,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.pureWhite,
                                      letterSpacing: 0.5,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black54,
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (userBadgeUrl != null && userBadgeUrl.isNotEmpty) ...[
                                    const SizedBox(width: 4),
                                    VBadgeWidget(
                                      imageUrl: userBadgeUrl,
                                      animationType: userBadgeAnimation ?? 'none',
                                      size: 14,
                                    ),
                                  ],
                                ],
                              ),
                              if (captionText.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  captionText,
                                  style: TextStyle(
                                    color: AppColors.pureWhite,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                    height: 1.3,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black54,
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        
                        // V Fire 表示 (0固定、タップ無効)
                        IgnorePointer(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: AppColors.pureWhite.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.pureWhite.withValues(alpha: 0.1),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  Icons.local_fire_department,
                                  color: AppColors.accentGold,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 16,
                                child: Text(
                                  '0',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.pureWhite,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 指示テキスト（調整可能なことをユーザーに示すマイクロUX）
                  // ※ アバター/ユーザー情報と重ならないように、下部エリアより少し上に配置
                  Positioned(
                    bottom: 120, // アバター情報(bottom 32)の上に避けるように配置
                    left: 20,
                    child: IgnorePointer(
                      child: Row(
                        children: [
                          Icon(
                            Icons.zoom_out_map_rounded,
                            color: AppColors.pureWhite.withValues(alpha: 0.6),
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            AppLocalizations.of(context)!.cameraScreenDragPinch,
                            style: GoogleFonts.notoSansJp(
                              fontSize: 10,
                              color: AppColors.pureWhite.withValues(alpha: 0.6),
                              shadows: [
                                Shadow(
                                  color: AppColors.pureBlack,
                                  blurRadius: 4,
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// ── 投稿用ボトムバー（撮影済み時） ──
  Widget _buildPostBottomBar() {
    // 最適化: 重いBackdropFilterを削除し、透過グラデーションのみでガラス感を表現
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.pureBlack.withValues(alpha: 0.0),
            AppColors.pureBlack.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SwipeToPostButton(
          isUploading: _isUploading,
          onComplete: _uploadPost,
          text: AppLocalizations.of(context)!.cameraScreenPost,
        ),
      ),
    );
  }
}

class MusicSearchBottomSheet extends ConsumerStatefulWidget {
  final VoidCallback? onPreviewStarted;
  final VoidCallback? onPreviewStopped;

  const MusicSearchBottomSheet({
    super.key,
    this.onPreviewStarted,
    this.onPreviewStopped,
  });

  @override
  ConsumerState<MusicSearchBottomSheet> createState() => _MusicSearchBottomSheetState();
}

class _MusicSearchBottomSheetState extends ConsumerState<MusicSearchBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  final AudioPlayer _previewPlayer = AudioPlayer();
  
  List<MusicItem> _results = [];
  bool _isLoading = false;

  List<MusicItem> _recentSongs = [];
  List<MusicItem> _topSongs = [];
  bool _isLoadingInitial = true;

  String? _playingUrl;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final query = _searchController.text;
      if (query.trim().isNotEmpty) {
        _search(query);
      } else {
        setState(() {
          _results.clear();
        });
      }
    });
  }

  Future<void> _loadInitialData() async {
    final recent = await ref.read(musicApiServiceProvider).getRecentSongs();
    final top = await ref.read(musicApiServiceProvider).getTopSongs();
    if (mounted) {
      setState(() {
        _recentSongs = recent;
        _topSongs = top;
        _isLoadingInitial = false;
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _previewPlayer.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _isLoading = true;
    });
    final results = await ref.read(musicApiServiceProvider).searchSongs(query);
    if (mounted) {
      setState(() {
        _results = results;
        _isLoading = false;
      });
    }
  }

  Future<void> _togglePreview(String url) async {
    try {
      if (_playingUrl == url) {
        // 現在再生中のプレビュー曲をタップした場合は、再生を停止します
        await _previewPlayer.stop();
        setState(() {
          _playingUrl = null;
        });
        // プレビューが停止したため、カメラ画面側のBGMを再開（resume）するよう通知します
        widget.onPreviewStopped?.call();
      } else {
        // 別の曲を再生する場合、まず現在の再生を止めます
        await _previewPlayer.stop();
        // カメラ画面側で再生中のBGMがプレビュー音と被らないように、一時停止（pause）するよう通知します
        widget.onPreviewStarted?.call();
        
        await _previewPlayer.play(UrlSource(url));
        setState(() {
          _playingUrl = url;
        });
        // 曲が最後まで再生され終わったときの処理を監視します
        _previewPlayer.onPlayerComplete.listen((_) {
          if (mounted) {
            setState(() {
              _playingUrl = null;
            });
            // プレビュー再生が完了したので、カメラ画面側のBGMを再開するよう通知します
            widget.onPreviewStopped?.call();
          }
        });
      }
    } catch (e) {
      debugPrint('Preview Play Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          // ハンドル
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.grey30,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // ヘッダーと「削除」ボタン
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.cameraMusicAdd,
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context, 'remove');
                  },
                  child: Text(AppLocalizations.of(context)!.cameraMusicRemoveBgm, style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 検索バー
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: AppColors.white),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.cameraMusicSearchHint,
                hintStyle: TextStyle(color: AppColors.grey50),
                prefixIcon: Icon(Icons.search, color: AppColors.grey50),
                filled: true,
                fillColor: AppColors.grey15,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (val) {
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                _search(val);
              },
              textInputAction: TextInputAction.search,
            ),
          ),
          const SizedBox(height: 16),
          // 結果リスト
          Expanded(
            child: _searchController.text.isEmpty
                ? _buildInitialView()
                : _isLoading
                    ? Center(child: CircularProgressIndicator(color: AppColors.accentGold))
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          return _buildMusicTile(_results[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialView() {
    if (_isLoadingInitial) {
      return Center(child: CircularProgressIndicator(color: AppColors.accentGold));
    }
    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 40),
      children: [
        if (_recentSongs.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              AppLocalizations.of(context)!.cameraMusicRecentSongs,
              style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _recentSongs.length,
              itemBuilder: (context, index) {
                final item = _recentSongs[index];
                return GestureDetector(
                  onTap: () => _selectSong(item),
                  child: Container(
                    width: 100,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: item.artworkUrl,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.title,
                          style: TextStyle(color: AppColors.white, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            AppLocalizations.of(context)!.cameraMusicTrends,
            style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        ..._topSongs.map((item) => _buildMusicTile(item)),
      ],
    );
  }

  Widget _buildMusicTile(MusicItem item) {
    final isPlaying = _playingUrl == item.previewUrl;
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _togglePreview(item.previewUrl);
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              CachedNetworkImage(
                imageUrl: item.artworkUrl,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
              ),
              Container(
                width: 50,
                height: 50,
                color: AppColors.black.withValues(alpha: isPlaying ? 0.5 : 0.0),
                child: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  color: AppColors.white,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
      title: Text(
        item.title,
        style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        item.artist,
        style: TextStyle(color: AppColors.grey50),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentGold,
          foregroundColor: AppColors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        onPressed: () => _selectSong(item),
        child: Text(AppLocalizations.of(context)!.cameraMusicSelect, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _selectSong(MusicItem item) async {
    HapticFeedback.mediumImpact();
    await _previewPlayer.stop();
    await ref.read(musicApiServiceProvider).addRecentSong(item);
    if (mounted) {
      Navigator.pop(context, item);
    }
  }
}
