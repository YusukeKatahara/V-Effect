import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_colors.dart';
import '../models/app_user.dart';
import '../services/user_service.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserService _userService = UserService.instance;
  final _db = FirebaseFirestore.instance;
  late final String _uid;
  bool _loading = true;
  AppUser? _user;
  Map<String, dynamic> _privateData = {};
  Stream<DocumentSnapshot>? _userStream;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser!.uid;
    _userStream = _db.collection('users').doc(_uid).snapshots();
    _loadPrivateData();
  }

  Future<void> _loadPrivateData() async {
    final privateSnap = await _db
        .collection('users')
        .doc(_uid)
        .collection('private')
        .doc('data')
        .get();
    if (!mounted) return;
    setState(() {
      _privateData =
          privateSnap.exists ? privateSnap.data() as Map<String, dynamic> : {};
      _loading = false;
    });
  }

  Future<void> _loadProfile() async {
    await _loadPrivateData();
  }

  // ---── 時刻設定の変更 ──
  Future<void> _selectTime(BuildContext context, bool isWakeUp) async {
    final initialTimeStr =
        isWakeUp
            ? (_privateData['wakeUpTime'] ?? '07:00')
            : (_privateData['taskTime'] ?? '08:00');
    final parts = initialTimeStr.split(':');
    final now = DateTime.now();
    DateTime tempDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );

    await showCupertinoModalPopup(
      context: context,
      builder:
          (context) => Container(
            height: 300,
            padding: const EdgeInsets.only(top: 6.0),
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            color: AppColors.bgElevated,
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                   // ---ツールバー（完了ボタン）
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.white.withValues(alpha: 0.1),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CupertinoButton(
                          child: const Text(
                            'キャンセル',
                            style: TextStyle(color: AppColors.grey50),
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        CupertinoButton(
                          child: const Text(
                            '完了',
                            style: TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () {
                            final timeStr =
                                '${tempDateTime.hour.toString().padLeft(2, '0')}:${tempDateTime.minute.toString().padLeft(2, '0')}';
                            _userService.updateProfile(
                              wakeUpTime: isWakeUp ? timeStr : null,
                              taskTime: isWakeUp ? null : timeStr,
                            );
                            Navigator.pop(context);
                            _loadProfile();
                          },
                        ),
                      ],
                    ),
                  ),
                  // ---ピッカー本体
                  Expanded(
                    child: CupertinoTheme(
                      data: const CupertinoThemeData(
                        brightness: Brightness.dark,
                        textTheme: CupertinoTextThemeData(
                          dateTimePickerTextStyle: TextStyle(
                            color: AppColors.white,
                            fontSize: 22,
                          ),
                        ),
                      ),
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.time,
                        use24hFormat: true,
                        initialDateTime: tempDateTime,
                        onDateTimeChanged: (DateTime newDate) {
                          tempDateTime = newDate;
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // ---── ヒーロータスクの追加 ──
  Future<void> _addTask() async {
    final controller = TextEditingController();
    final newTask = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppColors.bgElevated,
            title: const Text(
              'タスクを追加',
              style: TextStyle(color: AppColors.white),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: AppColors.white),
              decoration: const InputDecoration(
                hintText: '例: 読書を30分する',
                hintStyle: TextStyle(color: AppColors.grey30),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'キャンセル',
                  style: TextStyle(color: AppColors.grey50),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, controller.text),
                child: const Text(
                  '追加',
                  style: TextStyle(color: AppColors.white),
                ),
              ),
            ],
          ),
    );

    if (newTask != null && newTask.trim().isNotEmpty) {
      final updatedTasks = List<String>.from(_user!.tasks)..add(newTask.trim());
      await _userService.updateProfile(tasks: updatedTasks);
      _loadProfile();
    }
  }

  // ---── ヒーロータスクの編集 ──
  Future<void> _editTask(int index) async {
    final controller = TextEditingController(text: _user!.tasks[index]);
    final updatedTask = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppColors.bgElevated,
            title: const Text(
              'タスクを編集',
              style: TextStyle(color: AppColors.white),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: AppColors.white),
              decoration: const InputDecoration(
                hintText: '例: 読書を30分する',
                hintStyle: TextStyle(color: AppColors.grey30),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'キャンセル',
                  style: TextStyle(color: AppColors.grey50),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, controller.text),
                child: const Text(
                  '保存',
                  style: TextStyle(color: AppColors.white),
                ),
              ),
            ],
          ),
    );

    if (updatedTask != null && updatedTask.trim().isNotEmpty) {
      final updatedTasks = List<String>.from(_user!.tasks);
      updatedTasks[index] = updatedTask.trim();
      await _userService.updateProfile(tasks: updatedTasks);
      _loadProfile();
    }
  }

  // ---── ヒーロータスクの削除 ──
  Future<void> _deleteTask(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppColors.bgElevated,
            title: const Text(
              '削除の確認',
              style: TextStyle(color: AppColors.white),
            ),
            content: const Text('このタスクを削除しますか？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'キャンセル',
                  style: TextStyle(color: AppColors.grey50),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  '削除',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      final updatedTasks = List<String>.from(_user!.tasks)..removeAt(index);
      await _userService.updateProfile(tasks: updatedTasks);
      _loadProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<DocumentSnapshot>(
              stream: _userStream,
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.exists) {
                  _user = AppUser.fromFirestore(snapshot.data!);
                }
                if (_user == null) return _buildEmptyState();
                return _buildContent();
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Text(
        'プロフィールが見つかりません',
        style: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadProfile,
      color: AppColors.primary,
      backgroundColor: AppColors.bgSurface,
      child: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(child: _buildProfileHeader()),

          // ---── スケジュール設定 ─────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(child: _buildScheduleSection()),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(child: _buildTaskSection()),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),


        ],
      ),
    );
  }

  // ---
  // ---SliverAppBar
  // ---
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: AppColors.bgBase,
      surfaceTintColor: Colors.transparent,
      pinned: true,
      title: const Text('プロフィール'),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: AppColors.textPrimary),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: AppColors.bgSurface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (BuildContext context) {
                return SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.grey30,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: const Icon(Icons.edit_outlined, color: AppColors.textPrimary),
                        title: const Text('プロフィールを編集', style: TextStyle(color: AppColors.textPrimary)),
                        onTap: () async {
                          Navigator.pop(context);
                          if (_user == null) return;
                          final didUpdate = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditProfileScreen(
                                user: _user!,
                                privateData: _privateData,
                              ),
                            ),
                          );
                          if (didUpdate == true) {
                            _loadProfile();
                          }
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.settings_outlined, color: AppColors.textPrimary),
                        title: const Text('その他の設定', style: TextStyle(color: AppColors.textPrimary)),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SettingsScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // ---
  // ---プロフィールヘッダー
  // ---
  Widget _buildProfileHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient:
                      _user!.photoUrl == null ? AppColors.primaryGradient : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.1),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child:
                    _user!.photoUrl != null
                        ? CircleAvatar(
                          radius: 40,
                          backgroundImage: ResizeImage(
                            CachedNetworkImageProvider(_user!.photoUrl!),
                            width: 240,
                          ),
                        )
                        : const CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.transparent,
                          child: Icon(
                            Icons.person_rounded,
                            size: 40,
                            color: AppColors.black,
                          ),
                        ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _user!.username ?? '',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${_user!.userId ?? ''}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildFollowStat(
                'フォロー',
                _user!.following.length,
                onTap: () => Navigator.pushNamed(
                  context,
                  '/follow-list',
                  arguments: {
                    'uid': _uid,
                    'isFollowing': true,
                    'title': 'フォロー中',
                  },
                ),
              ),
              _buildFollowStat(
                'フォロワー',
                _user!.followers.length,
                onTap: () => Navigator.pushNamed(
                  context,
                  '/follow-list',
                  arguments: {
                    'uid': _uid,
                    'isFollowing': false,
                    'title': 'フォロワー',
                  },
                ),
              ),
              _buildFollowStat('ストリーク', _user!.streak, icon: Icons.local_fire_department_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFollowStat(String label, int count, {IconData? icon, VoidCallback? onTap}) {
    final content = Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: const Color(0xFFD4AF37)),
              const SizedBox(width: 4),
            ],
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (label != 'ストリーク')
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        // 下線を削除
        /*
        if (onTap != null) ...[
          const SizedBox(height: 2),
          Container(width: 24, height: 1, color: AppColors.grey20),
        ],
        */
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: content,
        ),
      );
    }
    return content;
  }

  // ---
  // ---スケジュール設定（直接変更可能）
  // ---
  Widget _buildScheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _EditableInfoRow(
                icon: Icons.schedule_rounded,
                label: 'Focus Time',
                value: _privateData['taskTime'] ?? '08:00',
                onTap: () => _selectTime(context, false),
                isFirst: true,
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---
  // ---ヒーロータスクセクション（追加・削除可能）
  // ---
  Widget _buildTaskSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'ヒーロータスク'),
        const SizedBox(height: 16),
        if (_user!.tasks.isEmpty)
          _buildEmptyTaskCard()
        else
          Column(
            children: [
              ...List.generate(_user!.tasks.length, (i) => _buildQuestCard(i)),
              _buildAddTaskSlot(),
            ],
          ),
      ],
    );
  }

  Widget _buildEmptyTaskCard() {
    return InkWell(
      onTap: _addTask,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: AppColors.bgSurface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.white.withValues(alpha: 0.05),
              AppColors.white.withValues(alpha: 0.02),
            ],
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.add_circle_outline_rounded,
              size: 32,
              color: AppColors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            const Text(
              '最初のタスクを追加',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddTaskSlot() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: InkWell(
        onTap: _addTask,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.add_rounded,
              size: 24,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestCard(int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8), // よりコンパクトに
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16), // 少し収まりの良い角丸に
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.grey15,
              AppColors.grey10,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.4), // 少し影を深めて奥行きを
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: AppColors.white.withValues(alpha: 0.08), // 高級感のある細い境界線
            width: 0.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _editTask(index),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // コンパクトなパディング
              child: Row(
                children: [
                  Container(
                    width: 26, // サイズ縮小
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.white.withValues(alpha: 0.05), // 主張を抑える
                      border: Border.all(
                        color: AppColors.white.withValues(alpha: 0.08),
                        width: 0.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontSize: 12, // 文字サイズ調整
                          fontWeight: FontWeight.w700, // ボールド感は維持
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _user!.tasks[index],
                      style: const TextStyle(
                        fontSize: 14, // コンパクトに
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _deleteTask(index),
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppColors.white.withValues(alpha: 0.2),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---────────────────────────────────────────────
// ---直接編集可能な情報行
// ---────────────────────────────────────────────
class _EditableInfoRow extends StatelessWidget {
  const _EditableInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.isFirst = false,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(16) : Radius.zero,
        bottom: isLast ? const Radius.circular(16) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textMuted),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.grey20,
            ),
          ],
        ),
      ),
    );
  }
}

// ---────────────────────────────────────────────
// ---セクションタイトル
// ---────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFFD4AF37),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
