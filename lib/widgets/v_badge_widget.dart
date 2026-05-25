import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_colors.dart';

/// バッジのアニメーションタイプ定義
enum BadgeAnimationType {
  none,
  shimmer,
  heartbeat,
}

/// 運営がお知らせエディタで設定したバッジを、指定されたアニメーション効果付きで表示する Widget。
class VBadgeWidget extends StatefulWidget {
  final String? imageUrl;
  final String? animationType; // 'none', 'shimmer', 'heartbeat'
  final double size;

  const VBadgeWidget({
    super.key,
    this.imageUrl,
    this.animationType = 'none',
    this.size = 24.0,
  });

  @override
  State<VBadgeWidget> createState() => _VBadgeWidgetState();
}

class _VBadgeWidgetState extends State<VBadgeWidget>
    with TickerProviderStateMixin {
  
  // ハートビート（鼓動）用
  late AnimationController _heartbeatController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseScaleAnimation;
  late Animation<double> _pulseOpacityAnimation;

  // シマー（光沢）用
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  BadgeAnimationType get _type {
    switch (widget.animationType?.toLowerCase()) {
      case 'shimmer':
        return BadgeAnimationType.shimmer;
      case 'heartbeat':
        return BadgeAnimationType.heartbeat;
      default:
        return BadgeAnimationType.none;
    }
  }

  @override
  void initState() {
    super.initState();

    // 1. ハートビート（鼓動）アニメーションの初期化
    _heartbeatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.25).chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.25, end: 1.1).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.1, end: 1.35).chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.35, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 40,
      ),
    ]).animate(_heartbeatController);

    _pulseScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 2.2).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: ConstantTween(2.2),
        weight: 50,
      ),
    ]).animate(_heartbeatController);

    _pulseOpacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.5).chain(CurveTween(curve: Curves.easeOut)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.5, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: ConstantTween(0.0),
        weight: 50,
      ),
    ]).animate(_heartbeatController);

    // 2. シマー（光沢）アニメーションの初期化（3秒周期で1.2秒かけて光が走る）
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _shimmerAnimation = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(
        parent: _shimmerController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeInOut),
      ),
    );

    _startAnimations();
  }

  @override
  void didUpdateWidget(covariant VBadgeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationType != widget.animationType) {
      _startAnimations();
    }
  }

  void _startAnimations() {
    _heartbeatController.stop();
    _shimmerController.stop();

    if (_type == BadgeAnimationType.heartbeat) {
      _heartbeatController.repeat();
    } else if (_type == BadgeAnimationType.shimmer) {
      _shimmerController.repeat();
    }
  }

  @override
  void dispose() {
    _heartbeatController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // バッジ画像Widgetの構築
    Widget badgeImage;
    if (widget.imageUrl == 'tester') {
      badgeImage = Stack(
        alignment: Alignment.center,
        children: [
          // 枠線（バッジの縁）
          Text(
            'T',
            style: GoogleFonts.outfit(
              fontSize: widget.size * 1.6,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3.0
                ..color = AppColors.black.withValues(alpha: 0.8),
            ),
          ),
          // 金属的なグラデーションの塗りつぶし
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                Color(0xFFFFF2CC), // ハイライト
                Color(0xFFFFD700), // ベースのゴールド
                Color(0xFFD4AF37), // 濃いゴールド
                Color(0xFFFFF2CC), // 反射
              ],
              stops: [0.0, 0.4, 0.8, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Text(
              'T',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: widget.size * 1.6,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      );
    } else if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      badgeImage = widget.imageUrl!.startsWith('http')
          ? CachedNetworkImage(
              imageUrl: widget.imageUrl!,
              width: widget.size * 1.3,
              height: widget.size * 1.3,
              fit: BoxFit.contain,
              placeholder: (context, url) => const Icon(
                Icons.verified_rounded,
                color: Colors.amber,
              ),
              errorWidget: (context, url, error) => const Icon(
                Icons.verified_rounded,
                color: Colors.amber,
              ),
            )
          : Image.asset(
              widget.imageUrl!,
              width: widget.size * 1.3,
              height: widget.size * 1.3,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.verified_rounded,
                color: Colors.amber,
              ),
            );
    } else {
      // 画像URL未指定の場合は、デフォルトの星型認証マーク
      badgeImage = Icon(
        Icons.verified,
        color: Colors.amber,
        size: widget.size * 1.3,
      );
    }

    // アニメーションの種類に応じてラップ
    Widget finalBadge;
    if (_type == BadgeAnimationType.heartbeat) {
      finalBadge = SizedBox(
        width: widget.size * 2,
        height: widget.size * 2,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 背面のパルス（波紋）
            AnimatedBuilder(
              animation: _heartbeatController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseScaleAnimation.value,
                  child: Opacity(
                    opacity: _pulseOpacityAnimation.value,
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red.withValues(alpha: 0.4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withValues(alpha: 0.6),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            // ハート本体のバンプ
            ScaleTransition(
              scale: _scaleAnimation,
              child: badgeImage,
            ),
          ],
        ),
      );
    } else if (_type == BadgeAnimationType.shimmer) {
      finalBadge = AnimatedBuilder(
        animation: _shimmerAnimation,
        builder: (context, child) {
          return ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.0),
                  Colors.white.withValues(alpha: 0.75),
                  Colors.white.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.5, 1.0],
                transform: _SlidingGradientTransform(
                  slidePercent: _shimmerAnimation.value,
                ),
              ).createShader(bounds);
            },
            blendMode: BlendMode.srcATop,
            child: child,
          );
        },
        child: badgeImage,
      );
    } else {
      // アニメーションなし
      finalBadge = badgeImage;
    }

    if (widget.imageUrl == 'tester') {
      return Transform(
        transform: Matrix4.skewX(-0.15),
        alignment: Alignment.center,
        child: finalBadge,
      );
    }

    return finalBadge;
  }
}

/// シマー用のグラデーションスライド変形クラス
class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform({
    required this.slidePercent,
  });

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final double translation = bounds.width * slidePercent;
    return Matrix4.translationValues(translation, 0.0, 0.0);
  }
}
