import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  bool _showWeekends = true;
  bool _initialized = false;

  ThemeMode get themeMode => _themeMode;
  bool get showWeekends => _showWeekends;
  bool get initialized => _initialized;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('themeMode') ?? 0;
    _themeMode = ThemeMode.values[themeIndex];
    _showWeekends = prefs.getBool('showWeekends') ?? true;
    _initialized = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', mode.index);
    notifyListeners();
  }

  Future<void> setShowWeekends(bool show) async {
    _showWeekends = show;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showWeekends', show);
    notifyListeners();
  }
}
