import 'dart:async';
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import '../config/app_colors.dart';
import '../models/post.dart';
import '../models/app_task.dart';
import '../models/hero_pick.dart';
import '../services/user_service.dart';
import '../services/sound_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../providers/service_providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/shimmer_container.dart';
import '../widgets/branded_loading.dart';

class PastComparisonScreen extends ConsumerStatefulWidget {
  final List<AppTask> userTasks;

  const PastComparisonScreen({super.key, required this.userTasks});

  @override
  ConsumerState<PastComparisonScreen> createState() => _PastComparisonScreenState();
}

class _PastComparisonScreenState extends ConsumerState<PastComparisonScreen> with TickerProviderStateMixin {
  
  bool _isLoading = true;
  List<Post> _allPosts = [];
  Map<String, List<Post>> _postsByTask = {};
  
  late TabController _tabController;
  late List<String> _validTaskIds;
  final Map<String, String> _taskIdToName = {};
  
  // 選択モード状態
  bool _isSelectMode = false;
  final List<Post> _selectedPosts = [];

  /// 選択された投稿の中にシーズンタスクのものが含まれているか判定
  bool get _hasSelectedSeasonPost {
    return _selectedPosts.any((post) {
      final task = widget.userTasks.firstWhere(
        (t) => (t.id.isNotEmpty && t.id == post.taskId) || t.title == post.taskName,
        orElse: () => const AppTask(title: ''),
      );
      return task.isSeason;
    });
  }
  
  // 並び順（true = 新しい順/降順, false = 古い順/昇順）
  bool _isDescending = true;

  // グリッドの表示列数（2〜5列の間でピンチイン・アウトにより動的に変更）
  int _crossAxisCount = 3;

  // スムーズなズーム用変数
  double _scale = 1.0;
  Offset _focalPoint = Offset.zero;
  double _gridOpacity = 1.0;
  late AnimationController _pinchAnimationController;
  Animation<double>? _scaleAnimation;
  int? _targetCrossAxisCount;
  
  // ピンチ開始時の状態保存
  late int _startCrossAxisCount;

  // スライド選択（ドラッグ選択）用の変数
  bool _isDraggingToSelect = false;
  bool? _dragSelectActionIsAdd; // true = 選択追加モード, false = 選択解除モード
  final Set<String> _draggedPostIds = {}; // 同一ドラッグ中に処理済みのポストIDを保持
  final Map<String, GlobalKey> _postKeys = {}; // 各ポストの位置検出用GlobalKey
  final Map<String, ScrollController> _scrollControllers = {}; // 各タブ用のスクロールコントローラー
  Ticker? _autoScrollTicker; // オートスクロール用Ticker

  @override
  void initState() {
    super.initState();
    _validTaskIds = [];
    for (final task in widget.userTasks) {
      if (task.id.isNotEmpty) {
        _validTaskIds.add(task.id);
        _taskIdToName[task.id] = task.title;
      }
    }
    _tabController = TabController(length: _validTaskIds.length, vsync: this);
    _pinchAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _pinchAnimationController.addListener(() {
      if (_scaleAnimation != null) {
        setState(() {
          _scale = _scaleAnimation!.value;
        });
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pinchAnimationController.dispose();
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
    _autoScrollTicker?.stop();
    _autoScrollTicker?.dispose();
    super.dispose();
  }

  void _updateStateWithPosts(List<Post> posts) {
    // タスクごとにグループ化
    final Map<String, List<Post>> grouped = {
      for (var id in _validTaskIds) id: []
    };
    
    bool hasOther = false;
    for (var p in posts) {
      String? matchedTaskId;
      
      // 1. まずは投稿の taskId が現在のユーザーのタスクIDのいずれかと一致するか確認
      if (p.taskId != null && p.taskId!.isNotEmpty && grouped.containsKey(p.taskId)) {
        matchedTaskId = p.taskId;
      } 
      // 2. 一致しない、または taskId がない場合、フォールバックとして taskName でマッチング
      else {
        for (final task in widget.userTasks) {
          if (task.id.isNotEmpty && task.title == p.taskName) {
            matchedTaskId = task.id;
            break;
          }
        }
      }

      if (matchedTaskId != null) {
        grouped[matchedTaskId]!.add(p);
      } else {
        hasOther = true;
        if (grouped['その他'] == null) grouped['その他'] = [];
        grouped['その他']!.add(p);
      }
    }
    
    if (hasOther && !_validTaskIds.contains('その他')) {
      _validTaskIds.add('その他');
      _taskIdToName['その他'] = 'その他';
      // タブを作り直す
      _tabController.dispose();
      _tabController = TabController(length: _validTaskIds.length, vsync: this);
    }
    
    // 初回ソート
    for (var key in grouped.keys) {
      grouped[key]!.sort((a, b) {
        return _isDescending 
            ? b.createdAt.compareTo(a.createdAt) 
            : a.createdAt.compareTo(b.createdAt);
      });
    }

    if (mounted) {
      setState(() {
        _allPosts = posts;
        _postsByTask = grouped;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadData() async {
    // 1. キャッシュから取得して即時描画
    try {
      final cachedPosts = await ref.read(postServiceProvider).getAllMyPastPosts(source: Source.cache);
      if (cachedPosts.isNotEmpty) {
        _updateStateWithPosts(cachedPosts);
      }
    } catch (_) {
      // キャッシュがないかエラーの場合は無視して最新を待つ
    }

    // 2. サーバーから最新を取得
    try {
      final latestPosts = await ref.read(postServiceProvider).getAllMyPastPosts(source: Source.serverAndCache);
      _updateStateWithPosts(latestPosts);
    } catch (e) {
      debugPrint('Error loading past posts: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleSortOrder() {
    setState(() {
      _isDescending = !_isDescending;
      for (var key in _postsByTask.keys) {
        _postsByTask[key]!.sort((a, b) {
          return _isDescending 
              ? b.createdAt.compareTo(a.createdAt) 
              : a.createdAt.compareTo(b.createdAt);
        });
      }
    });
  }

  IconData _getGridIcon() {
    switch (_crossAxisCount) {
      case 2:
        return Icons.grid_view; // 2x2 グリッド
      case 3:
        return Icons.view_module; // 3x3 グリッド
      case 4:
        return Icons.view_compact; // 4x4 グリッド
      case 5:
        return Icons.apps; // より細かいグリッド
      default:
        return Icons.grid_view;
    }
  }

  void _cycleCrossAxisCount() {
    int nextCount = _crossAxisCount + 1;
    if (nextCount > 5) {
      nextCount = 2; // 2列に戻る
    }

    setState(() {
      _targetCrossAxisCount = nextCount;
      _gridOpacity = 0.0;
    });
  }

  void _toggleSelectMode() {
    setState(() {
      _isSelectMode = !_isSelectMode;
      if (!_isSelectMode) {
        _selectedPosts.clear();
      }
    });
  }

  void _toggleSelection(Post post) {
    setState(() {
      if (_selectedPosts.contains(post)) {
        _selectedPosts.remove(post);
      } else {
        _selectedPosts.add(post);
      }
    });
  }

  void _showComparisonViewer() {
    if (_selectedPosts.length != 2) return;
    
    // 日付でソート（古い方を[0]、新しい方を[1]にする）
    final sorted = List<Post>.from(_selectedPosts)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ComparisonViewerScreen(
          oldPost: sorted[0],
          newPost: sorted[1],
        ),
      ),
    );
  }

  Future<void> _moveSelectedPostsToTask(AppTask targetTask) async {
    if (_selectedPosts.isEmpty) return;

    // ローディング状態にする
    setState(() {
      _isLoading = true;
    });

    try {
      final batch = FirebaseFirestore.instance.batch();
      
      for (final post in _selectedPosts) {
        final docRef = FirebaseFirestore.instance.collection('posts').doc(post.id);
        batch.update(docRef, {
          'taskId': targetTask.id,
          'taskName': targetTask.title,
        });
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.pastComparisonMoveSuccess(_selectedPosts.length),
            ),
            backgroundColor: AppColors.accentGold,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error moving posts: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('移動に失敗しました: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      // 選択を解除して、データを再読み込み
      if (mounted) {
        setState(() {
          _selectedPosts.clear();
          _isSelectMode = false;
        });
        _loadData(); // 画面リフレッシュ
      }
    }
  }

  void _showMoveTaskBottomSheet() {
    if (_selectedPosts.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppLocalizations.of(context)!.pastComparisonMoveTask,
                  style: GoogleFonts.notoSansJp(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.userTasks.length,
                    itemBuilder: (context, index) {
                      final task = widget.userTasks[index];
                      if (task.id.isEmpty) return const SizedBox.shrink();
                      // 💡 シーズンタスクは移動先として選択できないように除外します
                      if (task.isSeason) return const SizedBox.shrink();

                      return ListTile(
                        title: Text(
                          task.title,
                          style: GoogleFonts.notoSansJp(color: AppColors.white),
                        ),
                        trailing: Icon(Icons.chevron_right, color: AppColors.grey50),
                        onTap: () {
                          Navigator.pop(context); // ボトムシートを閉じる
                          _confirmMoveTask(task);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmMoveTask(AppTask targetTask) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.bgSurface,
          title: Text(
            AppLocalizations.of(context)!.pastComparisonMoveConfirmTitle,
            style: GoogleFonts.notoSansJp(color: AppColors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            AppLocalizations.of(context)!.pastComparisonMoveConfirmBody(_selectedPosts.length, targetTask.title),
            style: GoogleFonts.notoSansJp(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppLocalizations.of(context)!.pastComparisonCancel,
                style: GoogleFonts.notoSansJp(color: AppColors.grey50),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // ダイアログを閉じる
                _moveSelectedPostsToTask(targetTask);
              },
              child: Text(
                AppLocalizations.of(context)!.pastComparisonMoveTask,
                style: GoogleFonts.notoSansJp(color: AppColors.accentGold, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget? _buildBottomActionBar() {
    if (!_isSelectMode) return null;

    final isCompareReady = _selectedPosts.length == 2;
    final isMoveReady = _selectedPosts.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // キャンセルボタン
          TextButton.icon(
            onPressed: _toggleSelectMode,
            icon: Icon(Icons.close, color: AppColors.grey50),
            label: Text(
              AppLocalizations.of(context)!.pastComparisonCancel,
              style: GoogleFonts.notoSansJp(color: AppColors.grey50),
            ),
          ),
          Row(
            children: [
              // 1件選択時のHero Pickボタン
              if (_selectedPosts.length == 1) ...[
                OutlinedButton.icon(
                  onPressed: () async {
                    final heroPick = HeroPick.fromPost(_selectedPosts.first);
                    final success = await UserService.instance.addHeroPick(heroPick);
                    if (mounted) {
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(AppLocalizations.of(context)!.profileHeroPicksSuccess),
                            backgroundColor: AppColors.accentGold,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        _toggleSelectMode();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(AppLocalizations.of(context)!.profileHeroPicksMaxReached),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                  icon: Icon(Icons.push_pin_outlined, color: AppColors.accentGold, size: 18),
                  label: Text(
                    AppLocalizations.of(context)!.profileHeroPicksAction,
                    style: GoogleFonts.notoSansJp(
                      color: AppColors.accentGold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.accentGold),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

              ],
              // 比較するボタン
              OutlinedButton.icon(
                onPressed: isCompareReady ? _showComparisonViewer : null,

                icon: Icon(
                  Icons.compare_arrows,
                  color: isCompareReady ? AppColors.accentGold : AppColors.grey30,
                ),
                label: Text(
                  AppLocalizations.of(context)!.pastComparisonCompare,
                  style: GoogleFonts.notoSansJp(
                    color: isCompareReady ? AppColors.accentGold : AppColors.grey30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isCompareReady ? AppColors.accentGold : AppColors.grey30,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // タスク移動ボタン
              ElevatedButton.icon(
                onPressed: isMoveReady
                    ? () {
                        if (_hasSelectedSeasonPost) {
                          final isJa = Localizations.localeOf(context).languageCode == 'ja';
                          final msg = isJa
                              ? 'シーズンタスクの投稿は他のタスクへ移動できません。'
                              : 'Season task posts cannot be moved to other tasks.';
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(msg),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } else {
                          _showMoveTaskBottomSheet();
                        }
                      }
                    : null,
                icon: Icon(
                  Icons.drive_file_move_outlined,
                  color: isMoveReady ? AppColors.black : AppColors.grey70,
                ),
                label: Text(
                  AppLocalizations.of(context)!.pastComparisonMoveTask,
                  style: GoogleFonts.notoSansJp(
                    color: isMoveReady ? AppColors.black : AppColors.grey70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isMoveReady ? AppColors.accentGold : AppColors.grey30,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: AppColors.bgBase,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.white),
        // どのタスクでも違和感なく振り返りができ、より柔らかい表現になるように「積み重ねを振りかえる」に統一しました
        title: Text(
          AppLocalizations.of(context)!.pastComparisonTitle,
          style: GoogleFonts.notoSansJp(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(_getGridIcon()),
            onPressed: _isLoading ? null : _cycleCrossAxisCount,
            tooltip: '表示列数を切り替える',
          ),
          IconButton(
            icon: const Icon(Icons.swap_vert), // 上下矢印アイコン
            onPressed: _isLoading ? null : _toggleSortOrder,
            tooltip: _isDescending ? AppLocalizations.of(context)!.pastComparisonSortOld : AppLocalizations.of(context)!.pastComparisonSortNew,
          ),
        ],
        bottom: _validTaskIds.isEmpty ? null : TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.accentGold,
          labelColor: AppColors.accentGold,
          unselectedLabelColor: AppColors.grey50,
          tabs: _validTaskIds.map((id) {
            final name = _taskIdToName[id] ?? 'Unknown';
            final displayName = id == 'その他' ? AppLocalizations.of(context)!.categoryOther : name;
            
            // タスクごとの投稿数を取得
            final postsCount = _postsByTask[id]?.length ?? 0;
            // 1件以上の場合のみ括弧書きで件数を追加
            final tabText = postsCount > 0 ? '$displayName ($postsCount)' : displayName;
            
            return Tab(text: tabText);
          }).toList(),
        ),
      ),
      body: _isLoading
          ? const BrandedFullPageLoading()
          : _validTaskIds.isEmpty
              ? _buildEmptyState()
              : TabBarView(
                  controller: _tabController,
                  children: _validTaskIds.map((taskId) {
                    return _buildTimelineList(_postsByTask[taskId] ?? [], taskId);
                  }).toList(),
                ),
      bottomNavigationBar: _buildBottomActionBar(),
      floatingActionButton: _isSelectMode || _isLoading || _allPosts.isEmpty ? null : _buildFab(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        AppLocalizations.of(context)!.pastComparisonEmpty,
        style: GoogleFonts.notoSansJp(color: AppColors.grey50),
      ),
    );
  }

  GlobalKey _getKeyForPost(String postId) {
    return _postKeys.putIfAbsent(postId, () => GlobalKey());
  }

  Post? _findPostAtOffset(Offset globalPosition, List<Post> posts) {
    for (final post in posts) {
      final key = _postKeys[post.id];
      if (key == null) continue;

      final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) continue;

      final localOffset = renderBox.globalToLocal(globalPosition);
      final size = renderBox.size;

      if (localOffset.dx >= 0 &&
          localOffset.dx <= size.width &&
          localOffset.dy >= 0 &&
          localOffset.dy <= size.height) {
        return post;
      }
    }
    return null;
  }

  void _handleLongPressStart(LongPressStartDetails details, List<Post> posts) {
    final hitPost = _findPostAtOffset(details.globalPosition, posts);
    if (hitPost != null) {
      _isDraggingToSelect = true;
      _draggedPostIds.clear();

      if (!_isSelectMode) {
        setState(() {
          _isSelectMode = true;
        });
      }

      final isSelected = _selectedPosts.contains(hitPost);
      _dragSelectActionIsAdd = !isSelected;

      _updatePostSelection(hitPost, _dragSelectActionIsAdd!);
      _draggedPostIds.add(hitPost.id);

      HapticFeedback.lightImpact();
      setState(() {});
    }
  }

  void _handleLongPressMoveUpdate(LongPressMoveUpdateDetails details, List<Post> posts, String taskId) {
    if (!_isDraggingToSelect || _dragSelectActionIsAdd == null) return;

    final controller = _scrollControllers[taskId];
    if (controller != null && controller.hasClients) {
      final screenHeight = MediaQuery.of(context).size.height;
      final y = details.globalPosition.dy;
      const threshold = 150.0;

      if (y < threshold) {
        final speed = ((threshold - y) / threshold).clamp(0.1, 1.0);
        _startAutoScroll(controller, -speed);
      } else if (y > screenHeight - threshold) {
        final speed = ((y - (screenHeight - threshold)) / threshold).clamp(0.1, 1.0);
        _startAutoScroll(controller, speed);
      } else {
        _stopAutoScroll();
      }
    }

    final hitPost = _findPostAtOffset(details.globalPosition, posts);
    if (hitPost != null && !_draggedPostIds.contains(hitPost.id)) {
      _draggedPostIds.add(hitPost.id);
      _updatePostSelection(hitPost, _dragSelectActionIsAdd!);
      HapticFeedback.lightImpact();
      setState(() {});
    }
  }

  void _handleLongPressEnd() {
    _stopAutoScroll();
    setState(() {
      _isDraggingToSelect = false;
      _dragSelectActionIsAdd = null;
      _draggedPostIds.clear();
    });
  }

  void _updatePostSelection(Post post, bool select) {
    if (select) {
      if (!_selectedPosts.contains(post)) {
        _selectedPosts.add(post);
      }
    } else {
      _selectedPosts.remove(post);
    }
  }

  void _startAutoScroll(ScrollController controller, double direction) {
    _autoScrollTicker?.stop();
    _autoScrollTicker?.dispose();
    _autoScrollTicker = createTicker((elapsed) {
      if (!controller.hasClients) return;
      final newOffset = controller.offset + direction * 10;
      final maxScroll = controller.position.maxScrollExtent;
      final minScroll = controller.position.minScrollExtent;

      if (newOffset >= minScroll && newOffset <= maxScroll) {
        controller.jumpTo(newOffset);
      } else if (newOffset > maxScroll) {
        controller.jumpTo(maxScroll);
        _stopAutoScroll();
      } else if (newOffset < minScroll) {
        controller.jumpTo(minScroll);
        _stopAutoScroll();
      }
    });
    _autoScrollTicker?.start();
  }

  void _stopAutoScroll() {
    _autoScrollTicker?.stop();
    _autoScrollTicker?.dispose();
    _autoScrollTicker = null;
  }

  void _handleScaleEnd() {
    int targetCount = _startCrossAxisCount;
    if (_scale >= 1.35) {
      if (_startCrossAxisCount > 2) {
        targetCount = _startCrossAxisCount - 1;
      }
    } else if (_scale <= 0.65) {
      if (_startCrossAxisCount < 5) {
        targetCount = _startCrossAxisCount + 1;
      }
    }

    if (targetCount != _startCrossAxisCount) {
      // 列数が変更される場合：フェードアウトを開始（AnimatedOpacityのonEndで列数更新＆フェードインを行う）
      setState(() {
        _targetCrossAxisCount = targetCount;
        _gridOpacity = 0.0;
      });
    } else {
      // 列数が変更されない場合：スケールをバネのように1.0に戻す
      _pinchAnimationController.stop();
      _scaleAnimation = Tween<double>(begin: _scale, end: 1.0).animate(
        CurvedAnimation(parent: _pinchAnimationController, curve: Curves.easeOutBack),
      );
      _pinchAnimationController.forward(from: 0.0);
    }
  }

  Widget _buildTimelineList(List<Post> posts, String taskId) {
    if (posts.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.pastComparisonTaskEmpty,
          style: GoogleFonts.notoSansJp(color: AppColors.grey50),
        ),
      );
    }

    final controller = _scrollControllers.putIfAbsent(taskId, () => ScrollController());
    
    return GestureDetector(
      onScaleStart: (details) {
        _startCrossAxisCount = _crossAxisCount;
        _pinchAnimationController.stop();
        _scaleAnimation = null;
        setState(() {
          _focalPoint = details.localFocalPoint;
          _scale = 1.0;
        });
      },
      onScaleUpdate: (details) {
        if (details.pointerCount < 2) return;
        setState(() {
          _scale = details.scale.clamp(0.5, 2.0);
          _focalPoint = details.localFocalPoint;
        });
      },
      onScaleEnd: (details) {
        _handleScaleEnd();
      },
      onLongPressStart: (details) => _handleLongPressStart(details, posts),
      onLongPressMoveUpdate: (details) => _handleLongPressMoveUpdate(details, posts, taskId),
      onLongPressEnd: (details) => _handleLongPressEnd(),
      child: AnimatedOpacity(
        opacity: _gridOpacity,
        duration: const Duration(milliseconds: 80),
        onEnd: () {
          if (_gridOpacity == 0.0 && _targetCrossAxisCount != null) {
            setState(() {
              _crossAxisCount = _targetCrossAxisCount!;
              _scale = 1.0;
              _gridOpacity = 1.0;
              _targetCrossAxisCount = null;
            });
            HapticFeedback.lightImpact();
          }
        },
        child: Transform(
          transform: Matrix4.identity()
            ..translate(_focalPoint.dx, _focalPoint.dy)
            ..scale(_scale)
            ..translate(-_focalPoint.dx, -_focalPoint.dy),
          alignment: Alignment.topLeft,
          child: ClipRect(
            child: GridView.builder(
              controller: controller,
              physics: _isDraggingToSelect
                  ? const NeverScrollableScrollPhysics()
                  : const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 16, bottom: 100, left: 16, right: 16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _crossAxisCount,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 9 / 16,
              ),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                final isSelected = _selectedPosts.contains(post);
                
                return GestureDetector(
                  key: _getKeyForPost(post.id),
                  onTap: () {
                    if (_isSelectMode) {
                      _toggleSelection(post);
                    } else {
                      // 詳細表示へ遷移
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PostDetailViewerScreen(post: post),
                        ),
                      );
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.bgElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: _isSelectMode && isSelected 
                          ? Border.all(color: AppColors.accentGold, width: 2)
                          : Border.all(color: AppColors.border, width: 1),
                      boxShadow: _isSelectMode && isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.isDark
                                    ? Colors.transparent
                                    : AppColors.accentGold.withValues(alpha: 0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // 画像部分
                          if (post.imageUrl != null)
                            CachedNetworkImage(
                              imageUrl: post.imageUrl!,
                              fit: BoxFit.cover,
                              fadeInDuration: const Duration(milliseconds: 250),
                              placeholder: (context, url) => const ShimmerContainer(
                                width: double.infinity,
                                height: double.infinity,
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: AppColors.bgElevated,
                                child: Icon(Icons.error, color: AppColors.grey50),
                              ),
                            )
                          else
                            Container(
                              color: AppColors.grey20,
                              child: Icon(Icons.image_not_supported, color: AppColors.grey50),
                            ),
                          // 右上チェックマーク (選択モード)
                          if (_isSelectMode)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? AppColors.accentGold : AppColors.black.withValues(alpha: 0.5),
                                  border: Border.all(color: AppColors.white, width: 1.5),
                                ),
                                padding: const EdgeInsets.all(2),
                                child: Icon(
                                  Icons.check,
                                  size: _crossAxisCount >= 5 ? 10 : 14,
                                  color: isSelected ? AppColors.black : Colors.transparent,
                                ),
                              ),
                            ),
                          // 左下の日付バッジ
                          Positioned(
                            bottom: 8,
                            left: 4,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: _crossAxisCount >= 5 ? 4 : 6,
                                vertical: _crossAxisCount >= 5 ? 2 : 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                DateFormat('yyyy.MM.dd').format(post.createdAt),
                                style: GoogleFonts.rubik(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: _crossAxisCount == 2
                                      ? 12
                                      : _crossAxisCount == 3
                                          ? 10
                                          : _crossAxisCount == 4
                                              ? 8.5
                                              : 7.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFab() {
    return FloatingActionButton.extended(
      onPressed: _toggleSelectMode,
      backgroundColor: AppColors.bgElevated,
      foregroundColor: AppColors.accentGold,
      icon: const Icon(Icons.check_box_outlined),
      label: Text(
        AppLocalizations.of(context)!.pastComparisonSelectMode,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// 2枚の写真を立体的に重なり合わせて比較するビューアー
class ComparisonViewerScreen extends StatefulWidget {
  final Post oldPost;
  final Post newPost;

  const ComparisonViewerScreen({
    super.key,
    required this.oldPost,
    required this.newPost,
  });

  @override
  State<ComparisonViewerScreen> createState() => _ComparisonViewerScreenState();
}

class _ComparisonViewerScreenState extends State<ComparisonViewerScreen> {
  // true = 新しい方（After）が手前, false = 古い方（Before）が手前
  bool _isNewOnTop = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Builder(
                  builder: (context) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    final stackWidth = screenWidth * 0.85;
                    // カード幅Wが1/4(0.25W)重なるとき、全体の幅 = W + W - 0.25W = 1.75W
                    final cardWidth = stackWidth / 1.75;
                    final cardHeight = cardWidth * (16 / 9);
                    final stackHeight = cardHeight * 1.75;

                    return SizedBox(
                      width: stackWidth,
                      height: stackHeight,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // 奥にあるカード（isNewOnTopがtrueならoldPost、falseならnewPost）
                          _buildPhotoCard(
                            post: _isNewOnTop ? widget.oldPost : widget.newPost,
                            isOld: _isNewOnTop ? true : false,
                            isTop: false,
                            cardWidth: cardWidth,
                            cardHeight: cardHeight,
                          ),
                          // 手前にあるカード
                          _buildPhotoCard(
                            post: _isNewOnTop ? widget.newPost : widget.oldPost,
                            isOld: _isNewOnTop ? false : true,
                            isTop: true,
                            cardWidth: cardWidth,
                            cardHeight: cardHeight,
                          ),
                        ],
                      ),
                    );
                  }
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoCard({
    required Post post, 
    required bool isOld, 
    required bool isTop,
    required double cardWidth,
    required double cardHeight,
  }) {
    // 古い写真（Before）は左下に配置し、やや左に傾ける
    // 新しい写真（After）は右上に配置し、やや右に傾ける
    final double rotation = isOld ? -0.04 : 0.04;
    
    // 手前の時は少し大きく、影を濃くする
    final double scale = isTop ? 1.05 : 0.95;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      width: cardWidth,
      height: cardHeight,
      left: isOld ? 0 : null,
      bottom: isOld ? 0 : null,
      right: isOld ? null : 0,
      top: isOld ? null : 0,
      child: GestureDetector(
        onTap: () {
          if (!isTop) {
            setState(() {
              _isNewOnTop = !_isNewOnTop;
            });
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          transformAlignment: Alignment.center,
          transform: Matrix4.identity()
            ..rotateZ(rotation)
            ..scale(scale),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isTop ? 0.5 : 0.3),
                blurRadius: isTop ? 20 : 10,
                offset: Offset(0, isTop ? 10 : 5),
              ),
            ],
            border: Border.all(
              color: isTop ? AppColors.accentGold : AppColors.border,
              width: isTop ? 3 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 画像全体
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: post.imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: post.imageUrl!,
                              fit: BoxFit.cover,
                              fadeInDuration: const Duration(milliseconds: 250),
                              placeholder: (context, url) => const ShimmerContainer(
                                width: double.infinity,
                                height: double.infinity,
                              ),
                              errorWidget: (context, url, error) => Icon(Icons.error, color: AppColors.grey50),
                            )
                          : Container(
                              color: AppColors.grey10,
                              child: Center(
                                child: Icon(Icons.image_not_supported, color: AppColors.grey50),
                              ),
                            ),
                    ),
                    // 日付バッジ
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          DateFormat('yyyy.MM.dd').format(post.createdAt),
                          style: GoogleFonts.rubik(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
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

/// 画像とコメントを全画面表示するビューアー
class PostDetailViewerScreen extends ConsumerStatefulWidget {
  final Post post;

  const PostDetailViewerScreen({super.key, required this.post});

  @override
  ConsumerState<PostDetailViewerScreen> createState() => _PostDetailViewerScreenState();
}

class _PostDetailViewerScreenState extends ConsumerState<PostDetailViewerScreen> {
  SoundService get _soundService => ref.read(soundServiceProvider);

  @override
  void initState() {
    super.initState();
    if (widget.post.bgmUrl != null && widget.post.bgmUrl!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _soundService.playBgm(widget.post.bgmUrl!);
      });
    }
  }

  @override
  void dispose() {
    if (widget.post.bgmUrl != null && widget.post.bgmUrl!.isNotEmpty) {
      _soundService.stopBgm();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? AppColors.white : AppColors.pureBlack),
          onPressed: () {
            _soundService.stopBgm();
            Navigator.pop(context);
          },
        ),
        iconTheme: IconThemeData(color: isDark ? AppColors.white : AppColors.pureBlack),
        actions: [
          IconButton(
            icon: Icon(Icons.push_pin_outlined, color: AppColors.accentGold),
            tooltip: AppLocalizations.of(context)!.profileHeroPicksAdd,
            onPressed: () async {
              final heroPick = HeroPick.fromPost(widget.post);
              final success = await UserService.instance.addHeroPick(heroPick);
              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)!.profileHeroPicksSuccess),
                      backgroundColor: AppColors.accentGold,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)!.profileHeroPicksMaxReached),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),

      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Center(
                child: widget.post.imageUrl != null
                    ? InteractiveViewer(
                        child: AspectRatio(
                          aspectRatio: 9 / 16,
                          child: CachedNetworkImage(
                            imageUrl: widget.post.imageUrl!,
                            fit: BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 250),
                            placeholder: (context, url) => const ShimmerContainer(
                              width: double.infinity,
                              height: double.infinity,
                            ),
                            errorWidget: (context, url, error) => Center(
                              child: Icon(Icons.error, color: AppColors.grey50, size: 48),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Icon(Icons.image_not_supported, color: AppColors.grey50, size: 64),
                      ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('yyyy.MM.dd HH:mm').format(widget.post.createdAt),
                    style: GoogleFonts.rubik(
                      color: AppColors.accentGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (widget.post.caption != null && widget.post.caption!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      widget.post.caption!,
                      style: GoogleFonts.notoSansJp(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        height: 1.6,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

