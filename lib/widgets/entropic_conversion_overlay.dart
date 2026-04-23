import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_colors.dart';

class EntropicConversionOverlay extends StatefulWidget {
  final VoidCallback onComplete;
  final String? finishedImagePath; // 再誕時に映し出す写真のパス
  final String taskName;

  const EntropicConversionOverlay({
    super.key,
    required this.onComplete,
    this.finishedImagePath,
    required this.taskName,
  });

  static Future<void> show(BuildContext context, {
    String? finishedImagePath,
    required String taskName,
  }) async {
    await showGeneralDialog(
      context: context,
      barrierColor: Colors.transparent,
      transitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) {
        return EntropicConversionOverlay(
          finishedImagePath: finishedImagePath,
          taskName: taskName,
          onComplete: () {
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  @override
  State<EntropicConversionOverlay> createState() => _EntropicConversionOverlayState();
}

class _EntropicConversionOverlayState extends State<EntropicConversionOverlay> with TickerProviderStateMixin {
  late AnimationController _mainController;
  
  // 1. 背景の暗転
  late Animation<double> _bgOpacity;
  
  // 2. 引力クエリ（カードの吸引と排出）
  late Animation<double> _cardScale;
  late Animation<double> _cardScaleY; // 引き伸ばし変形用
  late Animation<double> _cardTranslateY;
  late Animation<double> _cardRotation;
  late Animation<double> _cardOpacity;

  // 3. ブラックホール（特異点）の挙動
  late Animation<double> _singularityScale;

  // 4. 爆発（Ignition）フラッシュ
  late Animation<double> _flashOpacity;

  // 5. ロゴの特異点化（Collapsing logo into singularity）
  late Animation<double> _logoScale;
  late Animation<double> _logoLetterSpacing;
  late Animation<double> _logoOpacity;
  
  final List<FlameParticle> _particles = [];
  bool _isRebirthPhase = false; // 写真付きカードが吐き出されるフェーズかどうか

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    // 背景の暗転（エネルギー変換の演出）
    _bgOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.85).chain(CurveTween(curve: Curves.easeOut)), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 0.85), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 0.0), weight: 20),
    ]).animate(_mainController);

    // カードの変形ロジック (0.0 - 0.5: 吸引, 0.5: 爆発, 0.5 - 1.0: 再誕射出)
    _cardScale = TweenSequence<double>([
      // 吸引
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 0.1).chain(CurveTween(curve: Curves.easeInQuint)), weight: 45),
      // 無
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 10),
      // 射出（再誕）
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.9).chain(CurveTween(curve: Curves.elasticOut)), weight: 45),
    ]).animate(_mainController);

    _cardScaleY = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 3.5).chain(CurveTween(curve: Curves.easeInQuint)), weight: 45), // 縦に伸びる
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 45),
    ]).animate(_mainController);

    _cardTranslateY = TweenSequence<double>([
      // 上部の特異点へ移動 (0.0: 開始点, 1.0: 特異点到達)
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeInQuint)), weight: 45),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 10),
      // 特異点から中央へ射出
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOutExpo)), weight: 45),
    ]).animate(_mainController);
    
    _cardRotation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: pi * 2).chain(CurveTween(curve: Curves.easeInQuint)), weight: 45),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: -pi / 6, end: 0.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 45),
    ]).animate(_mainController);

    _cardOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: const Interval(0.8, 1.0))), weight: 45),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: const Interval(0.0, 0.2))), weight: 45),
    ]).animate(_mainController);

    // Singularity (Black hole)
    _singularityScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2).chain(CurveTween(curve: Curves.easeOutBack)), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.2), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.0).chain(CurveTween(curve: Curves.easeInExpo)), weight: 5), // 消滅直前の収縮
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 45),
    ]).animate(_mainController);

    _flashOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 50), 
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOutExpo)), weight: 5), // 変換の瞬間
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)), weight: 45),
    ]).animate(_mainController);

    // ロゴの崩壊アニメーション（最初の15%でブラックホールに吸い込まれる）
    _logoScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeInBack)), weight: 15),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 85),
    ]).animate(_mainController);

    _logoLetterSpacing = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 4.0, end: -15.0).chain(CurveTween(curve: Curves.easeInExpo)), weight: 15),
      TweenSequenceItem(tween: ConstantTween(-15.0), weight: 85),
    ]).animate(_mainController);

    _logoOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: const Interval(0.5, 1.0))), weight: 15),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 85),
    ]).animate(_mainController);

    _mainController.addListener(() {
      // 50%経過（吸い込まれた瞬間）でフェーズ切り替え
      if (_mainController.value >= 0.5 && !_isRebirthPhase) {
        setState(() {
          _isRebirthPhase = true;
        });
        _createParticles();
      }
    });

    _playAnimation();
  }

  void _createParticles() {
    final rand = Random();
    for (int i = 0; i < 50; i++) {
        final speed = rand.nextDouble() * 20 + 8;
        final angle = rand.nextDouble() * 2 * pi;
        _particles.add(FlameParticle(
          dx: cos(angle) * speed,
          dy: sin(angle) * speed,
          size: rand.nextDouble() * 10 + 5,
          life: 1.0,
          decay: rand.nextDouble() * 0.06 + 0.02,
        ));
    }
  }

  Future<void> _playAnimation() async {
    HapticFeedback.mediumImpact();
    _mainController.forward();
    
    await Future.delayed(const Duration(milliseconds: 1200));
    // 吸い込み完了・爆発
    HapticFeedback.heavyImpact();
    
    await Future.delayed(const Duration(milliseconds: 100));
    // 射出・再誕
    HapticFeedback.mediumImpact();
    
    await Future.delayed(const Duration(milliseconds: 1300));
    if (mounted) {
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final topPadding = MediaQuery.paddingOf(context).top;
    // ヘッダーロゴの正確な位置を再計算 (safeArea + headerPadding + textOffset)
    // 17 = 8(padding) + 9(fontSize18の半分強)
    final topCenter = Offset(size.width / 2, topPadding + 8 + 9);
    
    // カードの移動目標距離 (中央からブラックホール位置まで)
    final targetShiftY = topCenter.dy - (size.height / 2);

    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _mainController,
        builder: (context, child) {
          
          if (_mainController.value >= 0.5) {
            for (var p in _particles) {
              p.x += p.dx;
              p.y += p.dy;
              p.life -= p.decay;
              p.dx *= 0.95; // 減速
              p.dy *= 0.95;
            }
            _particles.removeWhere((p) => p.life <= 0);
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              // 背景
              Container(color: Colors.black.withValues(alpha: _bgOpacity.value)),
              
              // 特異点（ブラックホール）
              Positioned(
                left: topCenter.dx - 30,
                top: topCenter.dy - 30,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 吸い込まれていくロゴ
                    if (_mainController.value < 0.2)
                      Transform.scale(
                        scale: _logoScale.value,
                        child: Opacity(
                          opacity: _logoOpacity.value,
                          child: Padding(
                            // letterSpacing 4.0 分の右余白を補正して真のセンターを出す
                            padding: const EdgeInsets.only(left: 4.0),
                            child: Text(
                              'V EFFECT',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.white,
                                letterSpacing: _logoLetterSpacing.value,
                              ),
                            ),
                          ),
                        ),
                      ),
                    
                    Transform.scale(
                      scale: _singularityScale.value,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accentGold.withValues(alpha: 0.6),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // カード（吸引と再誕のトランスフォーム）
              Center(
                child: Transform.translate(
                  offset: Offset(0, _cardTranslateY.value * targetShiftY),
                  child: Transform.rotate(
                    angle: _cardRotation.value,
                    child: Transform.scale(
                      scale: _cardScale.value,
                      scaleY: _cardScaleY.value,
                      child: Opacity(
                        opacity: _cardOpacity.value,
                        child: _buildCardContent(size),
                      ),
                    ),
                  ),
                ),
              ),

              // パーティクル
              if (_particles.isNotEmpty)
                Positioned.fill(child: CustomPaint(painter: _ParticlePainter(_particles, topCenter))),

              // 変換の瞬間のフラッシュ
              if (_flashOpacity.value > 0)
                Container(color: Colors.white.withValues(alpha: _flashOpacity.value)),

              // VICTORY 文字
              if (_isRebirthPhase && _mainController.value >= 0.55 && _mainController.value <= 0.85)
                Center(
                  child: Opacity(
                    opacity: (1.0 - (_mainController.value - 0.55) * 3).clamp(0.0, 1.0),
                    child: Text(
                      'VICTORY',
                      style: GoogleFonts.outfit(
                        fontSize: 64, fontWeight: FontWeight.w900,
                        color: AppColors.accentGold, letterSpacing: 8.0,
                        shadows: [Shadow(color: AppColors.accentGold.withValues(alpha: 0.8), blurRadius: 30)],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCardContent(Size size) {
    return Container(
      width: size.width * 0.85,
      height: (size.width * 0.85) * (16 / 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.accentGold, width: 2),
        color: const Color(0xFF1C1D21),
        boxShadow: [BoxShadow(color: AppColors.accentGold.withValues(alpha: 0.3), blurRadius: 40)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 再誕フェーズなら写真を表示、それ以外は空（黒）
            if (_isRebirthPhase && widget.finishedImagePath != null)
              kIsWeb 
                ? Image.network(widget.finishedImagePath!, fit: BoxFit.cover)
                : Image.file(File(widget.finishedImagePath!), fit: BoxFit.cover, cacheWidth: 540)
            else
              Container(color: Colors.black),
            
            // タスク名などのオーバーレイ
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.taskName,
                    style: GoogleFonts.notoSansJp(
                      fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isRebirthPhase ? 'DONE' : 'READY',
                    style: GoogleFonts.outfit(
                      fontSize: 12, fontWeight: FontWeight.w800,
                      color: AppColors.accentGold, letterSpacing: 2,
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
}

class FlameParticle {
  double x = 0; double y = 0;
  double dx; double dy;
  double size; double life; double decay;
  FlameParticle({required this.dx, required this.dy, required this.size, required this.life, required this.decay});
}

class _ParticlePainter extends CustomPainter {
  final List<FlameParticle> particles;
  final Offset origin;
  _ParticlePainter(this.particles, this.origin);
  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      if (p.life <= 0) continue;
      final paint = Paint()
        ..color = Color.lerp(Colors.orange, AppColors.accentGold, p.life)!.withValues(alpha: p.life)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
      canvas.drawCircle(Offset(origin.dx + p.x, origin.dy + p.y), p.size * p.life, paint);
    }
  }
  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}
