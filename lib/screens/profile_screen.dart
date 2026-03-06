import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/routes.dart';
import '../models/app_user.dart';

/// プロフィール表示画面（ナビゲーションバーから遷移）
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  AppUser? _user;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final snap =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!mounted) return;
    setState(() {
      _user = snap.exists ? AppUser.fromFirestore(snap) : null;
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
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, AppRoutes.login);
              }
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
                      const SizedBox(height: 24),

                      // Info cards
                      _infoTile(Icons.cake, '生年月日',
                          _user!.birthDate ?? '未設定'),
                      _infoTile(Icons.wc, '性別',
                          _user!.gender ?? '未設定'),
                      _infoTile(Icons.email, 'メール', _user!.email ?? ''),
                      _infoTile(Icons.local_fire_department, 'ストリーク',
                          '${_user!.streak} 日連続'),
                      _infoTile(Icons.people, 'フレンド',
                          '${_user!.friends.length} 人'),
                      _infoTile(Icons.alarm, '起床時間',
                          _user!.wakeUpTime ?? '未設定'),
                      _infoTile(Icons.schedule, 'タスク時間',
                          _user!.taskTime ?? '未設定'),

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
