import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import '../config/app_colors.dart';
import '../config/routes.dart';
import '../services/friend_service.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
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

    final userId = Uri.decodeComponent(segments[1]);
    try {
      final user = await FriendService.instance.searchByUserId(userId);
      if (!mounted) return;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ユーザーが見つかりません')),
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
          SnackBar(content: Text('エラーが発生しました: $e')),
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
          const SnackBar(content: Text('画像からQRコードが見つかりませんでした')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title:
            const Text('QRスキャン', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.flashlight_on_outlined),
            tooltip: 'フラッシュライト',
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          const _ScanOverlay(),
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: TextButton.icon(
                onPressed: _isProcessing ? null : _pickFromGallery,
                icon: const Icon(Icons.photo_library_outlined,
                    color: Colors.white),
                label: const Text('フォルダーから選択',
                    style: TextStyle(color: Colors.white, fontSize: 15)),
              ),
            ),
          ),
          if (_isProcessing)
            const ColoredBox(
              color: Colors.black54,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

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
    const frameSize = 240.0;
    const cornerLen = 24.0;
    const cornerThickness = 4.0;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final left = cx - frameSize / 2;
    final top = cy - frameSize / 2;
    final right = left + frameSize;
    final bottom = top + frameSize;

    // 周囲を半透明の黒でマスク
    final maskPaint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()
          ..addRRect(
            RRect.fromLTRBR(left, top, right, bottom,
                const Radius.circular(4)),
          ),
      ),
      maskPaint,
    );

    // 四隅のゴールドコーナー
    final cornerPaint = Paint()
      ..color = AppColors.accentGold
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
