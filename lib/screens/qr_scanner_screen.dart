import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import '../config/app_colors.dart';
import '../config/routes.dart';
import '../models/app_user.dart';
import '../providers/service_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final rawValue = capture.barcodes.firstOrNull?.rawValue;
    if (rawValue == null) return;

    final uri = Uri.tryParse(rawValue);
    if (uri == null) return;
    if (uri.host != 'veffect.web.app') return;
    final segments = uri.pathSegments;
    if (segments.length < 2 || segments[0] != 'u') return;

    setState(() => _isProcessing = true);
    _controller.stop();

    final parsedId = Uri.decodeComponent(segments[1]);
    try {
      // まずはユーザー設定 of ID (userId) で検索
      AppUser? user = await ref.read(friendServiceProvider).searchByUserId(parsedId);
      
      // 見つからない場合は、システムID (uid) での取得を試みる
      user ??= await ref.read(friendServiceProvider).getUserByUid(parsedId);

      if (!mounted) return;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.qrScannerUserNotFound)),
        );
        setState(() => _isProcessing = false);
        _controller.start();
        return;
      }
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.userProfile,
        arguments: {
          'uid': user.uid,
          'username': user.username,
          'photoUrl': user.photoUrl,
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.qrScannerError(e))),
        );
        setState(() => _isProcessing = false);
        _controller.start();
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return;
    final capture = await _controller.analyzeImage(image.path);
    if (capture != null) {
      await _onDetect(capture);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.qrScannerNoQrInImage)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: AppColors.bgBase,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        title: Text(AppLocalizations.of(context)!.qrScannerTitle,
            style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.flashlight_on_outlined),
            tooltip: AppLocalizations.of(context)!.qrScannerFlashlight,
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.black,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.accentGold.withValues(alpha: 0.8),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.black.withValues(alpha: 0.6),
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
                    borderRadius: BorderRadius.circular(23),
                    child: Column(
                      children: [
                        // ── ブランディング ──────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                          child: Center(
                            child: Text(
                              'V EFFECT',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.white,
                                letterSpacing: 4.0,
                              ),
                            ),
                          ),
                        ),
                        Divider(
                          color: AppColors.accentGold.withValues(alpha: 0.25),
                          height: 1,
                          thickness: 0.5,
                          indent: 20,
                          endIndent: 20,
                        ),
                        // ── スキャナー ────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                          child: Container(
                            width: 224, // QrImageView size 200 + padding 12*2 = 224 に合わせる
                            height: 224,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                children: [
                                  MobileScanner(
                                    controller: _controller,
                                    onDetect: _onDetect,
                                  ),
                                  const _ScanOverlay(),
                                  if (_isProcessing)
                                    const ColoredBox(
                                      color: Colors.black54,
                                      child: Center(
                                          child: CircularProgressIndicator()),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // ── 説明テキスト ─────────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                AppLocalizations.of(context)!.qrScannerScanLabel,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                AppLocalizations.of(context)!.qrScannerInstruction,
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _pickFromGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(AppLocalizations.of(context)!.qrScannerPickFromGallery),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.bgElevated,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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

// スキャナー内の枠線
class _ScanOverlay extends StatelessWidget {
  const _ScanOverlay();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OverlayPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cornerLen = 20.0;
    const cornerThickness = 3.0;

    const padding = 12.0;
    final left = padding;
    final top = padding;
    final right = size.width - padding;
    final bottom = size.height - padding;

    final cornerPaint = Paint()
      ..color = AppColors.accentGold.withValues(alpha: 0.8)
      ..strokeWidth = cornerThickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    // 左上
    canvas.drawLine(
        Offset(left, top + cornerLen), Offset(left, top), cornerPaint);
    canvas.drawLine(
        Offset(left, top), Offset(left + cornerLen, top), cornerPaint);
    // 右上
    canvas.drawLine(
        Offset(right - cornerLen, top), Offset(right, top), cornerPaint);
    canvas.drawLine(
        Offset(right, top), Offset(right, top + cornerLen), cornerPaint);
    // 左下
    canvas.drawLine(
        Offset(left, bottom - cornerLen), Offset(left, bottom), cornerPaint);
    canvas.drawLine(
        Offset(left, bottom), Offset(left + cornerLen, bottom), cornerPaint);
    // 右下
    canvas.drawLine(
        Offset(right - cornerLen, bottom), Offset(right, bottom), cornerPaint);
    canvas.drawLine(
        Offset(right, bottom - cornerLen), Offset(right, bottom), cornerPaint);
  }

  @override
  bool shouldRepaint(_OverlayPainter oldDelegate) => false;
}
