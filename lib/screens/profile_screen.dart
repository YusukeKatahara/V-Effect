import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/routes.dart';
import '../models/app_user.dart';
import '../services/notification_service.dart';
import '../services/push_notification_service.dart';
import 'edit_profile_screen.dart';

/// プロフィール表示画面（ナビゲーションバーから遷移）
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
    final db = FirebaseFirestore.instance;

    final results = await Future.wait([
      db.collection('users').doc(uid).get(),
      db.collection('users').doc(uid).collection('private').doc('data').get(),
    ]);

    final userSnap = results[0];
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
      appBar: AppBar(
        title: const Text('プロフィール'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
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
              if (didUpdate == true) {
                _loadProfile();
              }
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
                  child: const Icon(Icons.notifications_outlined),
                ),
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.notifications);
                },
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _user == null
              ? const Center(child: Text('プロフィールが見つかりません'))
              : RefreshIndicator(
                  onRefresh: _loadProfile,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 48,
                        backgroundImage: _user!.photoUrl != null
                            ? NetworkImage(_user!.photoUrl!)
                            : null,
                        child: _user!.photoUrl == null
                            ? const Icon(Icons.person, size: 48)
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Username
                      Text(
                        _user!.username ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '@${_user!.userId ?? ''}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),

                      // Friends button
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          icon: const Icon(Icons.people, size: 20),
                          label: Text(
                            'フレンド ${_user!.friends.length}人',
                            style: const TextStyle(fontSize: 14),
                          ),
                          onPressed: () {
                            Navigator.pushNamed(context, AppRoutes.friends);
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Info cards
                      _infoTile(Icons.cake, '生年月日',
                          _privateData['birthDate'] ?? '未設定'),
                      _infoTile(Icons.wc, '性別',
                          _privateData['gender'] ?? '未設定'),
                      _infoTile(Icons.email, 'メール',
                          _privateData['email'] ?? ''),
                      _infoTile(Icons.local_fire_department, 'ストリーク',
                          '${_user!.streak} 日連続'),
                      _infoTile(Icons.alarm, '起床時間',
                          _privateData['wakeUpTime'] ?? '未設定'),
                      _infoTile(Icons.schedule, 'タスク時間',
                          _privateData['taskTime'] ?? '未設定'),

                      const SizedBox(height: 16),
                      const Text(
                        'タスク',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (_user!.tasks.isEmpty)
                        const Text('タスクが設定されていません',
                            style: TextStyle(color: Colors.grey))
                      else
                        ...List.generate(_user!.tasks.length, (i) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Text('${i + 1}',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              title: Text(_user!.tasks[i]),
                            ),
                          );
                        }),

                      // Logout
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.logout, color: Colors.redAccent),
                          label: const Text(
                            'ログアウト',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () async {
                            await PushNotificationService().removeFcmToken();
                            await FirebaseAuth.instance.signOut();
                            if (context.mounted) {
                              Navigator.pushReplacementNamed(
                                  context, AppRoutes.login);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: Text(value, style: const TextStyle(fontSize: 15)),
      ),
    );
  }
}
