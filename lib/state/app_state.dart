import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/dummy_data.dart';
import '../data/progressive_plan.dart';
import '../models/models.dart';

class AppState extends ChangeNotifier {
  IntervalTemplate _selectedTemplate = DummyData.todayTemplate;
  IntervalTemplate get selectedTemplate => _selectedTemplate;

  void setTemplate(IntervalTemplate template) {
    _selectedTemplate = template;
    notifyListeners();
  }

  int historyVersion = 0;
  void bumpHistoryVersion() {
    historyVersion++;
    notifyListeners();
  }

  static const _weekPrefsKey = 'progressive_plan_week';
  int currentWeek = 1;

  Future<void> loadCurrentWeek() async {
    final prefs = await SharedPreferences.getInstance();
    currentWeek = prefs.getInt(_weekPrefsKey) ?? 1;
    notifyListeners();
  }

  Future<void> setCurrentWeek(int week) async {
    currentWeek = week.clamp(1, ProgressivePlan.totalWeeks);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_weekPrefsKey, currentWeek);
  }

  // Light / Dark / System
  static const _themePrefsKey = 'theme_mode';
  ThemeMode themeMode = ThemeMode.system;

  Future<void> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_themePrefsKey);
    themeMode = switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePrefsKey, mode.name);
  }

  static const _profileImagePrefsKey = 'profile_image_path';
  String? profileImagePath;

  Future<void> loadProfileImagePath() async {
    final prefs = await SharedPreferences.getInstance();
    profileImagePath = prefs.getString(_profileImagePrefsKey);
    notifyListeners();
  }

  Future<void> setProfileImagePath(String? path) async {
    profileImagePath = path;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (path == null) {
      await prefs.remove(_profileImagePrefsKey);
    } else {
      await prefs.setString(_profileImagePrefsKey, path);
    }
  }

  int? requestedTabIndex;

  void requestTab(int index) {
    requestedTabIndex = index;
    notifyListeners();
  }

  void clearTabRequest() {
    requestedTabIndex = null;
  }

  static const _weightPrefsKey = 'user_weight_kg';
  double weightKg = 70;

  Future<void> setWeightKg(double kg) async {
    weightKg = kg;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_weightPrefsKey, kg);
  }

  static const _staminaGoalPrefsKey = 'stamina_goal_km';
  double staminaGoalKm = 24;

  Future<void> setStaminaGoalKm(double km) async {
    staminaGoalKm = km;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_staminaGoalPrefsKey, km);
  }

  Future<void> loadUserSettings() async {
    final prefs = await SharedPreferences.getInstance();
    weightKg = prefs.getDouble(_weightPrefsKey) ?? 70;
    staminaGoalKm = prefs.getDouble(_staminaGoalPrefsKey) ?? 24;
    notifyListeners();
  }
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'No AppStateScope found in context');
    return scope!.notifier!;
  }
}
