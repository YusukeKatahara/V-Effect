import 'package:flutter/material.dart';
import '../config/routes.dart';
import 'home_screen.dart';
import 'friends_screen.dart';
import 'profile_screen.dart';

/// Home / Friends / Profile を共通の BottomNavigationBar で切り替えるシェル
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    SizedBox.shrink(), // Placeholder (index 1)
    SizedBox.shrink(), // Camera (index 2) — handled by onTap
    FriendsScreen(),
    ProfileScreen(),
  ];

  void _onTap(int index) {
    // Camera icon — navigate to camera screen instead of switching tab
    if (index == 2) {
      Navigator.pushNamed(context, AppRoutes.camera);
      return;
    }
    // Placeholder — do nothing
    if (index == 1) return;

    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTap,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.amber,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'ホーム',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.circle, size: 8, color: Colors.transparent),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Transform.scale(
              scale: 1.2,
              child: const Icon(Icons.camera_alt),
            ),
            label: '投稿',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'フレンド',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'プロフィール',
          ),
        ],
      ),
    );
  }
}
