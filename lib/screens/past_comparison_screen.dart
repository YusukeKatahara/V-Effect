import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:v_effect/l10n/app_localizations.dart';
import '../config/app_colors.dart';
import '../models/post.dart';
import '../services/post_service.dart';

class PastComparisonScreen extends StatefulWidget {
  final List<String> userTaskNames;

  const PastComparisonScreen({super.key, required this.userTaskNames});

  @override
  State<PastComparisonScreen> createState() => _PastComparisonScreenState();
}

class _PastComparisonScreenState extends State<PastComparisonScreen> with SingleTickerProviderStateMixin {
  final PostService _postService = PostService.instance;
  bool _isLoading = true;
  List<Post> _allPosts = [];
  Map<String, List<Post>> _postsByTask = {};
  
  late TabController _tabController;
  late List<String> _validTabs;
  
  // 比較モード状態
  bool _isCompareMode = false;
  List<Post> _selectedPosts = [];
  
  // 並び順（true = 新しい順/降順, false = 古い順/昇順）
  bool _isDescending = true;

  @override
  void initState() {
    super.initState();
    _validTabs = List.from(widget.userTaskNames);
    _tabController = TabController(length: _validTabs.length, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final posts = await _postService.getAllMyPastPosts();
      
      // タスクごとにグループ化
      final Map<String, List<Post>> grouped = {
        for (var t in _validTabs) t: []
      };
      
      bool hasOther = false;
      for (var p in posts) {
        if (grouped.containsKey(p.taskName)) {
          grouped[p.taskName]!.add(p);
        } else {
          hasOther = true;
          if (grouped['その他'] == null) grouped['その他'] = [];
          grouped['その他']!.add(p);
        }
      }
      
      if (hasOther && !_validTabs.contains('その他')) {
        _validTabs.add('その他');
        // タブを作り直す
        _tabController.dispose();
        _tabController = TabController(length: _validTabs.length, vsync: this);
      }
      
      // 初回ソート
      for (var key in grouped.keys) {
        grouped[key]!.sort((a, b) {
          return _isDescending 
              ? b.createdAt.compareTo(a.createdAt) 
              : a.createdAt.compareTo(b.createdAt);
        });
      }

      setState(() {
        _allPosts = posts;
        _postsByTask = grouped;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading past posts: $e');
      setState(() => _isLoading = false);
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

  void _toggleCompareMode() {
    setState(() {
      _isCompareMode = !_isCompareMode;
      if (!_isCompareMode) {
        _selectedPosts.clear();
      }
    });
  }

  void _toggleSelection(Post post) {
    setState(() {
      if (_selectedPosts.contains(post)) {
        _selectedPosts.remove(post);
      } else {
        if (_selectedPosts.length < 2) {
          _selectedPosts.add(post);
        } else {
          // すでに2枚選択されている場合は、1枚目を押し出す
          _selectedPosts.removeAt(0);
          _selectedPosts.add(post);
        }
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
            icon: const Icon(Icons.swap_vert), // 上下矢印アイコン
            onPressed: _isLoading ? null : _toggleSortOrder,
            tooltip: _isDescending ? AppLocalizations.of(context)!.pastComparisonSortOld : AppLocalizations.of(context)!.pastComparisonSortNew,
          ),
        ],
        bottom: _validTabs.isEmpty ? null : TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.accentGold,
          labelColor: AppColors.accentGold,
          unselectedLabelColor: AppColors.grey50,
          tabs: _validTabs.map((t) => Tab(text: t == 'その他' ? AppLocalizations.of(context)!.categoryOther : t)).toList(),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.accentGold))
          : _validTabs.isEmpty
              ? _buildEmptyState()
              : TabBarView(
                  controller: _tabController,
                  children: _validTabs.map((taskName) {
                    return _buildTimelineList(_postsByTask[taskName] ?? []);
                  }).toList(),
                ),
      floatingActionButton: _isLoading || _allPosts.isEmpty ? null : _buildFab(),
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

  Widget _buildTimelineList(List<Post> posts) {
    if (posts.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.pastComparisonTaskEmpty,
          style: GoogleFonts.notoSansJp(color: AppColors.grey50),
        ),
      );
    }
    
    return GridView.builder(
      padding: const EdgeInsets.only(top: 16, bottom: 100, left: 16, right: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 9 / 16,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        final isSelected = _selectedPosts.contains(post);
        
        return GestureDetector(
          onTap: () {
            if (_isCompareMode) {
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
              border: _isCompareMode && isSelected 
                  ? Border.all(color: AppColors.accentGold, width: 2)
                  : Border.all(color: AppColors.border, width: 1),
              boxShadow: _isCompareMode && isSelected
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
                      placeholder: (context, url) => Container(
                        color: AppColors.grey20,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.grey20,
                        child: Icon(Icons.error, color: AppColors.grey50),
                      ),
                    )
                  else
                    Container(
                      color: AppColors.grey20,
                      child: Icon(Icons.image_not_supported, color: AppColors.grey50),
                    ),
                  // 右上チェックマーク (比較モード)
                  if (_isCompareMode)
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
                          size: 14,
                          color: isSelected ? AppColors.black : Colors.transparent,
                        ),
                      ),
                    ),
                  // 左下の日付バッジ
                  Positioned(
                    bottom: 8,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        DateFormat('yyyy.MM.dd').format(post.createdAt),
                        style: GoogleFonts.rubik(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
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
    );
  }

  Widget _buildFab() {
    if (_isCompareMode) {
      final isReady = _selectedPosts.length == 2;
      return FloatingActionButton.extended(
        onPressed: isReady ? _showComparisonViewer : null,
        backgroundColor: isReady ? AppColors.accentGold : AppColors.grey30,
        foregroundColor: isReady ? AppColors.black : AppColors.grey70,
        icon: const Icon(Icons.compare_arrows),
        label: Text(
          isReady ? AppLocalizations.of(context)!.pastComparisonCompare : AppLocalizations.of(context)!.pastComparisonSelectTwo,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
    } else {
      return FloatingActionButton.extended(
        onPressed: _toggleCompareMode,
        backgroundColor: AppColors.bgElevated,
        foregroundColor: AppColors.accentGold,
        icon: const Icon(Icons.check_box_outlined),
        label: Text(
          AppLocalizations.of(context)!.pastComparisonMode,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
    }
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
                color: Colors.black.withOpacity(isTop ? 0.5 : 0.3),
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
                              placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
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
                          color: AppColors.black.withOpacity(0.7),
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
class PostDetailViewerScreen extends StatelessWidget {
  final Post post;

  const PostDetailViewerScreen({super.key, required this.post});

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Center(
                child: post.imageUrl != null
                    ? InteractiveViewer(
                        child: AspectRatio(
                          aspectRatio: 9 / 16,
                          child: CachedNetworkImage(
                            imageUrl: post.imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                            errorWidget: (context, url, error) => Center(child: Icon(Icons.error, color: AppColors.white, size: 48)),
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
                    color: Colors.black.withValues(alpha: 0.5),
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
                    DateFormat('yyyy.MM.dd HH:mm').format(post.createdAt),
                    style: GoogleFonts.rubik(
                      color: AppColors.accentGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (post.caption != null && post.caption!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      post.caption!,
                      style: GoogleFonts.notoSansJp(
                        color: AppColors.white,
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
