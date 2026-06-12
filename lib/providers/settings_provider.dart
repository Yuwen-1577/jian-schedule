import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  bool _showWeekends = true;
  bool _initialized = false;
  Color _seedColor = Colors.blue;
  SharedPreferences? _prefs;

  ThemeMode get themeMode => _themeMode;
  bool get showWeekends => _showWeekends;
  bool get initialized => _initialized;
  Color get seedColor => _seedColor;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final themeIndex = _prefs!.getInt('themeMode') ?? 0;
    _themeMode = ThemeMode.values[themeIndex];
    _showWeekends = _prefs!.getBool('showWeekends') ?? true;
    final seedColorValue = _prefs!.getInt('seedColor');
    if (seedColorValue != null) {
      _seedColor = Color(seedColorValue);
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs?.setInt('themeMode', mode.index);
    notifyListeners();
  }

  Future<void> setShowWeekends(bool show) async {
    _showWeekends = show;
    await _prefs?.setBool('showWeekends', show);
    notifyListeners();
  }

  Future<void> setSeedColor(Color color) async {
    _seedColor = color;
    await _prefs?.setInt('seedColor', color.toARGB32());
    notifyListeners();
  }
}
