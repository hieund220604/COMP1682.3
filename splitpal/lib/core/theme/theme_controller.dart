import 'package:flutter/material.dart';

import '../utils/token_manager.dart';

class ThemeController extends ChangeNotifier {
  final TokenManager _tokenManager;

  ThemeMode _themeMode;

  ThemeController({required TokenManager tokenManager})
    : _tokenManager = tokenManager,
      _themeMode = _parseThemeMode(tokenManager.getThemeMode());

  ThemeMode get themeMode => _themeMode;

  bool get isDarkThemeEnabled => _themeMode == ThemeMode.dark;

  String get themeModeLabel {
    switch (_themeMode) {
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.system:
        return 'System';
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) {
      return;
    }

    _themeMode = mode;
    await _tokenManager.saveThemeMode(_serializeThemeMode(mode));
    notifyListeners();
  }

  Future<void> setDarkThemeEnabled(bool enabled) {
    return setThemeMode(enabled ? ThemeMode.dark : ThemeMode.system);
  }

  static ThemeMode _parseThemeMode(String? mode) {
    switch (mode?.toLowerCase()) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  static String _serializeThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
        return 'system';
    }
  }
}
