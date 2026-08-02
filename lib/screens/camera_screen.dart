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
import '../config/routes.dart';
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
import '../models/app_task.dart';
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

  // ── スタンプ（ステッカー）配置状態 ──
  final List<StickerItem> _stickers = [];
  StickerItem? _selectedSticker;

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

  String? _selectedTaskName;

  String? get _taskName {
    // ルート引数 or コンストラクタ引数
    final args = ModalRoute.of(context)?.settings.arguments;
    if (widget.heroTaskName != null) return widget.heroTaskName;
    if (args is String) return args;
    return null;
  }

  String get _effectiveTaskName {
    if (_selectedTaskName != null) return _selectedTaskName!;
    if (_taskName != null) return _taskName!;

    // ユーザーのタスク一覧の中から、1日の最初の投稿として相応しいメインタスクを優先選択
    final homeData = ref.read(homeDataProvider).value;
    final userTasks = homeData?.tasks ?? [];
    if (userTasks.isNotEmpty) {
      final uncompletedTasks = userTasks.where((t) => !t.isCompletedToday).toList();
      final targetList = uncompletedTasks.isNotEmpty ? uncompletedTasks : userTasks;

      final sortedList = List<AppTask>.from(targetList);
      sortedList.sort((a, b) {
        // 0. 本日未完了のタスクを達成済みタスクよりも絶対優先
        final completedA = a.isCompletedToday;
        final completedB = b.isCompletedToday;
        if (!completedA && completedB) return -1;
        if (completedA && !completedB) return 1;

        final titleA = a.title.trim();
        final titleB = b.title.trim();

        // 1. 「感謝」「振り返り」「日記」などの締めくくり系タスクはファースト投稿の候補として後回しにする
        final isNightTaskA = titleA.contains('感謝') || titleA.contains('振り返り') || titleA.contains('日記');
        final isNightTaskB = titleB.contains('感謝') || titleB.contains('振り返り') || titleB.contains('日記');
        if (isNightTaskA && !isNightTaskB) return 1;
        if (!isNightTaskA && isNightTaskB) return -1;

        // 2. リマインダー時間 (HH:mm 形式) が設定されている場合は時間が早いものを優先
        if (a.reminderTime != null && b.reminderTime != null) {
          return a.reminderTime!.compareTo(b.reminderTime!);
        }
        if (a.reminderTime != null) return -1;
        if (b.reminderTime != null) return 1;

        return 0;
      });

      if (sortedList.first.title.trim().isNotEmpty) {
        return sortedList.first.title;
      }
    }

    return AppLocalizations.of(context)!.cameraScreenTaskDefault;
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
    // 初期化中（権限ダイアログ含む）や撮影後確認中、アップロード中は何もしない
    if (_isInitializing || _isUploading || _image != null) return;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      final controller = _cameraController;
      if (controller != null && controller.value.isInitialized) {
        controller.dispose();
        if (mounted) {
          setState(() {
            _isCameraReady = false;
            _cameraController = null;
          });
        }
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
      // 画面がすでに破棄（アンマウント）されたか、別のカメラが起動した場合は、
      // 不要になったコントローラーを即座に破棄（dispose）してカメラデバイスの解放とメモリリークを防ぎます。
      if (!mounted || _cameraController != controller) {
        controller.dispose();
        return;
      }
      
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
        // 撮影に成功したため、プレビュー表示中は不要になったカメラコントローラーを破棄してカメラデバイスを解放します。
        final oldController = _cameraController;
        _cameraController = null;
        oldController?.dispose();

        setState(() {
          _image = XFile(photoPath);
          _isCameraReady = false; // カメラが破棄されたため、準備完了フラグも下ろします
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
        // アルバムからの画像選択に成功したため、不要になったカメラコントローラーを破棄してカメラデバイスを解放します。
        final oldController = _cameraController;
        _cameraController = null;
        oldController?.dispose();

        setState(() {
          _image = XFile(photo.path);
          _isCameraReady = false; // カメラが破棄されたため、準備完了フラグも下ろします
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
      // 投稿画像への編集UI（金枠や削除✖ボタン）の写り込みを防ぐため、
      // キャプチャ直前にスタンプ（ステッカー）の選択状態を解除して再描画完了を待ちます。
      if (_selectedSticker != null) {
        setState(() {
          _selectedSticker = null;
        });
        // UIの再描画（フレーム確定）を確実に待機します
        await WidgetsBinding.instance.endOfFrame;
      }

      if (!mounted) return null;

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
    final taskName = _effectiveTaskName;

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
        if (Navigator.canPop(context)) {
          Navigator.pop(context, {
            'posted': true,
            'imagePath': tempPath, // 拡大調整された一時ファイルのパスを返す
            'newStreak': calculatedStreak,
            'isRecordUpdating': false,
          });
        } else {
          Navigator.pushReplacementNamed(context, AppRoutes.home);
        }
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
    final taskName = _effectiveTaskName;
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

  Widget _buildHeader(String taskName) {
    // 写真撮影済みの場合はフラッシュボタンを非表示にする
    final showFlash = _image == null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SizedBox(
        height: 44, // ── 高さを固定し、Stack内部のセンタリング基準を揃える ──
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── 中央: タスク名（左右のボタンと被らないようにセーフエリアマージンを設定・タップで変更可能） ──
            Positioned(
              left: 95,
              right: 95,
              child: Center(
                child: GestureDetector(
                  onTap: _isUploading ? null : () => _showTaskSelectionBottomSheet(context),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.pureWhite.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.pureWhite.withValues(alpha: 0.2),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          taskName,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.notoSansJp(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.pureWhite,
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: AppColors.pureWhite.withValues(alpha: 0.8),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

            // ── 左側: 閉じるボタン または 撮り直しボタン ＆ 地球トグル ──
            Positioned(
              left: 8,
              child: _image == null
                  ? IconButton(
                      icon: Icon(Icons.close, color: AppColors.pureWhite),
                      onPressed: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          Navigator.pushReplacementNamed(context, AppRoutes.home);
                        }
                      },
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
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
                        const SizedBox(width: 8),
                        _buildPublicToggleWidget(),
                      ],
                    ),
            ),

            // ── 右側: アクションボタン（フラッシュ または ステッカートグル＆BGM） ──
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
                        // 🆕 ステッカー（スタンプ）追加ボタン
                        GestureDetector(
                          onTap: _showStickerBottomSheet,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _stickers.isNotEmpty
                                  ? AppColors.accentGold.withValues(alpha: 0.2)
                                  : AppColors.pureWhite.withValues(alpha: 0.1),
                            ),
                            child: Icon(
                              Icons.sticky_note_2_rounded,
                              color: _stickers.isNotEmpty ? AppColors.accentGold : AppColors.pureWhite,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
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

  /// ── 🆕 地球トグルウィジェット（全体公開切り替え用） ──
  Widget _buildPublicToggleWidget() {
    return GestureDetector(
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
    );
  }

  /// ── 🆕 スタンプ選択ボトムシートを表示します ──
  void _showStickerBottomSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final homeData = ref.watch(homeDataProvider).value;
        final streak = homeData?.streak ?? 0;
        final totalPosts = homeData?.totalPosts ?? 0;
        final isJa = Localizations.localeOf(context).languageCode == 'ja';

        // 時刻の簡易フォーマット
        final now = DateTime.now();
        final hourStr = now.hour.toString().padLeft(2, '0');
        final minStr = now.minute.toString().padLeft(2, '0');
        final timeStr = '$hourStr:$minStr';

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isJa ? 'スタンプを追加' : 'Add Sticker',
                  style: GoogleFonts.notoSansJp(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.pureWhite,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // 1. タイムスタンプ
                    _buildStickerSelectButton(
                      icon: Icons.access_time_filled_rounded,
                      label: timeStr,
                      onTap: () {
                        Navigator.pop(context);
                        _addSticker(StickerType.timestamp);
                      },
                    ),
                    // 2. ストリーク
                    _buildStickerSelectButton(
                      icon: Icons.calendar_today_rounded,
                      label: isJa ? '$streakストリーク' : '$streak Streak',
                      iconColor: AppColors.accentGold,
                      onTap: () {
                        Navigator.pop(context);
                        _addSticker(StickerType.streak);
                      },
                    ),
                    // 3. トータルV
                    _buildStickerSelectButton(
                      icon: Icons.emoji_events_rounded,
                      label: isJa ? '🏆 トータルV: $totalPosts' : '🏆 Total V: $totalPosts',
                      iconColor: Colors.amber,
                      onTap: () {
                        Navigator.pop(context);
                        _addSticker(StickerType.totalV);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// ── 🆕 ボトムシート内のスタンプ選択ボタン ──
  Widget _buildStickerSelectButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.pureWhite.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.pureWhite.withValues(alpha: 0.15), width: 1),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 90, // はみ出し防止の幅制限
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.notoSansJp(
                fontSize: 11,
                color: AppColors.pureWhite,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ── 🆕 スタンプをリストに追加する ──
  void _addSticker(StickerType type) {
    HapticFeedback.lightImpact();
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final size = MediaQuery.of(context).size;
    
    // 画面中央よりやや上の、ドラッグしやすい位置をデフォルトとします
    final initialPos = Offset(size.width * 0.25, size.height * 0.20);
    
    setState(() {
      final sticker = StickerItem(
        id: newId,
        type: type,
        position: initialPos,
      );
      _stickers.add(sticker);
      _selectedSticker = sticker;
    });
  }

  /// ── 🆕 スタンプの実体Widgetデザインの生成（シャープで繊細なハイエンド・ラグジュアリー仕様） ──
  Widget _buildStickerContent(StickerItem sticker, int streak, int totalPosts) {
    final isJa = Localizations.localeOf(context).languageCode == 'ja';
    
    Widget content;
    Color? bgColor = sticker.isTextOnly ? null : AppColors.pureBlack.withValues(alpha: 0.65);
    EdgeInsets padding = sticker.isTextOnly ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 22, vertical: 10);
    Border? border = sticker.isTextOnly
        ? null
        : Border.all(color: AppColors.accentGold.withValues(alpha: 0.35), width: 1.0);
    BorderRadius borderRadius = BorderRadius.circular(20);

    // 高級感を引き立てる繊細でスマートなシャドウ
    final defaultShadows = [
      Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 10, offset: const Offset(0, 2)),
      Shadow(color: AppColors.accentGold.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 0)),
    ];

    switch (sticker.type) {
      case StickerType.timestamp:
        // 追加された瞬間の固定時間を表示します（再描画時に現在時刻で更新されるのを防ぎます）
        final time = sticker.time;
        final hourStr = time.hour.toString().padLeft(2, '0');
        final minStr = time.minute.toString().padLeft(2, '0');
        content = Text(
          '$hourStr:$minStr',
          style: GoogleFonts.montserrat(
            fontSize: 34,
            fontWeight: FontWeight.w300, // 繊細なLightウェイトでスタイリッシュな高級感を演出
            color: AppColors.pureWhite,
            letterSpacing: 5.0, // ゆとりのあるエレガントな文字間隔
            shadows: defaultShadows,
          ),
        );
        break;

      case StickerType.streak:
        content = Text(
          isJa ? '$streak ストリーク' : '$streak STREAK',
          style: GoogleFonts.montserrat(
            fontSize: 22,
            fontWeight: FontWeight.w400, // 細身のレギュラー
            color: AppColors.pureWhite,
            letterSpacing: 3.5,
            shadows: defaultShadows,
          ),
        );
        break;

      case StickerType.totalV:
        content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events_outlined, color: AppColors.accentGold, size: 20),
            const SizedBox(width: 10),
            Text(
              isJa ? 'トータルV: $totalPosts' : 'TOTAL V: $totalPosts',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w400,
                color: AppColors.pureWhite,
                letterSpacing: 3.0,
                shadows: defaultShadows,
              ),
            ),
          ],
        );
        break;
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: borderRadius,
        border: border,
        boxShadow: sticker.isTextOnly
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: content,
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
    final taskName = _effectiveTaskName;

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
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // 画像部分以外のタップでスタンプの選択状態を解除します
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              setState(() {
                                _selectedSticker = null;
                              });
                            },
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
                          // 🆕 配置されたスタンプたちを上に重ねて展開します
                          ..._stickers.map((sticker) {
                            final isSelected = _selectedSticker == sticker;
                            return StickerGestureWidget(
                              sticker: sticker,
                              isSelected: isSelected,
                              onTap: () {
                                setState(() {
                                  if (_selectedSticker != sticker) {
                                    // 未選択なら選択状態にします（背景トグルは行いません）
                                    _selectedSticker = sticker;
                                    HapticFeedback.selectionClick();
                                  }
                                });
                              },
                              onDelete: () {
                                setState(() {
                                  _stickers.remove(sticker);
                                  if (_selectedSticker == sticker) {
                                    _selectedSticker = null;
                                  }
                                });
                              },
                              onUpdate: (updated) {
                                setState(() {});
                              },
                              child: _buildStickerContent(sticker, homeData?.streak ?? 0, homeData?.totalPosts ?? 0),
                            );
                          }),
                        ],
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

  /// ── タスク名選択用ボトムシート ──
  void _showTaskSelectionBottomSheet(BuildContext context) {
    HapticFeedback.selectionClick();

    final homeData = ref.read(homeDataProvider).value;
    final userTasks = homeData?.tasks ?? [];

    final isDark = AppColors.isDark;

    // 重複を避けつつ、ユーザー登録タスクのリストを作成
    final taskCandidates = <AppTask>[];
    final addedTitles = <String>{};

    for (final task in userTasks) {
      if (task.title.trim().isNotEmpty && !addedTitles.contains(task.title.trim())) {
        taskCandidates.add(task);
        addedTitles.add(task.title.trim());
      }
    }

    // 現在選択中のタスク名が登録リストにない場合、先頭に追加
    final currentName = _effectiveTaskName;
    if (currentName.isNotEmpty && !addedTitles.contains(currentName)) {
      taskCandidates.insert(0, AppTask(title: currentName));
      addedTitles.add(currentName);
    }

    // 万が一タスクリストが空の場合のデフォルト候補
    if (taskCandidates.isEmpty) {
      final defaultList = ['Work Out', '読書', '勉強', '早起き', '健康維持'];
      for (final title in defaultList) {
        taskCandidates.add(AppTask(title: title));
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: AppColors.accentGold.withValues(alpha: isDark ? 0.3 : 0.5),
              width: 1,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ドラッグ用ハンドル
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.task_alt_rounded,
                      color: AppColors.accentGold,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'タスクを選択',
                      style: GoogleFonts.notoSansJp(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '証明するタスクを変更できます',
                  style: GoogleFonts.notoSansJp(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.45,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: taskCandidates.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (listContext, index) {
                      final task = taskCandidates[index];
                      final isSelected = task.title == _effectiveTaskName;

                      final unselectedBg = isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.04);
                      final unselectedBorder = isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.08);

                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedTaskName = task.title;
                          });
                          Navigator.pop(bottomSheetContext);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.accentGold.withValues(alpha: isDark ? 0.15 : 0.12)
                                : unselectedBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? AppColors.accentGold : unselectedBorder,
                              width: isSelected ? 1.5 : 0.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                task.isSeason ? Icons.stars_rounded : Icons.task_alt_rounded,
                                color: isSelected ? AppColors.accentGold : AppColors.textSecondary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  task.title,
                                  style: GoogleFonts.notoSansJp(
                                    fontSize: 15,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? AppColors.accentGold : AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.accentGold,
                                  size: 20,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
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

// ──────────────────────────────────────────────
// 🆕 スタンプ（ステッカー）配置機能用の定義クラス群
// ──────────────────────────────────────────────

enum StickerType { timestamp, streak, totalV }

class StickerItem {
  final String id;
  final StickerType type;
  Offset position;       // 配置位置
  double scale;          // 拡大縮小倍率
  double angle;          // 回転角度（ラジアン）
  bool isTextOnly;       // 背景の有無（タップでトグル切り替え）
  final DateTime time;   // 🆕 スタンプが追加された（固定された）日時

  StickerItem({
    required this.id,
    required this.type,
    required this.position,
    this.scale = 1.0,
    this.angle = 0.0,
    this.isTextOnly = true,
    DateTime? time,
  }) : time = time ?? DateTime.now();
}

class StickerGestureWidget extends StatefulWidget {
  final StickerItem sticker;
  final Widget child;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ValueChanged<StickerItem> onUpdate;

  const StickerGestureWidget({
    super.key,
    required this.sticker,
    required this.child,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
    required this.onUpdate,
  });

  @override
  State<StickerGestureWidget> createState() => _StickerGestureWidgetState();
}

class _StickerGestureWidgetState extends State<StickerGestureWidget> {
  late Offset _basePosition;
  late double _baseScale;
  late double _baseAngle;
  late Offset _startFocalPoint;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      // Paddingを追加したことによる表示位置のズレ（16px）を相殺します
      left: widget.sticker.position.dx - 16,
      top: widget.sticker.position.dy - 16,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..translate(0.0, 0.0)
          ..rotateZ(widget.sticker.angle)
          ..scale(widget.sticker.scale),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onScaleStart: (details) {
            widget.onTap();
            _basePosition = widget.sticker.position;
            _baseScale = widget.sticker.scale;
            _baseAngle = widget.sticker.angle;
            // 拡大縮小・回転されたローカル座標系ではなく、グローバル座標系で移動量を測ります
            _startFocalPoint = details.focalPoint;
          },
          onScaleUpdate: (details) {
            // 移動・拡大縮小・回転を指の動きに追従させて更新します
            setState(() {
              double newScale = _baseScale * details.scale;
              if (newScale < 0.5) newScale = 0.5; // 極端に小さくなりすぎるのを防ぐ
              if (newScale > 3.0) newScale = 3.0; // 極端に大きくなりすぎるのを防ぐ

              // グローバル座標の差分を移動量とします
              widget.sticker.position = _basePosition + (details.focalPoint - _startFocalPoint);
              widget.sticker.scale = newScale;
              widget.sticker.angle = _baseAngle + details.rotation;
            });
            widget.onUpdate(widget.sticker);
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 選択中のみ、位置調整の目安となる金色の枠線（ボーダー）を表示します
              // ✖ボタンが親Widgetのレイアウト境界外にはみ出てタップイベントをロストするのを防ぐため、
              // 全体に16pxのPaddingを適用し、確実に親Widgetの内側にボタンが収まるようにします。
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  decoration: BoxDecoration(
                    border: widget.isSelected
                        ? Border.all(color: AppColors.accentGold, width: 1.5)
                        : Border.all(color: Colors.transparent, width: 1.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: widget.child,
                ),
              ),
              // 選択中（タップされたとき）にのみ、右上に削除用の ✖ ボタンを表示します
              if (widget.isSelected)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Transform.scale(
                    // ステッカー本体が拡大縮小されても、✖ボタンの物理サイズは常に一定（押しやすい大きさ）を維持します
                    scale: 1.0 / widget.sticker.scale,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.mediumImpact(); // 削除時に少し強めの振動フィードバック
                        widget.onDelete();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6), // タッチ領域を広げるための余白
                        decoration: BoxDecoration(
                          color: AppColors.pureBlack,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.pureWhite, width: 1.5),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                          ],
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: AppColors.pureWhite,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
