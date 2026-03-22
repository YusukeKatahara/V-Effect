import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_colors.dart';
import '../config/routes.dart';
import '../services/analytics_service.dart';
import '../services/notification_service.dart';
import '../services/post_service.dart';
import '../widgets/fluid_blob.dart';
import '../widgets/streak_flame.dart';
import 'camera_screen.dart';
import 'friend_feed_screen.dart';
import '../widgets/splash_loading.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final PostService _postService = PostService.instance;
  final NotificationService _notificationService = NotificationService.instance;
  final AnalyticsService _analytics = AnalyticsService.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int _streak = 0;
  bool _postedToday = false;
  bool _loading = true;
  String _username = '';
  List<String> _tasks = []; // 表示用の未完了タスク
  bool _isAllTasksCompleted = false; // 全タスク完了フラグ
  List<Map<String, dynamic>> _friendStatuses = [];
  late final Stream<int> _notificationStream;

  // ── Gyro Parallax ──
  double _gyroX = 0;
  double _gyroY = 0;
  StreamSubscription? _gyroSub;
  DateTime _lastGyroUpdate = DateTime.now();

  // ── Zen Mode ──
  late final AnimationController _zenController;
  late final Animation<double> _zenGlow;

  // ── Sublimation ──
  late final AnimationController _sublimationController;
  late final Animation<double> _sublimation;
  int? _heroIndex; // 選ばれたHero Taskのインデックス
  bool _isSublimating = false;
  int _focusedIndex = 0; // 扇状カードのフォーカス位置（最前面）

  @override
  void initState() {
    super.initState();
    _notificationStream = _notificationService.getNotificationCount();
    _loadData().then((_) {
      _checkAndShowTutorial();
    });

    _zenController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _zenGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _zenController, curve: Curves.easeInOut),
    );

    _sublimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _sublimation = CurvedAnimation(
      parent: _sublimationController,
      curve: Curves.easeInOutCubic,
    );

    _initGyro();
  }

  void _initGyro() {
    try {
      _gyroSub = accelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 100),
      ).listen((event) {
        if (!mounted) return;
        // フレームレートを制限（最大10fps）
        final now = DateTime.now();
        if (now.difference(_lastGyroUpdate).inMilliseconds < 100) return;
        final newX = _gyroX * 0.85 + event.x * 0.15;
        final newY = _gyroY * 0.85 + event.y * 0.15;
        if ((newX - _gyroX).abs() < 0.15 && (newY - _gyroY).abs() < 0.15) {
          return;
        }
        _lastGyroUpdate = now;
        setState(() {
          _gyroX = newX;
          _gyroY = newY;
        });
      });
    } catch (e) {
      debugPrint('Gyro init failed: $e');
    }
  }

  @override
  void dispose() {
    _gyroSub?.cancel();
    _zenController.dispose();
    _sublimationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final homeData = await _postService.getHomeData();
      final friendUids = homeData['friends'] as List<String>;
      final friendStatuses = friendUids.isNotEmpty
          ? await _postService.getFriendsListFromUids(friendUids)
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      
      final allTasks = homeData['tasks'] as List<String>;
      final postedTasks = homeData['postedTasksToday'] as List<String>;
      final remainingTasks = allTasks.where((t) => !postedTasks.contains(t)).toList();

      setState(() {
        _streak = homeData['streak'] as int;
        _postedToday = homeData['postedToday'] as bool;
        _isAllTasksCompleted = homeData['isAllTasksCompleted'] as bool;
        _username = homeData['username'] as String;
        _tasks = remainingTasks;
        _friendStatuses = friendStatuses;
        _loading = false;
      });
      if (_isAllTasksCompleted && allTasks.isNotEmpty) {
        _zenController.repeat(reverse: true);
      }

      // ユーザープロパティを更新
      _analytics.setStreakTier(_streak);
      _analytics.setTaskCount(_tasks.length);
      _analytics.setFriendCount(friendUids.length);
      _analytics.setTaskCategories(_tasks);

      _notificationService
          .checkAndCreateTimeReminders(streak: _streak)
          .catchError((e) => debugPrint('Time reminder error: $e'));
    } catch (e) {
      debugPrint('Load data error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 初回アクセス時のチュートリアル表示（投稿方法）
  /// 本当の「初回のみ」を保証するため Firestore フラグで管理
  Future<void> _checkAndShowTutorial() async {
    if (!mounted || _postedToday) return;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final shown = snap.data()?['taskTutorialShown'] == true;
    if (shown || !mounted) return;

    await FirebaseFirestore.instance.collection('users').doc(uid).update({'taskTutorialShown': true});
    if (!mounted) return;
    _showTutorialDialog(
      title: 'ヒーロータスクを設定しました！',
      message: '画面中央のヒーロータスクカードをタップして、\n写真を撮って投稿してみましょう。',
      icon: Icons.touch_app_rounded,
    );
  }

  /// 投稿完了後のチュートリアル表示（初回投稿のみ）
  /// 本当の「初回のみ」を保証するため Firestore フラグで管理
  Future<void> _checkAndShowPostTutorial() async {
    if (!mounted) return;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final shown = snap.data()?['postTutorialShown'] == true;
    if (shown || !mounted) return;

    await FirebaseFirestore.instance.collection('users').doc(uid).update({'postTutorialShown': true});
    if (!mounted) return;
    _showTutorialDialog(
      title: 'ナイス初投稿！',
      message: '投稿はフィードに表示され、フレンドに共有されます。\n\n「プロフィールの設定画面」から、あなただけの独自のヒーロータスクを追加・変更することも可能です。',
      icon: Icons.celebration_rounded,
      buttonText: '次へ',
      onButtonPressed: () {
        Navigator.of(context).pop();
        Navigator.pushNamed(context, AppRoutes.initialFriend);
      },
    );
  }

  void _showTutorialDialog({
    required String title,
    required String message,
    required IconData icon,
    String buttonText = 'OK',
    VoidCallback? onButtonPressed,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: AppColors.bgElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48, color: AppColors.white),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: GoogleFonts.notoSansJp(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSansJp(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: onButtonPressed ?? () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.white,
                    foregroundColor: AppColors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text(
                    buttonText,
                    style: GoogleFonts.notoSansJp(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> get _postedFriends =>
      _friendStatuses.where((f) => f['hasPostedToday'] == true).toList();

  void _openFriendFeed(Map<String, dynamic> friend) {
    // 投稿済みフレンドのみ渡す（ただし未投稿でも自分はフィードを開ける）
    final feedFriends = _postedFriends.isNotEmpty ? _postedFriends : _friendStatuses;
    final idx = feedFriends.indexWhere((f) => f['uid'] == friend['uid']);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FriendFeedScreen(
          friendUid: friend['uid'] as String,
          friendUsername: friend['username'] as String,
          allFriends: feedFriends,
          initialFriendIndex: idx >= 0 ? idx : 0,
        ),
      ),
    );
  }

  /// Hero Task をタップ → カメラ起動 → 投稿成功で昇華アニメーション
  Future<void> _selectHeroTask(int index) async {
    HapticFeedback.lightImpact();

    final posted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CameraScreen(heroTaskName: _tasks[index]),
      ),
    );

    if (posted == true && mounted) {
      // 投稿成功 → 昇華アニメーション開始
      setState(() {
        _heroIndex = index;
        _isSublimating = true;
        _postedToday = true;
      });

      HapticFeedback.heavyImpact();
      await _sublimationController.forward();

      if (mounted) {
        // 昇華完了 → 状態更新
        setState(() => _isSublimating = false);
        await _loadData(); // streakや残りタスクを再取得
        await _checkAndShowPostTutorial();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: _loading
          ? const SplashLoading()
          : Stack(
              children: [
                _buildDeepBackground(),
                SafeArea(
                  child: Column(
                    children: [
                      _buildTitleBar(),
                      _buildBlobRow(),
                      if (_streak > 0 && !(_isAllTasksCompleted && !_isSublimating)) _buildStreakRow(),
                      Expanded(
                        child: _isAllTasksCompleted && !_isSublimating
                            ? _buildZenMode()
                            : _buildCardStack(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ════════════════════════════════════════════
  // Deep Background
  // ════════════════════════════════════════════
  Widget _buildDeepBackground() {
    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: Stack(
            children: [
              Positioned(
                top: -200 + _gyroY * 8,
                left: -100 + _gyroX * 6,
                child: Container(
                  width: 500,
                  height: 500,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      AppColors.white.withValues(alpha: 0.03),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
              Positioned(
                bottom: -150 + _gyroY * -5,
                right: -80 + _gyroX * -4,
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      AppColors.white.withValues(alpha: 0.02),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════
  // Title Bar
  // ════════════════════════════════════════════
  Widget _buildTitleBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: Text(
              'V EFFECT',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.white,
                letterSpacing: 6.0,
              ),
            ),
          ),
          Positioned(
            right: 0,
            child: StreamBuilder<int>(
              stream: _notificationStream,
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                return GestureDetector(
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.notifications),
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.grey10,
                      border: Border.all(
                          color: AppColors.grey20.withValues(alpha: 0.5)),
                    ),
                    child: Badge(
                      isLabelVisible: count > 0,
                      label:
                          Text('$count', style: const TextStyle(fontSize: 9)),
                      child: const Icon(Icons.notifications_none_rounded,
                          color: AppColors.grey50, size: 18),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════
  // Friend Blob Row
  // ════════════════════════════════════════════
  Widget _buildBlobRow() {
    if (_friendStatuses.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('フレンドを追加しましょう',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grey30, fontSize: 12)),
      );
    }

    final postedFriends = _postedFriends;
    if (postedFriends.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('今日はまだ誰も投稿していません',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grey30, fontSize: 12)),
      );
    }

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        itemCount: postedFriends.length,
        itemBuilder: (context, index) {
          final friend = postedFriends[index];
          final username = friend['username'] as String;
          final depthFactor = 1.0 + index * 0.3;
          final dx = _gyroX * depthFactor * 0.5;
          final dy = _gyroY * depthFactor * 0.3;

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _openFriendFeed(friend);
            },
            child: Transform.translate(
              offset: Offset(dx, dy),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FluidBlobAvatar(
                      size: 56,
                      isAnimating: true,
                      glowColor: AppColors.white,
                      gradient: friend['photoUrl'] == null
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [AppColors.grey85, AppColors.grey50],
                            )
                          : null,
                      borderWidth: 1.5,
                      child: friend['photoUrl'] != null
                          ? ClipOval(
                              child: Image.network(
                                friend['photoUrl'] as String,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Icon(Icons.person_rounded,
                              size: 24, color: AppColors.grey10),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 60,
                      child: Text(username,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: AppColors.grey50)),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ════════════════════════════════════════════
  // Streak Row — 炎 + "N Day Streak"
  // ════════════════════════════════════════════
  Widget _buildStreakRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const StreakFlame(size: 18),
          const SizedBox(width: 6),
          Text(
            '$_streak Day Streak',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.grey70,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════
  // Card Stack — Z軸に奥へ重なるカードスタック
  // ════════════════════════════════════════════
  Widget _buildCardStack() {
    if (_tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.layers_outlined, size: 48, color: AppColors.grey20),
            const SizedBox(height: 16),
            Text('ヒーロータスクが設定されていません',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.grey50)),
            const SizedBox(height: 4),
            Text('プロフィールからヒーロータスクを設定',
                style: TextStyle(fontSize: 12, color: AppColors.grey30)),
          ],
        ),
      );
    }

    // フォーカスインデックスをヒーロータスク数に合わせてクランプ
    if (_focusedIndex >= _tasks.length) _focusedIndex = _tasks.length - 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        // カードの最大高さを計算（9:16比率で利用可能幅の65%をカード幅に）
        final cardWidth = constraints.maxWidth * 0.72;
        final cardHeight = cardWidth * (16 / 9);
        // 高さが利用可能領域を超えないようクランプ
        final maxCardHeight = (constraints.maxHeight - 60).clamp(0.0, cardHeight);
        final finalCardWidth = maxCardHeight * (9 / 16);

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: _tasks.length > 1
              ? (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity < -200 && _focusedIndex < _tasks.length - 1) {
                    HapticFeedback.selectionClick();
                    setState(() => _focusedIndex++);
                  } else if (velocity > 200 && _focusedIndex > 0) {
                    HapticFeedback.selectionClick();
                    setState(() => _focusedIndex--);
                  }
                }
              : null,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // depth が大きい順に描画（フォーカスカードが最前面に来る）
              for (final i in _sortedCardIndices())
                _buildStackedCard(
                  index: i,
                  total: _tasks.length,
                  cardWidth: finalCardWidth,
                  cardHeight: maxCardHeight,
                ),
            ],
          ),
        );
      },
    );
  }

  /// カードの描画順を返す（depth が大きい→小さい順 = 奥→手前）
  List<int> _sortedCardIndices() {
    final indices = List.generate(_tasks.length, (i) => i);
    indices.sort((a, b) {
      final depthA = (a - _focusedIndex).abs();
      final depthB = (b - _focusedIndex).abs();
      return depthB.compareTo(depthA); // depth大きい方を先に描画
    });
    return indices;
  }

  Widget _buildStackedCard({
    required int index,
    required int total,
    required double cardWidth,
    required double cardHeight,
  }) {
    // フォーカス中のカードが最前面（depth=0）
    final depth = (index - _focusedIndex).abs();

    // ── 扇状レイアウト ──
    // フォーカスカードを中心(0°)として、他のカードが左右に広がる
    final fanPosition = index - _focusedIndex; // 負=左、正=右
    const fanSpreadDeg = 6.0; // カード間の角度（度）
    final fanAngleDeg = fanPosition * fanSpreadDeg;
    final fanAngleRad = fanAngleDeg * 3.14159265 / 180.0;

    // 奥行き表現
    final scale = 1.0 - depth * 0.04;
    final dimAlpha = depth * 0.10;
    final blurSigma = depth * 1.2;

    // ジャイロパララックス（奥のカードほど動きが小さい = 視差効果）
    final parallaxFactor = 1.0 - depth * 0.25;
    final px = _gyroX * 3.0 * parallaxFactor;
    final py = _gyroY * 2.0 * parallaxFactor;

    return AnimatedBuilder(
      animation: _sublimation,
      builder: (context, child) {
        double currentOpacity = 1.0;
        double currentScale = scale;
        double currentAngle = fanAngleRad;
        double currentSublimateY = 0;

        if (_isSublimating && _heroIndex != null) {
          final t = _sublimation.value;
          if (index == _heroIndex) {
            currentScale = scale + t * 0.05;
            currentOpacity = 1.0 - t * 0.3;
          } else {
            // 昇華時: 扇が広がりながら上へ飛ぶ
            currentAngle = fanAngleRad * (1.0 + t * 1.5);
            currentSublimateY = -t * 300 - depth * 40 * t;
            currentOpacity = (1.0 - t * 1.2).clamp(0.0, 1.0);
            currentScale = scale * (1.0 + t * 0.15);
          }
        }

        if (currentOpacity <= 0) return const SizedBox.shrink();

        return Transform.translate(
          offset: Offset(px, py + currentSublimateY),
          child: Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.identity()
              ..rotateZ(currentAngle)
              // ignore: deprecated_member_use
              ..scale(currentScale),
            child: Opacity(
              opacity: currentOpacity,
              child: child,
            ),
          ),
        );
      },
      child: GestureDetector(
        onTap: (!_postedToday && !_isSublimating && index == _focusedIndex)
            ? () => _selectHeroTask(index)
            : null,
        child: SizedBox(
          width: cardWidth,
          height: cardHeight,
          child: _TaskCard(
            title: _tasks[index],
            index: index + 1,
            total: total,
            depth: depth,
            dimAlpha: dimAlpha,
            blurSigma: blurSigma,
            showCamera: !_postedToday && !_isSublimating && index == _focusedIndex,
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════
  // Zen Mode — 投稿完了後の静寂
  // ════════════════════════════════════════════
  Widget _buildZenMode() {
    return AnimatedBuilder(
      animation: _zenGlow,
      builder: (context, _) {
        final glow = _zenGlow.value;
        final glowSize = 180 + glow * 60;
        final glowAlpha = 0.06 + glow * 0.08;

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: glowSize,
                height: glowSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.white.withValues(alpha: glowAlpha),
                      blurRadius: 100 + glow * 40,
                      spreadRadius: 20 + glow * 20,
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.white
                            .withValues(alpha: 0.12 + glow * 0.06),
                        AppColors.white.withValues(alpha: 0.03),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.white, AppColors.grey70],
                ).createShader(bounds),
                child: Text(
                  '$_streak',
                  style: GoogleFonts.outfit(
                    fontSize: 96,
                    fontWeight: FontWeight.w900,
                    color: AppColors.white,
                    height: 1,
                    letterSpacing: -4,
                  ),
                ),
              ),
              Text('Day Streak',
                  style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: AppColors.grey50,
                      letterSpacing: 4)),
              const SizedBox(height: 8),
              Text(_username.isNotEmpty ? _username : '',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.grey30,
                      letterSpacing: 1)),
              const SizedBox(height: 40),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.grey20, width: 1),
                ),
                child: Text('ALL CLEAR',
                    style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.grey50,
                        letterSpacing: 3)),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ────────────────────────────────────────────
// Task Card — 9:16 ガラスモーフィズムカード
// ────────────────────────────────────────────
class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.title,
    required this.index,
    required this.total,
    required this.depth,
    required this.dimAlpha,
    required this.blurSigma,
    required this.showCamera,
  });

  final String title;
  final int index;
  final int total;
  final int depth;
  final double dimAlpha;
  final double blurSigma;
  final bool showCamera;

  @override
  Widget build(BuildContext context) {
    final isTop = depth == 0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.grey15.withValues(alpha: isTop ? 0.95 : 0.6),
            AppColors.grey10.withValues(alpha: isTop ? 0.85 : 0.4),
          ],
        ),
        border: Border.all(
          color: AppColors.white.withValues(alpha: isTop ? 0.1 : 0.04),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.6),
            blurRadius: 32,
            offset: const Offset(0, 12),
            spreadRadius: -8,
          ),
          if (isTop)
            BoxShadow(
              color: AppColors.white.withValues(alpha: 0.04),
              blurRadius: 40,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: isTop ? 0 : blurSigma,
            sigmaY: isTop ? 0 : blurSigma,
          ),
          child: Stack(
            children: [
              // 暗幕レイヤー（奥のカードほど暗い）
              if (dimAlpha > 0)
                Positioned.fill(
                  child: ColoredBox(
                    color: AppColors.black.withValues(alpha: dimAlpha),
                  ),
                ),

              // カードコンテンツ
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.white.withValues(alpha: 0.08),
                            border: Border.all(
                                color: AppColors.white
                                    .withValues(alpha: 0.1)),
                          ),
                          child: Center(
                            child: Text(
                              '$index',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.grey70,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'TASK $index / $total',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.grey30,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // ── Camera icon (pre-post, top card only) ──
                    if (showCamera && isTop) ...[
                      Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.white.withValues(alpha: 0.06),
                            border: Border.all(
                              color: AppColors.white.withValues(alpha: 0.12),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppColors.white.withValues(alpha: 0.04),
                                blurRadius: 24,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: AppColors.grey50,
                            size: 30,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          'タップしてヒーロータスクに選ぶ',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: AppColors.grey30,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ] else if (showCamera && !isTop) ...[
                      // 奥のカードにもカメラアイコン（小さめ）
                      Center(
                        child: Icon(
                          Icons.camera_alt_outlined,
                          color: AppColors.grey30.withValues(alpha: 0.6),
                          size: 24,
                        ),
                      ),
                    ],

                    const Spacer(),

                    // ── Task title ──
                    Text(
                      title,
                      style: GoogleFonts.notoSansJp(
                        fontSize: isTop ? 18 : 15,
                        fontWeight: FontWeight.w600,
                        color: isTop ? AppColors.white : AppColors.grey50,
                        height: 1.3,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
