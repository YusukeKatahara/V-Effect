import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_colors.dart';
import '../config/routes.dart';
import '../models/app_user.dart';
import '../services/notification_service.dart';
import '../services/push_notification_service.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  AppUser? _user;
  Map<String, dynamic> _privateData = {};
  late final Stream<int> _notificationStream;

  @override
  void initState() {
    super.initState();
    _notificationStream = NotificationService().getNotificationCount();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final db  = FirebaseFirestore.instance;
    final results = await Future.wait([
      db.collection('users').doc(uid).get(),
      db.collection('users').doc(uid).collection('private').doc('data').get(),
    ]);
    final userSnap    = results[0];
    final privateSnap = results[1];
    if (!mounted) return;
    setState(() {
      _user = userSnap.exists ? AppUser.fromFirestore(userSnap) : null;
      _privateData = privateSnap.exists
          ? privateSnap.data() as Map<String, dynamic>
          : {};
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _user == null
              ? _buildEmptyState()
              : _buildContent(),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Text('プロフィールが見つかりません',
          style: TextStyle(color: AppColors.textSecondary)),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadProfile,
      color: AppColors.primary,
      backgroundColor: AppColors.bgSurface,
      child: CustomScrollView(
        slivers: [
          // ── カスタム SliverAppBar ─────────────────
          _buildSliverAppBar(),

          // ── プロフィールヘッダー ────────────────────
          SliverToBoxAdapter(child: _buildProfileHeader()),

          // ── 統計カード ─────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(child: _buildStatsRow()),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // ── 個人情報 ───────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(child: _buildInfoSection()),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // ── タスクリスト ───────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(child: _buildTaskSection()),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // ── ログアウト ─────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(child: _buildLogoutButton()),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════
  // SliverAppBar
  // ════════════════════════════════════════════
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: AppColors.bgBase,
      surfaceTintColor: Colors.transparent,
      pinned: true,
      title: const Text('プロフィール'),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined, color: AppColors.textPrimary),
          onPressed: () async {
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
            if (didUpdate == true) _loadProfile();
          },
        ),
        StreamBuilder<int>(
          stream: _notificationStream,
          builder: (context, snapshot) {
            final count = snapshot.data ?? 0;
            return IconButton(
              icon: Badge(
                isLabelVisible: count > 0,
                label: Text('$count'),
                child: const Icon(Icons.notifications_outlined,
                    color: AppColors.textPrimary),
              ),
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.notifications),
            );
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ════════════════════════════════════════════
  // プロフィールヘッダー
  // ════════════════════════════════════════════
  Widget _buildProfileHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          // アバター
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _user!.photoUrl == null ? AppColors.primaryGradient : null,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: _user!.photoUrl != null
                ? CircleAvatar(
                    radius: 40,
                    backgroundImage: NetworkImage(_user!.photoUrl!),
                  )
                : const CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.transparent,
                    child: Icon(Icons.person_rounded, size: 40, color: Color(0xFF1A1000)),
                  ),
          ),
          const SizedBox(width: 20),

          // 名前・ID
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
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                // フレンドボタン
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.friends),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people_outline_rounded,
                            size: 15, color: AppColors.textSecondary),
                        const SizedBox(width: 5),
                        Text(
                          'フレンド ${_user!.friends.length}人',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════
  // 統計カード（ストリーク等）
  // ════════════════════════════════════════════
  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: (_user!.streak) > 0
            ? AppColors.streakActiveGradient
            : const LinearGradient(
                colors: [AppColors.bgSurface, AppColors.bgElevated]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _user!.streak > 0
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.border,
        ),
        boxShadow: _user!.streak > 0
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatItem(
            icon: Icons.local_fire_department_rounded,
            value: '${_user!.streak}',
            label: '日連続',
            color: _user!.streak > 0 ? Colors.white : AppColors.textMuted,
          ),
          Container(width: 1, height: 32, color: Colors.white.withValues(alpha: 0.2)),
          _StatItem(
            icon: Icons.alarm_rounded,
            value: _privateData['wakeUpTime'] ?? '--',
            label: '起床時間',
            color: _user!.streak > 0 ? Colors.white : AppColors.textMuted,
          ),
          Container(width: 1, height: 32, color: Colors.white.withValues(alpha: 0.2)),
          _StatItem(
            icon: Icons.schedule_rounded,
            value: _privateData['taskTime'] ?? '--',
            label: 'タスク時間',
            color: _user!.streak > 0 ? Colors.white : AppColors.textMuted,
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════
  // 個人情報セクション
  // ════════════════════════════════════════════
  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: '基本情報'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.cake_outlined,
                label: '生年月日',
                value: _privateData['birthDate'] ?? '未設定',
                isFirst: true,
              ),
              const Divider(height: 1, indent: 52),
              _InfoRow(
                icon: Icons.wc_rounded,
                label: '性別',
                value: _privateData['gender'] ?? '未設定',
              ),
              const Divider(height: 1, indent: 52),
              _InfoRow(
                icon: Icons.mail_outline_rounded,
                label: 'メール',
                value: _privateData['email'] ?? '',
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════
  // タスクセクション
  // ════════════════════════════════════════════
  Widget _buildTaskSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'タスク'),
        const SizedBox(height: 12),
        if (_user!.tasks.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text('タスクが設定されていません',
                style: TextStyle(color: AppColors.textSecondary)),
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
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.primaryGradient,
                            ),
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1000),
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
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
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
  // ログアウトボタン
  // ════════════════════════════════════════════
  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
        label: const Text(
          'ログアウト',
          style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.error, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () async {
          await PushNotificationService().removeFcmToken();
          await FirebaseAuth.instance.signOut();
          if (context.mounted) {
            Navigator.pushReplacementNamed(context, AppRoutes.login);
          }
        },
      ),
    );
  }
}

// ────────────────────────────────────────────
// セクションタイトル
// ────────────────────────────────────────────
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
            gradient: AppColors.primaryGradient,
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

// ────────────────────────────────────────────
// 情報行
// ────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isFirst = false,
    this.isLast  = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textMuted),
          const SizedBox(width: 14),
          Text(label,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────
// 統計アイテム
// ────────────────────────────────────────────
class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}
