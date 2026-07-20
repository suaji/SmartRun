import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'plans_screen.dart';
import 'history_screen.dart';
import 'achievements_screen.dart';
import 'profile_screen.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _screens = [
    HomeScreen(),
    PlanScreen(),
    HistoryScreen(),
    AchievementsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final requested = appState.requestedTabIndex;
    if (requested != null && requested != _index) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _index = requested);
        appState.clearTabRequest();
      });
    }

    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        backgroundColor: context.colors.surface,
        selectedItemColor: context.colors.accent,
        unselectedItemColor: context.colors.textSecondary,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt_outlined), label: 'Plans'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.emoji_events_outlined), label: 'Achievements'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}
