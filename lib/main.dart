import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/root_shell.dart';
import 'screens/summary_screen.dart';
import 'state/app_state.dart';

void main() {
  runApp(const SmartRunCoachApp());
}

class SmartRunCoachApp extends StatefulWidget {
  const SmartRunCoachApp({super.key});

  @override
  State<SmartRunCoachApp> createState() => _SmartRunCoachAppState();
}

class _SmartRunCoachAppState extends State<SmartRunCoachApp> {
  final AppState _appState = AppState();

  @override
  void initState() {
    super.initState();
    _appState.loadCurrentWeek();
    _appState.loadThemeMode();
    _appState.loadProfileImagePath();
    _appState.loadUserSettings();
    _appState.addListener(_onAppStateChanged);
  }

  void _onAppStateChanged() => setState(() {});

  @override
  void dispose() {
    _appState.removeListener(_onAppStateChanged);
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      state: _appState,
      child: MaterialApp(
        title: AppTheme.appDisplayName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightThemeData,
        darkTheme: AppTheme.darkThemeData,
        themeMode: _appState.themeMode,
        initialRoute: '/',
        routes: {
          '/': (context) => const RootShell(),
          '/summary': (context) => const SummaryScreen(),
        },
      ),
    );
  }
}
