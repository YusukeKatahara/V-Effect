import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import '../config/app_colors.dart';
import '../models/app_user.dart';
import '../services/invite_service.dart';

class QrDisplayScreen extends StatefulWidget {
  final AppUser user;
  const QrDisplayScreen({super.key, required this.user});

  @override
  State<QrDisplayScreen> createState() => _QrDisplayScreenState();
}

class _QrDisplayScreenState extends State<QrDisplayScreen> {
  final GlobalKey _cardKey = GlobalKey();
  bool _isDownloading = false;

  Future<void> _downloadQr() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final boundary =
          _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      await Gal.putImageBytes(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.qrDisplaySaved)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.qrDisplaySaveFailed(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final qrData = InviteService.instance.buildInviteUrl(user.userId ?? '');

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: AppColors.bgBase,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        title: Text(AppLocalizations.of(context)!.qrDisplayTitle,
            style: TextStyle(color: AppColors.textPrimary)),
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: RepaintBoundary(
                  key: _cardKey,
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
                            padding:
                                const EdgeInsets.fromLTRB(20, 22, 20, 16),
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
                            color:
                                AppColors.accentGold.withValues(alpha: 0.25),
                            height: 1,
                            thickness: 0.5,
                            indent: 20,
                            endIndent: 20,
                          ),
                          // ── QRコード ────────────────────────────────
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(24, 24, 24, 20),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: QrImageView(
                                data: qrData,
                                version: QrVersions.auto,
                                size: 200,
                                backgroundColor: Colors.black,
                                errorCorrectionLevel: QrErrorCorrectLevel.H,
                                embeddedImage: const AssetImage(
                                    'assets/icon/app_icon.png'),
                                embeddedImageStyle:
                                    const QrEmbeddedImageStyle(
                                  size: Size(36, 36),
                                ),
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: Colors.white,
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          // ── ユーザー情報 ─────────────────────────────
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(20, 0, 20, 22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  user.username ?? '',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '@${user.userId ?? ''}',
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
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isDownloading ? null : _downloadQr,
                icon: _isDownloading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.download_outlined),
                label: Text(_isDownloading ? AppLocalizations.of(context)!.qrDisplaySaving : AppLocalizations.of(context)!.qrDisplayDownload),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGold,
                  foregroundColor: Colors.black,
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
