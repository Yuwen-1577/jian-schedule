import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  bool _showWeekends = true;
  bool _useSystemFont = false;
  String _ocrApiUrl = 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions';
  String _ocrApiKey = '';
  String _ocrModelName = 'qwen-vl-max';
  bool _initialized = false;
  Color _seedColor = Colors.blue;
  SharedPreferences? _prefs;

  ThemeMode get themeMode => _themeMode;
  bool get showWeekends => _showWeekends;
  bool get useSystemFont => _useSystemFont;
  String get ocrApiUrl => _ocrApiUrl;
  String get ocrApiKey => _ocrApiKey;
  String get ocrModelName => _ocrModelName;
  bool get initialized => _initialized;
  Color get seedColor => _seedColor;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final themeIndex = _prefs!.getInt('themeMode') ?? 0;
    _themeMode = ThemeMode.values[themeIndex];
    _showWeekends = _prefs!.getBool('showWeekends') ?? true;
    _useSystemFont = _prefs!.getBool('useSystemFont') ?? false;
    _ocrApiUrl = _prefs!.getString('ocrApiUrl') ?? 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions';
    _ocrApiKey = _prefs!.getString('ocrApiKey') ?? '';
    _ocrModelName = _prefs!.getString('ocrModelName') ?? 'qwen-vl-max';
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
  Future<void> setUseSystemFont(bool use) async {
    _useSystemFont = use;
    await _prefs?.setBool('useSystemFont', use);
    notifyListeners();
  }

  Future<void> setOcrApiUrl(String url) async {
    _ocrApiUrl = url;
    await _prefs?.setString('ocrApiUrl', url);
    notifyListeners();
  }

  Future<void> setOcrApiKey(String key) async {
    _ocrApiKey = key;
    await _prefs?.setString('ocrApiKey', key);
    notifyListeners();
  }

  Future<void> setOcrModelName(String name) async {
    _ocrModelName = name;
    await _prefs?.setString('ocrModelName', name);
    notifyListeners();
  }
}
