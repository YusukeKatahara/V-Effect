import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_colors.dart';
import '../config/routes.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/push_notification_service.dart';
import '../services/user_service.dart';
import 'edit_profile_screen.dart';
import 'follow_list_screen.dart';
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

          // ---── ヒーロータスク管理 ───────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(child: _buildTaskSection()),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),

          // ---── ログアウト ─────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(child: _buildLogoutButton()),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // ── アカウント削除 ─────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(child: _buildDeleteAccountButton()),
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
                            height: 240,
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
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        if (onTap != null) ...[
          const SizedBox(height: 2),
          Container(width: 24, height: 1, color: AppColors.grey20),
        ],
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
        const _SectionTitle(title: 'スケジュール'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _EditableInfoRow(
                icon: Icons.alarm_rounded,
                label: '起床リマインダー',
                value: _privateData['wakeUpTime'] ?? '07:00',
                onTap: () => _selectTime(context, true),
                isFirst: true,
              ),
              const Divider(height: 1, indent: 52),
              _EditableInfoRow(
                icon: Icons.schedule_rounded,
                label: 'タスクリマインダー',
                value: _privateData['taskTime'] ?? '08:00',
                onTap: () => _selectTime(context, false),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionTitle(title: 'ヒーロータスク'),
            IconButton(
              onPressed: _addTask,
              icon: const Icon(
                Icons.add_circle_outline_rounded,
                color: AppColors.white,
              ),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_user!.tasks.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.border,
                style: BorderStyle.solid,
              ),
            ),
            child: const Text(
              'タスクがありません。右上の＋から追加してください。',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: List.generate(_user!.tasks.length, (i) {
                final isLast = i == _user!.tasks.length - 1;
                return Column(
                  children: [
                    InkWell(
                      onTap: () => _editTask(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.grey10,
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _user!.tasks[i],
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => _deleteTask(i),
                              icon: const Icon(
                                Icons.remove_circle_outline_rounded,
                                size: 20,
                                color: AppColors.grey30,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!isLast) const Divider(height: 1, indent: 52),
                  ],
                );
              }),
            ),
          ),
      ],
    );
  }

  // ════════════════════════════════════════════
  // アカウント削除
  // ════════════════════════════════════════════
  Future<void> _deleteAccount() async {
    // 1回目の確認ダイアログ
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: const Text(
          'アカウントを削除しますか？',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'アカウントを削除すると、プロフィール・投稿・フォロー関係などすべてのデータが完全に削除されます。この操作は取り消せません。',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル', style: TextStyle(color: AppColors.grey50)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除する', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // 2回目の確認ダイアログ
    final finalConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: const Text(
          '本当に削除しますか？',
          style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'この操作は元に戻せません。アカウントを完全に削除してよろしいですか？',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル', style: TextStyle(color: AppColors.grey50)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('完全に削除する', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (finalConfirmed != true || !mounted) return;

    // ローディング表示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await PushNotificationService().removeFcmToken();
      await AuthService().deleteAccount();
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // ローディングを閉じる
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('アカウントの削除に失敗しました。時間をおいて再度お試しください。'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildDeleteAccountButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: TextButton(
        onPressed: _deleteAccount,
        child: const Text(
          'アカウントを削除する',
          style: TextStyle(
            color: AppColors.grey30,
            fontSize: 13,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.grey30,
          ),
        ),
      ),
    );
  }

  // ---
  // ---ログアウトボタン
  // ---

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        icon: const Icon(
          Icons.logout_rounded,
          color: AppColors.error,
          size: 20,
        ),
        label: const Text(
          'ログアウト',
          style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.error, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: () async {
          await PushNotificationService().removeFcmToken();
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            Navigator.pushReplacementNamed(context, AppRoutes.login);
          }
        },
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
